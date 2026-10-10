//
//  CreatePatchView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-10-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import PVLibrary
import PVLogging
import PVPatching
import PVFileSystem

/// Create a BPS or IPS/IPS32 patch from an original + modified ROM pair.
/// Never modifies either input. Optionally imports/links the result.
public struct CreatePatchView: View {
    @State private var originalURL: URL?
    @State private var modifiedURL: URL?
    @State private var format: PatchCreator.CreationFormat = .bps
    @State private var titleText = ""
    @State private var authorText = ""
    @State private var importAfterCreate = true
    @State private var linkGameMD5: String?
    @State private var statusMessage: String?
    @State private var isBusy = false
    @State private var pickingOriginal = false
    @State private var pickingModified = false
    @State private var games: [PVGame] = []

    public init() {}

    public var body: some View {
        Form {
            Section("Source ROMs") {
                Button(originalURL?.lastPathComponent ?? "Choose Original ROM…") {
                    pickingOriginal = true
                }
                Button(modifiedURL?.lastPathComponent ?? "Choose Modified ROM…") {
                    pickingModified = true
                }
            }

            Section("Format") {
                Picker("Patch Format", selection: $format) {
                    ForEach(PatchCreator.CreationFormat.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
#if !os(tvOS)
                .pickerStyle(.segmented)
#endif
            }

            Section("Metadata") {
                TextField("Title", text: $titleText)
                TextField("Author", text: $authorText)
            }

            Section("After Create") {
                Toggle("Import into library", isOn: $importAfterCreate)
                if importAfterCreate {
                    Picker("Link to game (optional)", selection: Binding(
                        get: { linkGameMD5 ?? "" },
                        set: { linkGameMD5 = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Auto-match").tag("")
                        ForEach(games, id: \.md5Hash) { game in
                            Text(game.title).tag(game.md5Hash)
                        }
                    }
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    create()
                } label: {
                    if isBusy {
                        ProgressView()
                    } else {
                        Text("Create Patch")
                    }
                }
                .disabled(isBusy || originalURL == nil || modifiedURL == nil)
            }
        }
        .navigationTitle("Create Patch")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $pickingOriginal, allowedContentTypes: [.data, .item]) { result in
            if case .success(let urls) = result { originalURL = urls.first }
        }
        .fileImporter(isPresented: $pickingModified, allowedContentTypes: [.data, .item]) { result in
            if case .success(let urls) = result { modifiedURL = urls.first }
        }
#endif
        .onAppear {
            let realm = RomDatabase.sharedInstance.realm
            games = realm.objects(PVGame.self)
                .filter("isPatchVariant == false AND contentless == false")
                .sorted(byKeyPath: "title", ascending: true)
                .prefix(500)
                .map { $0.isFrozen ? $0 : $0.freeze() }
        }
    }

    private func create() {
        guard let originalURL, let modifiedURL else { return }
        isBusy = true
        statusMessage = "Creating…"
        Task {
            let accessedO = originalURL.startAccessingSecurityScopedResource()
            let accessedM = modifiedURL.startAccessingSecurityScopedResource()
            defer {
                if accessedO { originalURL.stopAccessingSecurityScopedResource() }
                if accessedM { modifiedURL.stopAccessingSecurityScopedResource() }
            }

            do {
                let patchesDir = Paths.patchesPath
                try FileManager.default.createDirectory(at: patchesDir, withIntermediateDirectories: true)
                let stem = titleText.isEmpty
                    ? modifiedURL.deletingPathExtension().lastPathComponent
                    : titleText
                let output = patchesDir.appendingPathComponent("\(stem).\(format.fileExtension)")
                let metadata = PatchMetadata(
                    title: titleText.isEmpty ? nil : titleText,
                    author: authorText.isEmpty ? nil : authorText
                )
                let created = try PatchCreator().create(
                    originalURL: originalURL,
                    modifiedURL: modifiedURL,
                    outputURL: output,
                    format: format,
                    metadata: metadata,
                    verifyRoundTrip: true
                )

                if importAfterCreate {
                    let preferred: PVGame? = {
                        guard let linkGameMD5 else { return nil }
                        return RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: linkGameMD5)
                    }()
                    _ = try await PatchRepository.shared.importPatch(
                        at: created,
                        preferredGame: preferred,
                        autoMatch: preferred == nil
                    )
                    statusMessage = "Created and imported \(created.lastPathComponent)"
                } else {
                    statusMessage = "Created \(created.path)"
                }
            } catch {
                statusMessage = error.localizedDescription
            }
            isBusy = false
        }
    }
}
