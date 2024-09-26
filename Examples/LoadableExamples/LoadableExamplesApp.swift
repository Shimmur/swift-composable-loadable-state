import ComposableArchitecture
import SwiftUI

@main
struct LoadableExamplesApp: App {
    private var store = Store(initialState: LoadableExamples.State()) {
        LoadableExamples()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
    
    private struct ContentView: View {
        @Bindable
        var store: StoreOf<LoadableExamples>
        
        var body: some View {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                RootView()
            } destination: { destination in
                switch destination.case {
                case let .loadOnDemand(store):
                    LoadOnDemandView(store: store)
                }
            }
        }
    }
    
    private struct RootView: View {
        var body: some View {
            List {
                Section("Examples") {
                    NavigationLink(state: LoadableExamples.Path.State.loadOnDemand(.init())) {
                        Text("Load on demand")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Loadable Examples")
        }
    }
}
