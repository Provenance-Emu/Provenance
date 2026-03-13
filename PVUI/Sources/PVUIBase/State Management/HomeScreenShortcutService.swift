// HomeScreenShortcutService.swift
// Provenance
//
// Manages Home Screen Quick Actions (3D Touch / long-press on the app icon).
//
// Design goals:
//  • Never touches UIKit during bootup — starts observing only after bootup completes.
//  • Shortcut taps that arrive before bootup is done are queued and delivered afterward.
//  • Realm observations run on a background scheduler; UIKit assignment is always on main.
//  • Database access goes through PVGameLibrary so it works with both Realm and (future) SwiftData.
//  • Single responsibility: registration + tap routing only.  Navigation is delegated to AppState.

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
import RxSwift
import PVLibrary
import PVLogging

@MainActor
public final class HomeScreenShortcutService {

    // MARK: - Singleton

    public static let shared = HomeScreenShortcutService()
    private init() {}

    // MARK: - Private state

    private var disposeBag = DisposeBag()
    /// True once `startObserving` has been called (i.e. bootup is complete).
    private(set) var isReady: Bool = false
    /// Shortcut tap that arrived before bootup was complete.
    private var pendingMD5: String?

    // MARK: - Lifecycle

    /// Start live observation of favorites and recents.
    /// Call this exactly once, after bootup has completed and `AppState.gameLibrary` is available.
    public func startObserving(gameLibrary: PVGameLibrary<RealmDatabaseDriver>) {
        guard !isReady else { return }
        isReady = true

        let maxItems = 4   // iOS shows up to 4 Quick Actions
        let maxPerGroup = maxItems / 2

        Observable.combineLatest(
            gameLibrary.favorites
                .mapMany { $0.asShortcut(isFavorite: true) }
                .map { Array($0.prefix(maxPerGroup)) },
            gameLibrary.recents
                .mapMany { $0.game?.asShortcut(isFavorite: false) }
                .map { Array($0.compactMap { $0 }.prefix(maxPerGroup)) }
        ) { favorites, recents in
            Array((favorites + recents).prefix(maxItems))
        }
        .observe(on: MainScheduler.instance)
        .bind(onNext: { shortcuts in
            UIApplication.shared.shortcutItems = shortcuts
            ILOG("HomeScreenShortcutService: registered \(shortcuts.count) shortcut item(s)")
        })
        .disposed(by: disposeBag)

        // Deliver any tap that arrived during bootup
        if let md5 = pendingMD5 {
            pendingMD5 = nil
            ILOG("HomeScreenShortcutService: delivering queued tap md5=\(md5)")
            deliverTap(md5: md5)
        }
    }

    // MARK: - Tap handling

    /// Called by `PVSceneDelegate` when a Home Screen Quick Action is tapped.
    public func handleShortcutTap(_ item: UIApplicationShortcutItem) {
        ILOG("HomeScreenShortcutService: shortcut tapped type=\(item.type)")
        guard item.type == "kRecentGameShortcut",
              let md5 = item.userInfo?["PVGameHash"] as? String,
              !md5.isEmpty else {
            WLOG("HomeScreenShortcutService: unrecognized shortcut type or missing PVGameHash")
            return
        }

        if isReady {
            deliverTap(md5: md5)
        } else {
            // Bootup not yet complete — queue for delivery once startObserving is called.
            ILOG("HomeScreenShortcutService: bootup not complete, queueing md5=\(md5)")
            pendingMD5 = md5
        }
    }

    // MARK: - Private

    private func deliverTap(md5: String) {
        ILOG("HomeScreenShortcutService: opening game md5=\(md5)")
        AppState.shared.appOpenAction = .openMD5(md5)
    }
}
#endif
