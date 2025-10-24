import Foundation

/// Individual achievement information
public struct Achievement: Codable, Sendable {
    public let id: Int?
    public let numAwarded: Int?
    public let numAwardedHardcore: Int?
    public let title: String?
    public let description: String?
    public let points: Int?
    public let trueRatio: Int?
    public let author: String?
    public let dateModified: String?
    public let dateCreated: String?
    public let badgeName: String?
    public let displayOrder: Int?
    public let memAddr: String?
    public let type: String?
    public let rarity: Double?
    public let rarityHardcore: Double?
    public let isAwarded: Int?
    public let dateAwarded: String?
    public let hardcoreAchieved: Int?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case numAwarded = "NumAwarded"
        case numAwardedHardcore = "NumAwardedHardcore"
        case title = "Title"
        case description = "Description"
        case points = "Points"
        case trueRatio = "TrueRatio"
        case author = "Author"
        case dateModified = "DateModified"
        case dateCreated = "DateCreated"
        case badgeName = "BadgeName"
        case displayOrder = "DisplayOrder"
        case memAddr = "MemAddr"
        case type = "type"
        case rarity = "Rarity"
        case rarityHardcore = "RarityHardcore"
        case isAwarded = "IsAwarded"
        case dateAwarded = "DateAwarded"
        case hardcoreAchieved = "HardcoreAchieved"
    }
}

/// User who unlocked an achievement
public struct AchievementUnlock: Codable, Sendable {
    public let user: String?
    public let raPoints: Int?
    public let dateAwarded: String?
    public let hardcoreMode: Int?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case raPoints = "RAPoints"
        case dateAwarded = "DateAwarded"
        case hardcoreMode = "HardcoreMode"
    }
}

/// Collection of achievement unlocks
public struct AchievementUnlocks: Codable, Sendable {
    public let achievement: Achievement?
    public let console: GameConsole?
    public let game: GameSummary?
    public let unlocks: [AchievementUnlock]?
    public let totalUnlocks: Int?

    enum CodingKeys: String, CodingKey {
        case achievement = "Achievement"
        case console = "Console"
        case game = "Game"
        case unlocks = "Unlocks"
        case totalUnlocks = "TotalUnlocks"
    }
}

/// User's progress on a specific achievement set
public struct UserProgress: Codable, Sendable {
    public let numPossibleAchievements: Int?
    public let possibleScore: Int?
    public let numAchieved: Int?
    public let scoreAchieved: Int?
    public let numAchievedHardcore: Int?
    public let scoreAchievedHardcore: Int?

    enum CodingKeys: String, CodingKey {
        case numPossibleAchievements = "NumPossibleAchievements"
        case possibleScore = "PossibleScore"
        case numAchieved = "NumAchieved"
        case scoreAchieved = "ScoreAchieved"
        case numAchievedHardcore = "NumAchievedHardcore"
        case scoreAchievedHardcore = "ScoreAchievedHardcore"
    }
}

/// Game console information
public struct GameConsole: Codable, Sendable {
    public let id: Int?
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "Name"
    }
}

/// Basic game information
public struct GameSummary: Codable, Sendable {
    public let id: Int?
    public let title: String?
    public let imageIcon: String?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case title = "Title"
        case imageIcon = "ImageIcon"
    }
}
