import PVLogging

class ConfigFilterViewModel: ObservableObject {
    @Published var showOnlyModified = false
    @Published var searchText = ""

    var configEditor: any ConfigEditorProtocol

    init(configEditor: any ConfigEditorProtocol) {
        self.configEditor = configEditor
    }

    var modifiedKeys: [String] {
        configEditor.configKeys.filter { key in
            (configEditor as? RetroArchConfigEditorViewModel)?.originalConfig[key] != configEditor.configValues[key]
        }
    }
}
