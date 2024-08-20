import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - Loading paginated data

/// Defines the behaviour of how loaded paginated data should be stored.
public enum LoadingMode: Sendable {
    /// Loads the next page and appends or updates the existing
    /// collection from the loaded data.
    ///
    /// This mode is typically used to fetch older pages of data when
    /// scrolling through a paginated list and triggering a load for older
    /// values.
    case upsertNext

    /// Reloads the first page and prepends or updates the existing
    /// collection from the loaded data.
    ///
    /// This mode is useful for checking for any new values in a paginated
    /// collection without losing any other older pages that might have already
    /// been loaded.
    case upsertFirst
    
    /// Reloads the first page and returns a new collection containing
    /// only the results of that page.
    case reload
}

extension Reducer where State: Sendable {
    public func loadable<Results, Data>(
        state toLoadableValue: WritableKeyPath<State, LoadableState<Results>> & Sendable,
        action toLoadableActionPath: CaseKeyPath<Action, LoadableAction<Results>>,
        firstPage: @escaping @Sendable () -> Results.PageType,
        performsLoadOn loadCaseKeyPaths: [PartialCaseKeyPath<Action> & Sendable] = [],
        mode: @escaping @Sendable (State) -> LoadingMode = { _ in .upsertNext },
        guard precondition: @escaping @Sendable (State) -> Bool = { _ in true },
        animation: Animation? = nil,
        loadPage: @escaping @Sendable (Results.PageType, State) async throws -> Data
    ) -> some ReducerOf<Self>
    where
        Action: CasePathable,
        Results: PaginatedCollection,
        Data == Results.PageData
    {
        _paginatedLoadable(
            state: toLoadableValue,
            action: AnyCasePath(toLoadableActionPath),
            firstPage: firstPage,
            shouldTriggerLoad: { $0.isOneOf(loadCaseKeyPaths) },
            mode: mode,
            guard: precondition,
            animation: animation,
            loadPage: loadPage
        )
    }

    private func _paginatedLoadable<Results: Sendable, Data>(
        state toLoadableValue: WritableKeyPath<State, LoadableState<Results>> & Sendable,
        action toLoadableAction: AnyCasePath<Action, LoadableAction<Results>>,
        firstPage: @escaping @Sendable () -> Results.PageType,
        shouldTriggerLoad: @escaping @Sendable (Action) -> Bool,
        mode: @escaping @Sendable (State) -> LoadingMode = { _ in .upsertNext },
        guard precondition: @escaping @Sendable (State) -> Bool = { _ in true },
        animation: Animation?,
        loadPage: @escaping @Sendable (Results.PageType, State) async throws -> Data
    ) -> some ReducerOf<Self>
    where
        Results: PaginatedCollection,
        Data == Results.PageData
    {
        LoadableReducer(
            parent: .init(self),
            toLoadableValue: toLoadableValue,
            toLoadableAction: toLoadableAction,
            load: { state in
                if let currentValue = state[keyPath: toLoadableValue].currentValue {
                    switch mode(state) {
                    case .upsertNext:
                        // This won't be called if there's no next page due to the precondition
                        // below however we still need to unwrap the optional next page.
                        guard let nextPage = currentValue.nextPage else {
                            throw CancellationError()
                        }

                        // Load the next page and append the results to the current collection.
                        return try await currentValue.upsertAppending(
                            data: loadPage(nextPage, state)
                        )
                    case .upsertFirst:
                        // Load the next page and prepend the results to the current collection.
                        return try await currentValue.upsertPrepending(
                            data: loadPage(firstPage(), state)
                        )
                    case .reload:
                        // Reload the first page and return a new paginated collection.
                        return try await .init(initialData: loadPage(firstPage(), state))
                    }
                } else {
                    // Load the first page and return a new paginated collection.
                    return try await .init(initialData: loadPage(firstPage(), state))
                }
            },
            shouldTriggerLoad: shouldTriggerLoad,
            precondition: { state in
                // Check any supplied precondition first.
                guard precondition(state) else { return false }

                // Additionally, check if there is actually anything to load.
                guard let currentValue = state[keyPath: toLoadableValue].currentValue else {
                    // No existing data so we we need to perform a load.
                    return true
                }
                if mode(state) == .upsertNext && currentValue.nextPage == nil {
                    // Do nothing if there's no next page to load.
                    return false
                }
                return true
            },
            animation: animation
        )
    }
}
