import ComposableArchitecture2

@Feature
public struct Load<State, Action, Value> {
    private let stateKeyPath: WritableKeyPath<State, _Loadable<Value>.State>
    private let loadOnMount: Bool
    private let load: nonisolated(nonsending) (State) async throws -> Value
    
    public init(
        _ stateKeyPath: WritableKeyPath<State, _Loadable<Value>.State>,
        loadOnMount: Bool = true,
        load: nonisolated(nonsending) @escaping (State) async throws -> Value
    ) {
        self.stateKeyPath = stateKeyPath
        self.loadOnMount = loadOnMount
        self.load = load
    }
    
    public var body: some FeatureProtocol<State, Action> {
        Scope(state: stateKeyPath, action: \.never) {
            _Loadable {
                try await load(store.state)
            }
            .onMount { state in
                if self.loadOnMount {
                    state.load()
                }
            }
        }
    }
}

@Feature
public struct _Loadable<Value> {
    public typealias Action = Never
    
    let load: nonisolated(nonsending) () async throws -> Value
    
    public struct State {
        var value: Value?
        
        @Trigger
        public var load
        
        @Trigger
        public var refresh
        
        @StoreTaskID
        public var loadRequest
        
        public var isLoading: Bool {
            loadRequest.isRunning
        }
    }
    
    public var body: some Feature {
        EmptyFeature()
            .onTrigger(store.load) { state in
                state.value = nil
                store.addTask(id: state.loadRequest) {
                    try await loadValue()
                }
            }
            .onTrigger(store.refresh) { state in
                store.addTask(id: state.loadRequest) {
                    try await loadValue()
                }
            }
    }
    
    private nonisolated(nonsending) func loadValue() async throws {
        let loadedValue = try await load()
        try store.modify { $0.value = loadedValue }
    }
}

@propertyWrapper
public struct Loadable<Value> {
    private var state: _Loadable<Value>.State
    
    public init(wrappedValue: Value?) {
        self.state = .init(value: wrappedValue)
    }
    
    public var wrappedValue: Value? {
        state.value
    }
    
    public var projectedValue: _Loadable<Value>.State {
        get { state }
        set { state = newValue }
    }
}
