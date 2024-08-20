import ComposableArchitecture
import Combine
import Foundation
import SwiftUI

@CasePathable
public enum LoadableAction<Value: Equatable> {
    case loadRequestCompleted(Result<Value?, Error>)
    case loadRequestCancelled
}

extension LoadableAction: Sendable where Value: Sendable {}

// MARK: - Reducer

public struct LoadableTaskCancellationId<Root>: Hashable {
    let keyPath: PartialKeyPath<Root>
}

fileprivate extension LoadableState {
    /// Cancels any in-flight load operation and resets the loadable state to its previous state.
    mutating func cancelLoadOperation<ParentState, ParentAction>(id: KeyPath<ParentState, Self>) -> Effect<ParentAction> {
        if let currentValue {
            self = .loaded(currentValue, isStale: false)
        } else {
            self = .notLoaded
        }
        return .cancel(id: LoadableTaskCancellationId(keyPath: id))
    }
}

extension Effect {
    static func cancelLoadTask<ParentState, ParentAction, Value>(
        for keyPath: WritableKeyPath<ParentState, LoadableState<Value>>,
        on state: inout ParentState
    ) -> Effect<ParentAction> {
        var loadableState = state[keyPath: keyPath]
        let effect: Effect<ParentAction> = loadableState.cancelLoadOperation(id: keyPath)
        state[keyPath: keyPath] = loadableState
        return effect
    }
}

@Reducer
public struct LoadableReducer<Parent: Reducer, Value: Equatable & Sendable>: Sendable where Parent.State: Sendable {
    // We wrap the parent in UncheckedSendable so that `.loadable` can be chained on to built-in TCA
    // reducers which do not currently conform to Sendable.
    let parent: UncheckedSendable<Parent>
    let toLoadableValue: WritableKeyPath<Parent.State, LoadableState<Value>> & Sendable
    let toLoadableAction: AnyCasePath<Parent.Action, LoadableAction<Value>>
    let load: @Sendable (Parent.State) async throws -> Value?
    let shouldTriggerLoad: @Sendable (Parent.Action) -> Bool
    let precondition: @Sendable (Parent.State) -> Bool
    let animation: Animation?

    var taskID: LoadableTaskCancellationId<Parent.State> {
        .init(keyPath: toLoadableValue)
    }

    public var body: some ReducerOf<Parent> {
        Reduce { state, action in
            // The ordering of these combined reducers is important - the core loadable reducer
            // must be run before the parent reducer to ensure that the loadable reducer performs
            // state mutations before the parent reducer is called - this allows for the
            // parent reducer to layer behaviour on top of the loadable changes.
            var loadableEffect: Effect<Parent.Action> = .none
            if let loadableAction = toLoadableAction.extract(from: action) {
                loadableEffect = runLoadable(state: &state[keyPath: toLoadableValue], action: loadableAction)
            }

            // Check to see if there's already a load effect in progress.
            let wasLoadingBefore = state[keyPath: toLoadableValue].isLoading

            // Now we can run the parent reducer.
            let parentEffect = parent.value.reduce(into: &state, action: action)

            var loadEffect: Effect<Parent.Action> = .none
            let loadableState = state[keyPath: toLoadableValue]
            if loadableState.requiresLoading || shouldTriggerLoad(action) {
                // If the current action is one that should trigger an automatic load, or the current
                // value has been marked as stale, we will trigger a new load effect. We run this after the
                // parent reducer to give it a chance to mutate the loadable state to trigger reloads.
                // We will trigger a new load effect even if one was already running because load effects
                // cancel in-flight ones automatically.
                loadEffect = runLoadTask(state: &state).map(toLoadableAction.embed)
            } else if case .notLoaded(readyToLoad: false) = loadableState, wasLoadingBefore {
                // It is also possible that the parent reducer reset the loadable back into a `.notLoaded`
                // state while a load effect was in progress - if this happens any in-flight load effect should
                // be cancelled.
                loadEffect = .concatenate(
                    .cancel(id: taskID),
                    .send(toLoadableAction.embed(.loadRequestCancelled), animation: animation)
                )
            }
            return .merge(loadableEffect, parentEffect, loadEffect)
        }
    }

