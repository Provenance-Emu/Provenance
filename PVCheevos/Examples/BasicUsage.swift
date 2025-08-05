import Foundation
import PVCheevos

/// Example demonstrating basic usage of the PVCheevos library
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
class BasicUsageExample {

    /// Example: Setting up the client and validating credentials
    func setupClient() async {
        // Create credentials
        let credentials = PVCheevos.credentials(
            username: "your_username",
            webAPIKey: "your_api_key"
        )

        // Or create client directly
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
    }

    /// Example: Fetching user profile information
    func fetchUserProfile() async {
        let client = PVCheevos.client(username: "demo_user", webAPIKey: "demo_key")

        do {
            let profile = try await client.getUserProfile(username: "MaxMilyin")
            print("🎮 User: \(profile.user)")
            print("🏆 Total Points: \(profile.totalPoints ?? 0)")
            print("📅 Member Since: \(profile.memberSince ?? "Unknown")")

            if let motto = profile.motto {
                print("💭 Motto: \(motto)")
            }
        } catch let error as RetroError {
            handleRetroError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    /// Example: Getting user achievements and awards
    func fetchUserAchievements() async {
        let client = PVCheevos.client(username: "demo_user", webAPIKey: "demo_key")

        do {
            let awards = try await client.getUserAwards(username: "MaxMilyin")
            print("🏅 Total Awards: \(awards.totalAwardsCount ?? 0)")
            print("👑 Mastery Awards: \(awards.masteryAwardsCount ?? 0)")
            print("🎯 Completion Awards: \(awards.completionAwardsCount ?? 0)")

            // Display recent awards
            awards.visibleUserAwards?.prefix(5).forEach { award in
                print("🎖 \(award.title ?? "Unknown Award") - \(award.awardedAt ?? "Unknown Date")")
            }
        } catch let error as RetroError {
            handleRetroError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    /// Example: Fetching game information
    func fetchGameInfo() async {
        let client = PVCheevos.client(username: "demo_user", webAPIKey: "demo_key")

        do {
            // Get basic game info
            let game = try await client.getGame(gameId: 1) // Super Mario Bros.
            print("🎮 Game: \(game.title ?? "Unknown")")
            print("🕹 Console: \(game.consoleName ?? "Unknown")")
            print("🏆 Total Achievements: \(game.numAchievements ?? 0)")
            print("👨‍💻 Developer: \(game.developer ?? "Unknown")")
            print("🏢 Publisher: \(game.publisher ?? "Unknown")")

            // Get game with user progress
            let gameExtended = try await client.getGameExtended(gameId: 1, username: "MaxMilyin")
            if let progress = gameExtended.userProgress {
                let achieved = progress.numAchieved ?? 0
                let total = progress.numPossibleAchievements ?? 0
                let scoreAchieved = progress.scoreAchieved ?? 0
                let totalScore = progress.possibleScore ?? 0

                print("📊 Progress: \(achieved)/\(total) achievements (\(achieved * 100 / max(total, 1))%)")
                print("🎯 Score: \(scoreAchieved)/\(totalScore) points")
            }
        } catch let error as RetroError {
            handleRetroError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    /// Example: Getting achievement unlock information
    func fetchAchievementUnlocks() async {
        let client = PVCheevos.client(username: "demo_user", webAPIKey: "demo_key")

        do {
            let unlocks = try await client.getAchievementUnlocks(achievementId: 12345)

            if let achievement = unlocks.achievement {
                print("🏆 Achievement: \(achievement.title ?? "Unknown")")
                print("📝 Description: \(achievement.description ?? "No description")")
                print("💎 Points: \(achievement.points ?? 0)")
                print("👥 Total Unlocks: \(unlocks.totalUnlocks ?? 0)")

                // Show recent unlocks
                unlocks.unlocks?.prefix(5).forEach { unlock in
                    let mode = (unlock.hardcoreMode == 1) ? "💪 Hardcore" : "😌 Softcore"
                    print("   \(unlock.user ?? "Unknown") - \(mode) - \(unlock.dateAwarded ?? "Unknown Date")")
                }
            }
        } catch let error as RetroError {
            handleRetroError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    /// Example: Getting social connections
    func fetchSocialConnections() async {
        let client = PVCheevos.client(username: "demo_user", webAPIKey: "demo_key")

        do {
            // Get users I follow
            let following = try await client.getUsersIFollow()
            print("👥 Following \(following.users?.count ?? 0) users:")
            following.users?.prefix(5).forEach { user in
                print("   \(user.user ?? "Unknown") - \(user.points ?? 0) points")
            }

            // Get my followers
            let followers = try await client.getUsersFollowingMe()
            print("👥 \(followers.users?.count ?? 0) followers")
        } catch let error as RetroError {
            handleRetroError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    /// Example: Reading comments
    func fetchComments() async {
        let client = PVCheevos.client(username: "demo_user", webAPIKey: "demo_key")

        do {
            // Get comments on a user's wall
            let userComments = try await client.getCommentsOnUserWall(username: "MaxMilyin", count: 5)
            print("💬 User wall comments: \(userComments.count ?? 0)")
            userComments.results?.forEach { comment in
                print("   \(comment.user ?? "Unknown"): \(comment.commentText ?? "")")
            }

            // Get comments on a game
            let gameComments = try await client.getCommentsOnGameWall(gameId: 1, count: 5)
            print("💬 Game comments: \(gameComments.count ?? 0)")

            // Get comments on an achievement
            let achievementComments = try await client.getCommentsOnAchievementWall(achievementId: 12345, count: 5)
            print("💬 Achievement comments: \(achievementComments.count ?? 0)")
        } catch let error as RetroError {
            handleRetroError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    /// Helper function to handle RetroAchievements API errors
    private func handleRetroError(_ error: RetroError) {
        switch error {
        case .unauthorized:
            print("🔐 Authentication failed - check your credentials")
        case .notFound:
            print("🔍 Resource not found")
        case .rateLimitExceeded:
            print("⏱ Rate limit exceeded - please wait before making more requests")
        case .network(let networkError):
            print("🌐 Network error: \(networkError.localizedDescription)")
        case .serverError(let message):
            print("🖥 Server error: \(message ?? "Unknown server error")")
        case .invalidResponse:
            print("📄 Invalid response format")
        case .invalidCredentials:
            print("❌ Invalid credentials provided")
        case .custom(let message):
            print("⚠️ \(message)")
        }
    }
}

/// Example usage in an app
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
func exampleAppUsage() async {
    let example = BasicUsageExample()

    print("=== PVCheevos Library Example ===\n")

    await example.setupClient()
    print()

    await example.fetchUserProfile()
    print()

    await example.fetchUserAchievements()
    print()

    await example.fetchGameInfo()
    print()

    await example.fetchAchievementUnlocks()
    print()

    await example.fetchSocialConnections()
    print()

    await example.fetchComments()
    print()

    print("=== Example Complete ===")
}
