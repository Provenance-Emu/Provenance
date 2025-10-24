# PVCheevos

A Swift 6 library for communicating with the [RetroAchievements](https://retroachievements.org) API. This library provides a modern, async/await-based interface for accessing user profiles, achievements, games, and more.

## Features

- ✅ **Swift 6 with async/await support**
- ✅ **Complete type safety with Codable models**
- ✅ **Comprehensive error handling**
- ✅ **Actor-based concurrency safety**
- ✅ **iOS and tvOS compatible**
- ✅ **Extensive unit test coverage**
- ✅ **Protocol-oriented design**

## Requirements

- iOS 15.0+ / tvOS 15.0+ / macOS 12.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/PVCheevos.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. Go to File → Add Packages...
2. Enter the repository URL
3. Select the version and add to your target

## Getting Started

### 1. Authentication Options

The RetroAchievements API supports two authentication methods:

**Option A: Web API Key (Recommended)**
- Your RetroAchievements username
- A web API key (found in your profile settings on retroachievements.org)

**Option B: Username and Password**
- Your RetroAchievements username
- Your account password

### 2. Basic Usage

#### Using Web API Key (Recommended)

```swift
import PVCheevos

// Create a client with API key
let client = PVCheevos.client(
    username: "your_username",
    webAPIKey: "your_api_key"
)

// Validate credentials
let isValid = await client.validateCredentials()
if isValid {
    print("✅ Credentials are valid!")
} else {
    print("❌ Invalid credentials")
}
```

#### Using Username and Password

```swift
import PVCheevos

// Option 1: Create client and login manually
let client = PVCheevos.clientWithPassword(
    username: "your_username",
    password: "your_password"
)

let session = try await client.login(username: "your_username", password: "your_password")
print("✅ Logged in successfully! Token: \(session.token)")

// Option 2: Login and get client in one step
let (client, session) = try await PVCheevos.login(
    username: "your_username",
    password: "your_password"
)
print("✅ Logged in! User: \(session.username), Score: \(session.score ?? 0)")
```

### 3. User Profile Operations

```swift
// Get user profile
do {
    let profile = try await client.getUserProfile(username: "MaxMilyin")
    print("User: \(profile.user)")
    print("Total Points: \(profile.totalPoints ?? 0)")
    print("Member Since: \(profile.memberSince ?? "Unknown")")
} catch {
    print("Error: \(error)")
}

// Get user awards
do {
    let awards = try await client.getUserAwards(username: "MaxMilyin")
    print("Total Awards: \(awards.totalAwardsCount ?? 0)")
    print("Mastery Awards: \(awards.masteryAwardsCount ?? 0)")
} catch {
    print("Error: \(error)")
}

// Get users you follow
do {
    let following = try await client.getUsersIFollow()
    print("Following \(following.users?.count ?? 0) users")
} catch {
    print("Error: \(error)")
}
```

### 4. Achievement Operations

```swift
// Get achievement unlock information
do {
    let unlocks = try await client.getAchievementUnlocks(achievementId: 12345)
    print("Achievement: \(unlocks.achievement?.title ?? "Unknown")")
    print("Total Unlocks: \(unlocks.totalUnlocks ?? 0)")
} catch {
    print("Error: \(error)")
}
```

### 5. Game Operations

```swift
// Get game information
do {
    let game = try await client.getGame(gameId: 1)
    print("Game: \(game.title ?? "Unknown")")
    print("Console: \(game.consoleName ?? "Unknown")")
    print("Achievements: \(game.numAchievements ?? 0)")
} catch {
    print("Error: \(error)")
}

// Get game with user progress
do {
    let gameExtended = try await client.getGameExtended(gameId: 1, username: "MaxMilyin")
    if let progress = gameExtended.userProgress {
        print("Achieved: \(progress.numAchieved ?? 0)/\(progress.numPossibleAchievements ?? 0)")
        print("Score: \(progress.scoreAchieved ?? 0)/\(progress.possibleScore ?? 0)")
    }
} catch {
    print("Error: \(error)")
}

// Get game rankings
do {
    let rankings = try await client.getGameRankings(gameId: 1)
    print("Top players:")
    rankings.entries?.prefix(5).forEach { rank in
        print("\(rank.user ?? "Unknown"): \(rank.totalScore ?? 0) points")
    }
} catch {
    print("Error: \(error)")
}
```

### 6. Comment Operations

```swift
// Get comments on a user's wall
do {
    let comments = try await client.getCommentsOnUserWall(username: "MaxMilyin")
    print("Found \(comments.count ?? 0) comments")
    comments.results?.forEach { comment in
        print("\(comment.user ?? "Unknown"): \(comment.commentText ?? "")")
    }
} catch {
    print("Error: \(error)")
}

// Get comments on a game
do {
    let comments = try await client.getCommentsOnGameWall(gameId: 1)
    print("Game has \(comments.count ?? 0) comments")
} catch {
    print("Error: \(error)")
}

// Get comments on an achievement
do {
    let comments = try await client.getCommentsOnAchievementWall(achievementId: 12345)
    print("Achievement has \(comments.count ?? 0) comments")
} catch {
    print("Error: \(error)")
}
```

## Advanced Usage

### Custom URLSession

You can provide your own URLSession for custom networking configurations:

```swift
let customSession = URLSession(configuration: .ephemeral)
let client = PVCheevos.client(
    username: "your_username",
    webAPIKey: "your_api_key",
    urlSession: customSession
)
```

### Error Handling

The library provides comprehensive error handling through the `RetroError` enum:

```swift
do {
    let profile = try await client.getUserProfile(username: "nonexistent")
} catch let error as RetroError {
    switch error {
    case .unauthorized:
        print("Invalid credentials")
    case .notFound:
        print("User not found")
    case .rateLimitExceeded:
        print("Rate limit exceeded")
    case .network(let networkError):
        print("Network error: \(networkError)")
    case .serverError(let message):
        print("Server error: \(message ?? "Unknown")")
    case .invalidResponse:
        print("Invalid response format")
    case .custom(let message):
        print("Custom error: \(message)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Type Aliases

For convenience, the library provides shorter type aliases:

```swift
// Instead of RetroAchievementsClient
let client: RAClient = PVCheevos.client(username: "user", webAPIKey: "key")

// Instead of UserProfile
let profile: RAUserProfile = try await client.getUserProfile(username: "user")

// Instead of Achievement
let achievement: RAAchievement = // ...
```

## API Reference

### Core Types

- `RetroCredentials` / `RACredentials` - Authentication credentials
- `RetroAchievementsClient` / `RAClient` - Main API client
- `RetroError` / `RAError` - Error types

### User Types

- `UserProfile` / `RAUserProfile` - Complete user profile information
- `UserAwards` / `RAUserAwards` - User's awards and achievements
- `UserSummary` / `RAUserSummary` - Basic user information
- `UserList` / `RAUserList` - Collection of users

### Achievement Types

- `Achievement` / `RAAchievement` - Individual achievement information
- `AchievementUnlocks` / `RAAchievementUnlocks` - Achievement unlock data
- `UserProgress` / `RAUserProgress` - User's progress on a game

### Game Types

- `Game` / `RAGame` - Complete game information
- `GameExtended` / `RAGameExtended` - Game with user progress
- `GameSummary` / `RAGameSummary` - Basic game information
- `GameConsole` / `RAGameConsole` - Console information

### Comment Types

- `Comment` / `RAComment` - Individual comment
- `Comments` / `RAComments` - Collection of comments

## Testing

Run tests using Xcode or Swift Package Manager:

```bash
swift test
```

The library includes comprehensive unit tests with mock network responses to ensure reliability.

### CLI Tool

The package includes a command-line tool (`ra-cli`) for testing and exploring the RetroAchievements API:

```bash
# Build and run the CLI tool
swift build
swift run ra-cli --help

# Test with your credentials (API key)
swift run ra-cli -u your_username -k your_api_key

# Test with username and password
swift run ra-cli -u your_username -p your_password

# Explore different data types
swift run ra-cli -u your_username -k your_api_key -c awards
swift run ra-cli -u your_username -p your_password -c social
swift run ra-cli -u your_username -k your_api_key -c game
swift run ra-cli -u your_username -p your_password -c all

# Use environment variables for convenience
export RA_USERNAME=your_username
export RA_API_KEY=your_api_key
swift run ra-cli -c profile

# Or with password
export RA_USERNAME=your_username
export RA_PASSWORD=your_password
swift run ra-cli -c awards
```

The CLI tool provides:
- ✅ **Credential validation** - Test your login credentials
- 👤 **User profiles** - View detailed user information and stats
- 🏅 **Awards system** - Browse user awards and achievements
- 👥 **Social features** - Explore following/followers
- 🎮 **Game exploration** - Interactive game information lookup
- 🏆 **Achievement details** - Deep dive into specific achievements
- 📊 **Comprehensive data** - All API functionality in one tool

## Integration with Provenance

This library is designed to work seamlessly with the Provenance emulator app. Example integration:

```swift
class AchievementManager {
    private let client: RetroAchievementsClient

    init(username: String, apiKey: String) {
        self.client = PVCheevos.client(username: username, webAPIKey: apiKey)
    }

    func setupForGame(gameId: Int) async {
        do {
            let game = try await client.getGame(gameId: gameId)
            // Setup achievement tracking for this game
            await setupAchievementTracking(for: game)
        } catch {
            print("Failed to setup achievements: \(error)")
        }
    }

    private func setupAchievementTracking(for game: Game) async {
        // Implementation depends on your core's achievement system
    }
}
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [RetroAchievements](https://retroachievements.org) for providing the API
- [api-kotlin](https://github.com/RetroAchievements/api-kotlin) reference implementation
- The Provenance emulator project
