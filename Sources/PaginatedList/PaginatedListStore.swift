import ComposableArchitecture
import LoadableUI
import SwiftUI

/// A view that manages and displays a list of paginated content when loaded.
public struct PaginatedListStore<
    Value: Equatable & Identifiable & Sendable,
    PageType: Hashable & Sendable,
    ListContent: View,
    LoadingView: View,
    _ContentUnavailableView: View,
    FailureView: View
>: View where Value.ID: Sendable {
    public typealias Collection = PaginatedListReducer<Value, PageType>

    private let store: StoreOf<Collection>
    private let listContentView: (Collection.CollectionType) -> ListContent
    private let loadingView: LoadingView
    private let contentUnavailableView: _ContentUnavailableView
    private let failureView: FailureView

    @available(iOS 17, *)
    public init(
        store: StoreOf<PaginatedListReducer<Value, PageType>>,
        @ViewBuilder content: @escaping (Collection.CollectionType) -> ListContent
    ) where LoadingView == DefaultProgressView, _ContentUnavailableView == DefaultFailureView, FailureView == DefaultFailureView {
        self.store = store
        self.listContentView = content
        self.loadingView = DefaultProgressView()
        self.contentUnavailableView = DefaultFailureView {
            store.send(.retryButtonTapped)
        }
        self.failureView = DefaultFailureView {
            store.send(.retryButtonTapped)
        }
    }
    
    public init(
        store: StoreOf<PaginatedListReducer<Value, PageType>>,
        @ViewBuilder content: @escaping (Collection.CollectionType) -> ListContent,
        @ViewBuilder loading: @escaping () -> LoadingView,
        @ViewBuilder contentUnavailable: @escaping () -> _ContentUnavailableView,
        @ViewBuilder failureView: @escaping () -> FailureView
    ) {
        self.store = store
        self.listContentView = content
        self.loadingView = loading()
        self.contentUnavailableView = contentUnavailable()
        self.failureView = failureView()
    }

    public var body: some View {
        WithPerceptionTracking {
            LoadableView(value: store.$collection) {
                loadingView
            } loaded: { collection in
                WithPerceptionTracking {
                    if let collection {
                        listContentView(collection).environment(
                            \.loadNextPage, 
                             LoadNextPageAction(load: {
                                 await store.send(.reachedEndOfPage).finish()
                             })
                        )
                        .refreshable {
                            await store.send(.pullToRefresh).finish()
                        }
                    } else {
                        contentUnavailableView
                    }
                }
            } failed: {
                failureView
            }
        }
        .task {
            await store.send(.task).finish()
        }
    }
}

public struct DefaultProgressView: View {
    public var body: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
}

@available(iOS 17, *)
public struct DefaultFailureView: View {
    let handleRetry: () -> Void
    public var body: some View {
        ContentUnavailableView {
            Label("Could not load data", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Please check your connection and try again.")
        } actions: {
            Button("Retry") { handleRetry() }
        }
    }
}

/// A view that takes an optional next page from a paginated collection and if present, displays
/// a progress indicator that will trigger a next page load when it appears.
public struct LoadNextPageView<PageType: Hashable>: View {
    let nextPage: PageType?

    @Environment(\.loadNextPage)
    private var loadNextPage

    public init(nextPage: PageType?) {
        self.nextPage = nextPage
    }

    public var body: some View {
        if let nextPage {
            LoadingMore().task {
                await loadNextPage()
            }
            // Forces the loading view to be re-rendered every time a
            // new page of results is appended - without this the
            // progress view becomes invisible after loading the second
            // page of results.
            .id(nextPage.hashValue)
        }
    }

    private struct LoadingMore: View {
        var body: some View {
            HStack {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            }
            .listRowSeparator(.hidden, edges: .bottom)
        }
    }
}

@MainActor
struct LoadNextPageAction {
    var load: @MainActor @Sendable () async -> Void

    func callAsFunction() async {
        await load()
    }
}

extension EnvironmentValues {
    @Entry var loadNextPage = LoadNextPageAction {
        reportIssue("Load next page action was called but not set.")
    }
}
