//
//  SettingsPresentationStyle.swift
//  PVUI
//
//  How the library presents Settings. A `.sheet` on iPad is a centered card (a form or page sheet, roughly
//  540 to 770pt wide whatever the screen size), which cramps the sidebar layout, so iPad covers the screen
//  instead. Pure, so it is unit-testable without a view.
//

import Foundation
#if os(iOS)
import UIKit
#endif

enum SettingsPresentationStyle: Equatable {
    /// A standard `.sheet`: full height on iPhone, a centered card on iPad.
    case sheet
    /// A `.fullScreenCover`. Settings has its own Done button, so nothing needs the sheet's swipe-to-dismiss.
    case fullScreen

    /// The style for a device.
    ///
    /// Decided by device idiom rather than the live horizontal size class: the size class changes while
    /// Settings is open (Split View, Stage Manager resizing), and a presentation style derived from it would
    /// tear Settings down and present it again mid-use.
    static func style(isPad: Bool) -> SettingsPresentationStyle {
        isPad ? .fullScreen : .sheet
    }

    /// The style on the running device. tvOS never leaves `.sheet`.
    static var current: SettingsPresentationStyle {
        #if os(iOS)
        return style(isPad: UIDevice.current.userInterfaceIdiom == .pad)
        #else
        return .sheet
        #endif
    }
}
