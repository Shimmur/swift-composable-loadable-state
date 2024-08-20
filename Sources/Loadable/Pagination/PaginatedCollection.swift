/// Represents an aggregated collection of paginated values built up from multiple pages of data as they are loaded.
public protocol PaginatedCollection {
    associatedtype Values: Collection
    associatedtype PageType
    associatedtype PageData: PaginatedData where PageData.Value == Values.Element, PageData.PageType == PageType

    /// The accumulated values loaded over multiple paginated requests.
    var values: Values { get set }

    /// The index of the last page that was accumulated.
    var lastPage: PageType { get }

    /// The next page to be loaded, if there is more data available.
    var nextPage: PageType? { get }

    /// Initializes a new paginated collection from some initial data (typically the first page).
    init(initialData: PageData)

    /// Returns a new paginated collection by appending the given page of data, updating any existing rows with the same ID.
    func upsertAppending(data: PageData) -> Self

    /// Returns a new paginated collection by prepending the given page of data, updating any existing rows with the same ID.
    func upsertPrepending(data: PageData) -> Self
}

public extension PaginatedCollection {
    /// Indicates if the collection has any values.
    var isEmpty: Bool {
        values.isEmpty
    }

    /// Indicates if there are more pages available to load.
    var hasNextPage: Bool {
        nextPage != nil
    }
}

public extension PaginatedCollection where PageType == NumberedPage {
    /// Returns the page number of the last loaded page.
    var pageNumber: Int {
        lastPage.number
    }
}
