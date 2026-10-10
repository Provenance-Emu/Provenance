/// Protocol defining core DeltaSkin functionality
public protocol DeltaSkinProtocol: Identifiable, Equatable {
    /// Unique identifier for the skin
    var identifier: String { get }

    /// Display name of the skin
    var name: String { get }

    /// Type of game this skin is for (e.g. "com.rileytestut.delta.game.ds")
    var gameType: DeltaSkinGameType { get }

    /// URL where the skin file is stored
    var fileURL: URL { get }

    /// Whether this skin supports given traits
    func supports(_ traits: DeltaSkinTraits) -> Bool

    /// Get the skin image for given traits
    func image(for traits: DeltaSkinTraits) async throws -> UIImage

    /// Get a small preview image whose longest side is about `maxDimension` points
    func thumbnail(for traits: DeltaSkinTraits, maxDimension: CGFloat) async throws -> UIImage

    /// Get screen layouts for the current skin and traits
    func screens(for traits: DeltaSkinTraits) -> [DeltaSkinScreen]?

    /// Get the mapping size for layout calculations
    func mappingSize(for traits: DeltaSkinTraits) -> CGSize?

    /// Returns button mappings for the given traits
    func buttons(for traits: DeltaSkinTraits) -> [DeltaSkinButton]?

    /// Returns screen groups for the given traits
    func screenGroups(for traits: DeltaSkinTraits) -> [DeltaSkinScreenGroup]?

    /// Returns whether debug mode is enabled for this skin
    var isDebugEnabled: Bool { get }

    /// The raw JSON representation of the skin
    var jsonRepresentation: [String: Any] { get }

    func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo?

    /// Optional keyboard overlay configuration embedded in the skin.
    /// Returns `nil` for skins that do not declare a keyboard overlay.
    var keyboardOverlay: KeyboardOverlayConfig? { get }

    /// All named theme variants bundled in this skin. Empty for legacy skins.
    var availableThemes: [DeltaSkin.Theme] { get }

    /// The currently selected theme ID for this skin, or nil for the default appearance.
    var selectedThemeId: String? { get set }

    /// Optional animated background configuration for this skin representation.
    /// Returns `nil` for skins that do not declare a background animation.
    func backgroundAnimation(for traits: DeltaSkinTraits) -> DeltaSkinBackgroundAnimation?

    /// Whether this skin is designed for a physical phone-case controller (GameSir, Soolra, Buppin, etc.).
    /// Determined by the `"caseController"` key in info.json, or by identifier heuristics.
    var isCaseControllerSkin: Bool { get }
}

public extension DeltaSkinProtocol {
    /// Default implementation — skins that do not override this return `nil`.
    var keyboardOverlay: KeyboardOverlayConfig? { nil }

    /// Default implementation — skins without themes return an empty array.
    var availableThemes: [DeltaSkin.Theme] { [] }

    /// Default: check identifier against known case-controller patterns.
    var isCaseControllerSkin: Bool {
        CaseControllerDetector.isCompanionSkinForKnownCase(identifier)
    }

    /// Default implementation — reads/writes from DeltaSkinPreferences using the skin identifier.
    var selectedThemeId: String? {
        get { DeltaSkinPreferences.shared.selectedThemeId(for: identifier) }
        set { DeltaSkinPreferences.shared.setSelectedThemeId(newValue, for: identifier) }
    }

    /// Default implementation — skins that do not override this return `nil`.
    func backgroundAnimation(for traits: DeltaSkinTraits) -> DeltaSkinBackgroundAnimation? { nil }
}

public extension Identifiable where  Self: DeltaSkinProtocol  {
    var id: String  { identifier }
}


public extension Equatable where  Self: DeltaSkinProtocol  {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

public extension DeltaSkinProtocol {
    /// Default: render the full-size image and scale it down. Conformers that can render
    /// directly at thumbnail size (``DeltaSkin``) override this to avoid the large intermediate.
    func thumbnail(for traits: DeltaSkinTraits, maxDimension: CGFloat) async throws -> UIImage {
        let image = try await image(for: traits)
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let size = CGSize(width: image.size.width * maxDimension / longest, height: image.size.height * maxDimension / longest)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
