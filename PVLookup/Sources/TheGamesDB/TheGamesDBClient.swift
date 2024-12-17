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

        #if DEBUG
        print("\nTheGamesDB API Request URL:")
        print(components.url?.absoluteString ?? "nil")
        #endif

        let request = URLRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        #if DEBUG
        print("\nTheGamesDB API Raw Response:")
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }

        // Try to parse as dictionary to see structure
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("\nResponse Structure:")
            print(json.keys)
            if let dataDict = json["data"] as? [String: Any] {
                print("\nData Structure:")
                print(dataDict.keys)
                if let images = dataDict["images"] {
                    print("\nImages Type:")
                    print(type(of: images))
                    print("\nImages Content:")
                    print(images)
                }
            }
        }
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TheGamesDBError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw TheGamesDBError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("\nDecoding Error for type \(T.self):")
            print(error)
            #endif
            throw error
        }
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

        #if DEBUG
        print("\nTheGamesDB API Request:")
        print("Endpoint: /v1/Games/Images")
        print("Parameters: \(params)")
        #endif

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
        let count: Int
        private let images: ImagesContainer

        init(base_url: BaseURL, count: Int, images: ImagesContainer) {
            self.base_url = base_url
            self.count = count
            self.images = images
        }

        var imagesDictionary: [String: [GameImage]] {
            switch images {
            case .dictionary(let dict): return dict
            case .array: return [:]
            }
        }

        struct BaseURL: Decodable {
            let original: String
            let small: String?
            let thumb: String?
            let cropped_center_thumb: String?
            let medium: String?
            let large: String?

            init(
                original: String,
                small: String?,
                thumb: String?,
                cropped_center_thumb: String?,
                medium: String?,
                large: String?
            ) {
                self.original = original
                self.small = small
                self.thumb = thumb
                self.cropped_center_thumb = cropped_center_thumb
                self.medium = medium
                self.large = large
            }
        }

        enum ImagesContainer: Decodable {
            case dictionary([String: [GameImage]])
            case array([GameImage])

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let dict = try? container.decode([String: [GameImage]].self) {
                    self = .dictionary(dict)
                } else if let array = try? container.decode([GameImage].self) {
                    self = .array(array)
                } else {
                    throw DecodingError.typeMismatch(
                        ImagesContainer.self,
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Expected either dictionary or array of images"
                        )
                    )
                }
            }
        }
    }

    init(code: Int, status: String, data: ImagesData) {
        self.code = code
        self.status = status
        self.data = data
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
