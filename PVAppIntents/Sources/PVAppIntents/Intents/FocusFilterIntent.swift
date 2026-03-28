//
//  FocusFilterIntent.swift
//  PVAppIntents
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Integrates Provenance with iOS Focus modes (Gaming Focus, Do Not Disturb, etc.)
//  Registered via `SetFocusFilterIntent` — iOS automatically calls this when
//  the user activates a Focus that includes Provenance as a "Customize App" entry.
//

#if canImport(AppIntents) && (os(iOS) || os(macOS))
import AppIntents

/// Configures Provenance behaviour when a Focus mode is active.
///
/// Users can add Provenance to any Focus in Settings → Focus → [Focus Name] →
/// App Customization. When the Focus activates, iOS calls `perform()`.
///
/// Current behaviour:
/// - Suppresses in-app notifications (achievement alerts, import warnings)
///   when `suppressNotifications` is `true` (default when Gaming Focus is on).
///
/// Future behaviour (once #2654 Game Music Player merges):
/// - Auto-start background music when Gaming Focus activates.
///
/// Note: `SetFocusFilterIntent` is iOS 16+ / macOS 13+ only — not available on tvOS or watchOS.
@available(iOS 17, macOS 14, *)
public struct ProvenanceFocusFilterIntent: SetFocusFilterIntent {

    public static let title: LocalizedStringResource = "Provenance Gaming Focus"
    public static let description = IntentDescription(
        "Customise Provenance when a Focus mode is active — suppress notifications and prepare for distraction-free gaming.",
        categoryName: "Focus"
    )

    // MARK: - Parameters

    @Parameter(
        title: "Suppress In-App Notifications",
        description: "Hides achievement alerts and import notifications while this Focus is active.",
        default: true
    )
    public var suppressNotifications: Bool

    // MARK: - Display Representation

    /// Describes the current focus filter configuration in system UI.
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Provenance Gaming Focus",
            subtitle: suppressNotifications ? "Notifications suppressed" : "Notifications enabled"
        )
    }

    // MARK: - Focus App Context

    public var appContext: FocusFilterAppContext {
        get async {
            FocusFilterAppContext(notificationFilterPredicate: suppressNotifications ? NSPredicate(value: false) : nil)
        }
    }

    // MARK: - Init

    public init() {}

    // MARK: - Perform

    public func perform() async throws -> some IntentResult {
        // Write the current focus state to App Group UserDefaults so the host
        // app and widget extension can read it without importing AppIntents.
        pvAppGroupDefaults?.set(suppressNotifications, forKey: "focusSuppressNotifications")
        return .result()
    }
}
#endif
