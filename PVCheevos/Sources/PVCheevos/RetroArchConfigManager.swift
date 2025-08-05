import Foundation

/// Manages RetroArch configuration file for RetroAchievements settings
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public final class RetroArchConfigManager: @unchecked Sendable {
    public static let shared = RetroArchConfigManager()

    private let userDefaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "com.pvcheevos.retroarch", qos: .userInitiated)

    // UserDefaults keys for app settings
    private let enabledKey = "ra_cheevos_enabled"
    private let hardcoreModeKey = "ra_cheevos_hardcore_mode"

    // RetroArch config keys
    private let retroArchKeys = (
        username: "cheevos_username",
        password: "cheevos_password",
        enable: "cheevos_enable",
        hardcore: "cheevos_hardcore_mode_enable"
    )

    private init() {}

    // MARK: - Public Properties

    /// Whether RetroAchievements is enabled in the app
    public var isRetroAchievementsEnabled: Bool {
        get {
            return queue.sync {
                userDefaults.bool(forKey: enabledKey)
            }
        }
        set {
            queue.async {
                self.userDefaults.set(newValue, forKey: self.enabledKey)
                self.syncToRetroArch()
            }
        }
    }

    /// Whether hardcore mode is enabled
    public var isHardcoreModeEnabled: Bool {
        get {
            return queue.sync {
                userDefaults.bool(forKey: hardcoreModeKey)
            }
        }
        set {
            queue.async {
                self.userDefaults.set(newValue, forKey: self.hardcoreModeKey)
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

    // MARK: - Private Methods

    /// Sync current app settings to RetroArch config file
    private func syncToRetroArch() {
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

        // Get current credentials
        let credentials = RetroCredentialsManager.shared.loadCredentials()
        let username = credentials?.username ?? ""
        let password = credentials?.password ?? ""

        // Update config values
        configContent = updateConfigValue(
            in: configContent,
            key: retroArchKeys.username,
            value: username
        )

        configContent = updateConfigValue(
            in: configContent,
            key: retroArchKeys.password,
            value: password
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
            userDefaults.set(enabled, forKey: enabledKey)
        }

        if let hardcoreStr = hardcoreValue {
            let hardcore = hardcoreStr.lowercased() == "true"
            userDefaults.set(hardcore, forKey: hardcoreModeKey)
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
