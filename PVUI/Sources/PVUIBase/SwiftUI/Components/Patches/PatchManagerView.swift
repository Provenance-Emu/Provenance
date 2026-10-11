//
//  PatchManagerView.swift
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

/// Per-game patch manager: list, play, default, tile visibility, export, reapply, delete.
public struct PatchManagerView: View {
    let gameMD5: String
    let gameTitle: String

    @State private var patches: [PVPatch] = []
    @State private var statusMessage: String?
    @State private var isBusy = false
    @State private var exportURL: URL?
    @State private var showExporter = false
    @Environment(\.dismiss) private var dismiss

    public init(gameMD5: String, gameTitle: String) {
        self.gameMD5 = gameMD5
        self.gameTitle = gameTitle
    }

    public var body: some View {
        SwiftUI.List {
            if let statusMessage {
                SwiftUI.Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            if patches.isEmpty {
                SwiftUI.Section {
                    Text("No patches linked to this game yet. Import a patch from the game menu or ROM Tools.")
                        .foregroundStyle(.secondary)
                }
            } else {
                SwiftUI.Section("Installed Patches") {
                    SwiftUI.ForEach(patches, id: \.id) { patch in
                        PatchRowView(
                            patch: patch,
                            isBusy: isBusy,
                            onPlay: { play(patch) },
                            onToggleDefault: { toggleDefault(patch) },
                            onToggleTile: { toggleTile(patch) },
                            onReapply: { reapply(patch) },
                            onExport: { export(patch) },
                            onDelete: { delete(patch) }
                        )
                    }
                }
            }
        }
        .navigationTitle("Patches")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear(perform: reload)
        .disabled(isBusy)
#if !os(tvOS)
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ActivityViewController(activityItems: [exportURL])
            }
        }
#endif
    }

    private func reload() {
        let results = PatchRepository.shared.patches(forGameMD5: gameMD5)
        patches = results.map { $0.isFrozen ? $0 : $0.freeze() }
    }

    private func play(_ patch: PVPatch) {
        dismiss()
        SceneCoordinator.shared.launchPatch(patch)
    }

    private func toggleDefault(_ patch: PVPatch) {
        let enabling = !patch.isDefaultLaunch
        do {
            try PatchRepository.shared.setDefaultLaunch(enabling, for: patch)
            statusMessage = enabling
                ? "\(patch.displayTitle) set as default launch."
                : "Cleared default patch."
            reload()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func toggleTile(_ patch: PVPatch) {
        let showing = !patch.showAsLibraryTile
        do {
            try PatchRepository.shared.setShowAsLibraryTile(showing, for: patch)
            statusMessage = showing
                ? "Added separate library tile."
                : "Removed separate library tile."
            reload()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reapply(_ patch: PVPatch) {
        isBusy = true
        statusMessage = "Reapplying…"
        Task {
            do {
                _ = try await PatchRepository.shared.reapply(patch)
                statusMessage = "Cache rebuilt."
                reload()
            } catch {
                statusMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func export(_ patch: PVPatch) {
        isBusy = true
        statusMessage = "Creating patched copy…"
        Task {
            do {
                let url = try await PatchRepository.shared.exportPatchedCopy(patch: patch)
                exportURL = url
                statusMessage = "Exported to \(url.lastPathComponent)"
#if !os(tvOS)
                showExporter = true
#endif
            } catch {
                statusMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func delete(_ patch: PVPatch) {
        do {
            try PatchRepository.shared.deletePatch(patch)
            statusMessage = "Patch deleted."
            reload()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private struct PatchRowView: View {
    let patch: PVPatch
    let isBusy: Bool
    let onPlay: () -> Void
    let onToggleDefault: () -> Void
    let onToggleTile: () -> Void
    let onReapply: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(patch.displayTitle)
                        .font(.headline)
                    Text(metadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if patch.isDefaultLaunch {
                    Label("Default", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            HStack(spacing: 12) {
                Button("Play", action: onPlay)
                Button(patch.isDefaultLaunch ? "Clear Default" : "Set Default", action: onToggleDefault)
                Button(patch.showAsLibraryTile ? "Hide Tile" : "Add Tile", action: onToggleTile)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)

            HStack(spacing: 12) {
                Button("Reapply", action: onReapply)
                Button("Export Copy", action: onExport)
                Button("Delete", role: .destructive, action: onDelete)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let format = patch.format {
            parts.append(format.displayName)
        }
        parts.append(patch.matchState.rawValue.capitalized)
        if patch.matchScore > 0 {
            parts.append(String(format: "score %.2f", patch.matchScore))
        }
        if let author = patch.author, !author.isEmpty {
            parts.append(author)
        }
        return parts.joined(separator: " · ")
    }
}
