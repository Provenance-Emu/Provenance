import Foundation

/// Multiplayer facts are stored separately from Realm so old libraries need no destructive migration.
/// Local confirmations use exact ROM hashes; catalog entries use system + full disc serial.
@MainActor
public final class NetplayMetadataStore {
    public static let shared = NetplayMetadataStore()
    private let defaults: UserDefaults
    private static let key = "netplay.multiplayerMetadata.v1"
    private var overrides: [String: NetplayMultiplayerMetadata]
    private let catalog: [String: NetplayMultiplayerMetadata]
    public private(set) var loadError: String?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                overrides = try JSONDecoder().decode([String: NetplayMultiplayerMetadata].self, from: data)
            } catch {
                overrides = [:]
                loadError = "Saved multiplayer details could not be read. Games remain unverified."
            }
        } else { overrides = [:] }
        do {
            guard let url = Bundle.module.url(forResource: "MultiplayerCatalog", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            catalog = try JSONDecoder().decode([String: NetplayMultiplayerMetadata].self, from: Data(contentsOf: url))
        } catch {
            catalog = [:]
            loadError = "Multiplayer catalog unavailable. Games without saved details remain unverified."
        }
    }

    public func metadata(md5: String, system: String, serial: String?, isPatched: Bool = false) -> NetplayMultiplayerMetadata? {
        if let local = overrides[Self.identity(md5: md5, system: system)] { return local }
        // Patches can change multiplayer behavior without changing the embedded disc ID.
        guard !isPatched, let serial, !serial.isEmpty else { return nil }
        return catalog[system + ":" + serial.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()]
    }

    /// A user's confirmation applies only to this ROM and never propagates to similarly named games.
    public func save(_ metadata: NetplayMultiplayerMetadata?, md5: String, system: String) throws {
        var updated = overrides
        updated[Self.identity(md5: md5, system: system)] = metadata
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: Self.key)
        overrides = updated
    }

    private static func identity(md5: String, system: String) -> String { system + ":" + md5.uppercased() }
}
