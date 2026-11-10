//
//  SkinDevicePreference.swift
//  PVUIBase
//
//  Which of a skin's device representations to draw, chosen from the window.
//
//  A skin ships separate iPhone and iPad layouts. A folding iPhone, unfolded, keeps the phone
//  idiom but has a window of about 1.4:1 in both postures, the shape iPad layouts are drawn
//  for; iPhone layouts are drawn for 19.5:9. So an unfolded phone prefers a skin's iPad layout
//  and falls back to its iPhone one, and every other window keeps the single device it had.
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SkinKitCore
#if canImport(UIKit)
import UIKit
#endif

public enum SkinDevicePreference {
    /// The devices whose representations a window can use, best first.
    public static func candidates(for windowClass: AdaptiveWindowClass) -> [DeltaSkinDevice] {
        switch windowClass {
        case .phone: [.iphone]
        case .expandedPhone: [.ipad, .iphone]
        case .tablet: [.ipad]
        }
    }

    /// The first candidate the skin has a representation for, else the best candidate.
    ///
    /// The fallback keeps today's behavior for a skin that supports none of them: its traits
    /// resolve to nothing and the built-in controls take over.
    public static func device(
        among candidates: [DeltaSkinDevice],
        where isSupported: (DeltaSkinDevice) -> Bool
    ) -> DeltaSkinDevice {
        candidates.first(where: isSupported) ?? candidates.first ?? .iphone
    }

    /// The device to draw `skin` with in `orientation`.
    public static func device(
        for skin: (any DeltaSkinProtocol)?,
        orientation: DeltaSkinOrientation,
        among candidates: [DeltaSkinDevice]
    ) -> DeltaSkinDevice {
        guard let skin else { return candidates.first ?? .iphone }
        return device(among: candidates) { supports(skin, device: $0, orientations: [orientation]) }
    }

    /// The device to draw `skin` with in whichever orientation it supports (previews).
    public static func device(for skin: any DeltaSkinProtocol, among candidates: [DeltaSkinDevice]) -> DeltaSkinDevice {
        device(among: candidates) { supportsAny(skin, among: [$0]) }
    }

    /// Whether `skin` can be drawn on any of the candidates, in any of `orientations`.
    public static func supportsAny(
        _ skin: any DeltaSkinProtocol,
        among candidates: [DeltaSkinDevice],
        orientations: [DeltaSkinOrientation] = [.portrait, .landscape]
    ) -> Bool {
        candidates.contains { supports(skin, device: $0, orientations: orientations) }
    }

    private static let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]

    private static func supports(
        _ skin: any DeltaSkinProtocol,
        device: DeltaSkinDevice,
        orientations: [DeltaSkinOrientation]
    ) -> Bool {
        orientations.contains { orientation in
            displayTypes.contains { displayType in
                skin.supports(DeltaSkinTraits(device: device, displayType: displayType, orientation: orientation))
            }
        }
    }
}

public extension SkinDevicePreference {
    /// Candidates for the window `AdaptiveWindow` last reported (SwiftUI views).
    @MainActor
    static var currentCandidates: [DeltaSkinDevice] {
        candidates(for: AdaptiveWindow.shared.windowClass)
    }

    #if canImport(UIKit)
    /// Candidates for a window with these traits (UIKit view controllers).
    @MainActor
    static func candidates(for traits: UITraitCollection) -> [DeltaSkinDevice] {
        candidates(for: AdaptiveWindowClass.of(traits))
    }
    #endif
}
