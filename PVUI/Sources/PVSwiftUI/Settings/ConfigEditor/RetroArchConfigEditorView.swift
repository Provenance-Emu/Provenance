import Combine
import SwiftUI

struct RetroArchConfigEditorView: View {
    @Binding var showExportSheet: Bool
    @Binding var showImportPicker: Bool
    @ObservedObject var filterVM: ConfigFilterViewModel
    @ObservedObject var editVM: ConfigEditViewModel
    
    @EnvironmentObject private var configEditor: RetroArchConfigEditorViewModel
    
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
                            showExportSheet = true
                        }) {
                            Label("Export Config", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            showImportPicker = true
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
        .sheet(isPresented: $showExportSheet, onDismiss: {
            showExportSheet = false
        }) {
            if let configURL = configEditor.exportConfig() {
                ActivityViewController(activityItems: [configURL])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            showImportPicker = false
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await configEditor.importConfig(from: url)
                    }
                }
            case .failure(let error):
                print("Import error: \(error)")
            }
        }
#endif
    }
}
