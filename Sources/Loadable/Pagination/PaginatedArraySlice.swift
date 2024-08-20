/// Represents a slice of paginated data that belongs to a specific page of results, represented as an array of values.
public struct PaginatedArraySlice<Value: Sendable, PageType: Sendable>: PaginatedData {
    /// The data for this page.
    public let values: [Value]

    /// The page to which this data relates.
    public let page: PageType

    /// The next available page, if there is one.
    public let nextPage: PageType?

    public init(
        values: [Value],
        page: PageType,
        nextPage: PageType?
    ) {
        self.values = values
        self.page = page
        self.nextPage = nextPage
    }
}

extension PaginatedArraySlice {
    /// Transforms a paginated array of values into a paginated array of mapped values.
    public func map<T>(_ transform: (Value) throws -> T) rethrows -> PaginatedArraySlice<T, PageType> {
        .init(values: try values.map(transform), page: page, nextPage: nextPage)
    }
}

extension PaginatedArraySlice: Equatable where Value: Equatable, PageType: Equatable {}
