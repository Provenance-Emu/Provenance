import Foundation

/// Detailed game information
public struct Game: Codable, Sendable {
    public let id: Int?
    public let title: String?
    public let consoleID: Int?
    public let consoleName: String?
    public let imageIcon: String?
    public let imageTitle: String?
    public let imageIngame: String?
    public let imageBoxArt: String?
    public let publisher: String?
    public let developer: String?
    public let genre: String?
    public let released: String?
    public let isFinal: Int?
    public let richPresencePatch: String?
    public let numAchievements: Int?
    public let numDistinctPlayersCasual: Int?
    public let numDistinctPlayersHardcore: Int?
    public let achievements: [String: Achievement]?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case title = "Title"
        case consoleID = "ConsoleID"
        case consoleName = "ConsoleName"
        case imageIcon = "ImageIcon"
        case imageTitle = "ImageTitle"
        case imageIngame = "ImageIngame"
        case imageBoxArt = "ImageBoxArt"
        case publisher = "Publisher"
        case developer = "Developer"
        case genre = "Genre"
        case released = "Released"
        case isFinal = "IsFinal"
        case richPresencePatch = "RichPresencePatch"
        case numAchievements = "NumAchievements"
        case numDistinctPlayersCasual = "NumDistinctPlayersCasual"
        case numDistinctPlayersHardcore = "NumDistinctPlayersHardcore"
        case achievements = "Achievements"
    }
}

/// Extended game information with user progress
public struct GameExtended: Codable, Sendable {
    public let game: Game?
    public let userProgress: UserProgress?

    enum CodingKeys: String, CodingKey {
        case game = "Game"
        case userProgress = "UserProgress"
    }
}

/// Comment on achievements, games, or user walls
public struct Comment: Codable, Sendable {
    public let user: String?
    public let submitted: String?
    public let commentText: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case submitted = "Submitted"
        case commentText = "CommentText"
    }
}

/// Collection of comments
public struct Comments: Codable, Sendable {
    public let count: Int?
    public let total: Int?
    public let results: [Comment]?

    enum CodingKeys: String, CodingKey {
        case count = "Count"
        case total = "Total"
        case results = "Results"
    }
}

/// Game ranking entry
public struct GameRank: Codable, Sendable {
    public let user: String?
    public let totalScore: Int?
    public let lastAward: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case totalScore = "TotalScore"
        case lastAward = "LastAward"
    }
}

/// Collection of game rankings
public struct GameRankings: Codable, Sendable {
    public let entries: [GameRank]?

    enum CodingKeys: String, CodingKey {
        case entries = "Entries"
    }
}
