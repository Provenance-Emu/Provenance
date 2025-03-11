import PVLogging

final class ConfigEditViewModel: ObservableObject {
    @Published var selectedKey: String = ""
    @Published var editedValue: String? = nil
    @Published var showValueEditor = false
    @Published var valueType: PVRetroArchCoreManager.ConfigValueType = .string
    @Published var alertTextValue: String? = nil

    var configEditor: any ConfigEditorProtocol

    @MainActor
    private var manager = PVRetroArchCoreManager.shared

    init(configEditor: any ConfigEditorProtocol) {
        self.configEditor = configEditor
    }

    @MainActor
    func prepareForEditing(key: String) {
        DLOG("Preparing to edit key: \(key)")
        selectedKey = key
        if let value = configEditor.configValues[key],
           let configEditor = configEditor as? RetroArchConfigEditorViewModel {
            editedValue = configEditor.stripQuotes(from: value)
            alertTextValue = editedValue
        }
        valueType = manager.detectValueType(editedValue ?? "")
        showValueEditor = true
        ILOG("Editing \(key) of type \(valueType)")
    }

    @MainActor
    func handleEditCompletion(newValue: String) {
        if let configEditor = configEditor as? RetroArchConfigEditorViewModel {
            let quotedValue = configEditor.addQuotes(to: newValue)
            setEditedValue(quotedValue)
        }
        showValueEditor = false
    }

    @MainActor
    func setEditedValue(_ newValue: String) {
        guard configEditor.configValues[selectedKey] != newValue else {
            DLOG("Value for \(selectedKey) unchanged")
            return
        }
        configEditor.configValues[selectedKey] = newValue
        (configEditor as? RetroArchConfigEditorViewModel)?.markAsChanged()
        ILOG("Updated value for \(selectedKey) to \(newValue)")
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
        guard let configEditor = configEditor as? RetroArchConfigEditorViewModel else { return false }
        return configEditor.originalConfig[key] == configEditor.configValues[key]
    }

    func isChanged(_ key: String) -> Bool {
        guard let configEditor = configEditor as? RetroArchConfigEditorViewModel else { return false }
        return configEditor.originalConfig[key] != configEditor.configValues[key]
    }

    // ... other editing-related methods ...
}
