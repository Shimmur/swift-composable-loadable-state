import Foundation

// MARK: - Built-in Page Types

private let DEFAULT_PAGE_SIZE = 25

/// Describes a page of data indexed by an auto-incrementing page number.
public struct NumberedPage: Equatable, Hashable, Sendable {
    /// The index of this page within the paginated collection.
    public let number: Int

    /// The number of records in this page.
    public let size: Int

    public init(number: Int, size: Int) {
        self.number = number
        self.size = size
    }
}

extension NumberedPage: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self.number = value
        self.size = DEFAULT_PAGE_SIZE
    }
}

/// Describes a page of data indexed by a timestamp.
public struct TimestampedPage: Equatable, Hashable, Sendable {
    /// The end date for this page.
    public let endDate: Date

    /// The number of records in this page.
    public let size: Int

    public init(endDate: Date, size: Int) {
        self.endDate = endDate
        self.size = size
    }
}

/// Describes a page of data that can be fetched by specifying a limit and record offset.
public struct OffsetPage: Equatable, Hashable, Sendable {
    /// The maximum number of records to fetch.
    public let limit: Int

    /// The offset from the first record in the collection.
    public let offset: Int

    public init(limit: Int, offset: Int) {
        self.limit = limit
        self.offset = offset
    }
}
