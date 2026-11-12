//
//  TVBezelPickerView.swift
//  PVUI
//
//  Picks the TV around the picture on an external display, and brings in bezels.
//

#if os(iOS) || os(tvOS)
import SwiftUI
import UniformTypeIdentifiers
import PVLogging
import PVSettings
import PVSystems

/// The list of TVs: none, the built-in ones and the player's own, with import.
struct TVBezelPickerView: View {
    /// The chosen TV's id. `nil` is *Automatic*, offered only with `allowsAutomatic`.
    @Binding var selection: String?
    /// The list is choosing for one game, which can also be left to the settings.
    var allowsAutomatic = false
    /// The running game, to choose its artwork from The Bezel Project by hand.
    var game: ExternalDisplayGameContext?

    @State private var myBezels = TVBezelLibrary.shared.listed
    @State private var isImporting = false
    @State private var importReport: String?
    @State private var editing: TVBezel?

    /// A RetroArch overlay description, which has no type of its own.
    private static let importTypes: [UTType] = [.png, .folder] + [UTType(filenameExtension: TVBezelLibrary.configExtension)].compactMap { $0 }

    var body: some View {
        List {
            Section {
                if allowsAutomatic {
                    row(String(localized: "Automatic"), id: nil)
                }
                row(String(localized: "None"), id: ExternalDisplayBezelRules.noBezelID)
            } footer: {
                if allowsAutomatic {
                    Text("Automatic follows the External Display settings. Anything else is used for this game only.")
                }
            }

            Section(String(localized: "Built In")) {
                ForEach(TVBezelCatalog.bundled) { bezel in
                    row(bezel.name, id: bezel.id)
                }
            }

            if !TVBezelCatalog.shaderPresets.isEmpty {
                Section(String(localized: "Shader Bezels")) {
                    ForEach(TVBezelCatalog.shaderPresets) { bezel in
                        row(bezel.name, id: bezel.id)
                    }
                }
            }

            Section {
                ForEach(myBezels) { bezel in
                    HStack {
                        row(bezel.name, id: bezel.id, detail: systemName(of: bezel))
                        Button {
                            editing = bezel
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(String(localized: "Edit \(bezel.name)"))
                    }
                }
                .onDelete { offsets in
                    offsets.map { myBezels[$0].id }.forEach(TVBezelLibrary.shared.delete(id:))
                }
                #if os(iOS)
                Button {
                    isImporting = true
                } label: {
                    Label(String(localized: "Import a Bezel…"), systemImage: "square.and.arrow.down")
                }
                #endif
            } header: {
                Text("My Bezels")
            } footer: {
                Text("A bezel is a PNG image with a see-through area where the game shows, such as a RetroArch overlay. "
                     + "You can also put PNG files in the Bezels/Imported folder.")
            }

            if let game, BezelProjectService.systems[game.systemID] != nil {
                Section {
                    NavigationLink(String(localized: "Choose from The Bezel Project…")) {
                        BezelProjectSystemView(systemID: game.systemID, game: game)
                    }
                }
            }
        }
        .navigationTitle(allowsAutomatic ? String(localized: "TV for This Game") : String(localized: "TV"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onReceive(NotificationCenter.default.publisher(for: TVBezelLibrary.didChangeNotification)) { _ in
            myBezels = TVBezelLibrary.shared.listed
        }
        .task {
            // Picks up files put in the folder by hand since the app started.
            await Task.detached(priority: .userInitiated) { TVBezelLibrary.shared.refresh() }.value
        }
        #if os(iOS)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: Self.importTypes, allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            importFiles(urls)
        }
        .alert(String(localized: "Import"), isPresented: Binding(get: { importReport != nil }, set: { if !$0 { importReport = nil } })) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(importReport ?? "")
        }
        #endif
        .sheet(item: $editing) { bezel in
            TVBezelInfoView(bezel: bezel)
        }
    }

    private func row(_ name: String, id: String?, detail: String? = nil) -> some View {
        Button {
            selection = id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).foregroundStyle(.primary)
                    if let detail {
                        Text(detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selection == id {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selection == id ? .isSelected : [])
    }

    private func systemName(of bezel: TVBezel) -> String? {
        bezel.preferredSystems.first.flatMap(SystemIdentifier.init(rawValue:))?.fullName
    }

    private func importFiles(_ urls: [URL]) {
        Task {
            let result = await Task.detached(priority: .userInitiated) { TVBezelLibrary.shared.importFiles(at: urls) }.value
            // One import that worked needs no report; it is in the list, and chosen.
            if result.problems.isEmpty, let only = result.imported.first, result.imported.count == 1 {
                selection = only.id
                return
            }
            var lines: [String] = []
            if !result.imported.isEmpty {
                lines.append(String(localized: "Imported \(result.imported.count)."))
            }
            lines += result.problems.map { "\($0.file): \($0.problem.message)" }
            importReport = lines.isEmpty ? String(localized: "No PNG images were found.") : lines.joined(separator: "\n")
        }
    }
}

/// Names a bezel and says which system it belongs to.
private struct TVBezelInfoView: View {
    let bezel: TVBezel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var systemID: String
    @State private var preview: UIImage?

    private static let anySystem = ""
    private static let previewPixels: CGFloat = 800

    init(bezel: TVBezel) {
        self.bezel = bezel
        _name = State(initialValue: bezel.name)
        _systemID = State(initialValue: bezel.preferredSystems.first ?? Self.anySystem)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let preview {
                    Section {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .background(Color.black)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                Section(String(localized: "Name")) {
                    TextField(String(localized: "Name"), text: $name)
                }
                Section {
                    Picker(String(localized: "Belongs To"), selection: $systemID) {
                        Text("Any System").tag(Self.anySystem)
                        ForEach(SystemIdentifier.allCases.sorted { $0.fullName < $1.fullName }, id: \.rawValue) { system in
                            Text(system.fullName).tag(system.rawValue)
                        }
                    }
                } footer: {
                    Text("Games of that system use this bezel in place of your TV while Match the System's Screen is on.")
                }
            }
            .navigationTitle(String(localized: "Bezel"))
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        TVBezelLibrary.shared.update(id: bezel.id, name: name.trimmingCharacters(in: .whitespaces),
                                                     system: .some(systemID == Self.anySystem ? nil : systemID))
                        dismiss()
                    }
                }
            }
            .task {
                guard let url = bezel.image?.fileURL else { return }
                preview = await Task.detached(priority: .userInitiated) {
                    TVBezelImage.displayImage(url, maxPixel: Self.previewPixels).map { UIImage(cgImage: $0) }
                }.value
            }
        }
    }
}
#endif
