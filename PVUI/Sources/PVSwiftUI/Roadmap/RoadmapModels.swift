import Foundation
import SwiftUI

public struct RoadmapEpic: Identifiable, Codable {
    public let id: Int
    public let githubIssue: Int?
    public let title: String
    public let description: String
    public let status: EpicStatus
    public let priority: EpicPriority
    public let effort: EpicEffort
    public let revenueImpact: RevenueImpact
    public let progress: Double
    public let tags: [String]
    public let provenancePlus: Bool

    public var githubURL: URL? {
        guard let issue = githubIssue else { return nil }
        return URL(string: "https://github.com/Provenance-Emu/Provenance/issues/\(issue)")
    }
}

public enum EpicStatus: String, Codable, CaseIterable {
    case active, complete, planned
    case onHold = "on-hold"

    public var displayName: String {
        switch self {
        case .active:   return "Active"
        case .complete: return "Complete"
        case .planned:  return "Planned"
        case .onHold:   return "On Hold"
        }
    }

    public var color: Color {
        switch self {
        case .active:   return .blue
        case .complete: return .green
        case .planned:  return .gray
        case .onHold:   return .orange
        }
    }

    public var systemImage: String {
        switch self {
        case .active:   return "bolt.fill"
        case .complete: return "checkmark.circle.fill"
        case .planned:  return "clock"
        case .onHold:   return "pause.circle"
        }
    }
}

public enum EpicPriority: String, Codable, CaseIterable, Comparable {
    case p0 = "P0", p1 = "P1", p2 = "P2", p3 = "P3"

    public var sortOrder: Int {
        switch self { case .p0: return 0; case .p1: return 1; case .p2: return 2; case .p3: return 3 }
    }

    public static func < (lhs: EpicPriority, rhs: EpicPriority) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    public var color: Color {
        switch self {
        case .p0: return .red
        case .p1: return .orange
        case .p2: return .yellow
        case .p3: return .gray
        }
    }
}

public enum EpicEffort: String, Codable, CaseIterable {
    case xs = "XS", s = "S", m = "M", l = "L", xl = "XL"

    public var description: String {
        switch self {
        case .xs: return "~1 day"
        case .s:  return "~1 week"
        case .m:  return "~2–4 weeks"
        case .l:  return "~1–2 months"
        case .xl: return "3+ months"
        }
    }
}

public enum RevenueImpact: String, Codable {
    case none, low, medium, high, critical
}