    private func runLoadable(state: inout LoadableState<Value>, action: LoadableAction<Value>) -> Effect<Parent.Action> {
        switch action {
        case let .loadRequestCompleted(.success(value)):
            state.loaded(with: value)
            return .none

        case let .loadRequestCompleted(.failure(error)):
            if !(error is CancellationError) {
                state.failed()
            }
            return .none

        case .loadRequestCancelled:
            return .none
        }
    }

    private func runLoadTask(state: inout Parent.State) -> Effect<LoadableAction<Value>> {
        guard precondition(state) else { return .none }

        state[keyPath: toLoadableValue].loading()
        // There is a race condition bug with TCA cancellation where calling .cancellable on
        // an async `.run` effect causes the cancellable to be set up inside the async task
        // - this means it is possible for another action to be received by the store that
        // attempts to cancel this effect before this effect starts executing - because the
        // .cancel effect runs synchronously it can end up happening too soon. By wrapping
        // the `.run` inside a `.merge` with a publisher effect, and calling `.cancellable`
        // on _that_, the publisher implementation of cancellable is used instead and this
        // sets up the cancellable synchronously.
        return .merge(
            .publisher { Empty(completeImmediately: true) },
            .run { [state, animation, load] send in
                let result = await Result { try await load(state) }
                switch result {
                case .success:
                    await send(.loadRequestCompleted(result), animation: animation)
                case let .failure(error) where error is CancellationError:
                    await send(.loadRequestCancelled, animation: animation)
                case .failure:
                    await send(.loadRequestCompleted(result), animation: animation)
                }
            }
        )
        .cancellable(id: taskID, cancelInFlight: true)
    }
}

// MARK: - Public API

extension Reducer where State: Sendable {
    public func loadable<Value>(
        state toLoadableValue: WritableKeyPath<State, LoadableState<Value>> & Sendable,
        action toLoadableAction: AnyCasePath<Action, LoadableAction<Value>>,
        guard precondition: @escaping @Sendable (State) -> Bool = { _ in true },
        animation: Animation? = nil,
        load: @escaping @Sendable (State) async throws -> Value?
    ) -> some Reducer<State, Action> {
        LoadableReducer(
            parent: .init(self),
            toLoadableValue: toLoadableValue,
            toLoadableAction: toLoadableAction,
            load: load,
            shouldTriggerLoad: { _ in false },
            precondition: precondition,
            animation: animation
        )
    }

    public func loadable<Value>(
        state toLoadableValue: WritableKeyPath<State, LoadableState<Value>> & Sendable,
        action toLoadableActionPath: CaseKeyPath<Action, LoadableAction<Value>>,
        performsLoadOn loadCaseKeyPaths: PartialCaseKeyPath<Action> & Sendable...,
        guard precondition: @escaping @Sendable (State) -> Bool = { _ in true },
        animation: Animation? = nil,
        load: @escaping @Sendable (State) async throws -> Value?
    ) -> some Reducer<State, Action> where Action: CasePathable {
        LoadableReducer(
            parent: .init(self),
            toLoadableValue: toLoadableValue,
            toLoadableAction: AnyCasePath(toLoadableActionPath),
            load: load,
            shouldTriggerLoad: { @Sendable action in
                action.isOneOf(loadCaseKeyPaths)
            },
            precondition: precondition,
            animation: animation
        )
    }
}

extension CasePathable {
    func isOneOf<KeyPaths: Sequence>(_ keyPaths: KeyPaths) -> Bool where KeyPaths.Element == PartialCaseKeyPath<Self> {
      keyPaths.contains { self.is($0) }
    }
}
