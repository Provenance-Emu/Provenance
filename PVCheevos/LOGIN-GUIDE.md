# PVCheevos Authentication Guide

This guide covers all authentication methods supported by the PVCheevos library, including the new username/password login functionality.

## 🔐 Authentication Methods

### Method 1: Web API Key (Recommended)

The web API key method is the most secure and recommended approach:

**Advantages:**
- ✅ More secure (no password transmitted)
- ✅ Faster authentication (no login required)
- ✅ No session management needed
- ✅ Works indefinitely (until key is revoked)

**How to get your API key:**
1. Log into your RetroAchievements account
2. Go to your profile settings
3. Find the "Web API Key" section
4. Copy your API key

```swift
import PVCheevos

// Create client with API key
let client = PVCheevos.client(
    username: "your_username",
    webAPIKey: "your_web_api_key"
)

// Ready to use immediately
let profile = try await client.getUserProfile(username: "your_username")
```

### Method 2: Username and Password

The username/password method provides a familiar login experience:

**Advantages:**
- ✅ Familiar login flow
- ✅ No need to manage API keys
- ✅ Returns session information
- ✅ Automatic token management

**Use cases:**
- User-facing applications
- When users don't want to manage API keys
- Interactive login flows

## 🚀 Usage Examples

### Web API Key Authentication

```swift
import PVCheevos

// Basic setup
let client = PVCheevos.client(
    username: "MaxMilyin",
    webAPIKey: "ABC123XYZ789"
)

// Validate credentials
let isValid = await client.validateCredentials()
print("Credentials valid: \(isValid)")

// Use the API
let profile = try await client.getUserProfile(username: "MaxMilyin")
print("User: \(profile.user), Points: \(profile.totalPoints ?? 0)")
```

### Username/Password Authentication

#### Option 1: Manual Login

```swift
import PVCheevos

// Create client for password authentication
let client = PVCheevos.clientWithPassword(
    username: "MaxMilyin",
    password: "mySecurePassword"
)

// Perform login
do {
    let session = try await client.login(
        username: "MaxMilyin",
        password: "mySecurePassword"
    )

    print("✅ Login successful!")
    print("Username: \(session.username)")
    print("Token: \(session.token)")
    print("Score: \(session.score ?? 0)")
    print("Softcore Score: \(session.softcoreScore ?? 0)")
    print("Permissions: \(session.permissions ?? 0)")
    print("Account Type: \(session.accountType ?? "Unknown")")

    // Now you can use the API
    let profile = try await client.getUserProfile(username: session.username)
    print("Profile loaded: \(profile.user)")

} catch {
    print("❌ Login failed: \(error)")
}
```

#### Option 2: One-Step Login

```swift
import PVCheevos

// Login and get client in one step
do {
    let (client, session) = try await PVCheevos.login(
        username: "MaxMilyin",
        password: "mySecurePassword"
    )

    print("✅ Logged in as \(session.username)")
    print("🏆 Total Score: \(session.score ?? 0)")

    // Client is ready to use
    let awards = try await client.getUserAwards(username: session.username)
    print("🏅 Total Awards: \(awards.totalAwardsCount ?? 0)")

} catch {
    print("❌ Login failed: \(error)")
}
```

### Automatic Login with Password Credentials

When using password credentials, the library automatically handles login:

```swift
import PVCheevos

// Create client with password credentials
let credentials = RetroCredentials.usernamePassword(
    username: "MaxMilyin",
    password: "mySecurePassword"
)
let client = PVCheevos.client(credentials: credentials)

// First API call automatically triggers login
let profile = try await client.getUserProfile(username: "MaxMilyin")
print("Profile: \(profile.user)") // Login happened automatically

// Subsequent calls use the cached session
let awards = try await client.getUserAwards(username: "MaxMilyin")
print("Awards: \(awards.totalAwardsCount ?? 0)")
```

## 🔄 Session Management

### Getting Current Session

```swift
// Check if there's an active session
if let session = await client.getCurrentSession() {
    print("Logged in as: \(session.username)")
    print("Token: \(session.token)")
    print("Score: \(session.score ?? 0)")
} else {
    print("Not logged in")
}
```

### Logout

```swift
// Clear the current session
await client.logout()
print("Logged out successfully")
```

## 🛠 Advanced Usage

### Custom Credentials Creation

```swift
import PVCheevos

// Create different types of credentials
let apiKeyCredentials = RetroCredentials.webAPIKey(
    username: "user",
    webAPIKey: "key"
)

let passwordCredentials = RetroCredentials.usernamePassword(
    username: "user",
    password: "pass"
)

let authenticatedCredentials = RetroCredentials.authenticated(
    username: "user",
    token: "existing_token"
)

// Use any credential type with the client
let client = PVCheevos.client(credentials: apiKeyCredentials)
```

### Error Handling

