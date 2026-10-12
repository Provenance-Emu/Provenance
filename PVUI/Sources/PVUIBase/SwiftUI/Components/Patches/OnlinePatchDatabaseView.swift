//
//  OnlinePatchDatabaseView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import Defaults
import PVSettings
import PVPatching
import PVLibrary
import PVLogging
import PVFileSystem

#if canImport(SafariServices)
import SafariServices
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Opt-in RomHacking.net search / download UI.
public struct OnlinePatchDatabaseView: View {
    private struct SafariItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @Default(.onlinePatchDatabaseEnabled) private var enabled
    @State private var query = ""
    @State private var category: OnlinePatchCategory?
    @State private var platformQuery = ""
    @State private var results: [OnlinePatchSearchResult] = []
    @State private var statusMessage: String?
    @State private var isSearching = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var safariItem: SafariItem?
    @State private var selectedResult: OnlinePatchSearchResult?
    @State private var showPatchApplier = false
    @State private var patchApplierGameMD5: String?
    @State private var lastImportedMatchTitle: String?

    private let database = RomHackingNetDatabase.shared

    public init() {}

    public var body: some View {
        Group {
            if enabled {
                searchContent
            } else {
                optInContent
            }
        }
        .navigationTitle("Online Patches")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#if canImport(SafariServices) && !os(tvOS)
        .sheet(item: $safariItem) { item in
            SafariWebView(url: item.url)
        }
#endif
        .onChange(of: selectedResult?.id) { _, newID in
            guard newID != nil else { return }
            // Fresh detail presentation — clear prior import match chrome.
            lastImportedMatchTitle = nil
            statusMessage = nil
            isDownloading = false
            downloadProgress = 0
        }
        .sheet(item: $selectedResult) { result in
            OnlinePatchDetailView(
                result: result,
                onOpenSafari: { openSafari(result.pageURL) },
                onDownload: { downloadAndImport(result) },
                onOpenApplier: {
                    selectedResult = nil
                    showPatchApplier = true
                },
                matchedGameTitle: $lastImportedMatchTitle,
                isDownloading: $isDownloading,
                downloadProgress: $downloadProgress,
                statusMessage: $statusMessage
            )
        }
        .sheet(isPresented: $showPatchApplier, onDismiss: {
            patchApplierGameMD5 = nil
        }) {
            NavigationStack {
                PatchApplierView(preselectedGameMD5: patchApplierGameMD5)
            }
        }
    }

    // MARK: - Opt-in

