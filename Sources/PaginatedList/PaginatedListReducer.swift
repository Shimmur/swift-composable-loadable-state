import ComposableArchitecture
import Foundation

@_exported import Loadable

/// A reusable reducer for modelling domains of loadable, paginated lists of values.
///
/// This builds on top of the loadable + pagination reducer but has some common functionality out of the box, including performing
/// the initial load on appear, handling retries and pull to refresh and automatically loading the next page.
///
/// This can be combined with the `PaginatedListStore` view to build a UI that displays list content when the data is
/// loaded.
@Reducer
public struct PaginatedListReducer<Value: Equatable & Identifiable & Sendable, PageType: Equatable & Sendable>: Sendable where Value.ID: Sendable {
    public typealias CollectionType = IdentifiedPaginatedCollection<Value, PageType>

    public var firstPage: PageType
    public var loadPage: @Sendable (PageType, State) async throws -> CollectionType.PageData

    public init(
        pageSize: Int,
        loadPage: @escaping @Sendable (PageType, State) async throws -> CollectionType.PageData
    ) where PageType == NumberedPage {
        self.firstPage = NumberedPage(number: 1, size: pageSize)
        self.loadPage = loadPage
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @ObservationStateIgnored @ObservedLoadable
        public internal(set) var collection: CollectionType?
        var loadingMode: LoadingMode = .reload

        public init() {}

        #if DEBUG
        public init(collection: CollectionType) {
            self._collection = .init(initialState: .loaded(collection, isStale: false))
        }

        public init(loadState: LoadableState<CollectionType>) {
            self._collection = .init(initialState: loadState)
        }
        #endif

        public var isLoading: Bool {
            $collection.isLoading
        }

        mutating func _reload() {
            loadingMode = .reload
            $collection.readyToLoad()
        }

        mutating func _refresh() {
            loadingMode = .reload
            $collection.markAsStale()
        }

        /// Clears the existing loaded state and reloads fresh data.
        public mutating func reload() -> Effect<Action> {
            _reload()
            return .send(.loadStateChanged)
        }

        /// Performs a refresh of the currently loaded data without clearing it.
        public mutating func refresh() -> Effect<Action> {
            _refresh()
            return .send(.loadStateChanged)
        }

        public mutating func remove(ids: Set<Value.ID>) {
            guard var values = collection?.values else { return }
            for id in ids { values.remove(id: id) }
            collection?.values = values
        }

        public mutating func update(_ value: Value) {
            collection?.values[id: value.id] = value
        }
    }
    
    public enum Action {
        case task
        case pullToRefresh
        case reachedEndOfPage
        case retryButtonTapped
        case loadStateChanged
        case loadResponse(LoadableAction<CollectionType>)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                // In some circumstances, generally when presented from a view that is using observable
                // state, the task action fires twice, so we also need to allow the the load to start
                // if its already loading, or it will get stuck in a loading state.
                guard state.$collection.isNotLoaded || state.$collection.isLoading else { return .none }
                state._reload()
                return .none
            case .retryButtonTapped:
                state._reload()
                return .none
            case .pullToRefresh:
                state._refresh()
                return .none
            case .reachedEndOfPage:
                state.loadingMode = .upsertNext
                state.$collection.markAsStale()
                return .none
            case .loadStateChanged:
                // This action is just used by the public API to trigger
                // the loadable reducer logic.
                return .none
            case .loadResponse:
                return .none
            }
        }
        .loadable(
            state: \.$collection,
            action: \.loadResponse,
            firstPage: { firstPage },
            mode: \.loadingMode,
            loadPage: loadPage
        )
    }
}