```swift
import PVCheevos

do {
    let (client, session) = try await PVCheevos.login(
        username: "user",
        password: "wrong_password"
    )
} catch let error as RetroError {
    switch error {
    case .unauthorized:
        print("❌ Invalid username or password")
    case .network(let networkError):
        print("🌐 Network error: \(networkError.localizedDescription)")
    case .serverError(let message):
        print("🖥 Server error: \(message ?? "Unknown")")
    default:
        print("⚠️ Other error: \(error.localizedDescription)")
    }
} catch {
    print("💥 Unexpected error: \(error)")
}
```

## 📱 CLI Tool Authentication

The CLI tool supports both authentication methods:

### Using Web API Key

```bash
# Command line arguments
ra-cli -u your_username -k your_api_key -c profile

# Environment variables
export RA_USERNAME=your_username
export RA_API_KEY=your_api_key
ra-cli -c awards
```

### Using Username and Password

```bash
# Command line arguments
ra-cli -u your_username -p your_password -c profile

# Environment variables
export RA_USERNAME=your_username
export RA_PASSWORD=your_password
ra-cli -c social
```

## 🎯 Best Practices

### Security Recommendations

1. **Use API Keys when possible**: More secure than passwords
2. **Store credentials securely**: Use Keychain or similar secure storage
3. **Don't hardcode credentials**: Use environment variables or secure storage
4. **Handle login failures gracefully**: Provide clear error messages to users

### Performance Tips

1. **Cache sessions**: Reuse the same client instance when possible
2. **Handle network errors**: Implement retry logic for transient failures
3. **Validate credentials early**: Check credentials before making multiple API calls

### Example: Secure Credential Storage

```swift
import Security
import PVCheevos

class SecureCredentialManager {
    private let usernameKey = "ra_username"
    private let apiKeyKey = "ra_api_key"

    func saveCredentials(username: String, apiKey: String) {
        // Save to Keychain (simplified example)
        saveToKeychain(key: usernameKey, value: username)
        saveToKeychain(key: apiKeyKey, value: apiKey)
    }

    func loadCredentials() -> RetroCredentials? {
        guard let username = loadFromKeychain(key: usernameKey),
              let apiKey = loadFromKeychain(key: apiKeyKey) else {
            return nil
        }

        return RetroCredentials.webAPIKey(username: username, webAPIKey: apiKey)
    }

    // Keychain helper methods (implementation depends on your needs)
    private func saveToKeychain(key: String, value: String) { /* ... */ }
    private func loadFromKeychain(key: String) -> String? { /* ... */ }
}

// Usage
let credentialManager = SecureCredentialManager()

// Save credentials securely
credentialManager.saveCredentials(username: "user", apiKey: "key")

// Load and use credentials
if let credentials = credentialManager.loadCredentials() {
    let client = PVCheevos.client(credentials: credentials)
    // Use client...
}
```

## 🔍 Troubleshooting

### Common Issues

**Invalid Credentials Error:**
```
❌ Authentication failed - check your credentials
```
- Double-check username and password/API key
- Ensure API key is from the correct account
- Verify account is in good standing

**Network Errors:**
```
🌐 Network error: The Internet connection appears to be offline
```
- Check internet connection
- Verify RetroAchievements.org is accessible
- Try again after a moment (might be temporary)

**Session Expiration:**
- Password-based sessions may expire
- The library automatically re-authenticates when needed
- For long-running apps, consider using API keys

### Testing Authentication

```swift
// Test different authentication methods
func testAuthentication() async {
    // Test API key
    let apiClient = PVCheevos.client(username: "test", webAPIKey: "test_key")
    let apiValid = await apiClient.validateCredentials()
    print("API Key valid: \(apiValid)")

    // Test password login
    do {
        let (passClient, session) = try await PVCheevos.login(
            username: "test",
            password: "test_pass"
        )
        print("Password login successful: \(session.username)")
    } catch {
        print("Password login failed: \(error)")
    }
}
```

## 🎮 Integration with Provenance

For integration with the Provenance emulator:

```swift
class ProvenanceAchievementManager {
    private var client: RetroAchievementsClient?
    private var currentSession: UserSession?

    func authenticateUser(username: String, password: String) async -> Bool {
        do {
            let (client, session) = try await PVCheevos.login(
                username: username,
                password: password
            )

            self.client = client
            self.currentSession = session

            print("🎮 Authenticated as \(session.username)")
            print("🏆 User has \(session.score ?? 0) points")

            return true
        } catch {
            print("❌ Authentication failed: \(error)")
            return false
        }
    }

    func loadGameAchievements(gameId: Int) async {
        guard let client = client else { return }

        do {
            let game = try await client.getGame(gameId: gameId)
            print("🎮 Loaded \(game.numAchievements ?? 0) achievements for \(game.title ?? "game")")

            // Set up achievement tracking in your emulator core
            setupAchievementTracking(achievements: game.achievements)
        } catch {
            print("❌ Failed to load achievements: \(error)")
        }
    }

    private func setupAchievementTracking(achievements: [String: Achievement]?) {
        // Implementation depends on your emulator core
        // This is where you'd configure the achievement system
    }
}
```

This authentication system provides the flexibility needed for both development and production use cases, supporting both the security of API keys and the user-friendliness of password-based login!
