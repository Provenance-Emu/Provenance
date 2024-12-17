import Foundation

/// Protocol defining TheGamesDB API client interface
protocol TheGamesDBClient: Actor {
    func searchGames(name: String, platformID: Int?) async throws -> GamesResponse
    func getGameImages(gameID: String?, types: [String]?) async throws -> ImagesResponse
}

/// Default implementation of TheGamesDB API client
actor TheGamesDBClientImpl: TheGamesDBClient {
    private let baseURL = URL(string: "https://api.thegamesdb.net")!
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String = API_KEY, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Generic fetch method for API requests
    private func fetch<T: Decodable>(_ endpoint: String, parameters: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)!

        // Add API key and other parameters
        var queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
        queryItems.append(contentsOf: parameters.map { URLQueryItem(name: $0.key, value: $0.value) })
        components.queryItems = queryItems

        let request = URLRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TheGamesDBError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw TheGamesDBError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Search for games by name
    func searchGames(name: String, platformID: Int? = nil) async throws -> GamesResponse {
        var params = ["name": name]
        if let platformID = platformID {
            params["filter[platform]"] = String(platformID)
        }
        return try await fetch("/v1.1/Games/ByGameName", parameters: params)
    }

    /// Get game images
    func getGameImages(gameID: String?, types: [String]? = nil) async throws -> ImagesResponse {
        var params = ["games_id": gameID ?? ""]
        if let types = types {
            params["filter[type]"] = types.joined(separator: ",")
        }
        return try await fetch("/v1/Games/Images", parameters: params)
    }
}

// MARK: - Response Types

struct GamesResponse: Decodable {
    let code: Int
    let status: String
    let data: GamesData

    struct GamesData: Decodable {
        let games: [Game]
    }
}

struct Game: Decodable {
    let id: Int
    let game_title: String
    let platform: Int?
}

struct ImagesResponse: Decodable {
    let code: Int
    let status: String
    let data: ImagesData

    struct ImagesData: Decodable {
        let base_url: BaseURL
        let images: [String: [GameImage]]

        struct BaseURL: Decodable {
            let original: String
            let small: String?
            let thumb: String?
        }
    }
}

struct GameImage: Decodable {
    let id: Int
    let type: String
    let side: String?
    let filename: String
    let resolution: String?
}

enum TheGamesDBError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
}
