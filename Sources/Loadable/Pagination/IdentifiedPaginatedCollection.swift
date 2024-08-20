import IdentifiedCollections

/// Represents an aggregated collection of paginated, identifiable values.
public struct IdentifiedPaginatedCollection<Value: Identifiable, PageType>: PaginatedCollection, Sendable
where Value: Sendable, Value.ID: Sendable, PageType: Sendable {
    /// A slice of data representing a single page within this collection.
    public typealias DataSlice = PaginatedArraySlice<Value, PageType>

    /// The accumulated set of loaded paginated data.
    public var values: IdentifiedArray<Value.ID, Value>

    /// The index of the last page accumulated.
    public let lastPage: PageType

    /// The next page to be loaded, if there is one
    public let nextPage: PageType?

    public init(
        values: IdentifiedArrayOf<Value>,
        lastPage: PageType,
        nextPage: PageType?
    ) {
        self.values = values
        self.lastPage = lastPage
        self.nextPage = nextPage
    }
}

extension IdentifiedPaginatedCollection: Equatable where Value: Equatable, PageType: Equatable {}
extension IdentifiedPaginatedCollection: Hashable where Value: Hashable, PageType: Hashable {}

extension IdentifiedPaginatedCollection {
    /// Initializes a new paginated collection from an initial slice of paginated values.
    public init(initialData data: DataSlice) {
        self.init(
            values: .init(uniqueElements: data.values),
            lastPage: data.page,
            nextPage: data.nextPage
        )
    }

    /// Returns a new paginated collection merging and appending the results of another paginated slice of data.
    public func upsertAppending(data: PageData) -> Self {
        .init(
            values: uniquelyAppend(values, with: data.values),
            lastPage: data.page,
            nextPage: data.nextPage
        )
    }

    /// Returns a new paginated collection merging and prepending the results of another paginated response.
    ///
    /// - This does not change the `nextPage` value.
    public func upsertPrepending(data: PageData) -> Self {
        .init(
            values: uniquelyPrepend(values, with: data.values),
            lastPage: data.page,
            nextPage: nextPage
        )
    }

    private func uniquelyAppend(
        _ values: IdentifiedArrayOf<Value>,
        with otherValues: [Value]
    ) -> IdentifiedArrayOf<Value> {
        var newValues = values
        newValues.reserveCapacity(otherValues.count)
        for value in otherValues {
            newValues.updateOrAppend(value)
        }
        return newValues
    }

    private func uniquelyPrepend(
        _ values: IdentifiedArrayOf<Value>,
        with otherValues: [Value]
    ) -> IdentifiedArrayOf<Value> {
        var newValues = values
        newValues.reserveCapacity(otherValues.count)
        for value in otherValues.reversed() {
            newValues.insert(value, at: 0)
        }
        return newValues
    }
}
