    //
    //  GameWithCheat.swift
    //  PVSupport
    //
import Foundation

@objc
public enum CheatCodeTypes: Int {
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
}

public func CheatCodeTypesMakeStringArray(_ types: [CheatCodeTypes]) -> [String] {
    return types.cheatCodeTypeStrings
}

public extension Collection where Self.Element == CheatCodeTypes {
    var cheatCodeTypeStrings: [String] { map { $0.stringValue } }
}

@objc public protocol GameWithCheat {
    @objc(setCheatWithCode:type:enabled:)
    optional func setCheat(code: String, type: String, enabled: Bool ) -> Bool

    @objc(setCheatWithCode:type:codeType:cheatIndex:enabled:)
    func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool

    @objc(supportsCheatCode)
    var supportsCheatCode: Bool { get }

    @objc(cheatCodeTypes)
    var cheatCodeTypes: [String] { get }

    @objc(resetCheatCodes)
    optional func resetCheatCodes()
}
