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

        // 1. Set shortcuts immediately from the current Realm snapshot so they show
        //    even before the reactive observer fires its first emission.
        applySnapshot(gameLibrary: gameLibrary)

        // 2. Subscribe for live updates as favorites / recents change.
        //    The closure captures gameLibrary weakly-by-reference; since it's a class
        //    held by AppState for the app's lifetime, strong capture is also safe, but
        //    explicit capture avoids a retain cycle through the DisposeBag.
        let maxPerGroup = 2

        Observable.combineLatest(
            gameLibrary.favorites
                .mapMany { $0.asShortcut(isFavorite: true) }
                .map { Array($0.prefix(maxPerGroup)) },
            gameLibrary.recents
                .mapMany { $0.game?.asShortcut(isFavorite: false) }
                .map { Array($0.prefix(maxPerGroup)) }
        ) { favorites, recents in (favorites, recents) }
        .observe(on: MainScheduler.instance)
        .bind(onNext: { [weak gameLibrary] (favorites, recents) in
            guard let gameLibrary else { return }
            let shortcuts = Self.buildShortcuts(
                favorites: favorites, recents: recents, library: gameLibrary)
            UIApplication.shared.shortcutItems = shortcuts
            ILOG("HomeScreenShortcutService: updated \(shortcuts.count) shortcut item(s)")
        })
        .disposed(by: disposeBag)

        // 3. Deliver any tap that arrived during bootup.
        if let md5 = pendingMD5 {
            pendingMD5 = nil
            ILOG("HomeScreenShortcutService: delivering queued tap md5=\(md5)")
            deliverTap(md5: md5)
        }
    }

    /// Synchronous Realm snapshot — sets shortcutItems immediately without waiting for RxSwift.
    private func applySnapshot(gameLibrary: PVGameLibrary<RealmDatabaseDriver>) {
        let favorites = Array(gameLibrary.favoritesResults.prefix(2))
            .map { $0.asShortcut(isFavorite: true) }
        let recents = Array(gameLibrary.recentsResults.prefix(2))
            .compactMap { $0.game?.asShortcut(isFavorite: false) }
        let shortcuts = Self.buildShortcuts(favorites: favorites, recents: recents, library: gameLibrary)
        UIApplication.shared.shortcutItems = shortcuts
        ILOG("HomeScreenShortcutService: initial snapshot — \(shortcuts.count) item(s) " +
             "(\(favorites.count) fav, \(recents.count) recent)")
    }

    /// Merges favorites + recents and backfills from recently imported games when the
    /// combined total falls below `maxTotal`.  Deduplicates by MD5.
    private static func buildShortcuts(
        favorites: [UIApplicationShortcutItem],
        recents: [UIApplicationShortcutItem],
        library: PVGameLibrary<RealmDatabaseDriver>,
        maxTotal: Int = 4
    ) -> [UIApplicationShortcutItem] {
        var result: [UIApplicationShortcutItem] = []
        var seen = Set<String>()

        for item in favorites + recents {
            guard result.count < maxTotal,
                  let md5 = item.userInfo?["PVGameHash"] as? String,
                  !seen.contains(md5) else { continue }
            result.append(item)
            seen.insert(md5)
        }

        // Backfill with recently imported games if we still have open slots.
        if result.count < maxTotal {
            // Scan a small window — scanning the entire library would be wasteful.
            let candidates = Array(library.database
                .all(PVGame.self)
                .sorted(byKeyPath: #keyPath(PVGame.importDate), ascending: false)
                .prefix(maxTotal * 4))
            for game in candidates where result.count < maxTotal {
                guard !game.isInvalidated, !seen.contains(game.md5Hash) else { continue }
                result.append(game.asShortcut(isFavorite: false))
                seen.insert(game.md5Hash)
            }
        }

        return result
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
