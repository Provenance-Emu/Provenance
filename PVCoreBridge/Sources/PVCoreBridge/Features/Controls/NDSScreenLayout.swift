//
//  NDSScreenLayout.swift
//  PVCoreBridge
//
//  Where the two Nintendo DS screens sit inside the single framebuffer a DS
//  libretro core emits. The arrangement is a core option (melonDS
//  `melonds_screen_layout`, DeSmuME `desmume_screens_layout`, melonDS DS
//  `melonds_screen_layout1`), so both the Metal dual-screen renderer (which
//  splits the framebuffer back into two screens) and the stylus path (which
//  must address the bottom screen inside the whole framebuffer) read it here.
//

import CoreGraphics
import Foundation

/// One of the two physical DS screens.
public enum NDSScreen: Sendable, Equatable {
    case top
    case bottom

    /// The other screen.
    public var other: NDSScreen { self == .top ? .bottom : .top }
}

/// How a DS core arranges its two screens in the framebuffer.
public enum NDSScreenArrangement: Sendable, Equatable {
    case topBottom
    case bottomTop
    case leftRight
    case rightLeft
    case topOnly
    case bottomOnly
    /// Hybrid, rotated and quick-switch layouts. Their geometry is not modelled,
    /// so neither the dual-screen split nor the stylus mapping is available.
    case unsupported
}

/// The DS core families whose screen-layout options Provenance understands.
public enum NDSCoreFamily: Sendable, Equatable {
    /// Legacy melonDS libretro core (`melonds`), also the native PVMelonDS core.
    case melonDS
    /// melonDS DS (`melondsds`).
    case melonDSDS
    /// DeSmuME / DeSmuME 2015.
    case desmume

    /// Detects the family from a Provenance core identifier.
    public init?(coreIdentifier: String?) {
        let identifier = coreIdentifier?.lowercased() ?? ""
        if identifier.contains("melondsds") {
            self = .melonDSDS
        } else if identifier.contains("melonds") {
            self = .melonDS
        } else if identifier.contains("desmume") {
            self = .desmume
        } else {
            return nil
        }
    }

    /// Core option key holding the screen arrangement.
    public var layoutOptionKey: String {
        switch self {
        case .melonDS: return "melonds_screen_layout"
        // melonDS DS cycles through up to eight layouts; the first is the one in effect at boot.
        case .melonDSDS: return "melonds_screen_layout1"
        case .desmume: return "desmume_screens_layout"
        }
    }

    /// Core option key holding the gap between the screens, in native pixels.
    public var gapOptionKey: String {
        switch self {
        case .melonDS, .melonDSDS: return "melonds_screen_gap"
        case .desmume: return "desmume_screens_gap"
        }
    }

    /// melonDS only inserts the gap between vertically stacked screens; DeSmuME
    /// also inserts it between side-by-side screens.
    var appliesGapHorizontally: Bool { self == .desmume }
}

/// Geometry of a DS core's framebuffer, in native (1x) DS pixels.
///
/// Every rectangle is resolution-scale independent: a core rendering at N× native
/// resolution scales its whole framebuffer, gap included, so normalised positions
/// derived from this model are valid at any internal resolution.
public struct NDSScreenLayout: Sendable, Equatable {
    /// Native width of one DS screen.
    public static let screenWidth: CGFloat = 256
    /// Native height of one DS screen.
    public static let screenHeight: CGFloat = 192
    /// Largest libretro `RETRO_DEVICE_POINTER` coordinate magnitude.
    public static let libretroPointerMaximum: CGFloat = 0x7fff

    /// Upstream defaults for every DS core: screens stacked, no gap.
    public static let `default` = NDSScreenLayout(arrangement: .topBottom, gap: 0)

    public let arrangement: NDSScreenArrangement
    /// Gap between the screens in native pixels (never negative).
    public let gap: CGFloat

    public init(arrangement: NDSScreenArrangement, gap: CGFloat) {
        self.arrangement = arrangement
        self.gap = max(0, gap)
    }

    /// Builds the layout from a core's current option values.
    ///
    /// - Parameter optionValue: returns the current string value for an option key,
    ///   or `nil` when the core has not reported one. Missing or unrecognised
    ///   values fall back to ``default``.
    public init(family: NDSCoreFamily, optionValue: (String) -> String?) {
        let arrangement = optionValue(family.layoutOptionKey)
            .flatMap(Self.arrangement(fromOptionValue:)) ?? Self.default.arrangement
        var gap = optionValue(family.gapOptionKey)
            .flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .map { CGFloat($0) } ?? Self.default.gap
        if !family.appliesGapHorizontally && (arrangement == .leftRight || arrangement == .rightLeft) {
            gap = 0
        }
        self.init(arrangement: arrangement, gap: gap)
    }

