import Foundation
import PVCheevos

/// RetroAchievements CLI Tool
/// A command-line interface for testing and exploring the RetroAchievements API
@available(macOS 12.0, *)
@main
struct RetroAchievementsCLI {
    static func main() async {
        let cli = CLIManager()
        await cli.run()
    }
}

@available(macOS 12.0, *)
class CLIManager {
    private var client: RetroAchievementsClient?
    private let args = CommandLine.arguments

    func run() async {
        printHeader()

        // Parse command line arguments
        guard let config = parseArguments() else {
            printUsage()
            exit(1)
        }

        // Initialize client based on available credentials
        if let apiKey = config.apiKey {
            print("🔑 Using API key authentication...")
            client = PVCheevos.client(
                username: config.username,
                webAPIKey: apiKey
            )
        } else if let password = config.password {
            print("🔐 Using username/password authentication...")
            client = PVCheevos.clientWithPassword(
                username: config.username,
                password: password
            )
        } else {
            print("❌ No valid credentials provided!")
            exit(1)
        }

        // Execute the command
        await executeCommand(config.command, username: config.username)
    }

        private func parseArguments() -> CLIConfig? {
        if args.contains("-h") || args.contains("--help") {
            return nil
        }

        // Get username
        let username = getArgument("--username") ?? getArgument("-u") ?? ProcessInfo.processInfo.environment["RA_USERNAME"]

        // Get credentials - either API key or password
        let apiKey = getArgument("--api-key") ?? getArgument("-k") ?? ProcessInfo.processInfo.environment["RA_API_KEY"]
        let password = getArgument("--password") ?? getArgument("-p") ?? ProcessInfo.processInfo.environment["RA_PASSWORD"]

        guard let username = username else {
            print("❌ Missing username!")
            print("   Provide username via --username or -u argument, or RA_USERNAME environment variable.")
            return nil
        }

        // Must have either API key or password
        guard apiKey != nil || password != nil else {
            print("❌ Missing credentials!")
            print("   Provide either API key (--api-key/-k) or password (--password/-p).")
            return nil
        }

        // Get command
        let command = getArgument("--command") ?? getArgument("-c") ?? "profile"

        return CLIConfig(username: username, apiKey: apiKey, password: password, command: command)
    }

