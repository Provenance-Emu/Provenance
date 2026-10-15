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
    @State private var placement: PatchPlacement = .newLibraryEntry
    @State private var allowCRCMismatch = false
    /// Set when applying failed because the ROM is not the one the patch was made for. xdelta and
    /// PPF carry no CRC to pre-check, so this is where they offer "Apply anyway".
    @State private var sourceMismatchFailed = false
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
                    if !inspection.canVerifyIntegrity {
                        Text("This patch carries no checksum, so it cannot confirm it was made for your ROM.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SwiftUI.Section("Target ROM") {
                Picker("Library game", selection: Binding(
                    get: { selectedGameMD5 ?? "" },
                    set: { newValue in
                        selectedGameMD5 = newValue.isEmpty ? nil : newValue
                        sourceMismatchFailed = false
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

            if crcValidation != nil || sourceMismatchFailed {
                SwiftUI.Section("Validation") {
                    if let crcValidation {
                        Text(crcValidation.userMessage)
                            .font(.footnote)
                            .foregroundStyle(crcValidation.isMismatch ? Color.orange : Color.secondary)
                    }
                    if sourceMismatchFailed {
                        Text("The ROM does not match the one this patch was made for.")
                            .font(.footnote)
                            .foregroundStyle(Color.orange)
                    }
                    if crcValidation?.isMismatch == true || sourceMismatchFailed {
                        Toggle("Apply anyway (ignore ROM mismatch)", isOn: $allowCRCMismatch)
                    }
                }
            }

            SwiftUI.Section("Output") {
                Toggle("Import patch into library after apply", isOn: $importToLibrary)
                if importToLibrary {
                    Picker("Patched version", selection: $placement) {
                        Text("New library entry").tag(PatchPlacement.newLibraryEntry)
                        Text("Replace the original").tag(PatchPlacement.replaceOriginal)
                    }
                    Text(placement == .replaceOriginal
                         ? "Playing the game starts the patched version. The original file is kept; play it from Patches & Mods › Play Original."
                         : "The patched version is listed under the game's Patches & Mods.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            sourceMismatchFailed = false
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
        PatchFormat.implementedFileExtensions.sorted().compactMap {
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
                allowCRCMismatch: allowCRCMismatch,
                placement: placement
            ) { progress in
                Task { @MainActor in
                    progressFraction = progress.fractionCompleted
                    progressStatus = progress.status
                }
            }
            lastExportURL = result.exportURL
            crcValidation = result.crcValidation
            inspection = result.inspection
            sourceMismatchFailed = false
            statusMessage = "Applied → \(result.exportURL.lastPathComponent)"
                + (result.importedPatch != nil ? " (imported to library)" : "")
                + (result.checkedAgainstSource ? "" : " — not verified against the ROM")
        } catch PatchError.sourceROMMismatch {
            sourceMismatchFailed = true
            statusMessage = PatchError.sourceROMMismatch.localizedDescription
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

// MARK: - Batch

public struct BatchPatchApplierView: View {
    @State private var folderURL: URL?
    @State private var jobs: [BatchPatchJob] = []
    @State private var skipped: [BatchPatchApplier.BatchPatchFailure] = []
    @State private var unmatchedCount = 0
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

            if !skipped.isEmpty {
                SwiftUI.Section("Skipped (\(skipped.count))") {
                    SwiftUI.ForEach(0..<skipped.count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skipped[index].patchURL.lastPathComponent).font(.subheadline)
                            Text(skipped[index].message).font(.caption).foregroundStyle(Color.orange)
                        }
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
                skipped = []
                unmatchedCount = 0
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
        let patches = await batcher.patchFiles(in: folderURL)
        let roms = PatchRepository.shared.batchROMCandidates()
        // The planner hashes only name-matched ROMs that lack a stored CRC, so a large
        // library isn't read wholesale. Run it off-main; it's pure file IO + CPU.
        let batcher = self.batcher
        let plan = await Task.detached(priority: .userInitiated) {
            await batcher.plan(patchURLs: patches, roms: roms) { rom in
                try? PatchCRCValidator.crc32(ofFileAt: rom.fileURL)
            }
        }.value
        jobs = plan.jobs
        skipped = plan.failed
        unmatchedCount = plan.unmatched.count
        var summary = "Found \(patches.count) patch(es); matched \(jobs.count)"
        if unmatchedCount > 0 { summary += ", \(unmatchedCount) without a library match" }
        if !skipped.isEmpty { summary += ", \(skipped.count) unreadable" }
        statusMessage = summary + "."
    }

    @MainActor
    private func run() async {
        guard !jobs.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        // The patch URLs live inside the Files-picked folder; its security scope was
        // released when plan() returned, so hold it again for the whole apply.
        let scoped = folderURL?.startAccessingSecurityScopedResource() ?? false
        defer { if scoped { folderURL?.stopAccessingSecurityScopedResource() } }
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
                .foregroundStyle(result.success ? Color.secondary : Color.red)
        }
    }
}
