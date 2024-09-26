import Dependencies
import DependenciesMacros
import Loadable
import Foundation

// MARK: - Interface

@DependencyClient
struct MusicBrainzClient {
    var fetchGenres: (_ page: OffsetPage) async throws -> MusicBrainz.GenreResponse
    
    enum Error: Swift.Error {
        case invalidResponse(URLResponse)
    }
}

enum MusicBrainz {
    struct GenreResponse: Codable, Equatable {
        let count: Int
        let offset: Int
        let genres: [Genre]
        
        enum CodingKeys: String, CodingKey {
            case count = "genre-count"
            case offset = "genre-offset"
            case genres
        }
    }
    
    struct Genre: Codable, Identifiable, Equatable {
        let id: UUID
        let name: String
    }
}

// MARK: - Pagination Support

extension MusicBrainz.GenreResponse {
    func paginatedData(limit: Int) -> PaginatedArraySlice<MusicBrainz.Genre, OffsetPage> {
        PaginatedArraySlice(
            values: genres,
            page: OffsetPage(limit: limit, offset: offset),
            nextPage: nextPage(limit: limit)
        )
    }
    
    private func nextPage(limit: Int) -> OffsetPage? {
        let nextOffset = offset + limit
        guard nextOffset < count else { return nil }
        return OffsetPage(limit: limit, offset: offset + limit)
    }
}

// MARK: - Live Implementation

extension MusicBrainzClient: DependencyKey {
    private static let decoder = JSONDecoder()
    
    static var liveValue: MusicBrainzClient = .init { page in
        let url = URL(string: "https://musicbrainz.org/ws/2/genre/all?fmt=json&limit=\(page.limit)&offset=\(page.offset)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw Error.invalidResponse(response)
        }
        return try decoder.decode(MusicBrainz.GenreResponse.self, from: data)
    }
}
