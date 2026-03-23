import Foundation
import GameController
import PVLogging

/// Identifies physical iPhone cases with built-in controller buttons.
///
/// ## Two-mode detection
///
/// **Smart cases** (GameSir Pocket Taco, Soolra, …) expose a `GCController`
/// over Bluetooth or MFi.  ``layout(for:)`` matches the controller's
/// `vendorName` against the ``PhysicalCaseLayout/vendorNames`` table.
///
/// **Passive cases** (Buppin, …) are purely mechanical plastic overlays with
/// no radio.  They cannot be detected via `GCController`.  Instead,
/// ``casesCompatibleWithSkin(_:)`` lets the app check whether an installed
/// or selected DeltaSkin was published for a known case — skin authors
/// embed a recognisable `identifier` in their `info.json` when uploading to
/// deltastyles.com and other skin repositories.
///
/// ## Notifications
///
/// | Name | Object | userInfo |
/// |------|--------|----------|
/// | ``Notification/Name/PVPhysicalCaseDidConnect`` | `GCController` | `"layout"` → `PhysicalCaseLayout` |
/// | ``Notification/Name/PVPhysicalCaseDidDisconnect`` | `GCController` | `"layout"` → `PhysicalCaseLayout` |
/// | ``Notification/Name/PVPhysicalCaseSkinDetected`` | `String` (skinIdentifier) | `"layout"` → `PhysicalCaseLayout` |
public enum CaseControllerDetector {

    // MARK: - Known layouts

    /// Lookup table of all recognised physical case layouts.
    ///
    /// Add new entries here as new cases are documented.  Use empty
    /// ``PhysicalCaseLayout/vendorNames`` for passive (non-Bluetooth) cases and
    /// populate ``PhysicalCaseLayout/knownSkinIdentifiers`` from the skin IDs that
    /// developers publish on deltastyles.com.
    public static let knownLayouts: [PhysicalCaseLayout] = [
        PhysicalCaseLayout(
            name: "GameSir Pocket Taco",
            vendorNames: [
                "Pocket Taco",
                "GameSir Pocket Taco",
                "GameSir Taco"
            ],
            buttonCount: 4,
            knownSkinIdentifiers: [
                "com.gamesir.pockettaco",
                "com.gamesir.pocket-taco",
                "gamesir.pockettaco",
                "com.litritt.ignited.gamesir.pocket-taco"
            ]
        ),
        PhysicalCaseLayout(
            name: "Soolra Controller",
            vendorNames: [
                "Soolra",
                "Soolra Controller",
                "Soolra MFi"
            ],
            buttonCount: 6,
            knownSkinIdentifiers: [
                "com.soolra.controller",
                "soolra.controller",
                "com.litritt.ignited.soolra"
            ]
        ),
        PhysicalCaseLayout(
            // Buppin is a passive plastic overlay — no Bluetooth, no GCController.
            // Detection relies entirely on skin-ID matching.
            name: "Buppin Case",
            vendorNames: [],
            buttonCount: 2,
            knownSkinIdentifiers: [
                "com.buppin.case",
                "buppin.case",
                "com.buppin.controller",
                "com.litritt.ignited.buppin"
            ]
        )
    ]

    // MARK: - GCController detection (smart cases)

    /// Returns the ``PhysicalCaseLayout`` matching `controller.vendorName`, or
    /// `nil` if the controller is not a recognised case.
    ///
    /// - Parameter controller: A newly connected `GCController`.
    public static func layout(for controller: GCController) -> PhysicalCaseLayout? {
        guard let vendorName = controller.vendorName else { return nil }
        let lowered = vendorName.lowercased()
        return knownLayouts.first { layout in
            layout.vendorNames.contains { $0.lowercased() == lowered }
        }
    }

    /// Returns `true` when `controller` matches a known physical case.
    public static func isKnownCase(_ controller: GCController) -> Bool {
        layout(for: controller) != nil
    }

    // MARK: - Skin-ID detection (passive cases and all known cases)

    /// Returns every ``PhysicalCaseLayout`` whose
    /// ``PhysicalCaseLayout/knownSkinIdentifiers`` contains `skinIdentifier`.
    ///
    /// Call this when the user installs or selects a DeltaSkin to surface a
    /// contextual tip ("This skin is designed for the Buppin Case").  Works
    /// for both smart and passive cases.
    ///
    /// - Parameter skinIdentifier: The `identifier` from the skin's `info.json`.
    public static func casesCompatibleWithSkin(_ skinIdentifier: String) -> [PhysicalCaseLayout] {
        let lowered = skinIdentifier.lowercased()
        return knownLayouts.filter { layout in
            layout.knownSkinIdentifiers.contains { $0.lowercased() == lowered }
        }
    }

    /// Returns the first ``PhysicalCaseLayout`` compatible with `skinIdentifier`,
    /// or `nil` if no known case uses that skin ID.
    public static func caseLayout(forSkinIdentifier skinIdentifier: String) -> PhysicalCaseLayout? {
        casesCompatibleWithSkin(skinIdentifier).first
    }

