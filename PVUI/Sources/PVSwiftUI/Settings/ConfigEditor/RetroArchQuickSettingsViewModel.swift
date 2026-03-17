import Combine
import Foundation
import PVLogging

@MainActor
final class RetroArchQuickSettingsViewModel: ObservableObject {
    @Published var configValues: [String: String] = [:]
    @Published var isLoading = true
    @Published var hasUnsavedChanges = false
    @Published var error: Error?

    private let manager = PVRetroArchCoreManager.shared
    private var originalValues: [String: String] = [:]
    private var saveTask: Task<Void, Never>?

    /// Load current values from retroarch.cfg
    func loadConfig() async {
        isLoading = true
        guard let url = manager.activeConfigURL else {
            WLOG("No active retroarch.cfg found")
            isLoading = false
            return
        }

        let config = await manager.parseConfigFile(at: url)
        configValues = [:]
        for setting in RetroArchCuratedSettings.all {
            let rawValue = config[setting.key] ?? setting.defaultValue
            configValues[setting.key] = stripQuotes(rawValue)
        }
        originalValues = configValues
        hasUnsavedChanges = false
        isLoading = false
        DLOG("Loaded \(configValues.count) curated RA settings")
    }

    /// Get the current value for a setting key as a bool
    func boolValue(for key: String) -> Bool {
        (configValues[key] ?? "false").lowercased() == "true"
    }

    /// Get the current value for a setting key as a double.
    /// Handles unit conversion for byte-valued keys displayed in MB.
    func doubleValue(for key: String) -> Double {
        let raw = Double(configValues[key] ?? "0") ?? 0
        if Self.byteToMBKeys.contains(key) {
            return raw / 1_048_576
        }
        return raw
    }

    /// Get the current string value
    func stringValue(for key: String) -> String {
        configValues[key] ?? ""
    }

    /// Update a setting value (auto-saves after debounce)
    func setValue(_ value: String, for key: String) {
        guard configValues[key] != value else { return }
        configValues[key] = value
        hasUnsavedChanges = configValues != originalValues
        scheduleSave()
    }

    func setBoolValue(_ value: Bool, for key: String) {
        setValue(value ? "true" : "false", for: key)
    }

    func setDoubleValue(_ value: Double, for key: String, format: String = "%.0f") {
        if Self.byteToMBKeys.contains(key) {
            // Convert MB back to bytes for storage
            setValue(String(format: "%.0f", value * 1_048_576), for: key)
        } else {
            setValue(String(format: format, value), for: key)
        }
    }

    /// Keys where the config stores bytes but the UI shows megabytes
    private static let byteToMBKeys: Set<String> = ["rewind_buffer_size"]

    /// Whether a specific setting differs from the on-disk original
    func isModified(_ key: String) -> Bool {
        configValues[key] != originalValues[key]
    }

    /// Save all changes to retroarch.cfg
    func saveChanges() async {
        guard let url = manager.activeConfigURL,
              hasUnsavedChanges else { return }

        do {
            // Read full config, update only our curated keys, write back
            var fullConfig = await manager.parseConfigFile(at: url)
            for (key, value) in configValues {
                fullConfig[key] = quoteValue(value)
            }

            let sortedKeys = fullConfig.keys.sorted()
            let content = sortedKeys.map { "\($0) = \(fullConfig[$0] ?? "")" }.joined(separator: "\n")
            try content.write(to: url, atomically: true, encoding: .utf8)

            originalValues = configValues
            hasUnsavedChanges = false
            ILOG("Saved curated RA settings to \(url.lastPathComponent)")
        } catch {
            ELOG("Failed to save RA config: \(error)")
            self.error = error
        }
    }

    // MARK: - Private

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            await saveChanges()
        }
    }

    private func stripQuotes(_ value: String) -> String {
        var v = value
        if v.hasPrefix("\"") && v.hasSuffix("\"") && v.count >= 2 {
            v.removeFirst()
            v.removeLast()
        }
        return v
    }

    private func quoteValue(_ value: String) -> String {
        "\"\(value)\""
    }
}
