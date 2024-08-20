import CasePaths
import ComposableArchitecture
import Foundation

/// An generic type that encapsulates some data that needs to be loaded - normally from an API -
/// and can be reloaded.
@CasePathable
public enum LoadableState<Value: Sendable>: Sendable {
    /// No request to load this data has been made.
    ///
    /// The `readyToLoad` parameter, when set to `true`, indicates that the data should be
    /// loaded by the loadable system.
    case notLoaded(readyToLoad: Bool = false)

    /// The data is being loaded -  the presence of an existing value indicates that this is a reload.
    case loading(Value?)

    /// The data has been loaded successfully.
    ///
    /// The loaded value is still optional as it may be perfectly valid for a load operation to succeed
    /// but not return any data.
    ///
    /// The `isStale` property indicates whether or not the value is out of date - when this is
    /// set to `true`, it will automatically trigger the value to be reloaded.
    case loaded(Value?, isStale: Bool = false)

    /// Loading failed with an error.
    case failed

    /// Returns the current value, if one is loaded (or reloading).
    public var currentValue: Value? {
        get {
            switch self {
            case let .loaded(.some(value), _), let .loading(.some(value)):
                return value
            case .notLoaded, .loading(.none), .loaded(.none, _), .failed:
                return nil
            }
        }
    }

    /// Indicates that the loadable failed to load.
    public var hasFailed: Bool {
        self.is(\.failed) // swiftlint:ignore:this explicit_self
    }

    /// Indicates that the loadable is currently loading
    public var isLoading: Bool {
        self.is(\.loading) // swiftlint:ignore:this explicit_self
    }

    /// Indicates that the loadable is currently loading and has an existing value.
    public var isReloading: Bool {
        isLoading && currentValue != nil
    }

    /// Indicates that the loadable is loading and has no existing value.
    public var isPerformingInitialLoad: Bool {
        isLoading && currentValue == nil
    }

    /// Indicates that the loadable is loaded.
    public var isLoaded: Bool {
        self.is(\.loaded) // swiftlint:ignore:this explicit_self
    }

    /// Indicates that the loadable is not loaded.
    public var isNotLoaded: Bool {
        self.is(\.notLoaded) // swiftlint:ignore:this explicit_self
    }

    public var isStale: Bool {
        guard case let .loaded(_, isStale) = self else {
            return false
        }
        return isStale
    }

    public var isReadyToLoad: Bool {
        guard case let .notLoaded(readyToLoad) = self else {
            return false
        }
        return readyToLoad
    }

    public var requiresLoading: Bool {
        isStale || isReadyToLoad
    }
}

// MARK: - Mutating Loadable State

extension LoadableState {
    /// Resets the loadable value back to a not loaded state.
    public mutating func unload() {
        self = .notLoaded
    }

    /// Tells the loadable system that the data should be loaded.
    ///
    /// - Note: You should generally call this when the loadable value is in either a
    /// `notLoaded` state and you want to trigger the initial load, or if it is in a failed state
    /// and you want to attempt to load it again.
    ///
    /// Calling this while in a `.loaded` state will immediately discard the current data and
    /// put the value into a `notLoaded` state again before triggering a load - if you want to
    /// perform a refresh while keeping the existing value, use `markAsStale` instead.
    ///
    /// Calling this while in a `loading` state will cause any in-flight load effect to be cancelled
    /// and a new one started.
    public mutating func readyToLoad() {
        self = .notLoaded(readyToLoad: true)
    }

    /// Will mark any loaded value as stale and automatically trigger a reload.
    ///
    /// If the state is already in a "loading" state, it will be reset back to a stale loaded state - this
    /// supports calling `markAsStale()` multiple times in quick succession in a debounced
    /// reload scenario (e.g. search).
    ///
    /// If in a not loaded state, it will mark the value as ready to load instead.
    public mutating func markAsStale() {
        if isLoaded || isLoading {
            self = .loaded(currentValue, isStale: true)
        } else {
            readyToLoad()
        }
    }

    /// Explicitly moves into a loading state - this is useful when you're using `Loadable`
    /// without using the `.loadable` reducer modifier (manual loading).
    public mutating func loading(withCurrentValue: Bool = true) {
        self = .loading(withCurrentValue ? currentValue : nil)
    }

    /// Explicitly moves into a failed state - this is useful when you're using `Loadable`
    /// without using the `.loadable` reducer modifier (manual loading).
    public mutating func failed() {
        self = .failed
    }

    /// Explicitly moves into a failed state - this is useful when you're using `Loadable`
    /// without using the `.loadable` reducer modifier (manual loading).
    public mutating func loaded(with newValue: Value?) {
        self = .loaded(newValue, isStale: false)
    }
}

// MARK: - Factory Methods

extension LoadableState {
    public static var notLoaded: Self {
        .notLoaded(readyToLoad: false)
    }

    public static var loading: Self {
        .loading(nil)
    }
}

// MARK: - Conformances

extension LoadableState: Equatable where Value: Equatable {}
extension LoadableState: Hashable where Value: Hashable {}
