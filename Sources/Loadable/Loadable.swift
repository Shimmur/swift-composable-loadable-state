import ComposableArchitecture
import CustomDump
import Foundation

/// A property wrapper for a loadable value.
///
/// Loadable properties track their load state and provide access to the loaded value as the `wrappedValue`. If you need
/// direct access to the `LoadableState` value, you should use the`projectedValue`.
@propertyWrapper
public struct Loadable<Value: Sendable> {
    private var state: LoadableState<Value>

    /// Provides direct access to the loaded value.
    ///
    /// When setting a value, it will always result in a `loaded` state - to set the underlying loadable
    /// state use the public APIs provided. If you need to reset the state to a `notLoaded` state, you
    /// should call the `unload` function on the projected value itself.
    public var wrappedValue: Value? {
        get { state.currentValue }
        set { state = .loaded(newValue) }
    }

    /// Provides access to the underlying loadable state.
    public var projectedValue: LoadableState<Value> {
        get { self.state }
        set { self.state = newValue }
    }

    /// Initializes a new loadable value when it is not possible for loading to fail.
    public init(wrappedValue: Value? = nil) {
        if let value = wrappedValue {
            state = .loaded(value)
        } else {
            state = .notLoaded()
        }
    }

    #if DEBUG
    /// Allows a loadable value to be initialized in a specific state, usually in previews and snapshot tests.
    public init(initialState: LoadableState<Value>) {
        state = initialState
    }
    #endif
}

extension Loadable: CustomDumpRepresentable {
    public var customDumpValue: Any { state }
}

extension Loadable: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(reflecting: self.wrappedValue as Any)
    }
}

extension Loadable: Equatable where Value: Equatable {}
extension Loadable: Hashable where Value: Hashable {}
extension Loadable: Sendable where Value: Sendable {}
