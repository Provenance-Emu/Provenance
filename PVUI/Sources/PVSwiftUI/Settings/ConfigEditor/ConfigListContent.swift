import SwiftUI
import PVUIBase
import struct PVUIBase.PVSearchBar

struct ConfigListContent: View {
    @ObservedObject var filterVM: ConfigFilterViewModel
    @ObservedObject var editVM: ConfigEditViewModel

    @EnvironmentObject private var configEditor: RetroArchConfigEditorViewModel

    var body: some View {
        let groupedKeys = Dictionary(grouping: filteredKeys) { key in
            key.components(separatedBy: "_").first ?? "Other"
        }

        return List {
            PVSearchBar(text: $filterVM.searchText)

            ForEach(groupedKeys.keys.sorted(), id: \.self) { section in
                CollapsibleSection(title: section) {
                    ForEach(groupedKeys[section] ?? [], id: \.self) { key in
                        ConfigRowView(
                            key: key,
                            value: configEditor.configValues[key] ?? "",
                            description: configEditor.configDescriptions[key] ?? "",
                            isChanged: editVM.isChanged(key),
                            isDefault: editVM.isDefaultValue(key)
                        )
                        .onTapGesture {
                            editVM.prepareForEditing(key: key)
                        }
                    }
                }
            }
        }
    }

    private var filteredKeys: [String] {
        let keys = filterVM.showOnlyModified ? filterVM.modifiedKeys : configEditor.configKeys
        if filterVM.searchText.isEmpty {
            return keys
        } else {
            return keys.filter { $0.localizedCaseInsensitiveContains(filterVM.searchText) }
        }
    }
}

struct ConfigRowView: View {
    let key: String
    let value: String
    let description: String
    let isChanged: Bool
    let isDefault: Bool

    @EnvironmentObject private var configEditor: RetroArchConfigEditorViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.headline)
                Text(configEditor.stripQuotes(from: value))
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
