import ComposableArchitecture
import Loadable
import LoadableUI
import Foundation
import SwiftUI

@Reducer
struct LoadOnDemand {
    @ObservableState
    struct State: Equatable {
        @ObservationStateIgnored @ObservedLoadable var fact: String?
        var number: Int = 0
    }
    
    enum Action: BindableAction {
        case loadButtonTapped
        case binding(BindingAction<State>)
        case fact(LoadableAction<String>)
    }
    
    @Dependency(\.continuousClock)
    private var clock
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .loadButtonTapped:
                state.$fact.readyToLoad()
                return .none
            case .fact:
                return .none
            case .binding:
                return .none
            }
        }
        .loadable(state: \.$fact, action: \.fact) { state in
            // Add a short delay so the state transition is visible
            try await clock.sleep(for: .milliseconds(200))
            // In practice this would be wrapped up in a client dependency.
            let session = URLSession.shared
            let url = URL(string: "http://numbersapi.com/\(state.number)")!
            let (data, _) = try await session.data(from: url)
            return String(data: data, encoding: .utf8)
        }
    }
}

struct LoadOnDemandView: View {
    @Bindable
    var store: StoreOf<LoadOnDemand>
    
    var body: some View {
        List {
            Section("Choose a number") {
                Stepper(value: $store.number) {
                    LabeledContent("Number", value: String(store.number))
                }
                Button("Load Fact") {
                    store.send(.loadButtonTapped)
                }
                .disabled(store.$fact.isLoading)
            }
            switch store.$fact {
            case .notLoaded:
                EmptyView()
            case .loading:
                Section {
                    // Give this an explicit identity to work around a bug
                    // where it doesn't display more than once.
                    ProgressView().id(UUID())
                }
            case .loaded(.some(let fact), _):
                Section {
                    Text(fact)
                }
            case .loaded(.none, _):
                Section {
                    Text("No fact available.")
                }
            case .failed:
                Section {
                    Text("Error: fact could not be loaded.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Load On Demand")
        .navigationBarTitleDisplayMode(.inline)
    }
}
