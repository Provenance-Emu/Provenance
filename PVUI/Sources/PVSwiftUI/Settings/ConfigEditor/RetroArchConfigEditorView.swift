import Combine
import SwiftUI
#if !os(tvOS)
import struct PVUIBase.ActivityViewController
#endif

struct RetroArchConfigEditorView: View {
    @Binding var showExportSheet: Bool
    @Binding var showImportPicker: Bool
    @ObservedObject var filterVM: ConfigFilterViewModel
    @ObservedObject var editVM: ConfigEditViewModel
    @EnvironmentObject private var configEditor: RetroArchConfigEditorViewModel

    /// Single source of truth for sheet presentation
    @State private var presentationState: PresentationState?
    @State private var showFileImporter = false

    /// Enum to manage all possible presentation states
    private enum PresentationState: Identifiable, Equatable {
        case export(URL)
        case error(Error)

        var id: String {
            switch self {
            case .export: return "export"
            case .error: return "error"
            }
        }

        static func == (lhs: PresentationState, rhs: PresentationState) -> Bool {
            switch (lhs, rhs) {
            case (.export(let lhsURL), .export(let rhsURL)):
                return lhsURL == rhsURL
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }

    var body: some View {
        ConfigListContent(
            filterVM: filterVM,
            editVM: editVM
        )
        .navigationTitle("RetroArch Config")
        .uiKitAlert(
            editVM.getEditorTitle(),
            message: editVM.getEditorMessage(),
            isPresented: $editVM.showValueEditor,
            textValue: $editVM.alertTextValue,
            preferredContentSize: CGSize(width: 300, height: 200),
            textField: editVM.valueType == .bool ? nil : { textField in
                textField.keyboardType = editVM.valueType == .int ? .numberPad : .default
            }
        ) {
            switch editVM.valueType {
            case .bool:
                [
                    UIAlertAction(title: "True", style: .default) { _ in
                        editVM.handleEditCompletion(newValue: "true")
                    },
                    UIAlertAction(title: "False", style: .default) { _ in
                        editVM.handleEditCompletion(newValue: "false")
                    },
                    UIAlertAction(title: "Cancel", style: .cancel)
                ]
            case .int, .float, .string:
                [
                    UIAlertAction(title: "Save", style: .default) { _ in
                        if let value = editVM.alertTextValue {
                            editVM.handleEditCompletion(newValue: value)
                        }
                    },
                    UIAlertAction(title: "Cancel", style: .cancel)
                ]
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    filterVM.showOnlyModified.toggle()
                }) {
                    Label(
                        "Show Modified",
                        systemImage: filterVM.showOnlyModified ?
                        "line.horizontal.3.decrease.circle.fill" :
                            "line.horizontal.3.decrease.circle"
                    )
                }
                .disabled(filterVM.modifiedKeys.isEmpty)

                if #available(tvOS 17.0, *) {
                    Menu {
#if !os(tvOS)
                        Button(action: {
                            Task {
                                await handleExport()
                            }
                        }) {
                            Label("Export Config", systemImage: "square.and.arrow.up")
                        }

                        Button(action: {
                            handleImport()
                        }) {
                            Label("Import Config", systemImage: "square.and.arrow.down")
                        }

                        Divider()
#endif

                        Button(action: {
                            Task {
                                await configEditor.reloadConfig()
                            }
                        }) {
                            Label("Reload Current Config", systemImage: "arrow.clockwise")
                        }
                        .disabled(!configEditor.hasChanges)

                        Button(action: {
                            Task {
                                await configEditor.reloadDefaultConfig()
                            }
                        }) {
                            Label("Reload Default Config", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                } else {
                    HStack {
                        Button(action: {
                            Task {
                                await configEditor.reloadConfig()
                            }
                        }) {
                            Label("Reload Current Config", systemImage: "arrow.clockwise")
                        }
                        .disabled(!configEditor.hasChanges)

                        Button(action: {
                            Task {
                                await configEditor.reloadDefaultConfig()
                            }
                        }) {
                            Label("Reload Default Config", systemImage: "arrow.counterclockwise")
                        }
                    }
                }

                Button(action: {
                    Task {
                        await configEditor.saveChanges()
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!configEditor.hasChanges)
            }
        }
#if !os(tvOS)
        // Sheet presentation for export and error states
        .sheet(item: $presentationState) { state in
            Group {
                switch state {
                case .export(let url):
                    ActivityViewController(
                        activityItems: [url],
                        applicationActivities: nil,
                        excludedActivityTypes: [
                            .assignToContact,
                            .addToReadingList,
                            .openInIBooks,
                            .postToWeibo,
                            .postToVimeo,
                            .postToFlickr,
                            .postToTwitter,
                            .postToFacebook,
                            .postToTencentWeibo
                        ]
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(true)
                    .onDisappear {
                        configEditor.finishExport()
                        presentationState = nil
                    }
                case .error(let error):
                    Text(error.localizedDescription)
                        .padding()
                }
            }
        }
        // Separate file importer
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await configEditor.importConfig(from: url)
                    }
                }
            case .failure(let error):
                presentationState = .error(error)
            }
            configEditor.finishImport()
        }
#endif
    }

    private func handleExport() async {
        configEditor.prepareExport()
        if let exportURL = configEditor.exportURL {
            presentationState = .export(exportURL)
        }
    }

    private func handleImport() {
        configEditor.startImport()
        showFileImporter = true
    }
}
