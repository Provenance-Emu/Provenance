import CoreGraphics
import Foundation
import Combine

/// Stores per-button position offsets for drag-to-reposition edit mode.
///
/// Offsets are keyed by `skinIdentifier + "." + buttonId` and stored as deltas in
/// mapping-space points (the same coordinate space as `DeltaSkinButton.frame`).
/// A positive `x` offset moves the button right; a positive `y` offset moves it down.
@MainActor
public final class DeltaSkinButtonOffsets: ObservableObject {

    // MARK: - Shared instance

    public static let shared = DeltaSkinButtonOffsets()

    // MARK: - Published state

    /// Fires whenever any offset changes so that views can re-render.
    @Published private(set) var revision: Int = 0

    // MARK: - Storage

    /// In-memory cache of offsets.  Key: `"\(skinIdentifier).\(buttonId)"`, Value: `CGPoint`.
    private var cache: [String: CGPoint] = [:]

    private let userDefaultsKeyPrefix = "com.provenance.deltaskin.buttonoffsets.v1."

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Returns the stored offset for a button, or `.zero` if none has been saved.
    public func offset(for buttonId: String, skinIdentifier: String) -> CGPoint {
        let key = cacheKey(buttonId: buttonId, skinIdentifier: skinIdentifier)
        if let cached = cache[key] {
            return cached
        }
        // Load lazily from UserDefaults
        let loaded = loadOffset(buttonId: buttonId, skinIdentifier: skinIdentifier)
        cache[key] = loaded
        return loaded
    }

    /// Persists an offset for a button.  Pass `.zero` to reset it to the default position.
    public func setOffset(_ offset: CGPoint, for buttonId: String, skinIdentifier: String) {
        let key = cacheKey(buttonId: buttonId, skinIdentifier: skinIdentifier)
        cache[key] = offset
        save(offset: offset, key: key, skinIdentifier: skinIdentifier)
        revision &+= 1
    }

    /// Resets all custom offsets for a given skin back to zero.
    public func resetOffsets(for skinIdentifier: String) {
        let udKey = userDefaultsKeyPrefix + skinIdentifier
        UserDefaults.standard.removeObject(forKey: udKey)
        // Clear cache entries for this skin
        let prefix = skinIdentifier + "."
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
        revision &+= 1
    }

    /// Returns `true` if any button in the given skin has a non-zero offset.
    public func hasCustomOffsets(for skinIdentifier: String) -> Bool {
        let udKey = userDefaultsKeyPrefix + skinIdentifier
        if let dict = UserDefaults.standard.dictionary(forKey: udKey), !dict.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Private helpers

    private func cacheKey(buttonId: String, skinIdentifier: String) -> String {
        "\(skinIdentifier).\(buttonId)"
    }

    private func loadOffset(buttonId: String, skinIdentifier: String) -> CGPoint {
        let udKey = userDefaultsKeyPrefix + skinIdentifier
        guard let dict = UserDefaults.standard.dictionary(forKey: udKey),
              let rawValue = dict[buttonId] as? [String: Double] else {
            return .zero
        }
        return CGPoint(x: rawValue["x"] ?? 0, y: rawValue["y"] ?? 0)
    }

    private func save(offset: CGPoint, key: String, skinIdentifier: String) {
        // Extract buttonId: remove the skinIdentifier prefix + separator
        let prefix = skinIdentifier + "."
        let buttonId: String
        if key.hasPrefix(prefix) {
            buttonId = String(key.dropFirst(prefix.count))
        } else {
            buttonId = key
        }
        let udKey = userDefaultsKeyPrefix + skinIdentifier
        var dict = (UserDefaults.standard.dictionary(forKey: udKey) as? [String: [String: Double]]) ?? [:]
        if offset == .zero {
            dict.removeValue(forKey: buttonId)
        } else {
            dict[buttonId] = ["x": Double(offset.x), "y": Double(offset.y)]
        }
        if dict.isEmpty {
            UserDefaults.standard.removeObject(forKey: udKey)
        } else {
            UserDefaults.standard.set(dict, forKey: udKey)
        }
    }
}
