//
//  BIOSGuideLink.swift
//  PVUI
//
//  Single source of truth for the "how do I install BIOS files" wiki link.
//

import Foundation
import PVHelp
#if canImport(UIKit)
import UIKit
#endif

/// Shared helper for pointing users at the BIOS requirements wiki page.
///
/// Every surface that reports missing BIOS files states *exactly* which files
/// are needed, but users still get stuck because the message gives them no way
/// to act on it. Each of those surfaces should offer this link so the message
/// is actionable, not just accurate.
///
/// - Note: Opening a browser is iOS-only; tvOS has no browser, so the action
///   helpers below are gated to iOS. A future tvOS affordance could render
///   ``url`` through `PVQRCodeView` or the in-app `WikiPageView`.
public enum BIOSGuideLink {

    /// Title used for the button/action on every surface, so the wording the
    /// message refers to always matches the control the user sees.
    public static let actionTitle = "BIOS Guide"

    /// Canonical web URL of the BIOS requirements wiki page.
    public static var url: URL {
        WikiConstants.webURL(for: WikiConstants.Paths.biosRequirements)
    }

    /// Sentence to append to a missing-BIOS message pointing at the action.
    public static var messageHint: String {
        "Tap \"\(actionTitle)\" for step-by-step instructions on obtaining and installing these files."
    }

#if os(iOS)
    /// Open the BIOS guide in the user's browser.
    @MainActor
    public static func open() {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// A `.default` alert action that opens the BIOS guide.
    ///
    /// - Parameter completion: Run after the guide is opened. A `UIAlertController`
    ///   dismisses on *any* action, so surfaces presented over a live emulator must
    ///   pass the same teardown their close button performs — otherwise tapping the
    ///   guide leaves the user on a dead emulator screen with the core still running.
    @MainActor
    public static func alertAction(then completion: (@MainActor () -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: actionTitle, style: .default, handler: { _ in
            Task { @MainActor in
                open()
                completion?()
            }
        })
    }
#endif
}
