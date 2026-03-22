import Foundation

/// Metadata describing a physical iPhone case with built-in controller buttons.
///
/// ## Detection strategies
///
/// Provenance uses two complementary strategies:
///
/// 1. **Smart cases** — cases with Bluetooth/MFi electronics (GameSir Pocket Taco,
///    Soolra) appear as `GCController` devices.  ``vendorNames`` lists all known
///    `GCController.vendorName` strings for a given model.
///
/// 2. **Passive cases** — cases that are purely mechanical overlays (e.g. Buppin)
///    have no radio and cannot be detected via `GCController`.  Instead,
///    ``knownSkinIdentifiers`` stores the skin `identifier` strings that developers
///    publish on deltastyles.com and other skin communities when they release a skin
///    tailored for that case.  When the user installs or selects such a skin,
///    Provenance can surface a contextual tip.
public struct PhysicalCaseLayout: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Display name shown to the user (e.g. "GameSir Pocket Taco").
    public let name: String

    /// Stable identifier — derived from `name` for simplicity.
    public var id: String { name }

    /// `GCController.vendorName` strings known to identify this case.
    ///
    /// Empty for passive (non-smart) cases that have no Bluetooth/MFi radio.
    /// Matching is performed case-insensitively by ``CaseControllerDetector``.
    public let vendorNames: [String]

    /// Number of physical hardware buttons on the case (approximate).
    public let buttonCount: Int

    /// Skin `identifier` strings that skin authors use when publishing skins
    /// designed for this case on deltastyles.com and similar communities.
    ///
    /// Used by ``CaseControllerDetector/casesCompatibleWithSkin(_:)`` to detect
    /// a passive case indirectly — the case itself has no radio, but if the user
    /// installs its companion skin, Provenance knows the case is likely in use.
    public let knownSkinIdentifiers: [String]

    /// Whether this case exposes a `GCController` (Bluetooth/MFi electronics).
    ///
    /// Returns `false` for purely mechanical cases like Buppin.
    public var isSmart: Bool { !vendorNames.isEmpty }

    // MARK: - Init

    public init(
        name: String,
        vendorNames: [String] = [],
        buttonCount: Int,
        knownSkinIdentifiers: [String] = []
    ) {
        self.name = name
        self.vendorNames = vendorNames
        self.buttonCount = buttonCount
        self.knownSkinIdentifiers = knownSkinIdentifiers
    }
}
