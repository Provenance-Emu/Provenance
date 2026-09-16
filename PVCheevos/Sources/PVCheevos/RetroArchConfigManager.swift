import Foundation

/// Manages RetroArch configuration file for RetroAchievements settings
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public final class RetroArchConfigManager: @unchecked Sendable {
    public static let shared = RetroArchConfigManager()

    private let userDefaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "com.pvcheevos.retroarch", qos: .userInitiated)

    private let defaultsKeys = (
        enabled: "retroAchievementsEnabled",
        hardcore: "retroAchievementsHardcoreEnabled"
    )
    private let legacyDefaultsKeys = (
        enabled: "ra_cheevos_enabled",
        hardcore: "ra_cheevos_hardcore_mode"
    )

    // RetroArch config keys
    private let retroArchKeys = (
        username: "cheevos_username",
        password: "cheevos_password",
        token: "cheevos_token",
        enable: "cheevos_enable",
        hardcore: "cheevos_hardcore_mode_enable"
    )

    /// RetroArch stores the RetroAchievements token in a `char[32]` buffer
    /// (`configuration.h`), so anything longer is silently truncated on its side
    /// and authentication then fails with no visible cause.
    static let maxRetroArchTokenLength = 31

    private init() {}

        // MARK: - Public Properties

    /// Whether RetroAchievements is enabled in the app
    public var isRetroAchievementsEnabled: Bool {
        get {
            readBooleanSetting(primaryKey: defaultsKeys.enabled, legacyKey: legacyDefaultsKeys.enabled)
        }
        set {
            writeBooleanSetting(newValue, primaryKey: defaultsKeys.enabled, legacyKey: legacyDefaultsKeys.enabled)
            queue.async {
                self.syncToRetroArch()
            }
        }
    }

    /// Whether hardcore mode is enabled
    public var isHardcoreModeEnabled: Bool {
        get {
            readBooleanSetting(primaryKey: defaultsKeys.hardcore, legacyKey: legacyDefaultsKeys.hardcore)
        }
        set {
            writeBooleanSetting(newValue, primaryKey: defaultsKeys.hardcore, legacyKey: legacyDefaultsKeys.hardcore)
            queue.async {
                self.syncToRetroArch()
            }
        }
    }

    // MARK: - RetroArch Config Path

    /// Get the RetroArch config file path
    private var retroArchConfigPath: URL? {
        let fileManager = FileManager.default

        #if os(tvOS)
        // On tvOS, use Caches directory
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesDir.appendingPathComponent("RetroArch/config/retroarch.cfg")
        #else
        // On iOS/macOS, use Documents directory
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDir.appendingPathComponent("RetroArch/config/retroarch.cfg")
        #endif
    }

    // MARK: - Public Methods

    /// Save current settings to RetroArch config file
    public func saveSettingsToRetroArch() {
        queue.async {
            self.syncToRetroArch()
        }
    }

    /// Update credentials and sync to RetroArch
    public func updateCredentials(username: String, password: String) {
        queue.async {
            // Save credentials using RetroCredentialsManager
            RetroCredentialsManager.shared.saveCredentials(username: username, password: password)

            // Sync to RetroArch
            self.syncToRetroArch()
        }
    }

    /// Load current settings from RetroArch config (if available)
    public func loadSettingsFromRetroArch() {
        queue.async {
            self.loadFromRetroArch()
        }
    }

    /// Blanks `cheevos_username`, `cheevos_token` and `cheevos_password` in
    /// `retroarch.cfg`. Call this alongside clearing the credential store on logout.
    ///
    /// The scrub is expressed explicitly rather than relying on
    /// `RetroCredentialsManager.clearAll()` having already emptied the store:
    /// that runs on `com.pvcheevos.credentials` while this runs on
    /// `com.pvcheevos.retroarch`, and correctness across two independent serial
    /// queues should not rest on FIFO reasoning about their interleaving.
    public func clearPersistedCredentials() {
        queue.async {
            self.syncToRetroArch(scrub: true)
        }
    }

    /// Rewrites `retroarch.cfg` onto the token scheme if it still carries a
    /// cleartext `cheevos_password` written by an older build.
    ///
    /// A no-op when the file is absent or the password field is already empty,
    /// so it is cheap to call unconditionally on launch.
    public func migratePersistedPasswordToToken() {
        queue.async {
            guard let configPath = self.retroArchConfigPath,
                  FileManager.default.fileExists(atPath: configPath.path),
                  let contents = try? String(contentsOf: configPath),
                  let existing = self.parseConfigValue(from: contents, key: self.retroArchKeys.password),
                  !existing.isEmpty else {
                return
            }
            self.syncToRetroArch()
        }
    }

    // MARK: - Credential Fields

    /// The RetroAchievements fields written into `retroarch.cfg`.
    struct RetroArchCredentialFields: Equatable {
        let username: String
        let token: String
        /// Always empty. See `retroArchCredentialFields(scrub:)`.
        let password: String
    }

    /// Computes the RetroAchievements credential fields to persist to `retroarch.cfg`.
    ///
    /// RetroArch itself never keeps the password on disk. On a successful login it
    /// copies the token into `cheevos_token` and immediately blanks
    /// `cheevos_password` — literally `/* store the token, clear the password */` in
    /// `cheevos/cheevos.c` — then authenticates from the token, falling back to
    /// username plus password only when no token is present.
    ///
    /// We mirror that, so `password` is **always** empty here, including when no
    /// token is available yet. The alternative, writing the password as a fallback,
    /// puts a reusable secret into a file the app publishes over unauthenticated LAN
    /// HTTP and WebDAV. A missing token produces a visible authentication failure;
    /// a persisted password produces a silent credential leak.
    ///
    /// - Parameter scrub: when `true`, every field is blanked, for logout.
    func retroArchCredentialFields(scrub: Bool = false) -> RetroArchCredentialFields {
        guard !scrub else {
            return RetroArchCredentialFields(username: "", token: "", password: "")
        }

        let credentials = RetroCredentialsManager.shared.loadCredentials()
        var token = RetroCredentialsManager.shared.loadSessionToken() ?? ""

        if token.count > Self.maxRetroArchTokenLength {
            print("RetroAchievements token is \(token.count) chars, over "
                + "RetroArch's \(Self.maxRetroArchTokenLength)-char limit; it "
                + "would be truncated and rejected. Writing an empty token instead.")
            token = ""
        }

        return RetroArchCredentialFields(
            username: credentials?.username ?? "",
            token: token,
            password: ""
        )
    }

    // MARK: - Private Methods

    /// Reads the canonical app setting and migrates the legacy RetroArch-only key on first access.
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

    /// Sync current app settings to RetroArch config file.
    /// - Parameter scrub: blank every credential field instead of writing the
    ///   stored ones, without touching the Keychain/UserDefaults credential store.
    private func syncToRetroArch(scrub: Bool = false) {
        guard let configPath = retroArchConfigPath else {
            print("RetroArch config path not found")
            return
        }

        // Ensure directory exists
        let configDir = configPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Read existing config or create new one
        var configContent = ""
        if FileManager.default.fileExists(atPath: configPath.path) {
            configContent = (try? String(contentsOf: configPath)) ?? ""
        }

        // Get the fields to persist. `password` is always empty — see
        // `retroArchCredentialFields(scrub:)` for why we mirror RetroArch here.
        let fields = retroArchCredentialFields(scrub: scrub)

        // Update config values
        configContent = updateConfigValue(
            in: configContent,
            key: retroArchKeys.username,
            value: fields.username
        )

        configContent = updateConfigValue(
            in: configContent,
            key: retroArchKeys.token,
            value: fields.token
        )

        configContent = updateConfigValue(
            in: configContent,
            key: retroArchKeys.password,
            value: fields.password
        )

        configContent = updateConfigValue(
            in: configContent,
            key: retroArchKeys.enable,
            value: isRetroAchievementsEnabled ? "true" : "false"
        )

        configContent = updateConfigValue(
            in: configContent,
            key: retroArchKeys.hardcore,
            value: isHardcoreModeEnabled ? "true" : "false"
        )

        // Write updated config
        do {
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            print("RetroArch config updated successfully")
        } catch {
            print("Failed to write RetroArch config: \(error)")
        }
    }

    /// Load settings from RetroArch config file
    private func loadFromRetroArch() {
        guard let configPath = retroArchConfigPath,
              FileManager.default.fileExists(atPath: configPath.path),
              let configContent = try? String(contentsOf: configPath) else {
            return
        }

        // Parse config values
        let enabledValue = parseConfigValue(from: configContent, key: retroArchKeys.enable)
        let hardcoreValue = parseConfigValue(from: configContent, key: retroArchKeys.hardcore)

        // Update app settings if values found
        if let enabledStr = enabledValue {
            let enabled = enabledStr.lowercased() == "true"
            writeBooleanSetting(enabled, primaryKey: defaultsKeys.enabled, legacyKey: legacyDefaultsKeys.enabled)
        }

        if let hardcoreStr = hardcoreValue {
            let hardcore = hardcoreStr.lowercased() == "true"
            writeBooleanSetting(hardcore, primaryKey: defaultsKeys.hardcore, legacyKey: legacyDefaultsKeys.hardcore)
        }
    }

    /// Update or add a config value in the content string
    private func updateConfigValue(in content: String, key: String, value: String) -> String {
        let pattern = "^\\s*\(NSRegularExpression.escapedPattern(for: key))\\s*=.*$"
        let newLine = "\(key) = \"\(value)\""

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            let range = NSRange(content.startIndex..<content.endIndex, in: content)

            if regex.firstMatch(in: content, options: [], range: range) != nil {
                // Key exists, replace it
                return regex.stringByReplacingMatches(
                    in: content,
                    options: [],
                    range: range,
                    withTemplate: newLine
                )
            } else {
                // Key doesn't exist, append it
                let separator = content.isEmpty || content.hasSuffix("\n") ? "" : "\n"
                return content + separator + newLine + "\n"
            }
        } catch {
            print("Failed to update config value for \(key): \(error)")
            return content
        }
    }

    /// Parse a config value from the content string
    private func parseConfigValue(from content: String, key: String) -> String? {
        let pattern = "^\\s*\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*\"?([^\"\\n]*)\"?\\s*$"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            let range = NSRange(content.startIndex..<content.endIndex, in: content)

            if let match = regex.firstMatch(in: content, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: content) {
                return String(content[valueRange])
            }
        } catch {
            print("Failed to parse config value for \(key): \(error)")
        }

        return nil
    }
}
