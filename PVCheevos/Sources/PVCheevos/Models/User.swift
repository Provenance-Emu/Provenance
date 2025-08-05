import Foundation

/// User profile information from RetroAchievements
public struct UserProfile: Codable, Sendable {
    public let user: String
    public let ulid: String?
    public let userPic: String?
    public let memberSince: String?
    public let richPresenceMsg: String?
    public let lastGameID: Int?
    public let contribCount: Int?
    public let contribYield: Int?
    public let totalPoints: Int?
    public let totalSoftcorePoints: Int?
    public let totalTruePoints: Int?
    public let permissions: Int?
    public let untracked: Int?
    public let id: Int?
    public let userWallActive: Bool?
    public let motto: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case ulid = "ULID"
        case userPic = "UserPic"
        case memberSince = "MemberSince"
        case richPresenceMsg = "RichPresenceMsg"
        case lastGameID = "LastGameID"
        case contribCount = "ContribCount"
        case contribYield = "ContribYield"
        case totalPoints = "TotalPoints"
        case totalSoftcorePoints = "TotalSoftcorePoints"
        case totalTruePoints = "TotalTruePoints"
        case permissions = "Permissions"
        case untracked = "Untracked"
        case id = "ID"
        case userWallActive = "UserWallActive"
        case motto = "Motto"
    }
}

/// User award information
public struct UserAward: Codable, Sendable {
    public let awardedAt: String?
    public let awardType: String?
    public let awardData: Int?
    public let awardDataExtra: Int?
    public let displayOrder: Int?
    public let title: String?
    public let consoleID: Int?
    public let consoleName: String?
    public let flags: Int?
    public let imageIcon: String?

    enum CodingKeys: String, CodingKey {
        case awardedAt = "AwardedAt"
        case awardType = "AwardType"
        case awardData = "AwardData"
        case awardDataExtra = "AwardDataExtra"
        case displayOrder = "DisplayOrder"
        case title = "Title"
        case consoleID = "ConsoleID"
        case consoleName = "ConsoleName"
        case flags = "Flags"
        case imageIcon = "ImageIcon"
    }
}

/// Collection of user awards
public struct UserAwards: Codable, Sendable {
    public let totalAwardsCount: Int?
    public let hiddenAwardsCount: Int?
    public let masteryAwardsCount: Int?
    public let completionAwardsCount: Int?
    public let beatHardcoreAwardsCount: Int?
    public let beatSoftcoreAwardsCount: Int?
    public let eventAwardsCount: Int?
    public let siteAwardsCount: Int?
    public let visibleUserAwards: [UserAward]?

    enum CodingKeys: String, CodingKey {
        case totalAwardsCount = "TotalAwardsCount"
        case hiddenAwardsCount = "HiddenAwardsCount"
        case masteryAwardsCount = "MasteryAwardsCount"
        case completionAwardsCount = "CompletionAwardsCount"
        case beatHardcoreAwardsCount = "BeatHardcoreAwardsCount"
        case beatSoftcoreAwardsCount = "BeatSoftcoreAwardsCount"
        case eventAwardsCount = "EventAwardsCount"
        case siteAwardsCount = "SiteAwardsCount"
        case visibleUserAwards = "VisibleUserAwards"
    }
}

/// Simple user information
public struct UserSummary: Codable, Sendable {
    public let user: String?
    public let points: Int?
    public let retroPoints: Int?
    public let lastActivity: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case points = "Points"
        case retroPoints = "RetroPoints"
        case lastActivity = "LastActivity"
    }
}

/// Collection of users that follow or are followed
public struct UserList: Codable, Sendable {
    public let users: [UserSummary]?

    enum CodingKeys: String, CodingKey {
        case users = "Users"
    }
}
