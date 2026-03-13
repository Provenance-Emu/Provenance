// PVSceneDelegate.swift
// Provenance
//
// Dedicated UIWindowSceneDelegate registered via
// `application(_:configurationForConnecting:options:)` in PVAppDelegate.
//
// Responsibilities (scope-limited on purpose):
//  • Capture UIApplicationShortcutItems from cold-launch connection options.
//  • Handle foreground shortcut taps via windowScene(_:performActionFor:).
//  • Forward both to HomeScreenShortcutService — no game launching here.
//
// Window / view-hierarchy setup is intentionally absent.  SwiftUI's WindowGroup
// manages its own window through internal APIs regardless of whether a custom
// scene delegate exists.  We just need to be the registered delegate so that
// iOS routes shortcut callbacks to us instead of SwiftUI's private no-op class.

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
import PVUIBase
import PVLogging

public final class PVSceneDelegate: UIResponder, UIWindowSceneDelegate {

    /// SwiftUI manages the actual UIWindow — we don't need to touch it.
    public var window: UIWindow?

    // MARK: - Cold-launch shortcut (app not running)

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            ILOG("PVSceneDelegate: cold-launch shortcut \(shortcutItem.type)")
            Task { @MainActor in
                HomeScreenShortcutService.shared.handleShortcutTap(shortcutItem)
            }
        }
    }

    // MARK: - Foreground shortcut (app already running)

    public func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        ILOG("PVSceneDelegate: foreground shortcut \(shortcutItem.type)")
        Task { @MainActor in
            HomeScreenShortcutService.shared.handleShortcutTap(shortcutItem)
        }
        completionHandler(true)
    }
}
#endif
