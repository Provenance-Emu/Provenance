import Foundation

/// Manages secure storage of RetroAchievements credentials
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public final class RetroCredentialsManager: @unchecked Sendable {
    public static let shared = RetroCredentialsManager()

    private let userDefaults = UserDefaults.standard
    private let usernameKey = "ra_username"
    private let passwordKey = "ra_password_encoded"
    private let tokenKey = "ra_session_token"
    private let userProfileKey = "ra_user_profile"
    private let queue = DispatchQueue(label: "com.pvcheevos.credentials", qos: .userInitiated)

    private init() {}

    /// Save username and password securely
    public func saveCredentials(username: String, password: String) {
        queue.async {
            self.userDefaults.set(username, forKey: self.usernameKey)
            // Simple encoding for password (in production, use Keychain)
            let encodedPassword = Data(password.utf8).base64EncodedString()
            self.userDefaults.set(encodedPassword, forKey: self.passwordKey)
        }
    }

    /// Save session token
    public func saveSessionToken(_ token: String) {
        queue.async {
            self.userDefaults.set(token, forKey: self.tokenKey)
        }
    }

    /// Save user profile
    public func saveUserProfile(_ profile: UserProfile) {
        queue.async {
            if let data = try? JSONEncoder().encode(profile) {
                self.userDefaults.set(data, forKey: self.userProfileKey)
            }
        }
    }

    /// Load stored credentials
    public func loadCredentials() -> (username: String, password: String)? {
        return queue.sync {
            guard let username = userDefaults.string(forKey: usernameKey),
                  let encodedPassword = userDefaults.string(forKey: passwordKey),
                  let passwordData = Data(base64Encoded: encodedPassword),
                  let password = String(data: passwordData, encoding: .utf8) else {
                return nil
            }
            return (username: username, password: password)
        }
    }

    /// Load stored session token
    public func loadSessionToken() -> String? {
        return queue.sync {
            return userDefaults.string(forKey: tokenKey)
        }
    }

    /// Load stored user profile
    public func loadUserProfile() -> UserProfile? {
        return queue.sync {
            guard let data = userDefaults.data(forKey: userProfileKey),
                  let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
                return nil
            }
            return profile
        }
    }

    /// Check if user has stored credentials
    public var hasStoredCredentials: Bool {
        return queue.sync {
            return loadCredentials() != nil
        }
    }

    /// Check if user has a valid session
    public var hasValidSession: Bool {
        return queue.sync {
            return loadSessionToken() != nil && loadUserProfile() != nil
        }
    }

    /// Clear all stored credentials and session data
    public func clearAll() {
        queue.async {
            self.userDefaults.removeObject(forKey: self.usernameKey)
            self.userDefaults.removeObject(forKey: self.passwordKey)
            self.userDefaults.removeObject(forKey: self.tokenKey)
            self.userDefaults.removeObject(forKey: self.userProfileKey)
        }
    }

    /// Clear only session data (keep credentials for re-login)
    public func clearSession() {
        queue.async {
            self.userDefaults.removeObject(forKey: self.tokenKey)
            self.userDefaults.removeObject(forKey: self.userProfileKey)
        }
    }
}

/// Authentication method for RetroAchievements API
public enum AuthenticationMethod: Sendable {
    /// Direct web API key authentication
    case webAPIKey(username: String, apiKey: String)
    /// Username and password authentication
    case usernamePassword(username: String, password: String)
    /// Already authenticated with token
    case authenticated(username: String, token: String)
}

/// Credentials for RetroAchievements API authentication
public struct RetroCredentials: Sendable {
    /// The authentication method to use
    public let authMethod: AuthenticationMethod

    /// The username for the RetroAchievements account
    public var username: String {
        switch authMethod {
        case .webAPIKey(let username, _),
             .usernamePassword(let username, _),
             .authenticated(let username, _):
            return username
        }
    }

    /// Create credentials with web API key
    /// - Parameters:
    ///   - username: The RetroAchievements username
    ///   - webAPIKey: The web API key from the user's profile settings
    /// - Returns: Credentials configured for web API key authentication
    public static func webAPIKey(username: String, webAPIKey: String) -> RetroCredentials {
        return RetroCredentials(authMethod: .webAPIKey(username: username, apiKey: webAPIKey))
    }

    /// Create credentials with username and password
    /// - Parameters:
    ///   - username: The RetroAchievements username
    ///   - password: The RetroAchievements password
    /// - Returns: Credentials configured for username/password authentication
    public static func usernamePassword(username: String, password: String) -> RetroCredentials {
        return RetroCredentials(authMethod: .usernamePassword(username: username, password: password))
    }

    /// Create credentials with existing token
    /// - Parameters:
    ///   - username: The RetroAchievements username
    ///   - token: The authentication token
    /// - Returns: Credentials configured for token authentication
    public static func token(username: String, token: String) -> RetroCredentials {
        return RetroCredentials(authMethod: .authenticated(username: username, token: token))
    }

    /// Initialize credentials with authentication method
    /// - Parameter authMethod: The authentication method to use
    public init(authMethod: AuthenticationMethod) {
        self.authMethod = authMethod
    }

    /// Legacy initializer for backward compatibility
    /// - Parameters:
    ///   - username: The RetroAchievements username
    ///   - webAPIKey: The web API key from the user's profile settings
    public init(username: String, webAPIKey: String) {
        self.authMethod = .webAPIKey(username: username, apiKey: webAPIKey)
    }
}

/// Response from login API call
public struct LoginResponse: Codable, Sendable {
    /// Whether the login was successful
    public let success: Bool
    /// Username
    public let user: String?
    /// Avatar URL
    public let avatarUrl: String?
    /// Authentication token
    public let token: String?
    /// User score
    public let score: Int?
    /// Softcore score
    public let softcoreScore: Int?
    /// Message count
    public let messages: Int?
    /// User permissions
    public let permissions: Int?
    /// Account type
    public let accountType: String?
    /// Error message if login failed
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case success = "Success"
        case user = "User"
        case avatarUrl = "AvatarUrl"
        case token = "Token"
        case score = "Score"
        case softcoreScore = "SoftcoreScore"
        case messages = "Messages"
        case permissions = "Permissions"
        case accountType = "AccountType"
        case error
    }

    /// Create a LoginResponse
    /// - Parameters:
    ///   - success: Whether the login was successful
    ///   - user: Username
    ///   - avatarUrl: Avatar URL
    ///   - token: Authentication token
    ///   - score: User score
    ///   - softcoreScore: Softcore score
    ///   - messages: Message count
    ///   - permissions: User permissions
    ///   - accountType: Account type
    ///   - error: Error message if login failed
    public init(success: Bool, user: String?, avatarUrl: String?, token: String?, score: Int?, softcoreScore: Int?, messages: Int?, permissions: Int?, accountType: String?, error: String?) {
        self.success = success
        self.user = user
        self.avatarUrl = avatarUrl
        self.token = token
        self.score = score
        self.softcoreScore = softcoreScore
        self.messages = messages
        self.permissions = permissions
        self.accountType = accountType
        self.error = error
    }
}

/// User session information
public struct UserSession: Sendable {
    /// The authenticated user
    public let user: UserProfile
    /// Authentication token
    public let token: String
    /// Credentials used for authentication
    public let credentials: RetroCredentials

    /// Create a UserSession
    /// - Parameters:
    ///   - user: The authenticated user
    ///   - token: Authentication token
    ///   - credentials: Credentials used for authentication
    public init(user: UserProfile, token: String, credentials: RetroCredentials) {
        self.user = user
        self.token = token
        self.credentials = credentials
    }
}