    private func getArgument(_ flag: String) -> String? {
        guard let index = args.firstIndex(of: flag),
              index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    private func executeCommand(_ command: String, username: String) async {
        guard let client = client else {
            print("❌ Client not initialized")
            return
        }

        // Validate credentials based on authentication method
        print("🔐 Validating credentials...")

        do {
            // Check if we're using password authentication and need to login first
            if let password = getStoredPassword() {
                // For password authentication, perform login to get token
                let session = try await client.login(username: username, password: password)
                print("✅ Successfully logged in as \(session.user.user)")

                // Demonstrate session-based gaming features instead of Data API
                await demonstrateGamingFeatures(client: client)
                return // Don't try to access Data API with session token
            } else {
                // For API key authentication, just validate
                let isValid = await client.validateCredentials()
                if !isValid {
                    print("❌ Invalid credentials! Please check your username and API key.")
                    return
                }
                print("✅ Credentials validated successfully!")
            }
        } catch {
            print("❌ Authentication failed: \(error.localizedDescription)")
            return
        }

        // Execute the command
        switch command.lowercased() {
        case "profile", "p":
            await showProfile(username: username)
        case "awards", "a":
            await showAwards(username: username)
        case "social", "s":
            await showSocial()
        case "achievement", "ach":
            await showAchievement()
        case "all":
            await showAll(username: username)
        default:
            print("❌ Unknown command: \(command)")
            printCommands()
        }
    }

    // Demonstrate session-based gaming features (RetroArch-style)
    private func demonstrateGamingFeatures(client: RetroAchievementsClient) async {
        print("\n🕹️  SESSION-BASED GAMING FEATURES")
        print("═══════════════════════════════════")
        print("🎮 This is what RetroArch uses password auth for:")

        do {
            // Start a game session (like RetroArch does)
            print("\n📡 Starting game session for game ID 1...")
            let sessionResponse = try await client.startGameSession(gameId: 1)

            if sessionResponse.success {
                print("✅ Game session started successfully!")
                if let unlocks = sessionResponse.unlocks, !unlocks.isEmpty {
                    print("🏆 Found \(unlocks.count) achievement unlock(s)")
                    for unlock in unlocks {
                        print("   • Achievement ID: \(unlock.id) (unlocked at: \(unlock.when))")
                    }
                }
                if let serverTime = sessionResponse.serverNow {
                    print("⏰ Server time: \(serverTime)")
                }
            } else {
                print("⚠️  Game session start failed: \(sessionResponse.error ?? "Unknown error")")
            }

            // Send Rich Presence updates (like RetroArch does)
            print("\n📡 Sending Rich Presence update...")
            let pingResponse = try await client.sendPing(gameId: 1, richPresence: "Playing Super Mario Bros - World 1-1")

            if pingResponse.success {
                print("✅ Rich Presence updated successfully!")
                print("   This would show 'Playing Super Mario Bros - World 1-1' on your profile")
            } else {
                print("⚠️  Rich Presence update failed: \(pingResponse.error ?? "Unknown error")")
            }

            // Send another ping without Rich Presence (session maintenance)
            print("\n📡 Sending session maintenance ping...")
            let maintenancePing = try await client.sendPing()

            if maintenancePing.success {
                print("✅ Session maintenance ping successful!")
            } else {
                print("⚠️  Session ping failed: \(maintenancePing.error ?? "Unknown error")")
            }

            print("\n🎯 Session-based gaming demo complete!")
            print("💡 For user profiles and achievements data, use API key authentication.")

        } catch {
            print("❌ Gaming session error: \(error.localizedDescription)")
        }
    }

    // Helper to check if we're using password authentication
    private func getStoredPassword() -> String? {
        // This is a simple way to check - in a real app you'd store this more securely
        return getArgument("--password") ?? getArgument("-p") ?? ProcessInfo.processInfo.environment["RA_PASSWORD"]
    }

    private func showProfile(username: String) async {
        print("👤 USER PROFILE")
        print("═══════════════")

        do {
            let profile = try await client!.getUserProfile(username: username)

            print("🎮 Username: \(profile.user)")
            print("📅 Member Since: \(profile.memberSince ?? "Unknown")")
            print("🏆 Total Points: \(formatNumber(profile.totalPoints ?? 0))")
            print("🎯 Softcore Points: \(formatNumber(profile.totalSoftcorePoints ?? 0))")
            print("💎 True Points: \(formatNumber(profile.totalTruePoints ?? 0))")

            if let richPresence = profile.richPresenceMsg, !richPresence.isEmpty {
                print("🎮 Currently: \(richPresence)")
            }

            if let motto = profile.motto, !motto.isEmpty {
                print("💭 Motto: \"\(motto)\"")
            }

            if let lastGameID = profile.lastGameID, lastGameID > 0 {
                print("🎲 Last Game ID: \(lastGameID)")
            }

            print("👨‍💻 Contributions: \(profile.contribCount ?? 0)")
            print("🔧 Permissions Level: \(profile.permissions ?? 0)")

        } catch {
            handleError(error)
        }
    }

    private func showAwards(username: String) async {
        print("\n🏅 USER AWARDS")
        print("══════════════")

        do {
            let awards = try await client!.getUserAwards(username: username)

            print("🏆 Total Awards: \(awards.totalAwardsCount ?? 0)")
            print("👑 Mastery Awards: \(awards.masteryAwardsCount ?? 0)")
            print("🎯 Completion Awards: \(awards.completionAwardsCount ?? 0)")
            print("💪 Hardcore Beat Awards: \(awards.beatHardcoreAwardsCount ?? 0)")
            print("😌 Softcore Beat Awards: \(awards.beatSoftcoreAwardsCount ?? 0)")
            print("🎪 Event Awards: \(awards.eventAwardsCount ?? 0)")
            print("🌟 Site Awards: \(awards.siteAwardsCount ?? 0)")

            if let visibleAwards = awards.visibleUserAwards, !visibleAwards.isEmpty {
                print("\n📋 Recent Awards:")
                for (index, award) in visibleAwards.prefix(10).enumerated() {
                    let title = award.title ?? "Unknown Award"
                    let date = award.awardedAt ?? "Unknown Date"
                    let type = award.awardType ?? "Unknown"
                    print("   \(index + 1). \(title) (\(type)) - \(date)")
                }
            }

        } catch {
            handleError(error)
        }
    }

    private func showSocial() async {
        print("\n👥 SOCIAL CONNECTIONS")
        print("════════════════════")

        do {
            // Show following
            let following = try await client!.getUsersIFollow(count: 10)
            print("📤 Following \(following.users?.count ?? 0) users:")
            following.users?.enumerated().forEach { index, user in
                let username = user.user ?? "Unknown"
                let points = formatNumber(user.points ?? 0)
                print("   \(index + 1). \(username) - \(points) points")
            }

            print()

            // Show followers
            let followers = try await client!.getUsersFollowingMe(count: 10)
            print("📥 \(followers.users?.count ?? 0) followers:")
            followers.users?.enumerated().forEach { index, user in
                let username = user.user ?? "Unknown"
                let points = formatNumber(user.points ?? 0)
                print("   \(index + 1). \(username) - \(points) points")
            }

        } catch {
            handleError(error)
        }
    }

    private func showGame() async {
        print("\n🎮 GAME INFORMATION")
        print("══════════════════")
        print("Enter a game ID to explore (e.g., 1 for Super Mario Bros.): ", terminator: "")

        guard let input = readLine(), let gameId = Int(input) else {
            print("❌ Invalid game ID")
            return
        }

        do {
            let game = try await client!.getGame(gameId: gameId)

            print("🎮 Game: \(game.title ?? "Unknown")")
            print("🕹 Console: \(game.consoleName ?? "Unknown") (ID: \(game.consoleID ?? 0))")
            print("👨‍💻 Developer: \(game.developer ?? "Unknown")")
            print("🏢 Publisher: \(game.publisher ?? "Unknown")")
            print("🎭 Genre: \(game.genre ?? "Unknown")")
            print("📅 Released: \(game.released ?? "Unknown")")
            print("🏆 Total Achievements: \(game.numAchievements ?? 0)")
            print("👥 Casual Players: \(formatNumber(game.numDistinctPlayersCasual ?? 0))")
            print("💪 Hardcore Players: \(formatNumber(game.numDistinctPlayersHardcore ?? 0))")

            if let achievements = game.achievements, !achievements.isEmpty {
                print("\n🏆 Sample Achievements:")
                for (_, achievement) in achievements.prefix(5) {
                    let title = achievement.title ?? "Unknown"
                    let points = achievement.points ?? 0
                    let description = achievement.description ?? "No description"
                    print("   • \(title) (\(points) pts) - \(description)")
                }

                if achievements.count > 5 {
                    print("   ... and \(achievements.count - 5) more achievements")
                }
            }

        } catch {
            handleError(error)
        }
    }

    private func showAchievement() async {
        print("\n🏆 ACHIEVEMENT INFORMATION")
        print("═════════════════════════")
        print("Enter an achievement ID to explore: ", terminator: "")

        guard let input = readLine(), let achievementId = Int(input) else {
            print("❌ Invalid achievement ID")
            return
        }

        do {
            let unlocks = try await client!.getAchievementUnlocks(achievementId: achievementId)

            if let achievement = unlocks.achievement {
                print("🏆 Achievement: \(achievement.title ?? "Unknown")")
                print("📝 Description: \(achievement.description ?? "No description")")
                print("💎 Points: \(achievement.points ?? 0)")
                print("🏅 True Ratio: \(achievement.trueRatio ?? 0)")
                print("👨‍💻 Author: \(achievement.author ?? "Unknown")")
                print("📅 Created: \(achievement.dateCreated ?? "Unknown")")
                print("🔄 Modified: \(achievement.dateModified ?? "Unknown")")
                print("👥 Total Unlocks: \(unlocks.totalUnlocks ?? 0)")
                print("💪 Hardcore Unlocks: \(achievement.numAwardedHardcore ?? 0)")

                if let unlocksList = unlocks.unlocks, !unlocksList.isEmpty {
                    print("\n📋 Recent Unlocks:")
                    for (index, unlock) in unlocksList.prefix(10).enumerated() {
                        let user = unlock.user ?? "Unknown"
                        let date = unlock.dateAwarded ?? "Unknown"
                        let mode = (unlock.hardcoreMode == 1) ? "💪" : "😌"
                        print("   \(index + 1). \(user) \(mode) - \(date)")
                    }
                }
            }

            if let game = unlocks.game {
                print("\n🎮 From Game: \(game.title ?? "Unknown") (ID: \(game.id ?? 0))")
            }

            if let console = unlocks.console {
                print("🕹 Console: \(console.name ?? "Unknown")")
            }

        } catch {
            handleError(error)
        }
    }

    private func showAll(username: String) async {
        await showProfile(username: username)
        await showAwards(username: username)
        await showSocial()

        print("\n🎮 Want to explore games and achievements? Use specific commands:")
        print("   ra-cli -u <username> -k <api-key> -c game")
        print("   ra-cli -u <username> -k <api-key> -c achievement")
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func handleError(_ error: Error) {
        if let retroError = error as? RetroError {
            switch retroError {
            case .unauthorized, .authenticationFailed:
                print("❌ Authentication failed - check your credentials")
            case .invalidCredentials:
                print("❌ Invalid credentials provided")
            case .network(let error), .networkError(let error):
                print("❌ Network error: \(error.localizedDescription)")
            case .invalidURL:
                print("❌ Invalid URL - API endpoint error")
            case .invalidResponse:
                print("❌ Invalid response from server")
            case .notFound:
                print("❌ Resource not found")
            case .serverError(let message):
                print("❌ Server error: \(message ?? "Unknown")")
            case .rateLimitExceeded:
                print("❌ Rate limit exceeded - please wait before retrying")
            case .custom(let message):
                print("❌ \(message)")
            }
        } else {
            print("❌ Unexpected error: \(error.localizedDescription)")
        }
    }

    private func printHeader() {
        print("""
        ╔══════════════════════════════════════════════════════════════╗
        ║                  🏆 RetroAchievements CLI 🏆                 ║
        ║                    PVCheevos Library Demo                    ║
        ╚══════════════════════════════════════════════════════════════╝
        """)
    }

    private func printUsage() {
        print("RetroAchievements CLI Tool")
        print("")
        print("USAGE:")
        print("    ra-cli [OPTIONS] --command <COMMAND>")
        print("")
        print("OPTIONS:")
        print("    -u, --username <USERNAME>    RetroAchievements username")
        print("    -k, --api-key <API_KEY>      Web API key (preferred)")
        print("    -p, --password <PASSWORD>    Account password (alternative)")
        print("    -c, --command <COMMAND>      Command to execute")
        print("    -h, --help                   Show this help message")
        print("")
        print("COMMANDS:")
        print("    profile                      Show user profile")
        print("    awards                       Show user awards")
        print("    games                        Show completed games")
        print("    recent                       Show recent achievements")
        print("")
        print("ENVIRONMENT VARIABLES:")
        print("    RA_USERNAME                  RetroAchievements username")
        print("    RA_API_KEY                   Web API key")
        print("    RA_PASSWORD                  Account password")
        print("")
        print("EXAMPLES:")
        print("    ra-cli -u myuser -k myapikey -c profile")
        print("    ra-cli -u myuser -p mypassword -c awards")
        print("    RA_USERNAME=myuser RA_API_KEY=mykey ra-cli -c profile")
    }

    private func printCommands() {
        print("""

        Available commands:
            profile, p        User profile information
            awards, a         User awards and achievements
            social, s         Social connections
            game, g           Game exploration (interactive)
            achievement, ach  Achievement exploration (interactive)
            all              Show everything

        """)
    }
}

struct CLIConfig {
    let username: String
    let apiKey: String?
    let password: String?
    let command: String
}