    /// Parses the layout value of any supported DS core, e.g. melonDS "Top/Bottom",
    /// DeSmuME "top only", melonDS DS "left-right". Returns `nil` when unrecognised.
    static func arrangement(fromOptionValue value: String) -> NDSScreenArrangement? {
        let normalized = value.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "-", with: "/")
        switch normalized {
        case "top/bottom": return .topBottom
        case "bottom/top": return .bottomTop
        case "left/right": return .leftRight
        case "right/left": return .rightLeft
        case "top only", "top": return .topOnly
        case "bottom only", "bottom": return .bottomOnly
        case "hybrid top", "hybrid bottom", "hybrid/top", "hybrid/bottom",
             "flipped/hybrid/top", "flipped/hybrid/bottom",
             "rotate/left", "rotate/right", "rotate/180", "quick switch":
            return .unsupported
        default: return nil
        }
    }

    /// `true` when both screens are present in the framebuffer.
    public var showsBothScreens: Bool {
        frame(of: .top) != nil && frame(of: .bottom) != nil
    }

    /// Size of the whole framebuffer, or `nil` for unsupported arrangements.
    public var framebufferSize: CGSize? {
        let width = Self.screenWidth
        let height = Self.screenHeight
        switch arrangement {
        case .topBottom, .bottomTop: return CGSize(width: width, height: height * 2 + gap)
        case .leftRight, .rightLeft: return CGSize(width: width * 2 + gap, height: height)
        case .topOnly, .bottomOnly: return CGSize(width: width, height: height)
        case .unsupported: return nil
        }
    }

    /// Where `screen` is drawn in the framebuffer, or `nil` when it is not drawn.
    public func frame(of screen: NDSScreen) -> CGRect? {
        let size = CGSize(width: Self.screenWidth, height: Self.screenHeight)
        let second = CGPoint(x: 0, y: Self.screenHeight + gap)
        let secondHorizontal = CGPoint(x: Self.screenWidth + gap, y: 0)
        let origin: CGPoint?
        switch (arrangement, screen) {
        case (.topBottom, .top), (.bottomTop, .bottom),
             (.leftRight, .top), (.rightLeft, .bottom),
             (.topOnly, .top), (.bottomOnly, .bottom):
            origin = .zero
        case (.topBottom, .bottom), (.bottomTop, .top):
            origin = second
        case (.leftRight, .bottom), (.rightLeft, .top):
            origin = secondHorizontal
        case (.topOnly, .bottom), (.bottomOnly, .top), (.unsupported, _):
            origin = nil
        }
        return origin.map { CGRect(origin: $0, size: size) }
    }

    /// Origin of the region in which the core accepts stylus input. This equals the
    /// bottom screen's frame except in DeSmuME's horizontal layouts, which accept
    /// touches from x = 256 even when a gap pushes the drawn screen further right.
    private var touchOrigin: CGPoint? {
        switch arrangement {
        case .leftRight: return CGPoint(x: Self.screenWidth, y: 0)
        default: return frame(of: .bottom)?.origin
        }
    }

    /// Maps a DS touchscreen point (x 0–255, y 0–191) to the normalised (0–1)
    /// whole-framebuffer position that `RETRO_DEVICE_POINTER` reports.
    ///
    /// libretro pointer coordinates span the whole framebuffer, and in touch mode
    /// DS cores only accept points inside their bottom-screen region, so the point
    /// is offset into that region. Pixel centres are used so the cores' truncating
    /// decoders land back on the same DS pixel.
    ///
    /// - Returns: `nil` when the layout does not show a touchable bottom screen.
    public func normalizedPointerPosition(forTouchScreenPoint point: CGPoint) -> CGPoint? {
        guard let size = framebufferSize, let origin = touchOrigin,
              frame(of: .bottom) != nil else { return nil }
        let pixelCentre: CGFloat = 0.5
        let x = min(max(point.x.rounded(.down), 0), Self.screenWidth - 1) + pixelCentre
        let y = min(max(point.y.rounded(.down), 0), Self.screenHeight - 1) + pixelCentre
        return CGPoint(x: (origin.x + x) / size.width,
                       y: (origin.y + y) / size.height)
    }

    /// Converts a normalised (0–1) position to the libretro pointer range
    /// (-0x7fff…0x7fff), clamping out-of-range input.
    public static func libretroPointerCoordinate(_ normalized: CGFloat) -> Int16 {
        let clamped = min(max(normalized, 0), 1)
        return Int16(clamping: Int((clamped * 2 - 1) * libretroPointerMaximum))
    }
}

/// Adopted by DS cores so the frontend can read the framebuffer layout they emit.
public protocol NDSScreenLayoutProviding: AnyObject {
    /// The layout currently selected by the core's options.
    var ndsScreenLayout: NDSScreenLayout { get }
}
