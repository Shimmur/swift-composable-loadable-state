import ComposableArchitecture2
import DependenciesTestSupport
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
        let loadOnMount: Bool
        
        struct State {
            @ValueObservationIgnored
            @Loadable
            var fact: String? = nil
        }
        
        enum Action {
            case loadFactButtonTapped
            case refreshButtonTapped
        }
        
        var body: some Feature {
            Load(\.$fact, loadOnMount: loadOnMount) { _ in
                await factLoader.load()
            }
            Update { state, action in
                switch action {
                case .loadFactButtonTapped:
                    state.$fact.load()
                case .refreshButtonTapped:
                    state.$fact.refresh()
                }
            }
        }
    }
    
    @MainActor
    @Test func `load on mount`() {
        let factLoader = FactLoader(load: { "this is a random fact" })
        _ = TestStore(initialState: DemoFeature.State()) {
            DemoFeature(factLoader: factLoader, loadOnMount: true)
        } changes: { state in
            state.fact = "this is a random fact"
        }
    }
    
    @MainActor
    @Test func `load on action`() {
        let factLoader = FactLoader(load: { "this is a random fact" })
        let store = TestStore(initialState: DemoFeature.State()) {
            DemoFeature(factLoader: factLoader, loadOnMount: false)
        }
        
        store.send(.loadFactButtonTapped) {
            $0.fact = "this is a random fact"
        }
    }
    
    @MainActor
    @Test(.dependency(\.exhaustivity, .off))
    func `refresh with existing value`() async {
        var currentFact = "this is a test fact"
        let factLoader = FactLoader { currentFact }
        
        let store = TestStore(initialState: DemoFeature.State()) {
            DemoFeature(factLoader: factLoader, loadOnMount: true)
        }
        currentFact = "this is a new fact"
        
        store.send(.refreshButtonTapped)
        
        store.expect {
            $0.fact = "this is a new fact"
        }
    }
    
    @MainActor
    @Test func `reload with existing value`() async {
        let clock = TestClock()
        var currentFact = "this is a test fact"
        var delayLoad = false
        let factLoader = FactLoader {
            if delayLoad {
                try? await clock.sleep(for: .seconds(1))
            }
            return currentFact
        }
        
        let store = TestStore(initialState: DemoFeature.State()) {
            DemoFeature(factLoader: factLoader, loadOnMount: false)
        }
        
        store.send(.loadFactButtonTapped) {
            $0.fact = "this is a test fact"
        }
        
        delayLoad = true
        currentFact = "this is a new fact"
        
        store.send(.loadFactButtonTapped) {
            $0.fact = nil
        }

        await clock.run()
        
        store.expect {
            $0.fact = "this is a new fact"
        }
    }
}
