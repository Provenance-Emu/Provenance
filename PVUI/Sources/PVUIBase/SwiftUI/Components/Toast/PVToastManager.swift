//
//  PVToastManager.swift
//  PVUI
//
//  Created by Claude on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Toast Handle

/// An opaque handle returned by `showPersistent` that can be used to dismiss a specific toast.
///
/// `PVToastHandle` is `Sendable` and its `dismiss()` is `nonisolated`, so it can
/// be called from any concurrency context (background actors, ObjC bridges, etc.)
/// without `await`.
public final class PVToastHandle: Sendable {
    public let id: String

    init(id: String) {
        self.id = id
    }

    /// Dismiss the associated persistent toast.
    /// Safe to call from any actor or thread — internally hops to `@MainActor`
    /// via `PVToastManager.shared.dismissAsync(id:)`.
    public nonisolated func dismiss() {
        PVToastManager.shared.dismissAsync(id: id)
    }
}

// MARK: - Toast Manager

/// Singleton responsible for queuing and auto-dismissing in-game toast notifications.
///
/// ## Why `@MainActor`?
/// `PVToastManager` is `@MainActor` because its state drives SwiftUI via
/// `ObservableObject`/`@Published`, all mutations use `withAnimation`, and
/// `UIAccessibility.post` is main-thread-only.  The annotation is **correct**
/// — it is not a concession.
///
/// ## Calling from non-`@MainActor` contexts
/// Use the `nonisolated` fire-and-forget helpers (no `await` required):
/// ```swift
/// // From any thread, actor, or Obj-C bridge:
/// PVToastManager.post("Save state created", type: .success)
/// PVToastManager.postPersistent("JIT active", id: "jit", type: .jit)
/// PVToastManager.shared.dismissAsync(id: "jit")
/// ```
///
/// ## Calling from `@MainActor` or SwiftUI contexts
/// The synchronous API is available directly:
/// ```swift
/// PVToastManager.shared.show("Save state created", type: .success)
/// let handle = PVToastManager.shared.showPersistent("JIT active", id: "jit", type: .jit)
/// handle.dismiss()
/// ```
@MainActor
public final class PVToastManager: ObservableObject {
    // MARK: Singleton
    public static let shared = PVToastManager()

    // MARK: Published state
    /// Current toast queue, oldest first (newest at the end).
    @Published public private(set) var toasts: [PVToast] = []

    // MARK: Private state
    private var dismissTimers: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Synchronous API (requires @MainActor)

    /// Show a transient toast that auto-dismisses after `duration` seconds.
    public func show(
        _ message: String,
        type: PVToastType = .info,
        duration: TimeInterval = 3.0,
        icon: String? = nil
    ) {
        let toast = PVToast(message: message, type: type, icon: icon, duration: duration, isPersistent: false)
        enqueue(toast)
        scheduleAutoDismiss(id: toast.id, after: duration)
        postAccessibilityAnnouncement(toast)
    }

    /// Show a persistent toast that remains until explicitly dismissed.
    /// - Parameters:
    ///   - id: Stable identifier so callers can dismiss or deduplicate this toast.
    /// - Returns: A handle that can be used to dismiss the toast later.
    @discardableResult
    public func showPersistent(
        _ message: String,
        id: String,
        type: PVToastType = .info,
        icon: String? = nil
    ) -> PVToastHandle {
        // Deduplicate: remove any existing toast with the same id first
        removeToast(withID: id)
        let toast = PVToast(id: id, message: message, type: type, icon: icon, duration: .infinity, isPersistent: true)
        enqueue(toast)
        postAccessibilityAnnouncement(toast)
        return PVToastHandle(id: id)
    }

    /// Dismiss a toast by its string id.
    public func dismiss(id: String) {
        removeToast(withID: id)
    }

    /// Dismiss all toasts immediately.
    public func dismissAll() {
        dismissTimers.values.forEach { $0.cancel() }
        dismissTimers.removeAll()
        withAnimation { toasts.removeAll() }
    }

    // MARK: - Private helpers

    private func enqueue(_ toast: PVToast) {
        withAnimation { toasts.append(toast) }
    }

    private func removeToast(withID id: String) {
        dismissTimers[id]?.cancel()
        dismissTimers.removeValue(forKey: id)
        withAnimation { toasts.removeAll { $0.id == id } }
    }

    private func scheduleAutoDismiss(id: String, after duration: TimeInterval) {
        // Treat non-positive durations as "immediate dismiss"
        if duration <= 0 {
            Task { @MainActor [weak self] in
                self?.removeToast(withID: id)
            }
            return
        }

        // Clamp duration to avoid overflow when converting to UInt64 nanoseconds
        let maxDurationSeconds = TimeInterval(UInt64.max) / 1_000_000_000.0
        let clampedDuration = min(duration, maxDurationSeconds)
        let nanosecondsDouble = min(clampedDuration * 1_000_000_000.0, Double(UInt64.max))
        let delayNanoseconds = UInt64(nanosecondsDouble)

        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.removeToast(withID: id)
            }
        }
        dismissTimers[id] = task
    }

    private func postAccessibilityAnnouncement(_ toast: PVToast) {
        let announcement = "\(toast.type.accessibilityLabel): \(toast.message)"
        #if os(iOS) || os(tvOS)
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }
}

// MARK: - nonisolated fire-and-forget API (callable from any context)

public extension PVToastManager {
    /// Post a transient toast from **any** concurrency context — no `await` needed.
    ///
    /// Internally dispatches to `@MainActor` via an unstructured `Task`.
    /// This is the preferred call site for emulator core bridges, audio callbacks,
    /// and other non-`@MainActor` code.
    ///
    /// ```swift
    /// // In ObjC bridge or background actor — no await, no Task boilerplate:
    /// PVToastManager.post("Cheat applied", type: .success)
    /// ```
    nonisolated static func post(
        _ message: String,
        type: PVToastType = .info,
        duration: TimeInterval = 3.0,
        icon: String? = nil
    ) {
        Task { @MainActor in
            PVToastManager.shared.show(message, type: type, duration: duration, icon: icon)
        }
    }

    /// Post a persistent toast from **any** concurrency context — no `await` needed.
    ///
    /// Returns `Void` (fire-and-forget). If you need the dismiss handle, call
    /// `showPersistent` from a `@MainActor` context instead.
    nonisolated static func postPersistent(
        _ message: String,
        id: String,
        type: PVToastType = .info,
        icon: String? = nil
    ) {
        Task { @MainActor in
            PVToastManager.shared.showPersistent(message, id: id, type: type, icon: icon)
        }
    }

    /// Dismiss a toast by id from **any** concurrency context — no `await` needed.
    nonisolated func dismissAsync(id: String) {
        Task { @MainActor [weak self] in
            self?.dismiss(id: id)
        }
    }

    /// Dismiss all toasts from **any** concurrency context — no `await` needed.
    nonisolated func dismissAllAsync() {
        Task { @MainActor [weak self] in
            self?.dismissAll()
        }
    }
}