    private var optInContent: some View {
        SwiftUI.List {
            SwiftUI.Section {
                Text("Search RomHacking.net for fan translations, hacks, and bug fixes. Downloads are imported as local patches and matched to your library.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            SwiftUI.Section("Privacy") {
                Text("This feature is off by default. Enabling it lets Provenance query a search index and optionally open RomHacking.net pages. No account is created and no library contents are uploaded.")
                    .font(.footnote)
                Button("Enable Online Patch Search") {
                    Defaults[.onlinePatchDatabaseEnabled] = true
                }
                .buttonStyle(.borderedProminent)
            }
            SwiftUI.Section {
                Button("Open RomHacking.net in Browser") {
                    if let url = URL(string: "https://www.romhacking.net/") {
                        openSafari(url)
                    }
                }
            }
        }
    }

    // MARK: - Search

    private var searchContent: some View {
        SwiftUI.List {
            SwiftUI.Section {
                TextField("Search patches…", text: $query)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                Picker("Type", selection: $category) {
                    Text("Any").tag(Optional<OnlinePatchCategory>.none)
                    SwiftUI.ForEach([OnlinePatchCategory.translation, .hack, .improvement, .bugfix, .patch]) { item in
                        Text(item.displayName).tag(Optional(item))
                    }
                }
                TextField("Platform filter (optional)", text: $platformQuery)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                Button {
                    Task { await runSearch() }
                } label: {
                    if isSearching {
                        ProgressView()
                    } else {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
                .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Open Search in Safari") {
                    let filter = OnlinePatchSearchFilter(
                        category: category,
                        platformQuery: platformQuery.isEmpty ? nil : platformQuery
                    )
                    if let url = database.safariSearchURL(query: query, filter: filter) {
                        openSafari(url)
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let statusMessage {
                SwiftUI.Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.Section("Results") {
                if results.isEmpty {
                    Text(isSearching ? "Searching…" : "No results yet.")
                        .foregroundStyle(.secondary)
                } else {
                    SwiftUI.ForEach(0..<results.count, id: \.self) { index in
                        let result = results[index]
                        Button {
                            selectedResult = result
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 8) {
                                    Text(result.category.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
                                    if let snippet = result.snippet {
                                        Text(snippet)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SwiftUI.Section {
                ThemedToggle(isOn: $enabled) {
                    Text("Online patch search enabled")
                }
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func runSearch() async {
        isSearching = true
        statusMessage = nil
        defer { isSearching = false }
        let filter = OnlinePatchSearchFilter(
            category: category,
            platformQuery: platformQuery.isEmpty ? nil : platformQuery
        )
        do {
            results = try await database.search(query: query, filter: filter)
            statusMessage = results.isEmpty
                ? "No patch pages found. Try Safari search, or broaden the query."
                : "\(results.count) result(s). Tap one for details."
        } catch let error as OnlinePatchDatabaseError {
            statusMessage = error.localizedDescription
            // A Cloudflare block on RHDN itself → Safari can get through. A DuckDuckGo
            // anomaly page is a rate limit on us; opening Safari to RHDN won't help.
            if error == .blockedByUpstream,
               let url = database.safariSearchURL(query: query, filter: filter) {
                openSafari(url)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func downloadAndImport(_ result: OnlinePatchSearchResult) {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        statusMessage = "Downloading…"
        lastImportedMatchTitle = nil
        patchApplierGameMD5 = nil
        Task {
            do {
                // Download to a scratch folder; importPatchFile moves the patch (or the
                // patches inside a ZIP — RHDN usually serves archives) into Patches/.
                let destDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("OnlinePatchDownload-\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: destDir) }
                let fileURL = try await database.downloadPatch(id: result.id, to: destDir) { progress in
                    Task { @MainActor in
                        downloadProgress = progress.fractionCompleted
                        if !progress.status.isEmpty {
                            statusMessage = progress.status
                        }
                    }
                }
                let patch = try await PatchRepository.shared.importPatchFile(at: fileURL, autoMatch: true)
                let frozen = patch.isFrozen ? patch : patch.freeze()
                if let game = frozen.game, !game.isInvalidated {
                    lastImportedMatchTitle = game.title
                    patchApplierGameMD5 = game.md5Hash
                    // Ensure a library variant exists so Apply / launch works immediately.
                    _ = try? await PatchRepository.shared.ensureVariant(for: frozen, baseGame: game)
                    statusMessage = "Imported \(fileURL.lastPathComponent) and matched to \(game.title)."
                } else {
                    statusMessage = "Imported \(fileURL.lastPathComponent). No library match yet — link it under Patches, or use Patch Applier."
                }
            } catch let error as OnlinePatchDatabaseError where error == .blockedByUpstream {
                statusMessage = error.localizedDescription
                openSafari(result.pageURL)
            } catch {
                statusMessage = error.localizedDescription
            }
            isDownloading = false
        }
    }

    private func openSafari(_ url: URL) {
#if canImport(SafariServices) && !os(tvOS)
        safariItem = SafariItem(url: url)
#elseif canImport(AppKit)
        AppKit.NSWorkspace.shared.open(url)
#else
        statusMessage = "Open in browser: \(url.absoluteString)"
#endif
    }
}

// MARK: - Detail

private struct OnlinePatchDetailView: View {
    let result: OnlinePatchSearchResult
    let onOpenSafari: () -> Void
    let onDownload: () -> Void
    let onOpenApplier: () -> Void
    @Binding var matchedGameTitle: String?
    @Binding var isDownloading: Bool
    @Binding var downloadProgress: Double
    @Binding var statusMessage: String?

    @State private var info: OnlinePatchInfo?
    @State private var loadError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SwiftUI.List {
                SwiftUI.Section("Listing") {
                    Text(result.title).font(.headline)
                    detailRow("Type", result.category.displayName)
                    if let author = info?.author ?? result.author {
                        detailRow("Author", author)
                    }
                    if let platform = info?.platformName {
                        detailRow("Platform", platform)
                    }
                    if let version = info?.version {
                        detailRow("Version", version)
                    }
                    if let language = info?.language {
                        detailRow("Language", language)
                    }
                }

                if let description = info?.patchDescription ?? result.snippet {
                    SwiftUI.Section("Description") {
                        Text(description)
                            .font(.footnote)
                    }
                }

                if let loadError {
                    SwiftUI.Section {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                    Button("Open Page in Safari", action: onOpenSafari)
                    Button {
                        onDownload()
                    } label: {
                        if isDownloading {
                            ProgressView(value: downloadProgress)
                        } else {
                            Label("Download & Import", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isDownloading)
                    if let matchedGameTitle {
                        Button(action: onOpenApplier) {
                            Label("Open Patch Applier (\(matchedGameTitle))", systemImage: "wand.and.stars")
                        }
                        .disabled(isDownloading)
                    }
                }
            }
            .navigationTitle("Patch Details")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                do {
                    info = try await RomHackingNetDatabase.shared.fetchPatchInfo(id: result.id)
                } catch {
                    loadError = error.localizedDescription
                    info = OnlinePatchInfo(
                        id: result.id,
                        title: result.title,
                        author: result.author,
                        category: result.category,
                        patchDescription: result.snippet,
                        pageURL: result.pageURL
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
