import SwiftUI
import PVThemes

struct RetroArchConfigEditorView: View {
    @StateObject private var viewModel = RetroArchConfigEditorViewModel()
    @State private var searchText = ""
    @State private var showExportSheet = false
    @State private var showImportPicker = false

    var body: some View {
        Group {
            ConfigListContent(viewModel: viewModel, searchText: $searchText)
            .navigationTitle("RetroArch Config")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showOnlyModified.toggle()
                    }) {
                        Label(
                            "Show Modified",
                            systemImage: viewModel.showOnlyModified ?
                                "line.horizontal.3.decrease.circle.fill" :
                                "line.horizontal.3.decrease.circle"
                        )
                    }
                    .disabled(viewModel.modifiedKeys.isEmpty)

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
                            viewModel.showReloadConfirmation = true
                        }) {
                            Label("Reload Config", systemImage: "arrow.clockwise")
                        }
                        .disabled(!viewModel.hasChanges)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button(action: {
                        viewModel.showSaveConfirmation = true
                    }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!viewModel.hasChanges)
                }
            }
        }
        #if !os(tvOS)
        .sheet(isPresented: $showExportSheet, onDismiss: {
            showExportSheet = false
        }) {
            if let configURL = viewModel.exportConfig() {
                ActivityViewController(activityItems: [configURL])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false,
            onCompletion: { result in
                showImportPicker = false
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await viewModel.importConfig(from: url)
                        }
                    }
                case .failure(let error):
                    print("Import error: \(error)")
                }
            }
        )
        #endif
        .task {
            await viewModel.loadConfig()
        }
        .uiKitAlert(
            "Edit Config Value",
            message: viewModel.editMessage,
            isPresented: $viewModel.showEditAlert,
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "Cancel", style: .cancel) { _ in
                viewModel.cancelEdit()
            }
            UIAlertAction(title: "Save", style: .default) { _ in
                if let newValue = viewModel.editedValue {
                    viewModel.setEditedValue(newValue)
                }
            }
        }
        .uiKitAlert(
            "Save Changes",
            message: "Are you sure you want to save your changes?",
            isPresented: $viewModel.showSaveConfirmation,
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "Cancel", style: .cancel) { _ in
                viewModel.showSaveConfirmation = false
            }
            UIAlertAction(title: "Save", style: .default) { _ in
                Task {
                    await viewModel.saveChanges()
                }
            }
        }
        .uiKitAlert(
            "Reload Config",
            message: "Are you sure you want to reload the config? Any unsaved changes will be lost.",
            isPresented: $viewModel.showReloadConfirmation,
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "Cancel", style: .cancel) { _ in
                viewModel.showReloadConfirmation = false
            }
            UIAlertAction(title: "Reload", style: .destructive) { _ in
                Task {
                    await viewModel.reloadConfig()
                }
            }
        }
        .uiKitAlert(
            viewModel.getEditorTitle(),
            message: viewModel.getEditorMessage(),
            isPresented: $viewModel.showValueEditor,
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            switch viewModel.valueType {
            case .bool:
                [
                    UIAlertAction(title: "True", style: .default) { _ in
                        viewModel.setEditedValue("true")
                        viewModel.showValueEditor = false
                    },
                    UIAlertAction(title: "False", style: .default) { _ in
                        viewModel.setEditedValue("false")
                        viewModel.showValueEditor = false
                    }
                ]
            case .int, .float:
                [
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        viewModel.showValueEditor = false
                    },
                    UIAlertAction(title: "Save", style: .default) { _ in
                        if let newValue = viewModel.editedValue {
                            viewModel.setEditedValue(newValue)
                        }
                        viewModel.showValueEditor = false
                    }
                ]
            case .string:
                [
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        viewModel.showValueEditor = false
                    },
                    UIAlertAction(title: "Save", style: .default) { _ in
                        if let newValue = viewModel.editedValue {
                            viewModel.setEditedValue(newValue)
                        }
                        viewModel.showValueEditor = false
                    }
                ]
            }
        }
    }
}

struct ConfigListContent: View {
    @ObservedObject var viewModel: RetroArchConfigEditorViewModel
    @Binding var searchText: String

    var body: some View {
        let groupedKeys = Dictionary(grouping: filteredKeys) { key in
            key.components(separatedBy: "_").first ?? "Other"
        }

        return List {
            PVSearchBar(text: $searchText)

            ForEach(groupedKeys.keys.sorted(), id: \.self) { section in
                CollapsibleSection(title: section) {
                    ForEach(groupedKeys[section] ?? [], id: \.self) { key in
                        let configValue = viewModel.configValues[key] ?? ""
                        let description = viewModel.configDescriptions[key] ?? ""
                        let isChanged = viewModel.isChanged(key)
                        let isDefault = viewModel.isDefaultValue(key)

                        ConfigRowView(
                            key: key,
                            value: configValue,
                            description: description,
                            isChanged: isChanged,
                            isDefault: isDefault
                        )
                        .onTapGesture {
                            viewModel.prepareForEditing(key: key)
                        }
                    }
                }
            }
        }
    }

    private var filteredKeys: [String] {
        let keys = viewModel.showOnlyModified ? viewModel.modifiedKeys : viewModel.configKeys
        if searchText.isEmpty {
            return keys
        } else {
            return keys.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct ConfigRowView: View {
    let key: String
    let value: String
    let description: String
    let isChanged: Bool
    let isDefault: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.headline)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isChanged {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.accentColor)
            } else if isDefault {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .background(isChanged ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
