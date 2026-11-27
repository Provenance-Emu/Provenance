#if os(iOS) && !targetEnvironment(macCatalyst)
import Combine
import GameController
import GamepadKit
import SwiftUI
import UIKit

private enum ClamshellDockPreferences {
    static let modeKey = "clamshellDock.mode"
    static let heightKey = "clamshellDock.coverMillimetres"
    static let heightRange: ClosedRange<Double> = 20 ... 110

    static var controllerNames: [String?] { GCController.controllers().map(\.vendorName) }

    static func height(_ stored: Double) -> Double {
        guard stored > 0 else { return 0 }
        return min(max(stored, heightRange.lowerBound), heightRange.upperBound)
    }
}

/// Shortens full-screen windows so presented content clears the controller too.
@MainActor
final class ClamshellScreenCover {
    static let shared = ClamshellScreenCover()

    private var subscriptions = Set<AnyCancellable>()
    private var sceneObservers: [NSKeyValueObservation] = []
    private let shortenedWindows = NSHashTable<UIWindow>.weakObjects()

    private init() {}

    func start() {
        guard UIDevice.current.userInterfaceIdiom == .phone, subscriptions.isEmpty else { return }

        let center = NotificationCenter.default
        for name in [
            .GCControllerDidConnect, .GCControllerDidDisconnect,
            UIScene.didActivateNotification, UIScene.didDisconnectNotification,
            UIWindow.didBecomeKeyNotification, UserDefaults.didChangeNotification
        ] {
            center.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                }
                .store(in: &subscriptions)
        }
        refresh()
    }

    private func refresh() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }
        sceneObservers = scenes.map { scene in
            scene.observe(\.effectiveGeometry, options: [.new]) { [weak self] scene, _ in
                MainActor.assumeIsolated { self?.apply(to: scene) }
            }
        }
        scenes.forEach { apply(to: $0) }
    }

    private func apply(to scene: UIWindowScene) {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: ClamshellDockPreferences.modeKey)
            .flatMap(ClamshellDockMode.init(rawValue:)) ?? .automatic
        let height = ClamshellDockPreferences.height(defaults.double(forKey: ClamshellDockPreferences.heightKey))
        let cover = ClamshellDockCatalog.coverPoints(
            mode: mode, storedMillimetres: height, controllerNames: ClamshellDockPreferences.controllerNames
        )
        let full = scene.coordinateSpace.bounds
        let inset = scene.effectiveGeometry.interfaceOrientation == .portrait
            ? min(CGFloat(cover), (full.height * 2 / 3).rounded()) : 0
        let target = CGRect(origin: full.origin, size: CGSize(width: full.width, height: full.height - inset))

        for window in scene.windows {
            if inset > 0 {
                guard window.frame == full || shortenedWindows.contains(window) else { continue }
                shortenedWindows.add(window)
            } else {
                guard shortenedWindows.contains(window) else { continue }
                shortenedWindows.remove(window)
            }
            if window.frame != target { window.frame = target }
        }
    }
}

struct ClamshellDockSettingsRows: View {
    @AppStorage(ClamshellDockPreferences.modeKey) private var mode = ClamshellDockMode.automatic
    @AppStorage(ClamshellDockPreferences.heightKey) private var storedHeight = 0.0
    @State private var controllerNames = ClamshellDockPreferences.controllerNames

    private var shownHeight: Double {
        let height = ClamshellDockPreferences.height(storedHeight)
        if height > 0 { return height }
        return controllerNames.lazy.compactMap { ClamshellDockCatalog.entry(forControllerNamed: $0) }
            .first?.coverMillimetres ?? ClamshellDockCatalog.defaultCoverMillimetres
    }

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            Group {
                Picker("Controller Covers Screen", selection: $mode) {
                    Text("Automatic").tag(ClamshellDockMode.automatic)
                    Text("Always").tag(ClamshellDockMode.always)
                    Text("Off").tag(ClamshellDockMode.off)
                }
                if mode != .off {
                    Stepper(
                        "Covered Height: \(Int(shownHeight)) mm",
                        value: Binding(get: { shownHeight }, set: { storedHeight = $0 }),
                        in: ClamshellDockPreferences.heightRange,
                        step: 2
                    )
                }
                Text("Keeps the app above the controller in portrait. Automatic applies to recognized clamshell controllers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .onAppear { controllerNames = ClamshellDockPreferences.controllerNames }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)
                .merge(with: NotificationCenter.default.publisher(for: .GCControllerDidDisconnect))
                .receive(on: DispatchQueue.main)) { _ in
                    controllerNames = ClamshellDockPreferences.controllerNames
                }
        }
    }
}
#endif
