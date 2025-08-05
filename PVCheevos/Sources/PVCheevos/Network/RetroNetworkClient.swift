import Foundation

/// Network client for RetroAchievements API communication
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public actor RetroNetworkClient: Sendable {
    private let urlSession: URLSessionProtocol
    private let baseURL: URL

    /// Initialize the network client
    /// - Parameter urlSession: URLSession to use for requests (defaults to shared session)
    public init(urlSession: URLSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
        self.baseURL = URL(string: "https://retroachievements.org/API")!
    }

    /// Perform a GET request to the RetroAchievements API
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - parameters: Query parameters to include in the request
    /// - Returns: The response data
    /// - Throws: RetroError for various error conditions
    public func performRequest(
        endpoint: String,
        parameters: [String: String] = [:]
    ) async throws -> Data {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)!

        // Add parameters as query items
        if !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = urlComponents.url else {
            throw RetroError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("RetroAchievements-Swift-Client", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RetroError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw RetroError.unauthorized
            case 404:
                throw RetroError.notFound
            case 429:
                throw RetroError.rateLimitExceeded
            case 400...499:
                // Try to parse error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw RetroError.serverError(errorResponse.message)
                } else {
                    throw RetroError.serverError("Client error")
                }
            case 500...599:
                throw RetroError.serverError("Server error")
            default:
                throw RetroError.serverError("Unknown error")
            }
        } catch let retroError as RetroError {
            throw retroError
        } catch {
            throw RetroError.network(error)
        }
    }

        /// Perform a request and decode the JSON response
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - parameters: Query parameters to include in the request
    ///   - responseType: The type to decode the response to
    /// - Returns: The decoded response object
    /// - Throws: RetroError for various error conditions
    public func performRequest<T: Codable>(
        endpoint: String,
        parameters: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        let data = try await performRequest(endpoint: endpoint, parameters: parameters)

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(responseType, from: data)
        } catch {
            throw RetroError.invalidResponse
        }
    }

    /// Perform login with username and password
    /// - Parameters:
    ///   - username: RetroAchievements username
    ///   - password: RetroAchievements password
    /// - Returns: Login response with token if successful
    /// - Throws: RetroError if the request fails
    public func login(username: String, password: String) async throws -> LoginResponse {
        guard let url = URL(string: "https://retroachievements.org/dorequest.php") else {
            throw RetroError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("RetroAchievements-Swift-Client", forHTTPHeaderField: "User-Agent")

        // Parameters for login request
        let parameters = [
            "r": "login",
            "u": username,
            "p": password
        ]

        let body = parameters.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RetroError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw RetroError.serverError("\(httpResponse.statusCode)")
            }

            // Parse the response as JSON
            do {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                return loginResponse
            } catch {
                // If JSON parsing fails, return a generic error response
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                return LoginResponse(success: false, user: nil, avatarUrl: nil, token: nil, score: nil, softcoreScore: nil, messages: nil, permissions: nil, accountType: nil, error: responseString)
            }

        } catch let retroError as RetroError {
            throw retroError
        } catch {
            throw RetroError.networkError(error)
        }
    }

    /// Start a game session (RetroArch-style real-time gaming)
    /// - Parameters:
    ///   - username: RetroAchievements username
    ///   - token: Session token from login
    ///   - gameId: Game ID to start session for
    ///   - gameHash: Optional game hash
    /// - Returns: Session start response with unlock data
    /// - Throws: RetroError if the request fails
    public func startSession(username: String, token: String, gameId: Int, gameHash: String? = nil) async throws -> StartSessionResponse {
        guard let url = URL(string: "https://retroachievements.org/dorequest.php") else {
            throw RetroError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("PVCheevos-Swift-Client", forHTTPHeaderField: "User-Agent")

        var parameters = [
            "r": "startsession",
            "u": username,
            "t": token,
            "g": "\(gameId)"
        ]

        if let hash = gameHash {
            parameters["h"] = hash
        }

        let body = parameters.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RetroError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw RetroError.serverError("\(httpResponse.statusCode)")
            }

            let sessionResponse = try JSONDecoder().decode(StartSessionResponse.self, from: data)
            return sessionResponse

        } catch let retroError as RetroError {
            throw retroError
        } catch {
            throw RetroError.networkError(error)
        }
    }

    /// Send a ping update (Rich Presence and session maintenance)
    /// - Parameters:
    ///   - username: RetroAchievements username
    ///   - token: Session token from login
    ///   - gameId: Current game ID (optional)
    ///   - richPresence: Rich presence message (optional)
    /// - Returns: Ping response
    /// - Throws: RetroError if the request fails
    public func ping(username: String, token: String, gameId: Int? = nil, richPresence: String? = nil) async throws -> PingResponse {
        guard let url = URL(string: "https://retroachievements.org/dorequest.php") else {
            throw RetroError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("PVCheevos-Swift-Client", forHTTPHeaderField: "User-Agent")

        var parameters = [
            "r": "ping",
            "u": username,
            "t": token
        ]

        if let gameId = gameId {
            parameters["g"] = "\(gameId)"
        }

        if let presence = richPresence {
            parameters["m"] = presence
        }

        let body = parameters.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RetroError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw RetroError.serverError("\(httpResponse.statusCode)")
            }

            let pingResponse = try JSONDecoder().decode(PingResponse.self, from: data)
            return pingResponse

        } catch let retroError as RetroError {
            throw retroError
        } catch {
            throw RetroError.networkError(error)
        }
    }

}
