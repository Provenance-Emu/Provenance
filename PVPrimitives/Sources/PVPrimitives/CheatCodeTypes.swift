//
//  CheatCodeTypes.swift
//  PVPrimitives
//

import Foundation

/// The cheat code formats supported across Provenance emulator cores.
///
/// This enum defines all recognized cheat code format types. The `stringValue`
/// property returns the human-readable display name used in Core.plist entries,
/// and `init?(string:)` parses those same display names back into cases.
@objc
public enum CheatCodeTypes: Int, CaseIterable, Sendable {
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
    case gateway
    case rawCode
    case rawMemAddress

    /// The human-readable display name used in Core.plist and the UI.
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
        case .proActionReplayV1: return "Pro Action Replay V1"
        case .proActionReplayV2: return "Pro Action Replay V2"
        case .gateway: return "Gateway"
        case .rawCode: return "Raw Code"
        case .rawMemAddress: return "Raw MemAddress:Value Pairs"
        }
    }

    /// Initializes a `CheatCodeTypes` case from its display-name string.
    ///
    /// Used when deserializing `PVSupportedCheatTypes` arrays from Core.plist.
    /// Returns `nil` for unknown strings (unknown values are logged by the caller).
    ///
    /// Matching is case-insensitive and tolerant of spaces/underscores, and
    /// accepts common aliases used by various cores (e.g. "GameShark",
    /// "Action Replay v1/v2", "Action Replay v3").
    public init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        // Strip all non-alphanumeric characters (spaces, underscores, slashes,
        // parentheses, colons, etc.) for maximum tolerance. This allows variants
        // like "GameShark", "game_shark", "Action Replay v1/v2", etc.
        let compact = lowercased
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .reduce("") { $0 + String($1) }

        switch compact {
        case "codebreaker":
            self = .codeBreaker

        case "gamegenie":
            self = .gameGenie

        // GameShark family (with or without spaces/underscores, case-insensitive)
        case "gameshark", "gamesharkv1", "gameshark1":
            self = .gameShark
        case "gamesharkv2", "gameshark2":
            self = .gameSharkV2
        case "gamesharkv3", "gameshark3":
            self = .gameSharkV3

        case "gecko":
            self = .gecko

        case "goldfinger":
            self = .goldFinger

        // Pro Action Replay / Action Replay aliases
        case "proactionreplay", "actionreplay":
            self = .proActionReplay

        case "proactionreplayv1", "proactionreplay1",
             "actionreplayv1", "actionreplay1":
            self = .proActionReplayV1

        // "Action Replay v1/v2" is a combined format label (e.g. from VisualBoyAdvance).
        // The "/" is stripped by normalization, giving "actionreplayv1v2".
        // Map to v2 since the format encompasses the v2 superset.
        case "proactionreplayv2", "proactionreplay2",
             "actionreplayv2", "actionreplay2",
             "actionreplayv1v2":
            self = .proActionReplayV2

        // Some cores report "Action Replay v3"; map to the closest available type.
        case "proactionreplayv3", "proactionreplay3",
             "actionreplayv3", "actionreplay3":
            self = .proActionReplayV2

        case "gateway":
            self = .gateway

        case "rawcode":
            self = .rawCode

        // "Raw Address Value Pairs (PPSSPP CwCheat)" (emitted by PPSSPP core):
        // After stripping all non-alphanumerics, becomes "rawaddressvaluepairsppssppcwcheat".
        // "Raw MemAddress:Value Pairs" becomes "rawmemaddressvaluepairs".
        case "rawmemaddressvaluepairs",
             "rawaddressvaluepairsppssppcwcheat":
            self = .rawMemAddress

        default:
            // Fall back to the original exact-string matching to preserve any
            // legacy or unforeseen formats that happen to match exactly.
            switch trimmed {
            case "Code Breaker":
                self = .codeBreaker
            case "Game Genie":
                self = .gameGenie
            case "Game Shark":
                self = .gameShark
            case "Game Shark V2":
                self = .gameSharkV2
            case "Game Shark V3":
                self = .gameSharkV3
            case "Gecko":
                self = .gecko
            case "Gold Finger":
                self = .goldFinger
            case "Gateway":
                self = .gateway
            case "Pro Action Replay":
                self = .proActionReplay
            case "Pro Action Replay V1":
                self = .proActionReplayV1
            case "Pro Action Replay V2":
                self = .proActionReplayV2
            case "Raw Code":
                self = .rawCode
            case "Raw MemAddress:Value Pairs":
                self = .rawMemAddress
            default:
                return nil
            }
        }
    }
}

/// Converts an array of `CheatCodeTypes` to their string display names.
public func CheatCodeTypesMakeStringArray(_ types: [CheatCodeTypes]) -> [String] {
    return types.cheatCodeTypeStrings
}

public extension Collection where Self.Element == CheatCodeTypes {
    /// The display-name strings for all elements.
    var cheatCodeTypeStrings: [String] { map { $0.stringValue } }
}
