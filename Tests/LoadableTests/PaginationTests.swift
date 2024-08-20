import ComposableArchitecture
import OrderedCollections
import Foundation
import TestUtilities
import XCTest

@testable import Loadable

struct Record: Identifiable, Equatable {
    let id: Int
    let label: String

    init(id: Int, label: String = "") {
        self.id = id
        self.label = label
    }
}

@Reducer
struct PaginationTestFeature {
    let environment: Environment

    struct Environment: Sendable {
        var loadRecords: @Sendable (NumberedPage) -> PaginatedArraySlice<Record, NumberedPage>
        var loadSearchResults: @Sendable (NumberedPage) -> SearchResultsResponse
        var loadChronologicalRecords: @Sendable (TimestampedPage) -> PaginatedArraySlice<Record, TimestampedPage>
        var date: DateGenerator
    }

    struct State: Equatable {
        @Loadable
        var records: IdentifiedPaginatedCollection<Record, NumberedPage>? = nil
        @Loadable
        var searchResults: SearchResults? = nil
        @Loadable
        var chronologicalRecords: IdentifiedPaginatedCollection<Record, TimestampedPage>? = nil
        var loadingMode: LoadingMode = .upsertNext
    }

    enum Action {
        case loadMoreRecords
        case loadMoreSearchResults
        case loadable(LoadableAction<IdentifiedPaginatedCollection<Record, NumberedPage>>)
        case timestampedLoadable(LoadableAction<IdentifiedPaginatedCollection<Record, TimestampedPage>>)
        case searchResults(LoadableAction<SearchResults>)
        case reloadRecords
        case setLoadingMode(LoadingMode)
        case loadTimestampedRecords
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .reloadRecords:
                return .none
            case .loadable:
                return .none
            case let .setLoadingMode(loadingMode):
                state.loadingMode = loadingMode
                return .none
            case .loadMoreRecords:
                state.loadingMode = .upsertNext
                return .none
            case .loadMoreSearchResults:
                state.loadingMode = .upsertNext
                return .none
            case .searchResults:
                return .none
            case .timestampedLoadable:
                return .none
            case .loadTimestampedRecords:
                return .none
            }
        }
        .loadable(
            state: \.$records,
            action: \.loadable,
            firstPage: { NumberedPage(number: 1, size: 30) },
            performsLoadOn: [\.loadMoreRecords, \.reloadRecords],
            mode: \.loadingMode
        ) { [environment] page, _ in
            environment.loadRecords(page)
        }
        .loadable(
            state: \.$searchResults,
            action: \.searchResults,
            firstPage: { NumberedPage(number: 1, size: 2) },
            performsLoadOn: [\.loadMoreSearchResults],
            mode: \.loadingMode
        ) { [environment] page, _ in
            environment.loadSearchResults(page)
        }
        .loadable(
            state: \.$chronologicalRecords,
            action: \.timestampedLoadable,
            firstPage: { TimestampedPage(endDate: environment.date(), size: 10) },
            performsLoadOn: [\.loadTimestampedRecords],
            mode: \.loadingMode
        ) { [environment] page, _ in
            environment.loadChronologicalRecords(page)
        }
    }
}

