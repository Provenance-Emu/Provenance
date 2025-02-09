import Combine
import PVLogging
import PVThemes

class RetroArchConfigEditorViewModel: ObservableObject {
    @Published var configKeys: [String] = []
    @Published var configValues: [String: String] = [:]
    @Published var configDescriptions: [String: String] = [:]
    @Published var showEditAlert = false {
        didSet {
            if !showEditAlert {
                selectedKey = ""
                editedValue = nil
            }
        }
    }
    @Published var editMessage = ""
    @Published var hasChanges = false
    @Published var showSaveConfirmation = false
    @Published var showReloadConfirmation = false
    private var originalConfig: [String: String] = [:]
    @Published var editedValue: String? = nil
    @Published var showValueEditor = false
    @Published var valueType: PVRetroArchCoreManager.ConfigValueType = .string
    @Published var showOnlyModified = false

    var selectedKey: String = "" {
        didSet {
            showEditAlert = true
            editMessage = "Edit value for \(selectedKey)"
        }
    }

    var modifiedKeys: [String] {
        configKeys.filter { isChanged($0) }
    }

    private var manager = PVRetroArchCoreManager.shared

    @MainActor
    func loadConfig() async {
        do {
            // Load active config
            if let activeURL = await manager.activeConfigURL,
               let contents = try? String(contentsOf: activeURL) {
                let config = await manager.parseConfigFile(at: activeURL)
                configKeys = Array(config.keys).sorted()
                configValues = config
            }

            // Load descriptions
            let defaultConfig = try await manager.downloadDefaultConfig()
            configDescriptions = await manager.parseConfigDescriptions(defaultConfig)
        } catch {
            ELOG("Error loading config: \(error)")
        }
    }

    func cancelEdit() {
        selectedKey = ""
    }

    func saveEditedValue() {
        guard !selectedKey.isEmpty else { return }

        Task {
            do {
                // Update the config values
                if let newValue = editedValue {
                    configValues[selectedKey] = newValue
                    hasChanges = true

                    // Save the changes to file
                    guard let activeURL = await manager.activeConfigURL else { return }

                    // Create the new config content
                    let newContent = configKeys.map { "\($0) = \(configValues[$0] ?? "")" }.joined(separator: "\n")

                    // Write to file
                    try newContent.write(to: activeURL, atomically: true, encoding: .utf8)

                    // Update the original config to reflect the changes
                    originalConfig[selectedKey] = newValue
                }
            } catch {
                ELOG("Error saving edited value: \(error)")
            }
        }
    }

    func setEditedValue(_ newValue: String) {
        guard configValues[selectedKey] != newValue else { return }
        configValues[selectedKey] = newValue
        hasChanges = true
    }

    func saveChanges() async {
        guard let activeURL = await manager.activeConfigURL else { return }

        do {
            // Create the new config file content
            let newContent = configKeys.map { "\($0) = \(configValues[$0] ?? "")" }.joined(separator: "\n")
            try newContent.write(to: activeURL, atomically: true, encoding: .utf8)

            // Update state
            hasChanges = false
            originalConfig = configValues
        } catch {
            print("Error saving config: \(error)")
        }
    }

    func reloadConfig() async {
        do {
            if let activeURL = await manager.activeConfigURL,
               let contents = try? String(contentsOf: activeURL) {
                let config = await manager.parseConfigFile(at: activeURL)
                configKeys = Array(config.keys).sorted()
                configValues = config
                originalConfig = config
                hasChanges = false
            }
        } catch {
            print("Error reloading config: \(error)")
        }
    }

    @MainActor
    func prepareForEditing(key: String) {
        selectedKey = key
        editedValue = configValues[key]
        valueType = manager.detectValueType(editedValue ?? "")
        showValueEditor = true
    }

    func getEditorTitle() -> String {
        switch valueType {
        case .bool: return "Toggle Value"
        case .int: return "Enter Integer"
        case .float: return "Enter Number"
        case .string: return "Enter Text"
        }
    }

    func getEditorMessage() -> String {
        switch valueType {
        case .bool: return "Select new value for \(selectedKey)"
        case .int: return "Enter new integer value for \(selectedKey)"
        case .float: return "Enter new number value for \(selectedKey)"
        case .string: return "Enter new text value for \(selectedKey)"
        }
    }

    func isDefaultValue(_ key: String) -> Bool {
        return originalConfig[key] == configValues[key]
    }

    func isChanged(_ key: String) -> Bool {
        return originalConfig[key] != configValues[key]
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

    func importConfig(from url: URL) async {
        #if !os(tvOS)
        do {
            try await manager.copyConfigFile(from: url, to: manager.activeConfigURL!)
            await reloadConfig()
        } catch {
            print("Error importing config: \(error)")
        }
        #endif
    }
}
