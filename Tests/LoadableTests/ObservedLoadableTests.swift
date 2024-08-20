import ComposableArchitecture
import OrderedCollections
import Foundation
import TestUtilities
import XCTest

@testable import Loadable

final class ObservedLoadableTests: XCTestCase {
    @ObservableState
    struct State: Equatable {
        @ObservationStateIgnored
        @ObservedLoadable
        var value: Int? = nil
    }

    func testBasics() async {
        var state = State()
        let valueDidChange = expectation(description: "value.didChange")
        valueDidChange.expectedFulfillmentCount = 2

        withPerceptionTracking {
            _ = state.value
        } onChange: {
            valueDidChange.fulfill()
        }

        state.$value = .loading

        withPerceptionTracking {
            _ = state.value
        } onChange: {
            valueDidChange.fulfill()
        }

        state.$value = .loaded(100, isStale: false)
        
        XCTAssertEqual(100, state.value)

        await fulfillment(of: [valueDidChange], timeout: 0.1)
    }

    @MainActor
    func testStore() async {
        let store = Store<State, Void>(initialState: State()) {
            Reduce { state, _ in
                if let value = state.value {
                    state.value = value + 1
                } else {
                    state.value = 1
                }
                return .none
            }
        }
        let valueDidChange = expectation(description: "value.didChange")
        valueDidChange.expectedFulfillmentCount = 2

        withPerceptionTracking {
            _ = store.value
        } onChange: {
            valueDidChange.fulfill()
        }

        store.send(())
        XCTAssertEqual(1, store.value)

        withPerceptionTracking {
            _ = store.value
        } onChange: {
            valueDidChange.fulfill()
        }

        store.send(())
        XCTAssertEqual(2, store.value)

        await fulfillment(of: [valueDidChange], timeout: 0.1)
    }
}
