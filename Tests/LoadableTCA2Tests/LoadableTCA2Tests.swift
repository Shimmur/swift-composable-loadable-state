import ComposableArchitecture2
import LoadableTCA2
import Testing

struct FactLoader {
    var load: nonisolated(nonsending) () async -> String
}

@Suite
struct LoadableTCA2Tests {
    @Feature
    struct DemoFeature {
        let factLoader: FactLoader
        let autoload: Bool
        
        struct State {
            @ValueObservationIgnored @Loadable
            var fact: String? = nil
        }
        
        enum Action {
            case loadFactButtonTapped
        }
        
        var body: some Feature {
            Load(\.$fact, loadOnMount: autoload) { _ in
                await factLoader.load()
            }
            Update { state, action in
                switch action {
                case .loadFactButtonTapped:
                    state.$fact.load()
                }
            }
        }
    }
    
    @MainActor
    @Test func `load on mount`() {
        let factLoader = FactLoader(load: { "this is a random fact" })
        let store = TestStore(initialState: DemoFeature.State()) {
            DemoFeature(factLoader: factLoader, autoload: true)
        } changes: { state in
            state.fact = "this is a random fact"
        }
    }
    
    @MainActor
    @Test func `load on action`() {
        let factLoader = FactLoader(load: { "this is a random fact" })
        let store = TestStore(initialState: DemoFeature.State()) {
            DemoFeature(factLoader: factLoader, autoload: false)
        }
        
        store.send(.loadFactButtonTapped) {
            $0.fact = "this is a random fact"
        }
    }
}
