//
//  PatchApplierView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import RealmSwift
import PVLibrary
import PVRealm
import PVLogging
import PVPatching
import PVFileSystem

/// Dedicated Patch Applier: pick patch + ROM, validate CRC, apply with progress.
public struct PatchApplierView: View {
    private enum PickerTarget {
        case patch
        case romFile
    }

    /// Optional library game preselected from a context menu.
    private let preselectedGameMD5: String?

    @State private var patchURL: URL?
    @State private var romURL: URL?
    @State private var selectedGameMD5: String?
    @State private var games: [PVGame] = []
    @State private var inspection: PatchInspection?
    @State private var crcValidation: PatchCRCValidation?
    @State private var importToLibrary = true
    @State private var allowCRCMismatch = false
    @State private var statusMessage: String?
    @State private var progressFraction: Double = 0
    @State private var progressStatus = ""
    @State private var isBusy = false
    @State private var showFilePicker = false
    @State private var pickerTarget: PickerTarget = .patch
    @State private var lastExportURL: URL?

    public init(preselectedGameMD5: String? = nil) {
        self.preselectedGameMD5 = preselectedGameMD5
        _selectedGameMD5 = State(initialValue: preselectedGameMD5)
    }

    public var body: some View {
        SwiftUI.Form {
            SwiftUI.Section("Patch File") {
                Button(patchURL?.lastPathComponent ?? "Choose Patch File…") {
                    pickerTarget = .patch
                    showFilePicker = true
                }
                if let inspection {
                    patchMetaRow("Format", inspection.format.displayName)
                    if let title = inspection.title, !title.isEmpty {
                        patchMetaRow("Title", title)
                    }
                    if let crc = inspection.sourceCRC32 {
                        patchMetaRow("Target CRC", String(format: "0x%08X", crc))
                    } else {
                        Text("No embedded source CRC")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let target = inspection.targetCRC32 {
                        patchMetaRow("Patched CRC", String(format: "0x%08X", target))
                    }
                }
            }

            SwiftUI.Section("Target ROM") {
                Picker("Library game", selection: Binding(
                    get: { selectedGameMD5 ?? "" },
                    set: { newValue in
                        selectedGameMD5 = newValue.isEmpty ? nil : newValue
                        if let md5 = selectedGameMD5,
                           let game = games.first(where: { $0.md5Hash == md5 }) {
                            romURL = game.file?.url
                        }
                        Task { await refreshValidation() }
                    }
                )) {
                    Text("None — pick from Files").tag("")
                    SwiftUI.ForEach(games, id: \.md5Hash) { game in
                        Text(game.title).tag(game.md5Hash)
                    }
                }
#if !os(tvOS)
                Button(romURL?.lastPathComponent ?? "Choose ROM from Files…") {
                    pickerTarget = .romFile
                    showFilePicker = true
                }
#endif
            }

            if let crcValidation {
                SwiftUI.Section("Validation") {
                    Text(crcValidation.userMessage)
                        .font(.footnote)
                        .foregroundStyle(crcValidation.isMismatch ? Color.orange : Color.secondary)
                    if crcValidation.isMismatch {
                        Toggle("Apply anyway (ignore CRC mismatch)", isOn: $allowCRCMismatch)
                    }
                }
            }

            SwiftUI.Section("Output") {
                Toggle("Import patch into library after apply", isOn: $importToLibrary)
                Text("Patched ROM is written to Documents/PatchedROMs/.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let lastExportURL {
                    Text("Last output: \(lastExportURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isBusy {
                SwiftUI.Section {
                    ProgressView(value: progressFraction) {
                        Text(progressStatus.isEmpty ? "Working…" : progressStatus)
                            .font(.footnote)
                    }
                }
            }

            if let statusMessage {
                SwiftUI.Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.Section {
                Button {
                    Task { await apply() }
                } label: {
                    Label("Apply Patch", systemImage: "bandage")
                }
                .disabled(isBusy || patchURL == nil || romURL == nil)
            }

            SwiftUI.Section("More") {
                NavigationLink {
                    BatchPatchApplierView()
                } label: {
                    Label("Batch Apply Folder…", systemImage: "folder.badge.gearshape")
                }
                NavigationLink {
                    CreatePatchView()
                } label: {
                    Label("Create Patch…", systemImage: "doc.badge.plus")
                }
            }
        }
        .navigationTitle("Patch Applier")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: pickerTarget == .patch ? Self.patchTypes : [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            switch pickerTarget {
            case .patch:
                patchURL = url
                Task { await inspectPatch() }
            case .romFile:
                romURL = url
                selectedGameMD5 = nil
                Task { await refreshValidation() }
            }
        }
#endif
        .task {
            loadGames()
            if let md5 = selectedGameMD5,
               let game = games.first(where: { $0.md5Hash == md5 }) {
                romURL = game.file?.url
            }
        }
    }

    private static var patchTypes: [UTType] {
        ["ips", "bps", "ups", "ppf", "xdelta", "vcdiff"].compactMap {
            UTType(filenameExtension: $0)
        } + [.data]
    }

    @ViewBuilder
    private func patchMetaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func loadGames() {
        let realm = RomDatabase.sharedInstance.realm
        games = Swift.Array(
            realm.objects(PVGame.self)
                .filter("isPatchVariant == false AND contentless == false")
                .sorted(byKeyPath: "title")
        ).map { $0.freeze() }
    }

    @MainActor
    private func inspectPatch() async {
        guard let patchURL else {
            inspection = nil
            crcValidation = nil
            return
        }
        do {
            let scoped = patchURL.startAccessingSecurityScopedResource()
            defer { if scoped { patchURL.stopAccessingSecurityScopedResource() } }
            inspection = try PatchInspector().inspect(patchURL: patchURL)
            await refreshValidation()
        } catch {
            inspection = nil
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshValidation() async {
        guard let patchURL, let romURL, let inspection else {
            crcValidation = nil
            return
        }
        do {
            let patchScoped = patchURL.startAccessingSecurityScopedResource()
            let romScoped = romURL.startAccessingSecurityScopedResource()
            defer {
                if patchScoped { patchURL.stopAccessingSecurityScopedResource() }
                if romScoped { romURL.stopAccessingSecurityScopedResource() }
            }
            crcValidation = try PatchCRCValidator.validate(romURL: romURL, inspection: inspection)
        } catch {
            crcValidation = nil
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func apply() async {
        guard let patchURL, let romURL else { return }
        isBusy = true
        progressFraction = 0
        progressStatus = "Starting…"
        statusMessage = nil
        defer { isBusy = false }

        let patchScoped = patchURL.startAccessingSecurityScopedResource()
        let romScoped = romURL.startAccessingSecurityScopedResource()
        defer {
            if patchScoped { patchURL.stopAccessingSecurityScopedResource() }
            if romScoped { romURL.stopAccessingSecurityScopedResource() }
        }

        let preferred: PVGame? = {
            guard let md5 = selectedGameMD5 else { return nil }
            return games.first(where: { $0.md5Hash == md5 })
        }()

        do {
            let result = try await PatchRepository.shared.applyStandalone(
                patchURL: patchURL,
                romURL: romURL,
                preferredGame: preferred,
                importToLibrary: importToLibrary,
                allowCRCMismatch: allowCRCMismatch
            ) { progress in
                Task { @MainActor in
                    progressFraction = progress.fractionCompleted
                    progressStatus = progress.status
                }
            }
            lastExportURL = result.exportURL
            crcValidation = result.crcValidation
            inspection = result.inspection
            statusMessage = "Applied → \(result.exportURL.lastPathComponent)"
                + (result.importedPatch != nil ? " (imported to library)" : "")
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

// MARK: - Batch

public struct BatchPatchApplierView: View {
    @State private var folderURL: URL?
    @State private var jobs: [BatchPatchJob] = []
    @State private var batchResults: [BatchPatchResult] = []
    @State private var allowCRCMismatch = false
    @State private var statusMessage: String?
    @State private var isBusy = false
    @State private var progressFraction: Double = 0
    @State private var progressStatus = ""
    @State private var showFolderPicker = false

    private let batcher = BatchPatchApplier()

    public init() {}

    public var body: some View {
        SwiftUI.Form {
            SwiftUI.Section("Patch Folder") {
#if !os(tvOS)
                Button(folderURL?.lastPathComponent ?? "Choose Folder of Patches…") {
                    showFolderPicker = true
                }
#else
                Text("Batch folder picking requires iOS/macOS Files access.")
                    .foregroundStyle(.secondary)
#endif
                Button("Scan & Match to Library") {
                    Task { await plan() }
                }
                .disabled(isBusy || folderURL == nil)
            }

            SwiftUI.Section {
                Toggle("Allow CRC mismatches", isOn: $allowCRCMismatch)
            }

            if !jobs.isEmpty {
                SwiftUI.Section("Matched Jobs (\(jobs.count))") {
                    // Index-based ForEach avoids Binding<[T]> overload selection in this target.
                    SwiftUI.ForEach(0..<jobs.count, id: \.self) { index in
                        BatchPatchJobRow(job: jobs[index])
                    }
                }
            }

            if isBusy {
                SwiftUI.Section {
                    ProgressView(value: progressFraction) {
                        Text(progressStatus.isEmpty ? "Working…" : progressStatus)
                            .font(.footnote)
                    }
                }
            }

            if let statusMessage {
                SwiftUI.Section {
                    Text(statusMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }

            if !batchResults.isEmpty {
                SwiftUI.Section("Results") {
                    // Index-based ForEach avoids Binding<[T]> overload selection in this target.
                    SwiftUI.ForEach(0..<batchResults.count, id: \.self) { index in
                        BatchPatchResultRow(result: batchResults[index])
                    }
                }
            }

            SwiftUI.Section {
                Button {
                    Task { await run() }
                } label: {
                    Label("Apply Matched Patches", systemImage: "play.fill")
                }
                .disabled(isBusy || jobs.isEmpty)
            }

            SwiftUI.Section("ROM Tools") {
                Text("Batch apply uses the shared ROMToolOperation foundation. Future converters (e.g. CHD) will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SwiftUI.ForEach(ROMToolRegistry.default.operations, id: \.id) { tool in
                    Text(tool.displayName)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Batch Apply")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                folderURL = urls.first
                jobs = []
                batchResults = []
            }
        }
#endif
    }

    @MainActor
    private func plan() async {
        guard let folderURL else { return }
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        let scoped = folderURL.startAccessingSecurityScopedResource()
        defer { if scoped { folderURL.stopAccessingSecurityScopedResource() } }
        do {
            let patches = await batcher.patchFiles(in: folderURL)
            let roms = PatchRepository.shared.batchROMCandidates()
            // Compute missing CRCs off-main for better matching.
            let enriched: [BatchPatchApplier.ROMCandidate] = await Task.detached(priority: .userInitiated) {
                roms.map { rom in
                    var copy = rom
                    if copy.crc32 == nil {
                        copy.crc32 = try? PatchCRCValidator.crc32(ofFileAt: rom.fileURL)
                    }
                    return copy
                }
            }.value
            jobs = try await batcher.plan(patchURLs: patches, roms: enriched)
            statusMessage = "Found \(patches.count) patch(es); matched \(jobs.count)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func run() async {
        guard !jobs.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        let dest = URL.documentsPath.appendingPathComponent("PatchedROMs", isDirectory: true)
        batchResults = await batcher.apply(
            jobs: jobs,
            outputDirectory: dest,
            allowCRCMismatch: allowCRCMismatch
        ) { progress in
            Task { @MainActor in
                progressFraction = progress.fractionCompleted
                progressStatus = progress.status
            }
        }
        let ok = batchResults.filter(\.success).count
        statusMessage = "Finished: \(ok)/\(batchResults.count) succeeded."
    }
}

// MARK: - Batch rows

private struct BatchPatchJobRow: View {
    let job: BatchPatchJob

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(job.patchURL.lastPathComponent).font(.headline)
            Text("→ \(job.romTitle) (\(job.confidence.rawValue))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if job.crcValidation.isMismatch {
                Text(job.crcValidation.userMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct BatchPatchResultRow: View {
    let result: BatchPatchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.patchURL.lastPathComponent)
                .font(.subheadline)
            Text(result.message)
                .font(.caption)
                .foregroundStyle(result.success ? .secondary : .red)
        }
    }
}
