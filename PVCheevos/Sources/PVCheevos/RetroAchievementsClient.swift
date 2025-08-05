import Foundation

/// Main client for accessing the RetroAchievements API
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public actor RetroAchievementsClient: Sendable {
    private let networkClient: RetroNetworkClient
    private let credentialsManager = RetroCredentialsManager.shared

    /// Current authenticated session
    @MainActor public private(set) var currentSession: UserSession?

    /// Initialize with optional credentials for backwards compatibility
    public init(credentials: RetroCredentials? = nil, urlSession: URLSessionProtocol = URLSession.shared) {
        self.networkClient = RetroNetworkClient(urlSession: urlSession)

        // Try to restore session from storage on initialization
        Task {
            await restoreSession()
        }
    }

    /// Restore session from stored credentials
    @MainActor
    public func restoreSession() async {
        // Try to load existing session first
        if let token = credentialsManager.loadSessionToken(),
           let profile = credentialsManager.loadUserProfile() {
            let credentials = RetroCredentials.token(username: profile.user, token: token)
            currentSession = UserSession(user: profile, token: token, credentials: credentials)
            return
        }

        // If no session, try to auto-login with stored credentials
        if let storedCreds = credentialsManager.loadCredentials() {
            do {
                _ = try await login(username: storedCreds.username, password: storedCreds.password)
            } catch {
                // Clear invalid stored credentials
                credentialsManager.clearAll()
            }
        }
    }

    /// Check if user is currently authenticated
    @MainActor
    public var isAuthenticated: Bool {
        return currentSession != nil
    }

    /// Get current username if authenticated
    @MainActor
    public var currentUsername: String? {
        return currentSession?.user.user
    }

    /// Get authentication parameters based on current session
    private var authParameters: [String: String] {
        get async throws {
            // Check for current session first
            let session = await getCurrentSession()

            if let session = session {
                return [
                    "z": session.user.user,
                    "y": session.token
                ]
            }

            // If no session, throw authentication error
            throw RetroError.authenticationFailed
        }
    }

    /// Merge authentication parameters with additional parameters
    /// - Parameter parameters: Additional parameters to include
    /// - Returns: Combined parameters including authentication
    private func parameters(_ parameters: [String: String] = [:]) async throws -> [String: String] {
        let authParams = try await authParameters
        return authParams.merging(parameters) { _, new in new }
    }

    /// Perform login and store session
    /// - Parameters:
    ///   - username: RetroAchievements username
    ///   - password: RetroAchievements password
    /// - Throws: RetroError if login fails
    private func performLogin(username: String, password: String) async throws {
        let loginResponse = try await networkClient.login(username: username, password: password)

        guard loginResponse.success, let token = loginResponse.token else {
            throw RetroError.authenticationFailed
        }

        // Create user profile from login response
        let userProfile = UserProfile(
            user: loginResponse.user ?? username,
            ulid: nil,
            userPic: loginResponse.avatarUrl,
            memberSince: nil,
            richPresenceMsg: nil,
            lastGameID: nil,
            contribCount: nil,
            contribYield: nil,
            totalPoints: loginResponse.score,
            totalSoftcorePoints: loginResponse.softcoreScore,
            totalTruePoints: nil,
            permissions: loginResponse.permissions,
            untracked: nil,
            id: nil,
            userWallActive: nil,
            motto: nil
        )

        let credentials = RetroCredentials.token(username: username, token: token)
        let session = UserSession(user: userProfile, token: token, credentials: credentials)

        await MainActor.run {
            currentSession = session
        }

        // Save credentials and session data
        credentialsManager.saveCredentials(username: username, password: password)
        credentialsManager.saveSessionToken(token)
        credentialsManager.saveUserProfile(userProfile)

        // Sync credentials to RetroArch config
        RetroArchConfigManager.shared.updateCredentials(username: username, password: password)
    }

    /// Perform login with username and password
    @MainActor
    public func login(username: String, password: String) async throws -> UserSession {
        try await performLogin(username: username, password: password)
        guard let session = currentSession else {
            throw RetroError.authenticationFailed
        }
        return session
    }

    /// Get current session
    @MainActor
    public func getCurrentSession() -> UserSession? {
        return currentSession
    }

    /// Logout current user
    @MainActor
    public func logout() {
        currentSession = nil
        credentialsManager.clearAll()
    }

    // MARK: - Session-Based Gaming (RetroArch-style)

    /// Start a game session for real-time achievement tracking
    public func startGameSession(gameId: Int, gameHash: String? = nil) async throws -> StartSessionResponse {
        guard let session = await getCurrentSession() else {
            throw RetroError.authenticationFailed
        }

        return try await networkClient.startSession(
            username: session.user.user,
            token: session.token,
            gameId: gameId,
            gameHash: gameHash
        )
    }

    /// Send ping update for Rich Presence and session maintenance
    public func sendPing(gameId: Int? = nil, richPresence: String? = nil) async throws -> PingResponse {
        guard let session = await getCurrentSession() else {
            throw RetroError.authenticationFailed
        }

        return try await networkClient.ping(
            username: session.user.user,
            token: session.token,
            gameId: gameId,
            richPresence: richPresence
        )
    }

    // MARK: - Data API (requires API key or will fail with session token)
}

