//
//  PendingPatchesView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-10-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVRealm
import PVLogging
import PVPatching
import PVFileSystem
import UniformTypeIdentifiers

/// Global ROM Tools screen for unmatched / pending patches and patch creation entry.
public struct PendingPatchesView: View {
    @State private var pending: [PVPatch] = []
    @State private var patchPendingDeletion: PVPatch?
    @State private var allPatches: [PVPatch] = []
    @State private var games: [PVGame] = []
    @State private var selectedPatch: PVPatch?
    @State private var statusMessage: String?
    @State private var showGamePicker = false
    @State private var showImporter = false
    @State private var isBusy = false

    public init() {}

    public var body: some View {
        SwiftUI.List {
            if let statusMessage {
                SwiftUI.Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.Section("ROM Tools") {
                NavigationLink {
                    PatchApplierView()
                } label: {
                    Label("Patch Applier", systemImage: "bandage")
                }
                NavigationLink {
                    BatchPatchApplierView()
                } label: {
                    Label("Batch Apply Folder…", systemImage: "folder.badge.gearshape")
                }
                NavigationLink {
                    OnlinePatchDatabaseView()
                } label: {
                    Label("Browse Online Patches…", systemImage: "globe")
                }
                NavigationLink {
                    CreatePatchView()
                } label: {
                    Label("Create Patch (BPS / IPS)…", systemImage: "doc.badge.plus")
                }
            }

            SwiftUI.Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Import Patch File…", systemImage: "square.and.arrow.down")
                }
                Button {
                    rematchAll()
                } label: {
                    Label("Retry Auto-Match", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isBusy || pending.isEmpty)
            }

            SwiftUI.Section("Pending / Unmatched") {
                if pending.isEmpty {
                    Text("No pending patches.")
                        .foregroundStyle(.secondary)
                } else {
                    SwiftUI.ForEach(pending, id: \.id) { patch in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(patch.displayTitle)
                                .font(.headline)
                            Text(subtitle(for: patch))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Link to Game…") {
                                    selectedPatch = patch
                                    showGamePicker = true
                                }
                                .buttonStyle(.bordered)
                                Button("Delete", role: .destructive) {
                                    patchPendingDeletion = patch
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            SwiftUI.Section("All Patches") {
                if allPatches.isEmpty {
                    Text("No patches imported yet.")
                        .foregroundStyle(.secondary)
                } else {
                    SwiftUI.ForEach(allPatches, id: \.id) { patch in
                        NavigationLink {
                            if let md5 = patch.baseGameMD5 ?? patch.game?.md5Hash {
                                PatchManagerView(
                                    gameMD5: md5,
                                    gameTitle: patch.game?.title ?? patch.displayTitle
                                )
                            } else {
                                Text("This patch is not linked to a game.")
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(patch.displayTitle)
                                Text(subtitle(for: patch))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Patches / ROM Tools")
        .confirmationDialog(
            "Delete this patch?",
            isPresented: Binding(
                get: { patchPendingDeletion != nil },
                set: { if !$0 { patchPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Patch", role: .destructive) {
                if let patch = patchPendingDeletion { delete(patch) }
                patchPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { patchPendingDeletion = nil }
        } message: {
            Text("The patch file and any save states for its patched copy are removed. The original ROM is not touched.")
        }
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: Self.patchTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
#endif
        .sheet(isPresented: $showGamePicker) {
            PatchGamePickerView(games: games) { game in
                guard let selectedPatch else { return }
                link(selectedPatch, to: game)
            }
        }
        .onAppear(perform: reload)
    }

    private static var patchTypes: [UTType] {
        var types: [UTType] = [.data, .item]
        for ext in ["ips", "bps", "ups", "ppf", "ips32"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }

    private func subtitle(for patch: PVPatch) -> String {
        var parts: [String] = []
        if let format = patch.format { parts.append(format.displayName) }
        parts.append(patch.matchState.rawValue.capitalized)
        if let gameTitle = patch.game?.title {
            parts.append(gameTitle)
        } else if let md5 = patch.baseGameMD5 {
            parts.append("MD5 \(md5.prefix(8))…")
        }
        return parts.joined(separator: " · ")
    }

    private func reload() {
        let realm = RomDatabase.sharedInstance.realm
        pending = PatchRepository.shared.pendingPatches().map { $0.isFrozen ? $0 : $0.freeze() }
        allPatches = realm.objects(PVPatch.self)
            .sorted(byKeyPath: "date", ascending: false)
            .map { $0.isFrozen ? $0 : $0.freeze() }
        games = realm.objects(PVGame.self)
            .filter("isPatchVariant == false AND contentless == false")
            .sorted(byKeyPath: "title", ascending: true)
            .map { $0.isFrozen ? $0 : $0.freeze() }
    }

    private func rematchAll() {
        isBusy = true
        statusMessage = "Matching…"
        Task {
            await PatchRepository.shared.rematchPendingPatches()
            statusMessage = "Auto-match finished."
            reload()
            isBusy = false
        }
    }

    private func link(_ patch: PVPatch, to game: PVGame) {
        isBusy = true
        Task {
            do {
                try await PatchRepository.shared.link(patch, to: game)
                statusMessage = "Linked \(patch.displayTitle) → \(game.title)"
                reload()
            } catch {
                statusMessage = error.localizedDescription
            }
            isBusy = false
            showGamePicker = false
            selectedPatch = nil
        }
    }

    private func delete(_ patch: PVPatch) {
        do {
            try PatchRepository.shared.deletePatch(patch)
            statusMessage = "Deleted \(patch.displayTitle)"
            reload()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            statusMessage = error.localizedDescription
        case .success(let urls):
            isBusy = true
            Task { @MainActor in
                var imported = 0
                var failures: [String] = []
                for url in urls {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    do {
                        _ = try await PatchRepository.shared.importPatchFile(at: url)
                        imported += 1
                    } catch {
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                if failures.isEmpty {
                    statusMessage = "Imported \(imported) patch\(imported == 1 ? "" : "es")."
                } else {
                    statusMessage = "Imported \(imported), failed \(failures.count): " + failures.joined(separator: "; ")
                }
                reload()
                isBusy = false
            }
        }
    }
}

private struct PatchGamePickerView: View {
    let games: [PVGame]
    let onSelect: (PVGame) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            SwiftUI.List(filtered, id: \.md5Hash) { game in
                Button {
                    onSelect(game)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(game.title)
                        Text(game.systemIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose Base Game")
#if !os(tvOS)
            .searchable(text: $query)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
#endif
        }
    }

    private var filtered: [PVGame] {
        guard !query.isEmpty else { return games }
        return games.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
