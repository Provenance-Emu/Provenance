import PVLogging

class RetroArchConfigEditorViewModel: ConfigEditorProtocol {
    @Published private(set) var configKeys: [String] = []
    @Published var configValues: [String: String] = [:]
    @Published private(set) var configDescriptions: [String: String] = [:]
    @Published private(set) var hasChanges = false
    @Published private(set) var isExporting = false
    @Published private(set) var isImporting = false
    @Published private(set) var exportURL: URL?
    @Published var error: Error?

    public private(set) var originalConfig: [String: String] = [:]
    private var manager = PVRetroArchCoreManager.shared
    private var temporaryExportURL: URL?

    deinit {
        cleanupTemporaryFiles()
    }

    private func cleanupTemporaryFiles() {
        if let tempURL = temporaryExportURL {
            try? FileManager.default.removeItem(at: tempURL)
            temporaryExportURL = nil
        }
    }

    @MainActor
    func markAsChanged() {
        hasChanges = true
    }

    @MainActor
    func markAsUnchanged() {
        hasChanges = false
    }

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
            self.error = error
        }
    }

    @MainActor
    func prepareExport() {
        guard let sourceURL = manager.activeConfigURL else { return }

        do {
            cleanupTemporaryFiles()

            // Create a temporary directory
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("com.provenance.retroarch", isDirectory: true)

            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let tempURL = tempDir.appendingPathComponent("retroarch.cfg")

            // Copy the file to temp directory
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)

            temporaryExportURL = tempURL
            exportURL = tempURL
            isExporting = true

            ILOG("Prepared config file for export at: \(tempURL.path)")
        } catch {
            ELOG("Failed to prepare config for export: \(error)")
            self.error = error
        }
    }

    @MainActor
    func finishExport() {
        exportURL = nil
        isExporting = false
        cleanupTemporaryFiles()
    }

    @MainActor
    func startImport() {
        isImporting = true
    }

    @MainActor
    func finishImport() {
        isImporting = false
    }

    @MainActor
    func importConfig(from url: URL) async {
        do {
            guard let activeURL = manager.activeConfigURL else {
                throw NSError(domain: "com.provenance", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active config URL"])
            }

            // Create a ConfigPackage from the imported file
            let data = try Data(contentsOf: url)
            let package = ConfigPackage(data: data, name: "Imported Config")

            // Write the data to the active config location
            try package.data.write(to: activeURL)

            // Reload the config to update the UI
            await reloadConfig()

            ILOG("Successfully imported config from: \(url.path)")
        } catch {
            ELOG("Error importing config: \(error)")
            self.error = error
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
                markAsUnchanged()
                originalConfig = configValues
            }
            ILOG("Config changes saved successfully")
        } catch {
            ELOG("Error saving config: \(error)")
            self.error = error
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
                    markAsUnchanged()
                }
                ILOG("Config reloaded successfully")
            }
        } catch {
            ELOG("Error reloading config: \(error)")
            self.error = error
        }
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
                    markAsUnchanged()
                }
                ILOG("Default config reloaded successfully")
            } else {
                throw NSError(domain: "com.provenance", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid default config URL"])
            }
        } catch {
            ELOG("Error reloading default config: \(error)")
            self.error = error
        }
    }
}

// Value type detection extension
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
