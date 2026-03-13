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

// MARK: - Toast Handle

/// An opaque handle returned by `showPersistent` that can be used to dismiss a specific toast.
public final class PVToastHandle: @unchecked Sendable {
    public let id: String
    private weak var manager: PVToastManager?

    init(id: String, manager: PVToastManager) {
        self.id = id
        self.manager = manager
    }

    /// Dismiss the associated persistent toast.
    public func dismiss() {
        manager?.dismiss(id: id)
    }
}

// MARK: - Toast Manager

/// Singleton responsible for queuing and auto-dismissing in-game toast notifications.
///
/// Usage:
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
    /// Current toast queue, newest first (bottom of the stack).
    @Published public private(set) var toasts: [PVToast] = []

    // MARK: Private state
    private var dismissTimers: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Public API

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
        return PVToastHandle(id: id, manager: self)
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
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
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
