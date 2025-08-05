import Foundation

/// Response from starting a game session
public struct StartSessionResponse: Codable, Sendable {
    /// Whether the session start was successful
    public let success: Bool
    /// List of unlocked achievements
    public let unlocks: [SessionUnlock]?
    /// Current server timestamp
    public let serverNow: Int?
    /// Error message if session start failed
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case success = "Success"
        case unlocks = "Unlocks"
        case serverNow = "ServerNow"
        case error = "Error"
    }
}

/// Achievement unlock information from session
public struct SessionUnlock: Codable, Sendable {
    /// Achievement ID
    public let id: Int
    /// When the achievement was unlocked (timestamp)
    public let when: Int

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case when = "When"
    }
}

/// Response from ping (Rich Presence update)
public struct PingResponse: Codable, Sendable {
    /// Whether the ping was successful
    public let success: Bool
    /// Error message if ping failed
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case success = "Success"
        case error = "Error"
    }
}
