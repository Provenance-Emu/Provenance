import Foundation

/// The app's RetroAchievements on/off and hardcore settings.
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public final class RetroAchievementsSettings: @unchecked Sendable {
    public static let shared = RetroAchievementsSettings()

    private let userDefaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "com.pvcheevos.settings", qos: .userInitiated)

    private let defaultsKeys = (
        enabled: "retroAchievementsEnabled",
        hardcore: "retroAchievementsHardcoreEnabled"
    )
    private let legacyDefaultsKeys = (
        enabled: "ra_cheevos_enabled",
        hardcore: "ra_cheevos_hardcore_mode"
    )

    /// Credential keys older builds wrote into `retroarch.cfg` for the
    /// in-process RetroArch runtime.
    static let legacyCredentialKeys = ["cheevos_username", "cheevos_password", "cheevos_token"]

    private init() {}

    // MARK: - Public Properties

    /// Whether RetroAchievements is enabled in the app
    public var isRetroAchievementsEnabled: Bool {
        get {
            readBooleanSetting(primaryKey: defaultsKeys.enabled, legacyKey: legacyDefaultsKeys.enabled)
        }
        set {
            writeBooleanSetting(newValue, primaryKey: defaultsKeys.enabled, legacyKey: legacyDefaultsKeys.enabled)
        }
    }

    /// Whether hardcore mode is enabled
    public var isHardcoreModeEnabled: Bool {
        get {
            readBooleanSetting(primaryKey: defaultsKeys.hardcore, legacyKey: legacyDefaultsKeys.hardcore)
        }
        set {
            writeBooleanSetting(newValue, primaryKey: defaultsKeys.hardcore, legacyKey: legacyDefaultsKeys.hardcore)
        }
    }

    // MARK: - Legacy retroarch.cfg

    /// Where older builds kept `retroarch.cfg`.
    private var legacyRetroArchConfigPath: URL? {
        #if os(tvOS)
        let directory: FileManager.SearchPathDirectory = .cachesDirectory
        #else
        let directory: FileManager.SearchPathDirectory = .documentDirectory
        #endif
        return FileManager.default.urls(for: directory, in: .userDomainMask).first?
            .appendingPathComponent("RetroArch/config/retroarch.cfg")
    }

    /// Blanks the RetroAchievements username, password and token that older
    /// builds wrote into `retroarch.cfg`.
    ///
    /// Nothing reads that file any more, and it sits in Documents, which the
    /// in-app web uploader and WebDAV server publish over the LAN. A no-op once
    /// the fields are empty, so it is cheap to call on every launch.
    public func scrubLegacyRetroArchConfig() {
        queue.async {
            guard let path = self.legacyRetroArchConfigPath,
                  let contents = try? String(contentsOf: path, encoding: .utf8) else {
                return
            }
            let scrubbed = Self.scrubbingCredentials(in: contents)
            guard scrubbed != contents else { return }
            do {
                try scrubbed.write(to: path, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to scrub RetroAchievements credentials from retroarch.cfg: \(error)")
            }
        }
    }

    /// `contents` with every legacy credential key's value blanked.
    static func scrubbingCredentials(in contents: String) -> String {
        legacyCredentialKeys.reduce(contents) { text, key in
            let pattern = "^(\\s*\(NSRegularExpression.escapedPattern(for: key))\\s*=).*$"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                return text
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1 \"\"")
        }
    }

    // MARK: - Defaults

    /// Reads the canonical app setting and migrates the legacy key on first access.
    func readBooleanSetting(primaryKey: String, legacyKey: String) -> Bool {
        if userDefaults.object(forKey: primaryKey) != nil {
            return userDefaults.bool(forKey: primaryKey)
        }

        guard userDefaults.object(forKey: legacyKey) != nil else {
            return false
        }

        let legacyValue = userDefaults.bool(forKey: legacyKey)
        userDefaults.set(legacyValue, forKey: primaryKey)
        return legacyValue
    }

    /// Persists the canonical setting while mirroring the legacy key for backward compatibility.
    func writeBooleanSetting(_ value: Bool, primaryKey: String, legacyKey: String) {
        userDefaults.set(value, forKey: primaryKey)
        userDefaults.set(value, forKey: legacyKey)
    }
}
