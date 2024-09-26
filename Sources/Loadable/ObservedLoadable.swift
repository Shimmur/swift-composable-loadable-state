import ComposableArchitecture
import CustomDump
import Foundation

/// A property wrapper for a loadable value that can be used with `@ObservableState`.
///
/// Loadable properties track their load state and provide access to the loaded value as the `wrappedValue`. If you need
/// direct access to the `LoadableState` value, you should use the`projectedValue`.
@propertyWrapper
public struct ObservedLoadable<Value: Sendable>: Observable, Perceptible {
    private var state: LoadableState<Value>

    /// Provides direct access to the loaded value.
    ///
    /// When setting a value, it will always result in a `loaded` state - to set the underlying loadable
    /// state use the public APIs provided. If you need to reset the state to a `notLoaded` state, you
    /// should call the `unload` function on the projected value itself.
    public var wrappedValue: Value? {
        get {
            access(keyPath: \.state)
            return state.currentValue
        }
        set {
            withMutation(keyPath: \.state) {
                state = .loaded(newValue)
            }
        }
    }

    /// Provides access to the underlying loadable state.
    public var projectedValue: LoadableState<Value> {
        get {
            access(keyPath: \.state)
            return self.state
        }
        set {
            withMutation(keyPath: \.state) {
                self.state = newValue
            }
        }
    }

    /// Initializes a new loadable value when it is not possible for loading to fail.
    public init(wrappedValue: Value? = nil) {
        if let value = wrappedValue {
            state = .loaded(value)
        } else {
            state = .notLoaded()
        }
    }

    /// Allows a loadable value to be initialized in a specific state, usually in previews and snapshot tests.
    public init(initialState: LoadableState<Value>) {
        state = initialState
    }

    private let _$perceptionRegistrar = Perception.PerceptionRegistrar(isPerceptionCheckingEnabled: _isLoadablePerceptionCheckingEnabled)

    internal nonisolated func access<Member>(
        keyPath: KeyPath<Self, Member>,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        _$perceptionRegistrar.access(
            self,
            keyPath: keyPath,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    internal nonisolated func withMutation<Member, MutationResult>(
        keyPath: KeyPath<Self, Member>,
        _ mutation: () throws -> MutationResult
    ) rethrows -> MutationResult {
        try _$perceptionRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    }
}

extension ObservedLoadable: CustomDumpRepresentable {
    public var customDumpValue: Any { state }
}

extension ObservedLoadable: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(reflecting: self.wrappedValue as Any)
    }
}

extension ObservedLoadable: Equatable where Value: Equatable {}
extension ObservedLoadable: Hashable where Value: Hashable {}
extension ObservedLoadable: Sendable where Value: Sendable {}

let _isLoadablePerceptionCheckingEnabled: Bool = {
  if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
    return false
  } else {
    return true
  }
}()