    // MARK: - Fuzzy vendor-name lookup

    /// Performs a case-insensitive substring check against all known vendor names.
    ///
    /// Use this when the exact `vendorName` string is uncertain (firmware
    /// revisions sometimes change the reported string).  Prefer ``layout(for:)``
    /// for ordinary controller-connect handling.
    ///
    /// - Parameter vendorName: Partial or full vendor name to search for.
    public static func layoutByFuzzyVendorName(_ vendorName: String) -> PhysicalCaseLayout? {
        let trimmed = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        return knownLayouts.first { layout in
            layout.vendorNames.contains {
                let kl = $0.lowercased()
                return kl.contains(lowered) || lowered.contains(kl)
            }
        }
    }

    // MARK: - Notification posting helpers

    /// Posts ``Notification/Name/PVPhysicalCaseDidConnect`` for `controller`
    /// if it matches a known case layout.
    ///
    /// Called automatically by `PVControllerManager.connectController(_:)`.
    ///
    /// - Parameter controller: Newly connected `GCController`.
    @discardableResult
    public static func notifyIfCase(_ controller: GCController) -> PhysicalCaseLayout? {
        guard let caseLayout = layout(for: controller) else { return nil }
        ILOG("CaseControllerDetector: recognised \(caseLayout.name) (vendor: \(controller.vendorName ?? "nil"))")
        NotificationCenter.default.post(
            name: .PVPhysicalCaseDidConnect,
            object: controller,
            userInfo: caseLayout.notificationUserInfo
        )
        return caseLayout
    }

    /// Posts ``Notification/Name/PVPhysicalCaseDidDisconnect`` for `controller`
    /// if it matches a known case layout.
    ///
    /// Called automatically by `PVControllerManager.handleControllerDidDisconnect(_:)`.
    ///
    /// - Parameter controller: Disconnected `GCController`.
    @discardableResult
    public static func notifyDisconnectIfCase(_ controller: GCController) -> PhysicalCaseLayout? {
        guard let caseLayout = layout(for: controller) else { return nil }
        ILOG("CaseControllerDetector: disconnect \(caseLayout.name)")
        NotificationCenter.default.post(
            name: .PVPhysicalCaseDidDisconnect,
            object: controller,
            userInfo: caseLayout.notificationUserInfo
        )
        return caseLayout
    }

    /// Posts ``Notification/Name/PVPhysicalCaseSkinDetected`` when a skin whose
    /// identifier matches a known case is selected or loaded.
    ///
    /// - Parameter skinIdentifier: The DeltaSkin `identifier` string.
    @discardableResult
    public static func notifyIfCaseSkin(_ skinIdentifier: String) -> [PhysicalCaseLayout] {
        let layouts = casesCompatibleWithSkin(skinIdentifier)
        for caseLayout in layouts {
            ILOG("CaseControllerDetector: skin '\(skinIdentifier)' matched case '\(caseLayout.name)'")
            NotificationCenter.default.post(
                name: .PVPhysicalCaseSkinDetected,
                object: skinIdentifier,
                userInfo: caseLayout.notificationUserInfo
            )
        }
        return layouts
    }
}

// MARK: - userInfo key constants

/// String-keyed constants for ``CaseControllerDetector`` notification `userInfo` dictionaries.
public enum CaseControllerDetectorKeys {
    /// `userInfo` key whose value is the matching ``PhysicalCaseLayout`` Swift struct.
    public static let layout = "layout"

    /// `userInfo` key whose value is the case's display name as an `NSString`.
    ///
    /// Provided for Objective-C observers that cannot consume the ``layout``
    /// value directly (it bridges as an opaque `_SwiftValue`).
    public static let layoutName = "layoutName"

    /// `userInfo` key whose value is the case's ``PhysicalCaseLayout/buttonCount``
    /// as an `NSNumber`.
    ///
    /// Provided for Objective-C observers alongside ``layoutName``.
    public static let layoutButtonCount = "layoutButtonCount"
}

// MARK: - Notification.Name extensions

public extension Notification.Name {
    /// Posted when a recognised smart (Bluetooth/MFi) case controller connects.
    ///
    /// - `object`: The `GCController` that connected.
    /// - `userInfo["layout"]`: The matching ``PhysicalCaseLayout``.
    static let PVPhysicalCaseDidConnect = Notification.Name("PVPhysicalCaseDidConnect")

    /// Posted when a recognised smart case controller disconnects.
    ///
    /// - `object`: The `GCController` that disconnected.
    /// - `userInfo["layout"]`: The matching ``PhysicalCaseLayout``.
    static let PVPhysicalCaseDidDisconnect = Notification.Name("PVPhysicalCaseDidDisconnect")

    /// Posted when a skin whose identifier matches a known physical case is
    /// installed or selected by the user.
    ///
    /// - `object`: The skin identifier `String`.
    /// - `userInfo["layout"]`: The matching ``PhysicalCaseLayout``.
    static let PVPhysicalCaseSkinDetected = Notification.Name("PVPhysicalCaseSkinDetected")
}
