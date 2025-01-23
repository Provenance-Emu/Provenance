//
//  CheatCodeTypes.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 1/22/25.
//

import Foundation

/// CheatCodeTypes represents different formats of cheat codes supported by emulators
public enum CheatCodeTypes: Int, CaseIterable, Codable, Hashable {
    case codeBreaker
    case gameGenie
    case gameShark
    case gameSharkV2
    case gameSharkV3
    case gecko
    case goldFinger
    case proActionReplay
    case proActionReplayV1
    case proActionReplayV2
    case rawCode
    case rawMemAddress
    
    /// Human-Readable description
    public var stringValue: String {
        switch self {
        case .codeBreaker: return "Code Breaker"
        case .gameGenie: return "Game Genie"
        case .gameShark: return "Game Shark"
        case .gameSharkV2: return "Game Shark V2"
        case .gameSharkV3: return "Game Shark V3"
        case .gecko: return "Gecko"
        case .goldFinger: return "Gold Finger"
        case .proActionReplay: return "Pro Action Replay"
        case .proActionReplayV1: return "Pro Action Replay V2"
        case .proActionReplayV2: return "Pro Action Replay V2"
        case .rawCode: return "Raw Code"
        case .rawMemAddress: return "Raw MemAddress:Value Pairs"
        }
    }

    /// Human readable description of the format
    public var formatDescription: String {
        switch self {
        case .codeBreaker:
            return "Format: XXXXXXXX YYYYYYYY - X is address, Y is value"
        case .gameGenie:
            return "Format: XXXX-YYYY or AAAA-BBBB-CCCC - Letters A-F and numbers only"
        case .gameShark:
            return "Format: 01XXYYYY - XX is type, YYYY is value"
        case .gameSharkV2:
            return "Format: XXXXXXXX YYYYYYYY - X is address, Y is value"
        case .gameSharkV3:
            return "Format: 0XXXXXXX YYYYYYYY - X is address, Y is value"
        case .gecko:
            return "Format: XXXXXXXX YYYYYYYY - X is command, Y is value"
        case .goldFinger:
            return "Format: XXXX:YY - XXXX is address, YY is value"
        case .proActionReplay:
            return "Format: XXXXXXXX-YYYY - X is address, Y is value"
        case .proActionReplayV1:
            return "Format: XXXX-YYYY - X is address, Y is value"
        case .proActionReplayV2:
            return "Format: XXXXXXXX YYYY - X is address, Y is value"
        case .rawCode:
            return "Format: XXXXXXXX - Raw hexadecimal code"
        case .rawMemAddress:
            return "Format: XXXXXXXX:YY - X is memory address, Y is value"
        }
    }

    /// Regular expression pattern for validation
    public var validationPattern: String {
        switch self {
        case .codeBreaker:
            return "^[0-9A-F]{8}\\s[0-9A-F]{8}$"
        case .gameGenie:
            return "^[A-F0-9]{4}-[A-F0-9]{4}(-[A-F0-9]{4})?$"
        case .gameShark:
            return "^01[0-9A-F]{2}[0-9A-F]{4}$"
        case .gameSharkV2:
            return "^[0-9A-F]{8}\\s[0-9A-F]{8}$"
        case .gameSharkV3:
            return "^0[0-9A-F]{7}\\s[0-9A-F]{8}$"
        case .gecko:
            return "^[0-9A-F]{8}\\s[0-9A-F]{8}$"
        case .goldFinger:
            return "^[0-9A-F]{4}:[0-9A-F]{2}$"
        case .proActionReplay:
            return "^[0-9A-F]{8}-[0-9A-F]{4}$"
        case .proActionReplayV1:
            return "^[0-9A-F]{4}-[0-9A-F]{4}$"
        case .proActionReplayV2:
            return "^[0-9A-F]{8}\\s[0-9A-F]{4}$"
        case .rawCode:
            return "^[0-9A-F]{8}$"
        case .rawMemAddress:
            return "^[0-9A-F]{8}:[0-9A-F]{2}$"
        }
    }

    /// Determines the cheat code type from a string
    /// - Parameter code: The cheat code to analyze
    /// - Returns: Array of matching CheatCodeTypes or empty if no matches
    public static func detectType(from code: String) -> [CheatCodeTypes] {
        return CheatCodeTypes.allCases.filter { type in
            guard let regex = try? NSRegularExpression(pattern: type.validationPattern) else {
                return false
            }
            let range = NSRange(code.startIndex..<code.endIndex, in: code)
            return regex.firstMatch(in: code, range: range) != nil
        }
    }

    /// Get supported cheat types for a core
    /// - Parameter coreIdentifier: Optional core identifier
    /// - Returns: Array of supported CheatCodeTypes
    public static func supportedTypes(for coreIdentifier: String?) -> [CheatCodeTypes] {
        // TODO: Add core-specific filtering when PVCore support is added
        return CheatCodeTypes.allCases
    }
}

public func CheatCodeTypesMakeStringArray(_ types: [CheatCodeTypes]) -> [String] {
    return types.cheatCodeTypeStrings
}

public extension Collection where Self.Element == CheatCodeTypes {
    var cheatCodeTypeStrings: [String] { map { $0.stringValue } }
}
