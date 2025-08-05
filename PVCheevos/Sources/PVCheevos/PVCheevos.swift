import Foundation

/// Main entry point for the PVCheevos library
/// Provides convenient access to RetroAchievements API functionality
public struct PVCheevos {
    /// Create a new RetroAchievements API client that automatically restores stored credentials
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static func client(urlSession: URLSessionProtocol = URLSession.shared) -> RetroAchievementsClient {
        // Create client - it will auto-restore from storage
        return RetroAchievementsClient(credentials: nil, urlSession: urlSession)
    }

    /// Check if user has stored RetroAchievements credentials
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static var hasStoredCredentials: Bool {
        return RetroCredentialsManager.shared.hasStoredCredentials
    }

    /// Check if user has a valid session
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static var hasValidSession: Bool {
        return RetroCredentialsManager.shared.hasValidSession
    }

    /// Clear all stored RetroAchievements data
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static func clearStoredCredentials() {
        RetroCredentialsManager.shared.clearAll()
    }

    /// Access to RetroArch configuration management
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static var retroArch: RetroArchConfigManager {
        return RetroArchConfigManager.shared
    }

    /// Create a new RetroAchievements API client with username and API key (legacy method)
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static func client(username: String, webAPIKey: String, urlSession: URLSessionProtocol = URLSession.shared) -> RetroAchievementsClient {
        let credentials = RetroCredentials.webAPIKey(username: username, webAPIKey: webAPIKey)
        return RetroAchievementsClient(credentials: credentials, urlSession: urlSession)
    }

    /// Create a new RetroAchievements API client with username and password (legacy method)
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static func clientWithPassword(
        username: String,
        password: String,
        urlSession: URLSessionProtocol = URLSession.shared
    ) -> RetroAchievementsClient {
        let credentials = RetroCredentials.usernamePassword(username: username, password: password)
        return RetroAchievementsClient(credentials: credentials, urlSession: urlSession)
    }

    /// Login with username and password and return client with session (legacy method)
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    public static func login(
        username: String,
        password: String,
        urlSession: URLSessionProtocol = URLSession.shared
    ) async throws -> RetroAchievementsClient {
        let client = RetroAchievementsClient(credentials: nil, urlSession: urlSession)
        _ = try await client.login(username: username, password: password)
        return client
    }
}

// MARK: - Public Exports
// Re-export all public types for convenience

// Core types
public typealias RACredentials = RetroCredentials
public typealias RAAuthenticationMethod = AuthenticationMethod
public typealias RALoginResponse = LoginResponse
public typealias RAUserSession = UserSession
public typealias RAStartSessionResponse = StartSessionResponse
public typealias RASessionUnlock = SessionUnlock
public typealias RAPingResponse = PingResponse
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public typealias RAClient = RetroAchievementsClient
public typealias RAError = RetroError

// User types
public typealias RAUserProfile = UserProfile
public typealias RAUserAwards = UserAwards
public typealias RAUserAward = UserAward
public typealias RAUserSummary = UserSummary
public typealias RAUserList = UserList

// Achievement types
public typealias RAAchievement = Achievement
public typealias RAAchievementUnlock = AchievementUnlock
public typealias RAAchievementUnlocks = AchievementUnlocks
public typealias RAUserProgress = UserProgress

// Game types
public typealias RAGame = Game
public typealias RAGameExtended = GameExtended
public typealias RAGameSummary = GameSummary
public typealias RAGameConsole = GameConsole
public typealias RAGameRank = GameRank
public typealias RAGameRankings = GameRankings

// Comment types
public typealias RAComment = Comment
public typealias RAComments = Comments

// MARK: - RetroArch Integration
public typealias RARetroArchConfigManager = RetroArchConfigManager
