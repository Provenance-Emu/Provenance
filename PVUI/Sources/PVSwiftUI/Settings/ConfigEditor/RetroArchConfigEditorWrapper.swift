import SwiftUI
import PVThemes
import PVLogging

struct RetroArchConfigEditorWrapper: View {
    @StateObject private var configEditor = RetroArchConfigEditorViewModel()
    @State private var searchText = ""
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showOnlyModified = false

    @StateObject private var filterVM: ConfigFilterViewModel
    @StateObject private var editVM: ConfigEditViewModel

    init() {
        // Create temporary view model for initialization
        let tempConfigEditor = RetroArchConfigEditorViewModel()
        _filterVM = StateObject(wrappedValue: ConfigFilterViewModel(configEditor: tempConfigEditor))
        _editVM = StateObject(wrappedValue: ConfigEditViewModel(configEditor: tempConfigEditor))
    }

    var body: some View {
        DLOG("Initializing RetroArchConfigEditorWrapper")
        return RetroArchConfigEditorView(
            showExportSheet: $showExportSheet,
            showImportPicker: $showImportPicker,
            filterVM: filterVM,
            editVM: editVM
        )
        .environmentObject(configEditor)
        .task {
            DLOG("Reinitializing view models with actual config editor")
            filterVM.configEditor = configEditor
            editVM.configEditor = configEditor
            await configEditor.loadConfig()
        }
    }
}
