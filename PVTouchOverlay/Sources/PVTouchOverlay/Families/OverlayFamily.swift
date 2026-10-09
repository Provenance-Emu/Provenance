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
    public static let coin = OverlayFamilySlot(rawValue: "coin"), reset = OverlayFamilySlot(rawValue: "reset")
    /// The second d-pad of a dual-d-pad pad.
    public static let dpad2Up = OverlayFamilySlot(rawValue: "dpad2Up")
    public static let dpad2Down = OverlayFamilySlot(rawValue: "dpad2Down")
    public static let dpad2Left = OverlayFamilySlot(rawValue: "dpad2Left")
    public static let dpad2Right = OverlayFamilySlot(rawValue: "dpad2Right")
    /// Keypad keys, `k0`...`k9`, then star and pound.
    public static let k0 = key(0), k1 = key(1), k2 = key(2), k3 = key(3), k4 = key(4)
    public static let k5 = key(5), k6 = key(6), k7 = key(7), k8 = key(8), k9 = key(9)
    public static let kStar = OverlayFamilySlot(rawValue: "kStar"), kPound = OverlayFamilySlot(rawValue: "kPound")
    // swiftlint:enable identifier_name

    private static func key(_ digit: Int) -> OverlayFamilySlot { OverlayFamilySlot(rawValue: "k\(digit)") }

    /// The 12 keypad keys in reading order (1-9, then star, 0, pound).
    public static let keypadKeys: [OverlayFamilySlot] = [k1, k2, k3, k4, k5, k6, k7, k8, k9, kStar, k0, kPound]

    /// Slots a binding may leave without a token. A family hides the control of every omittable slot whose
    /// binding has no token (see `SystemOverlayBinding.isHidden`); a slot outside this set always draws, with
    /// the slot name as its token when the binding has none.
    public static let omittable: Set<OverlayFamilySlot> = [
        .b, .c, .x, .y, .z, .l, .r, .l2, .r2, .start, .select, .reset, .coin
    ]
}

/// A controller shape. Systems bind to a family and supply tokens, labels and a palette.
public protocol OverlayFamily {
    static var id: String { get }
    /// Slots the family draws. A binding must provide a token for each one that is not in
    /// `OverlayFamilySlot.omittable`. D-pads and sticks use fixed tokens.
    static var requiredSlots: [OverlayFamilySlot] { get }
    static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind,
                         orientation: OverlayOrientation) -> OverlayTemplate
}

public enum OverlayFamilyRegistry {
    public static let all: [any OverlayFamily.Type] = [
        TwoButtonFamily.self, FourFaceFamily.self, ThreeFaceFamily.self, SixFaceFamily.self,
        N64Family.self, DigitalPadFamily.self, DualStickFamily.self,
        GameCubeFamily.self, WiiRemoteFamily.self, WiiRemoteSidewaysFamily.self, WiiClassicFamily.self,
        DSPadFamily.self, N3DSPadFamily.self, GBAFamily.self,
        KeypadFamily.self, ArcadeStickFamily.self, PaddleFamily.self, DualDPadFamily.self
    ]
    public static func family(id: String) -> (any OverlayFamily.Type)? { all.first { $0.id == id } }
}
