import PVLogging

class RetroArchConfigEditorViewModel: ConfigEditorProtocol {
    @Published var configKeys: [String] = []
    @Published var configValues: [String: String] = [:]
    @Published var configDescriptions: [String: String] = [:]
    @Published var hasChanges = false

    public private(set) var originalConfig: [String: String] = [:]
    private var manager = PVRetroArchCoreManager.shared

    @MainActor
    func loadConfig() async {
        DLOG("Loading RetroArch config")
        do {
            if let activeURL = await manager.activeConfigURL,
               let contents = try? String(contentsOf: activeURL) {
                ILOG("Found config file at: \(activeURL)")
                let config = await manager.parseConfigFile(at: activeURL)
                await MainActor.run {
                    configKeys = Array(config.keys).sorted()
                    configValues = config
                    originalConfig = config
                }
                DLOG("Loaded \(configKeys.count) config keys")
            }

            let defaultConfig = try await manager.downloadDefaultConfig()
            let descriptions = await manager.parseConfigDescriptions(defaultConfig)
            await MainActor.run {
                configDescriptions = descriptions
            }
            ILOG("Loaded config descriptions")
        } catch {
            ELOG("Error loading config: \(error)")
        }
    }

    @MainActor
    func saveChanges() async {
        DLOG("Saving config changes")
        guard let activeURL = await manager.activeConfigURL else {
            WLOG("No active config URL found")
            return
        }

        do {
            let newContent = configKeys.map { "\($0) = \(configValues[$0] ?? "")" }.joined(separator: "\n")
            try newContent.write(to: activeURL, atomically: true, encoding: .utf8)
            await MainActor.run {
                hasChanges = false
                originalConfig = configValues
            }
            ILOG("Config changes saved successfully")
        } catch {
            ELOG("Error saving config: \(error)")
        }
    }

    @MainActor
    func reloadConfig() async {
        DLOG("Reloading config")
        do {
            if let activeURL = await manager.activeConfigURL,
               let contents = try? String(contentsOf: activeURL) {
                let config = await manager.parseConfigFile(at: activeURL)
                await MainActor.run {
                    configKeys = Array(config.keys).sorted()
                    configValues = config
                    originalConfig = config
                    hasChanges = false
                }
                ILOG("Config reloaded successfully")
            }
        } catch {
            ELOG("Error reloading config: \(error)")
        }
    }

    @MainActor
    func exportConfig() -> URL? {
        #if !os(tvOS)
        guard let activeURL = manager.activeConfigURL else { return nil }
        return activeURL
        #else
        return nil
        #endif
    }

    @MainActor
    func importConfig(from url: URL) async {
        #if !os(tvOS)
        do {
            try await manager.copyConfigFile(from: url, to: manager.activeConfigURL!)
            await reloadConfig()
        } catch {
            ELOG("Error importing config: \(error)")
        }
        #endif
    }

    @MainActor
    func reloadDefaultConfig() async {
        DLOG("Reloading default RetroArch config")
        do {
            let defaultConfig = try await manager.downloadDefaultConfig()
            if let defaultConfigURL = URL(string: defaultConfig) {
                let config = await manager.parseConfigFile(at: defaultConfigURL)
                await MainActor.run {
                    configKeys = Array(config.keys).sorted()
                    configValues = config
                    originalConfig = config
                    hasChanges = false
                }
                ILOG("Default config reloaded successfully")
            } else {
                ELOG("Failed to create URL from default config path")
            }
        } catch {
            ELOG("Error reloading default config: \(error)")
        }
    }
}

extension RetroArchConfigEditorViewModel {
    func detectValueType(_ value: String) -> PVRetroArchCoreManager.ConfigValueType {
        if value.lowercased() == "true" || value.lowercased() == "false" {
            return .bool
        } else if Int(value) != nil {
            return .int
        } else if Float(value) != nil {
            return .float
        }
        return .string
    }

    func getEditorTitle(for key: String) -> String {
        let value = configValues[key] ?? ""
        let type = detectValueType(value)
        switch type {
        case .bool: return "Toggle Value"
        case .int: return "Enter Integer"
        case .float: return "Enter Number"
        case .string: return "Enter Text"
        }
    }

    func getEditorMessage(for key: String) -> String {
        let value = configValues[key] ?? ""
        let type = detectValueType(value)
        switch type {
        case .bool: return "Select new value for \(key)"
        case .int: return "Enter new integer value for \(key)"
        case .float: return "Enter new number value for \(key)"
        case .string: return "Enter new text value for \(key)"
        }
    }

    func isDefaultValue(_ key: String) -> Bool {
        return originalConfig[key] == configValues[key]
    }

    func isChanged(_ key: String) -> Bool {
        return originalConfig[key] != configValues[key]
    }

    func stripQuotes(from value: String) -> String {
        var stripped = value
        if stripped.first == "\"" && stripped.last == "\"" {
            stripped.removeFirst()
            stripped.removeLast()
        }
        return stripped
    }

    func addQuotes(to value: String) -> String {
        if value.contains(" ") || value.contains("\"") {
            return "\"\(value)\""
        }
        return value
    }
}
