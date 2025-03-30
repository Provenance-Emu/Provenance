/// Protocol defining core DeltaSkin functionality
public protocol DeltaSkinProtocol {
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
}
