import Foundation
@_exported import Loadable
import SwiftUI

/// A container view that presents some loadable state.
///
/// This view will render one of three possible views depending on the current loading state.
///
public struct LoadableView<Content: View>: View {
    let content: Content

    public init<State, LoadedContent: View, LoadingContent: View, ErrorContent: View>(
        value: LoadableState<State>,
        @ViewBuilder loading: @escaping () -> LoadingContent,
        @ViewBuilder loaded: @escaping (State?) -> LoadedContent,
        @ViewBuilder failed: @escaping () -> ErrorContent
    )
    where Content == _ConditionalContent<
        _ConditionalContent<LoadingContent, LoadedContent>,
        ErrorContent
    > {
        content = {
            switch value {
            case .notLoaded, .loading(.none):
                return ViewBuilder.buildEither(
                    first: ViewBuilder.buildEither(
                        first: loading()
                    )
                )
            case let .loaded(value, _), let .loading(value):
                return ViewBuilder.buildEither(
                    first: ViewBuilder.buildEither(
                        second: loaded(value)
                    )
                )
            case .failed:
                return ViewBuilder.buildEither(
                    second: failed()
                )
            }
        }()
    }

    public var body: some View { content }
}
