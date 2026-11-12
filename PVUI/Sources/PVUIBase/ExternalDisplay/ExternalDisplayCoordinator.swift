//
//  ExternalDisplayCoordinator.swift
//  PVUI
//
//  Tracks the external display the system hands the app: a cabled display or an AirPlay
//  screen. Both arrive as a window scene with the non-interactive external display role.
//

#if os(iOS)
import UIKit
import PVLogging

/// Holds the external display's window scene while one is connected.
///
/// The app shows nothing there by itself: until some window is put on the scene, the system
/// mirrors the device. `PVEmulatorViewController` adds a window for the game picture.
@MainActor
public final class ExternalDisplayCoordinator {
    public static let shared = ExternalDisplayCoordinator()

    /// Posted on the main thread when an external display connects or disconnects.
    public static let didChangeNotification = Notification.Name("org.provenance-emu.externalDisplay.didChange")

    /// The connected external display's scene, if any.
    public private(set) var scene: UIWindowScene?

    public var isConnected: Bool { scene != nil }

    private init() {}

    func sceneDidConnect(_ scene: UIWindowScene) {
        ILOG("External display connected: \(scene.screen.bounds.size) @\(scene.screen.scale)x")
        self.scene = scene
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard self.scene === scene else { return }
        ILOG("External display disconnected")
        self.scene = nil
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}

/// Scene delegate for the external display role. Registered in
/// `application(_:configurationForConnecting:options:)`.
public final class PVExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    public func scene(_ scene: UIScene,
                      willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        ExternalDisplayCoordinator.shared.sceneDidConnect(windowScene)
    }

    public func sceneDidDisconnect(_ scene: UIScene) {
        ExternalDisplayCoordinator.shared.sceneDidDisconnect(scene)
    }
}
#endif
