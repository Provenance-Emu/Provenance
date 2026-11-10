//
//  AdaptiveWindow.swift
//  PVUIBase
//
//  Layout decisions that follow the window instead of the device.
//
//  A folding iPhone keeps the phone idiom in both postures, and its window changes while the
//  app runs: folded it is one compact-width panel, unfolded it is regular in both size
//  classes, a combination no other iPhone reports (a Max phone in landscape is regular
//  width but compact height). Neither `UIDevice.current.userInterfaceIdiom` nor
//  `UIDevice.current.orientation` changes when it folds, so anything keyed on them keeps the
//  phone layout on a tablet-sized window, or a portrait skin on a landscape-shaped one.
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// How much room the app's window gives the interface.
public enum AdaptiveWindowClass: Equatable, Sendable {
    /// A phone-sized window: every non-folding iPhone, and a folding one while folded.
    case phone
    /// A phone-idiom window that is regular in both size classes: a folding iPhone, unfolded.
    case expandedPhone
    /// Anything that is not a phone: iPad, Mac, Apple TV.
    case tablet

    /// The pure rule, kept separate from UIKit so it can be unit-tested.
    public static func resolve(
        isPhoneIdiom: Bool,
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?
    ) -> AdaptiveWindowClass {
        guard isPhoneIdiom else { return .tablet }
        return horizontal == .regular && vertical == .regular ? .expandedPhone : .phone
    }
}

/// Whether the window is wider than it is tall.
///
/// A folding iPhone unfolds from a portrait-shaped window to a landscape-shaped one without
/// the device rotating, so the shape has to come from the window's own size.
public enum AdaptiveWindowShape: Equatable, Sendable {
    case portrait
    case landscape

    /// `nil` for an unmeasured (empty) size, so callers keep what they had.
    public static func resolve(_ size: CGSize) -> AdaptiveWindowShape? {
        guard size.width > 0, size.height > 0 else { return nil }
        return size.width > size.height ? .landscape : .portrait
    }
}

#if canImport(UIKit)
public extension AdaptiveWindowShape {
    /// The shape of an unfolded phone's window, and `nil` for every other window.
    ///
    /// Code that follows `UIDevice.current.orientation` keeps doing so wherever this is
    /// `nil`, so no existing device changes behavior; an unfolded phone follows its window.
    @MainActor
    static func ofExpandedPhone(traits: UITraitCollection, size: CGSize) -> AdaptiveWindowShape? {
        let windowClass = AdaptiveWindowClass.resolve(
            isPhoneIdiom: traits.userInterfaceIdiom == .phone,
            horizontal: sizeClass(traits.horizontalSizeClass),
            vertical: sizeClass(traits.verticalSizeClass))
        return windowClass == .expandedPhone ? resolve(size) : nil
    }

    private static func sizeClass(_ sizeClass: UIUserInterfaceSizeClass) -> UserInterfaceSizeClass? {
        switch sizeClass {
        case .compact: .compact
        case .regular: .regular
        default: nil
        }
    }
}
#endif

/// Rules for the layouts that change with `AdaptiveWindowClass`.
public enum AdaptiveWindowRules {
    /// Narrowest window the library sidebar pins in on a phone-idiom device: the width of
    /// the smallest iPad in portrait, where the sidebar already pins today.
    public static let sidebarPinMinimumWidth: CGFloat = 744

    /// Whether the library shows its sidebar beside the games instead of as a drawer.
    ///
    /// iPad pins whenever its width is regular, as before. An unfolded phone pins only once
    /// the window is as wide as an iPad's: held upright it is regular width but too narrow
    /// to give up a sidebar's worth of covers.
    public static func pinsLibrarySidebar(
        windowClass: AdaptiveWindowClass,
        horizontal: UserInterfaceSizeClass?,
        width: CGFloat
    ) -> Bool {
        switch windowClass {
        case .phone: false
        case .expandedPhone: width >= sidebarPinMinimumWidth
        case .tablet: horizontal == .regular
        }
    }

    /// Whether the library uses its one-handed phone chrome: the system selector docked at
    /// the bottom, the compact header and the BIOS tab.
    public static func usesCompactPhoneChrome(
        windowClass: AdaptiveWindowClass,
        vertical: UserInterfaceSizeClass?
    ) -> Bool {
        windowClass == .phone && vertical != .compact
    }
}

/// The current window's size and class, published for views that cannot read them from
/// their own environment (static layout helpers, UIKit code).
///
/// Fed by `reportsAdaptiveWindow()` on the app's root view. Reading a property inside a
/// SwiftUI body registers a dependency, so those views re-lay out when the device folds.
@MainActor
@Observable
public final class AdaptiveWindow {
    public static let shared = AdaptiveWindow()

    public private(set) var windowClass: AdaptiveWindowClass
    public private(set) var size: CGSize = .zero

    private init() {
        windowClass = AdaptiveWindowClass.resolve(
            isPhoneIdiom: Self.isPhoneIdiom, horizontal: nil, vertical: nil)
    }

    /// The window's shape while it is an unfolded phone's, and `nil` otherwise: the one case
    /// where the window, not `UIDevice.current.orientation`, says portrait or landscape.
    public var expandedPhoneShape: AdaptiveWindowShape? {
        windowClass == .expandedPhone ? AdaptiveWindowShape.resolve(size) : nil
    }

    /// Each property is written only when it changes, so a layout pass that changes nothing
    /// invalidates no view.
    func update(size newSize: CGSize, horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) {
        let newClass = AdaptiveWindowClass.resolve(
            isPhoneIdiom: Self.isPhoneIdiom, horizontal: horizontal, vertical: vertical)
        if windowClass != newClass {
            windowClass = newClass
        }
        if size != newSize {
            size = newSize
        }
    }

    private static var isPhoneIdiom: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}

private struct AdaptiveWindowReporter: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { report(proxy.size) }
                        .onChange(of: proxy.size) { _, size in report(size) }
                        .onChange(of: horizontalSizeClass) { _, _ in report(proxy.size) }
                        .onChange(of: verticalSizeClass) { _, _ in report(proxy.size) }
                }
                .ignoresSafeArea()
            }
    }

    private func report(_ size: CGSize) {
        AdaptiveWindow.shared.update(size: size, horizontal: horizontalSizeClass, vertical: verticalSizeClass)
    }
}

public extension View {
    /// Publishes this view's size and size classes as the window's, through `AdaptiveWindow`.
    /// Apply once, to a view that fills the window.
    func reportsAdaptiveWindow() -> some View {
        modifier(AdaptiveWindowReporter())
    }
}