// MARK: - Authentication
extension RetroAchievementsClient {
    /// Validate the current credentials by attempting to fetch user profile
    /// - Returns: True if credentials are valid, false otherwise
    public func validateCredentials() async -> Bool {
        do {
            _ = try await getUserProfile(username: credentialsManager.loadCredentials()?.username ?? "")
            return true
        } catch {
            return false
        }
    }
}

// MARK: - User Endpoints
extension RetroAchievementsClient {
    /// Get user profile information
    /// - Parameter username: The username to get profile for
    /// - Returns: User profile information
    /// - Throws: RetroError for various error conditions
    public func getUserProfile(username: String) async throws -> UserProfile {
        return try await networkClient.performRequest(
            endpoint: "API_GetUserProfile.php",
            parameters: try await parameters(["u": username]),
            responseType: UserProfile.self
        )
    }

    /// Get user awards
    /// - Parameter username: The username to get awards for
    /// - Returns: User awards information
    /// - Throws: RetroError for various error conditions
    public func getUserAwards(username: String) async throws -> UserAwards {
        return try await networkClient.performRequest(
            endpoint: "API_GetUserAwards.php",
            parameters: try await parameters(["u": username]),
            responseType: UserAwards.self
        )
    }

        /// Get users that I follow
    /// - Parameters:
    ///   - offset: Number of entries to skip (default: 0)
    ///   - count: Number of entries to return, max 500 (default: 100)
    /// - Returns: List of users being followed
    /// - Throws: RetroError for various error conditions
    public func getUsersIFollow(offset: Int = 0, count: Int = 100) async throws -> UserList {
        return try await networkClient.performRequest(
            endpoint: "API_GetUsersIFollow.php",
            parameters: try await parameters([
                "o": String(offset),
                "c": String(min(count, 500))
            ]),
            responseType: UserList.self
        )
    }

    /// Get users following me
    /// - Parameters:
    ///   - offset: Number of entries to skip (default: 0)
    ///   - count: Number of entries to return, max 500 (default: 100)
    /// - Returns: List of followers
    /// - Throws: RetroError for various error conditions
    public func getUsersFollowingMe(offset: Int = 0, count: Int = 100) async throws -> UserList {
        return try await networkClient.performRequest(
            endpoint: "API_GetUsersFollowingMe.php",
            parameters: try await parameters([
                "o": String(offset),
                "c": String(min(count, 500))
            ]),
            responseType: UserList.self
        )
    }
}

// MARK: - Achievement Endpoints
extension RetroAchievementsClient {
    /// Get users who unlocked a specific achievement
    /// - Parameter achievementId: The achievement ID to query
    /// - Returns: Achievement unlock information
    /// - Throws: RetroError for various error conditions
    public func getAchievementUnlocks(achievementId: Int) async throws -> AchievementUnlocks {
        return try await networkClient.performRequest(
            endpoint: "API_GetAchievementUnlocks.php",
            parameters: try await parameters(["a": String(achievementId)]),
            responseType: AchievementUnlocks.self
        )
    }
}

