/// A protocol that represents the abstraction of a paginated collection of values.
///
/// Paginated data represents a subset of the data available and defines the current page,
/// the values contained within that page and the next page, if there is one.
///
/// For most needs, you can use the built-in `PaginatedArraySlice` which conforms to this
/// protocol - if you need to model a more complicated response you can implement your
/// own paginated data type and conform to this protocol directly.
///
public protocol PaginatedData: Sendable {
    associatedtype Value: Sendable
    associatedtype PageType: Sendable

    /// The array of values in for the current page.
    var values: [Value] { get }

    /// The current page.
    var page: PageType { get }

    /// The next page, if there are more results available.
    var nextPage: PageType? { get }
}
