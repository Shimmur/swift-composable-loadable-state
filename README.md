# Loadable for The Composable Architecture

This library provides a convenient way for managing data that has to be loaded at runtime, 
for example from disk or from a HTTP API. It also has support for loading paginated data.

## The Basics

The core functionality of this library is provided by a property wrapper - `@Loadable` -
and a high-order reducer that manages how and when that data should be loaded.

For example, lets assume we have some user data that needs to be fetched from an API - you
have an API client that you can use to load that data and you want the data to be loaded 
when a view appears. The view will send an `.onAppear` action from its `onAppear` 
modifier.

First, you need to add a loadable property to your feature state - this property is marked 
as optional because all loadable data can be nil (because the data has not yet been 
loaded):

```swift
@Reducer
struct Feature {
  struct State: Equatable {
    @Loadable var profile: UserProfile?
  }
}
```

> [!IMPORTANT]
> If you're using Swift Observation tools and the `@ObservableState` macro, you will
> need to use the observable equivalent - `@ObservedLoadable`. This needs to be marked
> with `@ObservationStateIgnored` in order to work correctly - it will maintain its own
> internal observation registrar to track changes:
> 
> ```swift
> @Reducer
> struct Feature {
>   struct State: Equatable {
>     @ObservationStateIgnored @ObservedLoadable var profile: UserProfile?
>   }
> }
> ```

To configure how this data is loaded you use the `.loadable` higher-order reducer. First,
add a new action to your feature - this should wrap a `LoadableAction<T>` which is generic 
over the type of data being loaded:

```swift
@Reducer
struct Feature {
  ...
  
  enum Action {
    ...
    case profile(LoadableAction<UserProfile>)
  }
}
```

Next, attach the `.loadable` reducer - this requires a key-path to the `LoadableState<T>`, 
a case key path to the loadable action and an async throwing closure that performs the 
actual load operation and returns the loaded data. The `LoadableState<T>` value can be
accessed as the projected value of the `@Loadable` property wrapper using the 
dollar-sign prefix. The operation closure is passed a copy of the current state which 
can be useful if you need to access that data as part of the load operation. You can 
also access any dependencies you need in this closure to perform the load operation.

```swift
@Dependency(\.apiClient) var apiClient

var body: some ReducerOf<Self> {
  Reduce { state, action in
    ...
  }
  .loadable(state: \.$profile, action: \.profile) { state in
    try await apiClient.fetchUserProfile() // returns a decoded `UserProfile` value
  }
}
```

In order to trigger the initial load, we need to put `@Loadable` value into a 
"ready to load" state - `LoadableState` provides an API for controlling the load 
state of a value. We can perform this mutation in the reducer when we receive the 
`onAppear` action:

```swift
@Dependency(\.apiClient) var apiClient

var body: some ReducerOf<Self> {
  Reduce { state, action in
    switch action {
      case .onAppear:
        state.$profile.readyToLoad()
        return .none
    }
  }
  .loadable(state: \.$profile, action: \.profile) { state in
    try await apiClient.fetchUserProfile() // returns a decoded `UserProfile` value
  }
}
```

This is all that is needed to trigger the load - its important to note that the 
load state must be mutated in a reducer that the `.loadable` modifier is attached 
to or it will not be able to detect the state transition.

Performing a load when a certain action is received is a fairly common use case 
and so the `.loadable` function provides a convenience for this by allowing you to
specify the list of actions that should trigger a load declaratively. The above 
code can be rewritten as:

```swift
@Dependency(\.apiClient) var apiClient

var body: some ReducerOf<Self> {
  Reduce { state, action in
    return .none
  }
  .loadable(state: \.$profile, action: \.profile, performsLoadOn: \.onAppear) { state in
    try await apiClient.fetchUserProfile() // returns a decoded `UserProfile` value
  }
}
```

## LoadableState

This library has been designed to be state-driven as much as possible. A loadable value 
starts off in a `.notLoaded(readyToLoad: false)`. The `readyToLoad` parameter is used 
to indicate to the loadable system that a value should be loaded. In the first example
above, calling `$state.readyToLoad()` transitions to a `.notLoaded(readyToLoad: true)` 
state - when this is detected by the `.loadable` reducer a load operation is performed.

Before the load operation begins, the state transitions to a `.loading(T?)` state. The 
optional `T?` represents an existing loaded value. When loading for the first time this 
will be `nil` but the library supports reloading a value while keeping the current 
value in memory. If the load operation is successful, it will transition to a 
`.loaded(T?, isStale: false)` state. Its important to note that the `T?` is still optional 
in this state, because it may be valid for a load operation to succeed but not return 
a value. The `isStale` parameter is used to indicate to the loadable system that the 
data needs to be reloaded but not discarded (i.e. refresh).

Below is an overview of the API provided by `LoadableState`:

```swift
$state.readyToLoad()
```

This will put the loadable value into a ready-to-load state, discarding any existing 
value, and trigger the data to be reloaded from scratch.

```swift
$state.unload()
```