class PaginationTests: XCTestCase {
    @MainActor
    func testPaginationBasics() async {
        let nextPageOfRecords: LockIsolated<[Record]> = .init([])
        let pageLimit = 3

        let store = TestStore(
            initialState: .init(),
            reducer: {
                PaginationTestFeature(
                    environment: .init(
                        loadRecords: { page in
                            PaginatedArraySlice(
                                values: nextPageOfRecords.value,
                                page: page,
                                nextPage: {
                                    if page.number < pageLimit {
                                        return .init(number: page.number + 1, size: page.size)
                                    } else {
                                        return nil
                                    }
                                }()
                            )
                        },
                        loadSearchResults: unimplemented(
                            "loadMoreSearchResults",
                            placeholder: SearchResultsResponse(
                                data: .init(results: [], totalResults: 0),
                                paginationData: .init(
                                    pageNumber: 1,
                                    pageSize: 0,
                                    hasNextPage: false
                                )
                            )
                        ),
                        loadChronologicalRecords: unimplemented(
                            "loadChronologicalRecords",
                            placeholder: .init(
                                values: [],
                                page: .init(endDate: Date(), size: 25),
                                nextPage: nil
                            )
                        ),
                        date: .constant(.now)
                    )
                )
            }
        )

        // Load the initial page of results

        nextPageOfRecords.setValue([
            Record(id: 1),
            Record(id: 2),
            Record(id: 3)
        ])

        await store.send(.loadMoreRecords) {
            $0.$records = .loading
        }

        var expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 1),
                Record(id: 2),
                Record(id: 3)
            ],
            lastPage: NumberedPage(number: 1, size: 30),
            nextPage: NumberedPage(number: 2, size: 30)
        )

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.$records = .loaded(expectedCollection)
        }

        // Load another page of results

        nextPageOfRecords.setValue([
            Record(id: 4),
            Record(id: 5),
            Record(id: 6)
        ])

        await store.send(.loadMoreRecords) {
            $0.$records = .loading(expectedCollection)
        }

        expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 1),
                Record(id: 2),
                Record(id: 3),
                Record(id: 4),
                Record(id: 5),
                Record(id: 6)
            ],
            lastPage: NumberedPage(number: 2, size: 30),
            nextPage: NumberedPage(number: 3, size: 30)
        )

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.$records = .loaded(expectedCollection)
        }

        // Load the last page of results

        nextPageOfRecords.setValue([
            Record(id: 7),
            Record(id: 8)
        ])

        await store.send(.loadMoreRecords) {
            $0.$records = .loading(expectedCollection)
        }

        expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 1),
                Record(id: 2),
                Record(id: 3),
                Record(id: 4),
                Record(id: 5),
                Record(id: 6),
                Record(id: 7),
                Record(id: 8)
            ],
            lastPage: NumberedPage(number: 3, size: 30),
            nextPage: nil
        )

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.$records = .loaded(expectedCollection)
        }

        // Try to request more records when there are no more pages to fetch.

        await store.send(.loadMoreRecords)

        // Reload the first page of records without clearing (intended for loading new
        // records in an infinite scrolling list of items).

        nextPageOfRecords.setValue([
            Record(id: 0), // a new record has appeared in the first page
            Record(id: 1),
            Record(id: 2),
            Record(id: 3)
        ])

        await store.send(.setLoadingMode(.upsertFirst)) {
            $0.loadingMode = .upsertFirst
        }

        await store.send(.reloadRecords) {
            $0.$records = .loading(expectedCollection)
        }

        expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 0),
                Record(id: 1),
                Record(id: 2),
                Record(id: 3),
                Record(id: 4),
                Record(id: 5),
                Record(id: 6),
                Record(id: 7),
                Record(id: 8)
            ],
            lastPage: NumberedPage(number: 1, size: 30),
            nextPage: nil // next page has not changed!
        )

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.$records = .loaded(expectedCollection)
        }

        // Reload the records (intended to be triggered by a pull-to-refresh)

        nextPageOfRecords.setValue([
            Record(id: 0),
            Record(id: 1),
            Record(id: 2)
        ])

        await store.send(.setLoadingMode(.reload)) {
            $0.loadingMode = .reload
        }

        await store.send(.reloadRecords) {
            $0.$records = .loading(expectedCollection)
        }

        expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 0),
                Record(id: 1),
                Record(id: 2)
            ],
            lastPage: NumberedPage(number: 1, size: 30),
            nextPage: NumberedPage(number: 2, size: 30)
        )

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.$records = .loaded(expectedCollection)
        }
    }

    @MainActor
    func testPagination_ResponseContainsDuplicateRecord() async {
        let nextPageOfRecords: LockIsolated<[Record]> = .init([
            Record(id: 1),
            Record(id: 2),
            Record(id: 3, label: "first")
        ])
        let pageLimit = 3

        let store = TestStore(
            initialState: .init(),
            reducer: {
                PaginationTestFeature(environment: .init(
                    loadRecords: { page in
                        PaginatedArraySlice(
                            values: nextPageOfRecords.value,
                            page: page,
                            nextPage: {
                                if page.number < pageLimit {
                                    return .init(number: page.number + 1, size: page.size)
                                } else {
                                    return nil
                                }
                            }()
                        )
                    },
                    loadSearchResults: unimplemented(
                        "loadMoreSearchResults",
                        placeholder: SearchResultsResponse(
                            data: .init(results: [], totalResults: 0),
                            paginationData: .init(
                                pageNumber: 1,
                                pageSize: 0,
                                hasNextPage: false
                            )
                        )
                    ),
                    loadChronologicalRecords: unimplemented(
                        "loadChronologicalRecords",
                        placeholder: .init(
                            values: [],
                            page: .init(endDate: Date(), size: 25),
                            nextPage: nil
                        )
                    ),
                    date: .constant(.now)
                ))
            }
        )

        await store.send(.loadMoreRecords) {
            $0.$records = .loading
        }

        var expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 1),
                Record(id: 2),
                Record(id: 3, label: "first")
            ],
            lastPage: NumberedPage(number: 1, size: 30),
            nextPage: NumberedPage(number: 2, size: 30)
        )

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.$records = .loaded(expectedCollection)
        }

        nextPageOfRecords.setValue([
            Record(id: 3, label: "second"),
            Record(id: 4),
            Record(id: 5)
        ])

        await store.send(.loadMoreRecords) {
            $0.$records = .loading(expectedCollection)
        }

        expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 1),
                Record(id: 2),
                Record(id: 3, label: "second"),
                Record(id: 4),
                Record(id: 5)
            ],
            lastPage: NumberedPage(number: 2, size: 30),
            nextPage: NumberedPage(number: 3, size: 30)
        )

        await store.receive(\.loadable.loadRequestCompleted.success) {
            $0.$records = .loaded(expectedCollection)
        }
    }

    @MainActor
    func testPagination_CustomCollectionType() async {
        let nextPageOfResults: LockIsolated<[SearchResult]> = .init([])
        let pageLimit = 2

        let store = TestStore(
            initialState: .init(),
            reducer: {
                PaginationTestFeature(
                    environment: .init(
                        loadRecords: unimplemented(
                            "loadRecords",
                            placeholder: .init(
                                values: [],
                                page: 0,
                                nextPage: nil
                            )
                        ),
                        loadSearchResults: { page in
                            SearchResultsResponse(
                                data: .init(
                                    results: nextPageOfResults.value,
                                    totalResults: 4
                                ),
                                paginationData: .init(
                                    pageNumber: page.number,
                                    pageSize: 2,
                                    hasNextPage: page.number < pageLimit
                                )
                            )
                        },
                        loadChronologicalRecords: unimplemented(
                            "loadChronologicalRecords",
                            placeholder: .init(
                                values: [],
                                page: .init(endDate: Date(), size: 25),
                                nextPage: nil
                            )
                        ),
                        date: .constant(.now)
                    )
                )
            }
        )

        // Load the initial page of results

        nextPageOfResults.setValue([
            SearchResult(text: "1"),
            SearchResult(text: "2")
        ])

        await store.send(.loadMoreSearchResults) {
            $0.$searchResults = .loading
        }

        var expectedCollection = SearchResults(
            values: [
                SearchResult(text: "1"),
                SearchResult(text: "2")
            ],
            totalResults: 4,
            lastPage: NumberedPage(number: 1, size: 2),
            nextPage: NumberedPage(number: 2, size: 2)
        )

        await store.receive(\.searchResults.loadRequestCompleted.success) {
            $0.$searchResults = .loaded(expectedCollection)
        }

        // Load another page of results

        nextPageOfResults.setValue([
            SearchResult(text: "3"),
            SearchResult(text: "4")
        ])

        await store.send(.loadMoreSearchResults) {
            $0.$searchResults = .loading(expectedCollection)
        }

        expectedCollection = SearchResults(
            values: [
                SearchResult(text: "1"),
                SearchResult(text: "2"),
                SearchResult(text: "3"),
                SearchResult(text: "4")
            ],
            totalResults: 4,
            lastPage: NumberedPage(number: 2, size: 2),
            nextPage: nil
        )

        await store.receive(\.searchResults.loadRequestCompleted.success) {
            $0.$searchResults = .loaded(expectedCollection)
        }
    }

    @MainActor
    func testTimestampedPagination() async {
        let now = Date()
        let lastPageDate = now.advanced(by: -60 * 60 * 24 * 7)
        let nextPageOfRecords: LockIsolated<[Record]> = .init([])

        let store = TestStore(
            initialState: .init(),
            reducer: {
                PaginationTestFeature(environment: .init(
                    loadRecords: unimplemented(
                        "loadRecords",
                        placeholder: .init(
                            values: [],
                            page: 0,
                            nextPage: nil
                        )
                    ),
                    loadSearchResults: unimplemented(
                        "loadMoreSearchResults",
                        placeholder: SearchResultsResponse(
                            data: .init(results: [], totalResults: 0),
                            paginationData: .init(
                                pageNumber: 1,
                                pageSize: 0,
                                hasNextPage: false
                            )
                        )
                    ),
                    loadChronologicalRecords: { page in
                        PaginatedArraySlice(
                            values: nextPageOfRecords.value,
                            page: page,
                            nextPage: {
                                if page.endDate > lastPageDate {
                                    return .init(endDate: lastPageDate, size: 10)
                                } else {
                                    return nil
                                }
                            }()
                        )
                    },
                    date: .constant(now)
                ))
            }
        )

        // Load the initial page of results

        nextPageOfRecords.setValue([
            Record(id: 1),
            Record(id: 2),
            Record(id: 3)
        ])

        await store.send(.loadTimestampedRecords) {
            $0.$chronologicalRecords = .loading
        }

        var expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 1),
                Record(id: 2),
                Record(id: 3)
            ],
            lastPage: TimestampedPage(endDate: now, size: 10),
            nextPage: TimestampedPage(endDate: lastPageDate, size: 10)
        )

        await store.receive(\.timestampedLoadable.loadRequestCompleted.success) {
            $0.$chronologicalRecords = .loaded(expectedCollection)
        }

        // Load another page of results

        nextPageOfRecords.setValue([
            Record(id: 4),
            Record(id: 5),
            Record(id: 6)
        ])

        await store.send(.loadTimestampedRecords) {
            $0.$chronologicalRecords = .loading(expectedCollection)
        }

        expectedCollection = IdentifiedPaginatedCollection(
            values: [
                Record(id: 1),
                Record(id: 2),
                Record(id: 3),
                Record(id: 4),
                Record(id: 5),
                Record(id: 6)
            ],
            lastPage: TimestampedPage(endDate: lastPageDate, size: 10),
            nextPage: nil
        )

        await store.receive(\.timestampedLoadable.loadRequestCompleted.success) {
            $0.$chronologicalRecords = .loaded(expectedCollection)
        }
    }
}

