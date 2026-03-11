import Foundation

public extension SkinCatalogEntry {
    /// The filename used when saving this catalog entry into the local skins directory.
    ///
    /// The catalog uses a stable `downloadURL`, and `DeltaSkinManager.importSkin(from:)` preserves the source filename.
    /// This gives us a reliable way to detect already-downloaded skins even when the catalog `id` does not match
    /// the internal `info.identifier` embedded in the `.deltaskin` file.
    var expectedLocalFileName: String {
        let name = downloadURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return "\(id).deltaskin"
    }
}