This will put the loadable value back into a `notLoaded` state, discarding any existing
value and will _not_ trigger a reload.

```swift
$state.markAsStale()
```

If there is already an existing value, or a load is already in progress, this will mark 
the value as stale, cancel any in-progress load operation and trigger a new load operation 
without discarding the existing value. If the value is not loaded, this will behave the 
same as calling `readyToLoad()`.

```swift
$state.loading(withCurrentValue: true)
$state.failed()
$state.loaded(with: newValue)
```

These methods can be used to explicitly transition the loadable state into a loading, failed 
or loaded state and are mainly intended for using `@LoadableState` without the `.loadable` 
reducer, allowing you to perform custom loading logic and manually manage the state 
transitions.

## Reloading

It is possible to handle data reloading without having to manually perform a state transition. 
The loadable reducer's `performsLoadOn:` parameter will automatically handle the case where 
a value is already loaded and transition to a `.loading(.some(existingValue))` state, 
preserving the existing value. This is useful where you want the existing data to remain 
visible in the UI, e.g. when handling pull to refresh:

```swift
// View
struct SomeView: View {
  ...
  
  var body: some View {
    if let profile = store.profile {
      ProfileView(profile: profile)
        .refreshable {
            store.send(.pullToRefresh)
        }
    }
  }
}

// Reducer
@Dependency(\.apiClient) var apiClient

var body: some ReducerOf<Self> {
  Reduce { state, action in
    return .none
  }
  .loadable(state: \.$profile, action: \.profile, performsLoadOn: [\.onAppear, \.pullToRefresh]) { state in
    ...
  }
}
```

To manually trigger a refresh from your own reducer logic, call `$state.markAsStale()`.

## Pagination Support

The loadable system also has full support for handling a range of paginated data types that you
might typically encounter when working with a paginated REST API.

Thie functionality is built on top of two core protocols:

### `PaginatedData`

This protocol represents a single page of loaded values. It holds on to a collection of values for 
that page, a reference to the page they belong to and an optional reference to the next page, 
if there is one.

The library provides a single concrete implementation, `PaginatedArraySlice`, which stores the 
loaded values as an `Array` and is generic over the page type. Three different page types are 
provided by the library:

* `NumberedPage` - a page represented by a size (the number of records to load per page) and a 
numeric index representing the page number.
* `OffsetPage` - a page represented by a limit (the number of records to load per page) and a 
numeric index representing the start index in the record collection.
* `TimestampedPage` - a page represented by a size (the number of records to load per page) and 
an end date.

### `PaginatedCollection`

A paginated collection represents an aggregate collection of values constructed from each page of 
data as it is loaded. It can be initialized with an intial page of data and can be upserted with 
additional pages of data as they are loaded. Additional pages can be appended or prepended to the
existing collection of data.

The library provides a single concrete implementation, `IdentifiedPaginatedCollection`, which is 
generic over its page type and any `Identifiable` value. Values are stored in an 
`IdentifiedArray` and when upserting the collection with additional pages, any existing elements 
with a matching ID are replaced with the value in the new page of data.

### Loadable Integration

There are a number of overloads of `.loadable` that are designed to be used with paginated data.

Firstly, you need to add a property to your state representing the loadable, paginated data. This 
should be an optional collection type conforming to `PaginatedCollection`. In most cases you can 
just use the provided `IdentifiedPaginatedCollection` type in combination with a page type that 
best represents your API. In this example, we will use a simple numbered page type. 

```swift
@Reducer
struct WidgetsFeature {
  typealias WidgetCollection = IdentifiedPaginatedCollection<Widget, NumberedPage>
  
  struct State: Equatable {
    @Loadable var widgets: WidgetCollection?
  }
  
  enum Action {
    case widgets(LoadableAction<WidgetCollection>)
  }
}
```

Even though each load operation will only load a single page of data, the `LoadableAction` is still 
generic over the entire aggregate collection as every load operation will yield an updated collection.

Adding the `.loadable` reducer is very similar to before, except for two main differences - the load 
operation should load a single page of data and return a value that conforms to `PaginatedData`. 
You also need to specify the first page as this is will what be loaded in a `.notLoaded` state. The 
load operation closure will be passed a reference to the page being requested as well as the current 
reducer state.

> [!TIP]
> Paginated load operations are expected to return a value that conforms to `PaginatedData`, such as
> the built-in `PaginatedArraySlice`. This will require you to decode the pagination data from your 
> API response into an appropriate page type in order to construct the paginated data. An example of
> what this API response could look like might be:
> 
> ```json5
> {
>   "values": [...],
>   "pagination": [
>     "size": 10, // the number of records in this page
>     "count": 100, // the total number of records
>     "next_page": 2 // the index of the next page, if there is one
>   ]
> }
> ```

It is down to you to decode your API response into the types that the `loadable` system requires - 
knowing if there is a next page of data will allow the loadable system to automatically handle the 
loading of the next page of data when requested.

