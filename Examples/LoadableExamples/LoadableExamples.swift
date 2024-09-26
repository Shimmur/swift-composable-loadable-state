import ComposableArchitecture
import Foundation

@Reducer
struct LoadableExamples {
    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
    }
    
    enum Action {
        case path(StackActionOf<Path>)
    }
    
    @Reducer(state: .equatable)
    enum Path {
        case loadOnDemand(LoadOnDemand)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