// MARK: - Custom pagination data types

struct SearchResult: Equatable, Hashable {
    let text: String
}

struct SearchResultsResponse: PaginatedData {
    struct Data {
        let results: [SearchResult]
        let totalResults: Int
    }

    struct PaginationData {
        let pageNumber: Int
        let pageSize: Int
        let hasNextPage: Bool
    }

    let data: Data
    let paginationData: PaginationData

    var values: [SearchResult] {
        data.results
    }

    var page: NumberedPage {
        .init(
            number: paginationData.pageNumber,
            size: paginationData.pageSize
        )
    }

    var nextPage: NumberedPage? {
        guard paginationData.hasNextPage else { return nil }

        return .init(
            number: paginationData.pageNumber + 1,
            size: paginationData.pageSize
        )
    }
}

struct SearchResults: PaginatedCollection, Equatable {
    var values: OrderedSet<SearchResult>
    let totalResults: Int
    let lastPage: NumberedPage
    let nextPage: NumberedPage?

    init(initialData: SearchResultsResponse) {
        values = OrderedSet(initialData.values)
        totalResults = initialData.data.totalResults
        lastPage = initialData.page
        nextPage = initialData.nextPage
    }

    init(
        values: OrderedSet<SearchResult>,
        totalResults: Int,
        lastPage: NumberedPage,
        nextPage: NumberedPage? = nil
    ) {
        self.values = OrderedSet(values)
        self.totalResults = totalResults
        self.lastPage = lastPage
        self.nextPage = nextPage
    }

    func upsertAppending(data: SearchResultsResponse) -> SearchResults {
        .init(
            values: values.appending(data.values),
            totalResults: totalResults,
            lastPage: data.page,
            nextPage: data.nextPage
        )
    }

    func upsertPrepending(data: SearchResultsResponse) -> SearchResults {
        .init(
            values: values.prepending(data.values),
            totalResults: totalResults,
            lastPage: data.page,
            nextPage: nextPage
        )
    }
}

extension OrderedSet {
    func appending(_ values: [Element]) -> Self {
        var newSet = self
        newSet.reserveCapacity(values.count)
        for value in values {
            newSet.updateOrAppend(value)
        }
        return newSet
    }

    func prepending(_ values: [Element]) -> Self {
        var newSet = self
        newSet.reserveCapacity(values.count)
        for value in values.reversed() {
            newSet.updateOrInsert(value, at: 0)
        }
        return newSet
    }
}