```swift
@Reducer
struct WidgetsFeature {
  ...
  
  private let pageOne = NumberedPage(number: 1, size: 50)
  
  @Dependency(\.apiClient) var apiClient
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      ...
    }
    .loadable(state: \.$widgets, action: \.widgets, firstPage: pageOne, performsLoadOn: \.onAppear) { page, _ in
      let response = try apiClient.loadWidgets(page: page.number, count: page.size)
      return PaginatedArraySlice(
        values: response.widgets,
        page: page, // you can just pass in the current page here
        nextPage: response.pagination.nextPage.flatMap { nextPageNumber in
          // Generally you want the next page to be the same size as the current.
          return NumberedPage(page: nextPageNumber, size: page.size)
        }
      )
    }
  }
}
```

Whenever a reload is triggered, either by using the `performsLoadOn:` parameter or by
calling `markAsStale()`, the data will be loaded in one of three modes. The default 
mode - `upsertNext` - will check if there is a next page of data and if there is, it 
will call the load operation closure with the next page and upsert the returned data 
into the existing collection by _appending_ the data to the end of the collection.

The `upsertFirst` mode can be used to reload the first page of data and _prepend_ it
to the exiting collection. This will cause any new values added to be prepended to 
the beginning of the collection while any existing values will be updated with the 
latest value. This mode is useful for a frequently updated collection of values that 
are displayed with the newest values first.

The final mode, `reload`, simply triggers a load of the first page of data and replaces 
the entire collection with just that page of data - this is often the mode you want 
to use when performing a pull to refresh operation on a list of paginated data.

The `mode:` parameter takes a closure that receives the current state as a parameter 
and returns a mode - this allows you to dynamically update the mode by storing it 
in your feature state and changing it as needed. For example, if you want to perform 
a reload on pull-to-refresh, you can handle this logic in your reducer:

```swift
@Reducer
struct WidgetsFeature {
  typealias WidgetCollection = IdentifiedPaginatedCollection<Widget, NumberedPage>
  
  struct State: Equatable {
    @Loadable var widgets: WidgetCollection?
    var loadingMode = LoadingMode.upsertNext
  }
  
  enum Action {
    case widgets(LoadableAction<WidgetCollection>)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        case .pullToRefresh:
          state.loadingMode = .reload
          state.markAsStale()
          return .none
        case .widgets(.loadRequestCompleted), .widgets(.loadRequestCancelled):
          // Whenever a load request finishes we should reset the loading mode
          state.loadingMode = .upsertNext
          return .none
      }
    }
    .loadable(
      state: \.$widgets, 
      action: \.widgets, 
      firstPage: pageOne, 
      performsLoadOn: \.onAppear,
      mode: \.loadingMode // equivalent to { $0.loadingMode }
    ) { page, _ in
      ...
    }
  }
}
```

### PaginatedList

This package contains an additional library that is designed to make building 
lazily loaded paginated lists in SwiftUI and TCA even easier. This builds on 
top of the lower-level pagination and loadable APIs outlined above.

#### Reducer Integration

The library provides a built-in reducer type, `PaginatedListReducer` which 
encapsulates all of the logic required to display and load a paginated list of 
data and supports lazy pagination and pull-to-refresh.

To integrate it into your existing feature, start by adding a state property 
and action case to wrap the reducer's state and action. The reducer is generic 
over the data being individual values being loaded and the type of page:

```swift
import PaginatedList

struct GenresListFeature {
    public typealias GenresList = PaginatedListReducer<Genre, OffsetPage>

    @ObservableState
    struct State: Equatable {
        var genreList = GenresList.State()
    }
    
    enum Action {
        case genreList(GenresList.Action)
    }
}
```

Next, scope down to the state/action added above and integrate the reducer - the 
reducer's initializer requires either a page size (for numbered pages) or limit 
(for offset pages) and takes an async throwing closure that should perform the 
page load operation:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.genreList, action: \.genreList) {
        PaginatedListReducer(limit: 50) { page, _ in
            return try await client.fetchGenres(page: page)
        }
    }
}
```

#### View Integration

You can construct your list of data by wrapping a `List` view with a 
`PaginatedListStore` view - this view requires a store scoped to the paginated 
list reducer state and action and takes a view builder closure that can be 
used to construct the list. A collection of values will be provided which can 
be iterated over using a `ForEach` view.

This view is responsible for:

* Creating your list or other custom container view for displaying the data.
* Iterating over the provided collection of data and displaying it.
* If automatic pagination is required, appending the built-in `LoadNextPageView` after iterating over the collection.
* Applying any list formatting required.

The `PaginatedListStore` view will take care of setting up the SwiftUI environment 
so that the `LoadNextPageView` will send the correct action to the store to trigger 
the load of the next page (if there is one) and pull-to-refresh.

```swift
struct GeneresListView: View {
    let store: StoreOf<GenresListFeature>
    
    var body: some View {
        PaginatedListStore(store: store.scope(state: \.genreList, action: \.genreList)) { genres in
            List {
                ForEach(genres.values) { genre in
                    Text(genre.name)
                }
                LoadNextPageView(nextPage: genres.nextPage)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Genres")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```






