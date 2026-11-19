//
//  TVBezelSceneCache.swift
//  PVUI
//
//  Built TV scenes, kept so a TV seen before shows at once.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A small cache of `TVBezelScene`s, keyed as `GameExternalOutputView` keys a TV: its id, the
/// scene's pixel width, room light and glass.
///
/// Building a scene draws the cabinet with CoreGraphics and PNG-encodes it. With TVs on by
/// default that would run at every game start, and at every step of the pause menu's
/// switcher, so the cache is app-wide rather than per game.
final class TVBezelSceneCache: @unchecked Sendable {
    static let shared = TVBezelSceneCache()

    private let capacity: Int
    private let lock = NSLock()
    private var scenes: [String: TVBezelScene] = [:]
    /// Keys from least to most recently used.
    private var order: [String] = []
    private var memoryWarningObserver: NSObjectProtocol?

    init(capacity: Int = 6) {
        self.capacity = max(1, capacity)
        #if canImport(UIKit) && !os(watchOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.removeAll()
        }
        #endif
    }

    deinit {
        if let memoryWarningObserver { NotificationCenter.default.removeObserver(memoryWarningObserver) }
    }

    /// The scene stored for `key`, which becomes the most recently used.
    func scene(for key: String) -> TVBezelScene? {
        lock.withLock {
            guard let scene = scenes[key] else { return nil }
            touch(key)
            return scene
        }
    }

    func store(_ scene: TVBezelScene, for key: String) {
        lock.withLock {
            scenes[key] = scene
            touch(key)
            while order.count > capacity {
                scenes[order.removeFirst()] = nil
            }
        }
    }

    func removeAll() {
        lock.withLock {
            scenes.removeAll()
            order.removeAll()
        }
    }

    /// Call with `lock` held.
    private func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}
