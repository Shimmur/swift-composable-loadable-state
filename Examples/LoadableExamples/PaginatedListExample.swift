import ComposableArchitecture
import Loadable
import PaginatedList
import Foundation
import SwiftUI

@Reducer
struct PaginatedListExample {
    public typealias GenresList = PaginatedListReducer<MusicBrainz.Genre, OffsetPage>
    
    @ObservableState
    struct State: Equatable {
        @ObservationStateIgnored
        var genreList = GenresList.State()
    }
    
    enum Action {
        case genreList(GenresList.Action)
    }
    
    @Dependency(MusicBrainzClient.self)
    private var client
    
    @Dependency(\.continuousClock)
    private var clock
    
    var body: some ReducerOf<Self> {
        Scope(state: \.genreList, action: \.genreList) {
            PaginatedListReducer(limit: 50) { page, _ in
                try await clock.sleep(for: .milliseconds(200))
                let response = try await client.fetchGenres(page: page)
                return response.paginatedData(limit: page.limit)
            }
        }
        ._printChanges()
    }
}

struct PaginatedListExampleView: View {
    let store: StoreOf<PaginatedListExample>
    
    var body: some View {
        // By default this view supports pull to refresh and lazy pagination on scroll.
        PaginatedListStore(store: store.scope(state: \.genreList, action: \.genreList)) { genres in
            List {
                ForEach(genres.values) { genre in
                    Text(genre.name)
                }
                // This view will trigger loading the next page when it appears.
                LoadNextPageView(nextPage: genres.nextPage)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Paginated List")
        .navigationBarTitleDisplayMode(.inline)
    }
}
