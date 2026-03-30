//
//  PVEmulatorViewController+OSD.swift
//  PVUIBase
//
//  Bridges PVOSDMessageNotification (posted by emulator core bridges) to
//  PVToastManager so in-game OSD messages surface as native toasts.
//

import Foundation
import PVLogging

// MARK: - Notification constants (mirror PVOSDNotification.h)

private extension Notification.Name {
    /// Must match `PVOSDMessageNotification` in PVOSDNotification.h
    static let pvOSDMessage = Notification.Name("PVOSDMessageNotification")
}

private enum PVOSDKey {
    static let message  = "PVOSDMessage"
    static let type     = "PVOSDType"
    static let duration = "PVOSDDuration"
}

/// Raw int values from the PVOSDType NS_ENUM in PVOSDNotification.h
private enum PVOSDTypeValue: Int {
    case info    = 0
    case success = 1
    case warning = 2
    case error   = 3
}

// MARK: - PVEmulatorViewController OSD observer

extension PVEmulatorViewController {

    /// Register to receive OSD notifications posted by emulator core bridges.
    /// Call from `viewDidLoad` (or wherever other system notifications are registered).
    func registerForOSDNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOSDNotification(_:)),
            name: .pvOSDMessage,
            object: nil
        )
    }

    @objc private func handleOSDNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo[PVOSDKey.message] as? String,
              !message.isEmpty
        else { return }

        let rawType  = (userInfo[PVOSDKey.type] as? Int) ?? PVOSDTypeValue.info.rawValue
        var duration = (userInfo[PVOSDKey.duration] as? Double) ?? 3.0
        if duration <= 0 {
            // `PVOSDDuration` semantics: 0 (or negative) = use default duration
            duration = 3.0
        }
        let osdType  = PVOSDTypeValue(rawValue: rawType) ?? .info

        let toastType: PVToastType = {
            switch osdType {
            case .info:    return .info
            case .success: return .success
            case .warning: return .warning
            case .error:   return .error
            }
        }()

        DLOG("OSD message [\(osdType)] \(duration)s — \(message)")

        // Detect progress-like messages (contain %) and use replaceKey so
        // they update in-place instead of stacking dozens of toasts.
        // Also use replaceKey for common RA sequential messages like
        // "Controller connected", achievement notifications, etc.
        let replaceKey: String?
        var progress: Double? = nil
        if message.contains("%") {
            // Progress messages: "Loading... 5%", "Compiling shaders: 42%", etc.
            // Use a stable key based on the message prefix (before any numbers)
            let prefix = message.replacingOccurrences(of: "\\d+", with: "#", options: .regularExpression)
            replaceKey = "progress:\(prefix)"

            // Parse the numeric percentage value for the progress bar.
            // Matches patterns like "98%", "5 %", "42.5%"
            if let range = message.range(of: "\\d+\\.?\\d*\\s*%", options: .regularExpression) {
                let matched = message[range].replacingOccurrences(of: "[^\\d.]", with: "", options: .regularExpression)
                if let value = Double(matched), value >= 0, value <= 100 {
                    progress = value / 100.0
                }
            }
        } else if message.lowercased().contains("controller") || message.lowercased().contains("connected") || message.lowercased().contains("disconnected") {
            replaceKey = "controller-status"
        } else {
            replaceKey = nil
        }

        PVToastManager.post(message, type: toastType, duration: duration, category: "osd", replaceKey: replaceKey, progress: progress)
    }
}
