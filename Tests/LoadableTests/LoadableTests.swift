import Combine
import ComposableArchitecture
import Dependencies
import XCTest

@testable import Loadable

class LoadableTests: XCTestCase {
    @Reducer
    struct TestFeature {
        @Dependency(\.loadableExample)
        private var testDependency: ExampleDependency

        struct State: Equatable {
            @Loadable
            var currentValue: String?
            @Loadable
            var currentValueTwo: String?
        }

        enum Action {
            case loadable(LoadableAction<String>)
            case loadableTwo(LoadableAction<String>)
            case refresh
            case triggersLoad
            case triggersLoadManually
            case triggersCancellation
            case refreshBoth
        }

        var body: some ReducerOf<Self> {
            Reduce { state, action in
                switch action {
                case .refresh:
                    state.$currentValue.markAsStale()
                    return .none
                case .refreshBoth:
                    state.$currentValue.markAsStale()
                    state.$currentValueTwo.markAsStale()
                    return .none
                case .triggersLoadManually:
                    state.$currentValue.readyToLoad()
                    return .none
                case .triggersCancellation:
                    return .cancelLoadTask(for: \.$currentValue, on: &state)
                case .loadable, .loadableTwo, .triggersLoad:
                    return .none
                }
            }
        }
    }
    
    @MainActor
    func testBasics() async {
        let store = TestStore(
            initialState: .init(),
            reducer: {
                TestFeature()
                    .loadable(
                        state: \.$currentValue,
                        action: \.loadable,
                        performsLoadOn: \.triggersLoad
                    ) { _ in
                        @Dependency(\.loadableExample)
                        var dependency
                        return await dependency.execute()
                    }
            }
        )

        store.dependencies.loadableExample.execute = {
            "loaded from mock"
        }

        await store.send(.triggersLoad) {
            $0.$currentValue = .loading(nil)
        }

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.currentValue = "loaded from mock"
        }
        
        store.dependencies.loadableExample.execute = {
            "refreshed value"
        }
        
        await store.send(.refresh) {
            $0.$currentValue = .loading("loaded from mock")
        }
        
        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.currentValue = "refreshed value"
        }
    }

    @MainActor
    func testMultipleLoadables() async {
        let scheduler = DispatchQueue.test
        let store = TestStore(
            initialState: .init(),
            reducer: {
                TestFeature()
                    .loadable(
                        state: \.$currentValue,
                        action: \.loadable,
                        performsLoadOn: \.triggersLoad
                    ) { _ in
                        @Dependency(\.loadableExample)
                        var dependency
                        return await dependency.execute()
                    }
                    .loadable(
                        state: \.$currentValueTwo,
                        action: \.loadableTwo,
                        performsLoadOn: \.triggersLoad
                    ) { _ in
                        @Dependency(\.loadableExample)
                        var dependency
                        try await scheduler.sleep(for: .seconds(1))
                        return await dependency.execute()
                    }
            }
        )

        store.dependencies.loadableExample.execute = {
            "loaded from mock"
        }

        await store.send(.triggersLoad) {
            $0.$currentValue = .loading(nil)
            $0.$currentValueTwo = .loading(nil)
        }

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.currentValue = "loaded from mock"
        }

        await scheduler.run()

        await store.receive(\.loadableTwo.loadRequestCompleted.success) {
            $0.currentValueTwo = "loaded from mock"
        }

        store.dependencies.loadableExample.execute = {
            "reloaded from mock"
        }

        await store.send(.refreshBoth) {
            $0.$currentValue = .loading("loaded from mock")
            $0.$currentValueTwo = .loading("loaded from mock")
        }

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.currentValue = "reloaded from mock"
        }

        await scheduler.run()

        await store.receive(\.loadableTwo.loadRequestCompleted.success) {
            $0.currentValueTwo = "reloaded from mock"
        }
    }

    @MainActor
    func testFailure() async {
        struct TestError: Error, Equatable {}

        let store = TestStore(
            initialState: .init(),
            reducer: {
                TestFeature().loadable(
                    state: \.$currentValue,
                    action: \.loadable,
                    performsLoadOn: \.triggersLoad
                ) { _ in
                    throw TestError()
                }
            }
        )

        await store.send(.triggersLoad) {
            $0.$currentValue = .loading(nil)
        }

        await store.receive(\.loadable.loadRequestCompleted.failure) {
            $0.$currentValue = .failed
        }
    }
    
    @MainActor
    func testManualFirstLoad() async {
        let store = TestStore(
            initialState: .init(),
            reducer: {
                TestFeature().loadable(
                    state: \.$currentValue,
                    action: \.loadable,
                    performsLoadOn: \.triggersLoad
                ) { _ in "example value" }
            }
        )

        await store.send(.triggersLoadManually) {
            $0.$currentValue = .loading(nil)
        }

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.currentValue = "example value"
        }
    }

    @MainActor
    func testExplicitCancellation() async {
        let scheduler = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: {
                TestFeature().loadable(
                    state: \.$currentValue,
                    action: \.loadable,
                    performsLoadOn: \.triggersLoad
                ) { _ in
                    try await scheduler.sleep(for: .seconds(1))
                    return "loaded from mock"
                }
            }
        )

        await store.send(.triggersLoad) {
            $0.$currentValue = .loading(nil)
        }

        await store.send(.triggersCancellation) {
            $0.$currentValue = .notLoaded
        }

        await store.receive(\.loadable.loadRequestCancelled)
    }

    @MainActor
    func testOperationThrowsCancellationError() async {
        let store = TestStore(
            initialState: .init(),
            reducer: {
                TestFeature().loadable(
                    state: \.$currentValue,
                    action: \.loadable,
                    performsLoadOn: \.triggersLoad
                ) { _ in
                    throw CancellationError()
                }
            }
        )

        await store.send(.triggersLoad) {
            $0.$currentValue = .loading(nil)
        }

        await store.receive(\.loadable.loadRequestCancelled)
    }

    @MainActor
    func testTaskCancellation() async {
        XCTExpectFailure(
            """
            This test will fail as it isn't currently possible to handle
            external cancellation by feeding an action back into the store.
            I'm leaving this test here for now as a reminder that this is
            something we'd like to be able to handle at some point.
            """
        )
        let scheduler = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: {
                TestFeature().loadable(
                    state: \.$currentValue,
                    action: \.loadable,
                    performsLoadOn: \.triggersLoad
                ) { _ in
                    try await scheduler.sleep(for: .seconds(1))
                    return "loaded from mock"
                }
            }
        )

        let task = await store.send(.triggersLoad) {
            $0.$currentValue = .loading(nil)
        }

        await task.cancel()

        await store.receive(\.loadable.loadRequestCancelled)
    }
}

struct ExampleDependency: Sendable {
    var execute: @Sendable () async -> String
}

extension ExampleDependency: TestDependencyKey {
    static var testValue: ExampleDependency {
        ExampleDependency(execute: unimplemented("ExampleDependency.execute", placeholder: ""))
    }
}

extension DependencyValues {
    var loadableExample: ExampleDependency {
        get { self[ExampleDependency.self] }
        set { self[ExampleDependency.self] = newValue }
    }
}