// MARK: - Game Endpoints
extension RetroAchievementsClient {
        /// Get detailed game information with achievements
    /// - Parameters:
    ///   - gameId: The game ID to query
    ///   - username: Username for user-specific progress (optional)
    /// - Returns: Detailed game information
    /// - Throws: RetroError for various error conditions
    public func getGame(gameId: Int, username: String? = nil) async throws -> Game {
        var params = ["i": String(gameId)]
        if let username = username {
            params["u"] = username
        }

        return try await networkClient.performRequest(
            endpoint: "API_GetGame.php",
            parameters: try await parameters(params),
            responseType: Game.self
        )
    }

    /// Get extended game information with user progress
    /// - Parameters:
    ///   - gameId: The game ID to query
    ///   - username: Username for progress information
    /// - Returns: Game information with user progress
    /// - Throws: RetroError for various error conditions
    public func getGameExtended(gameId: Int, username: String) async throws -> GameExtended {
        return try await networkClient.performRequest(
            endpoint: "API_GetGameExtended.php",
            parameters: try await parameters([
                "i": String(gameId),
                "u": username
            ]),
            responseType: GameExtended.self
        )
    }

    /// Get game rankings
    /// - Parameter gameId: The game ID to get rankings for
    /// - Returns: Game rankings
    /// - Throws: RetroError for various error conditions
    public func getGameRankings(gameId: Int) async throws -> GameRankings {
        return try await networkClient.performRequest(
            endpoint: "API_GetGameRanking.php",
            parameters: try await parameters(["i": String(gameId)]),
            responseType: GameRankings.self
        )
    }
}

// MARK: - Comment Endpoints
extension RetroAchievementsClient {
        /// Get comments on a user's wall
    /// - Parameters:
    ///   - username: The username to get comments for
    ///   - offset: Number of entries to skip (default: 0)
    ///   - count: Number of entries to return, max 500 (default: 100)
    /// - Returns: Comments from the user's wall
    /// - Throws: RetroError for various error conditions
    public func getCommentsOnUserWall(username: String, offset: Int = 0, count: Int = 100) async throws -> Comments {
        return try await networkClient.performRequest(
            endpoint: "API_GetUserComments.php",
            parameters: try await parameters([
                "u": username,
                "o": String(offset),
                "c": String(min(count, 500))
            ]),
            responseType: Comments.self
        )
    }

    /// Get comments on a game's wall
    /// - Parameters:
    ///   - gameId: The game ID to get comments for
    ///   - offset: Number of entries to skip (default: 0)
    ///   - count: Number of entries to return, max 500 (default: 100)
    /// - Returns: Comments from the game's wall
    /// - Throws: RetroError for various error conditions
    public func getCommentsOnGameWall(gameId: Int, offset: Int = 0, count: Int = 100) async throws -> Comments {
        return try await networkClient.performRequest(
            endpoint: "API_GetGameComments.php",
            parameters: try await parameters([
                "i": String(gameId),
                "o": String(offset),
                "c": String(min(count, 500))
            ]),
            responseType: Comments.self
        )
    }

    /// Get comments on an achievement's wall
    /// - Parameters:
    ///   - achievementId: The achievement ID to get comments for
    ///   - offset: Number of entries to skip (default: 0)
    ///   - count: Number of entries to return, max 500 (default: 100)
    /// - Returns: Comments from the achievement's wall
    /// - Throws: RetroError for various error conditions
    public func getCommentsOnAchievementWall(achievementId: Int, offset: Int = 0, count: Int = 100) async throws -> Comments {
        return try await networkClient.performRequest(
            endpoint: "API_GetAchievementComments.php",
            parameters: try await parameters([
                "i": String(achievementId),
                "o": String(offset),
                "c": String(min(count, 500))
            ]),
            responseType: Comments.self
        )
    }
}
