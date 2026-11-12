//
//  ExternalDisplaySkinLayout.swift
//  PVUI
//
//  Which of a skin's layouts is drawn around the picture on an external display.
//

#if os(iOS)
import CoreGraphics
import SkinKitCore

/// A skin layout that frames one game screen, for a screen nobody can touch.
///
/// A skin is shown there for its artwork, so only a layout that gives the picture a frame of
/// its own qualifies. Layouts with no screen (the game fills the view and translucent buttons
/// float over it) or several (DS) are left out: the display then shows the picture alone.
struct ExternalDisplaySkinLayout: Equatable {
    let traits: DeltaSkinTraits
    let mappingSize: CGSize
    /// The game screen in the skin's own coordinates (see `SkinViewportGeometry.screenFrame`).
    let screen: CGRect
    /// The picture keeps the game's aspect inside `screen` instead of filling it.
    let maintainsAspectRatio: Bool

    /// Landscape layouts made for a screen like this, best first: one for a TV (Delta's AirPlay
    /// skins), then one for an external display. The first the skin has is used.
    static let authoredLayouts: [(device: DeltaSkinDevice, displayType: DeltaSkinDisplayType)] = [
        (.tv, .standard),
        (.ipad, .externalDisplay),
        (.iphone, .externalDisplay)
    ]

    /// The device layouts to fall back on. None was drawn for a TV, so the one that gives the
    /// largest picture on the display is used (on a 16:9 TV that is usually an iPhone layout,
    /// not the 4:3 iPad one). A display type also matches its standard / edge-to-edge twin
    /// (`DeltaSkin.representation(for:)`), so both iPhone types are listed to compare them.
    static let deviceLayouts: [(device: DeltaSkinDevice, displayType: DeltaSkinDisplayType)] = [
        (.iphone, .standard),
        (.iphone, .edgeToEdge),
        (.ipad, .standard)
    ]

    /// The layout to draw on a display of `containerSize`, or `nil` when the skin has none that
    /// frames exactly one game screen.
    ///
    /// - Parameters:
    ///   - gameIdentifiers: the game's keys for the skin's per-game layouts.
    ///   - screens: the skin's screens for some traits (`nil` when it has no such layout).
    ///   - mappingSize: the skin's coordinate space for some traits.
    static func resolve(gameIdentifiers: [String],
                        usesAltRepresentations: Bool,
                        containerSize: CGSize,
                        screens: (DeltaSkinTraits) -> [DeltaSkinScreen]?,
                        mappingSize: (DeltaSkinTraits) -> CGSize?) -> ExternalDisplaySkinLayout? {
        func layout(_ candidate: (device: DeltaSkinDevice, displayType: DeltaSkinDisplayType)) -> ExternalDisplaySkinLayout? {
            let traits = DeltaSkinTraits(device: candidate.device,
                                         displayType: candidate.displayType,
                                         orientation: .landscape,
                                         externalDisplay: .dedicated,
                                         gameIdentifiers: gameIdentifiers,
                                         usesAltRepresentations: usesAltRepresentations)
            guard let screens = screens(traits), screens.count == 1, let screen = screens.first,
                  screen.placement == .controller,
                  let frame = screen.outputFrame, frame.width > 0, frame.height > 0,
                  let size = mappingSize(traits), size.width > 0, size.height > 0 else { return nil }
            return ExternalDisplaySkinLayout(traits: traits, mappingSize: size, screen: frame,
                                             maintainsAspectRatio: screen.maintainAspectRatio)
        }
        for candidate in authoredLayouts {
            if let authored = layout(candidate) { return authored }
        }
        var best: (layout: ExternalDisplaySkinLayout, area: CGFloat)?
        for deviceLayout in deviceLayouts {
            guard let candidate = layout(deviceLayout) else { continue }
            let screen = candidate.frames(in: containerSize)?.screen ?? .zero
            let area = screen.width * screen.height
            // Strictly larger: an earlier layout keeps a tie (and wins before the display has a size).
            if best == nil || area > (best?.area ?? 0) {
                best = (candidate, area)
            }
        }
        return best?.layout
    }

    /// Where the skin's image and its game screen go in a view of `containerSize`: the image
    /// scaled to fit and centred, as the skin renderer draws a landscape skin on the device.
    func frames(in containerSize: CGSize) -> (image: CGRect, screen: CGRect)? {
        guard let image = SkinViewportGeometry.skinImageFrame(containerSize: containerSize,
                                                              mappingSize: mappingSize,
                                                              restsOnBottomEdge: false) else { return nil }
        return (image, SkinViewportGeometry.screenFrame(screen, mappingSize: mappingSize, in: image))
    }
}
#endif
