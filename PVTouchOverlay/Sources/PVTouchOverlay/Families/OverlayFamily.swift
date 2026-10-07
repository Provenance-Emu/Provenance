import Foundation

public struct OverlayFamilySlot: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    // swiftlint:disable identifier_name
    public static let a = OverlayFamilySlot(rawValue: "a"), b = OverlayFamilySlot(rawValue: "b")
    public static let c = OverlayFamilySlot(rawValue: "c"), x = OverlayFamilySlot(rawValue: "x")
    public static let y = OverlayFamilySlot(rawValue: "y"), z = OverlayFamilySlot(rawValue: "z")
    public static let l = OverlayFamilySlot(rawValue: "l"), r = OverlayFamilySlot(rawValue: "r")
    public static let l2 = OverlayFamilySlot(rawValue: "l2"), r2 = OverlayFamilySlot(rawValue: "r2")
    public static let l3 = OverlayFamilySlot(rawValue: "l3"), r3 = OverlayFamilySlot(rawValue: "r3")
    public static let start = OverlayFamilySlot(rawValue: "start"), select = OverlayFamilySlot(rawValue: "select")
    public static let one = OverlayFamilySlot(rawValue: "one"), two = OverlayFamilySlot(rawValue: "two")
    public static let plus = OverlayFamilySlot(rawValue: "plus"), minus = OverlayFamilySlot(rawValue: "minus")
    public static let home = OverlayFamilySlot(rawValue: "home")
    public static let cUp = OverlayFamilySlot(rawValue: "cUp"), cDown = OverlayFamilySlot(rawValue: "cDown")
    public static let cLeft = OverlayFamilySlot(rawValue: "cLeft"), cRight = OverlayFamilySlot(rawValue: "cRight")
    // swiftlint:enable identifier_name
}

/// A controller shape. Systems bind to a family and supply tokens, labels and a palette.
public protocol OverlayFamily {
    static var id: String { get }
    /// Slots the binding must provide tokens for. D-pads and sticks use fixed tokens.
    static var requiredSlots: [OverlayFamilySlot] { get }
    static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                         orientation: OverlayOrientation) -> OverlayTemplate
}

public enum OverlayFamilyRegistry {
    public static let all: [any OverlayFamily.Type] = [
        TwoButtonFamily.self, FourFaceFamily.self, ThreeFaceFamily.self, SixFaceFamily.self,
        N64Family.self, DigitalPadFamily.self, DualStickFamily.self,
        GameCubeFamily.self, WiiRemoteFamily.self, WiiRemoteSidewaysFamily.self, WiiClassicFamily.self,
        DSPadFamily.self, GBAFamily.self
    ]
    public static func family(id: String) -> (any OverlayFamily.Type)? { all.first { $0.id == id } }
}
