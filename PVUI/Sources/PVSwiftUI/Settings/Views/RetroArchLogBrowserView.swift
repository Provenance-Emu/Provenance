//
//  RetroArchLogBrowserView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 3/30/26.
//  Copyright 2025 Provenance Emu. All rights reserved.
//
//  Browse, view, delete, and share RetroArch log files stored in
//  Documents/RetroArch/logs/ on the device.

import SwiftUI
import Observation
import PVUIBase

// MARK: - ViewModel

@MainActor
@Observable
final class RetroArchLogBrowserViewModel {
    var logFiles: [LogFileEntry] = []
    var isLoading = false
    var directoryExists = true
    var errorMessage: String?

    /// Static URL for the RetroArch logs directory (computed once, no existence check).
    static let logsDirectoryURL: URL? = {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docs.appendingPathComponent("RetroArch/logs")
    }()

    struct LogFileEntry: Identifiable {
        let id = UUID()
        let url: URL
        var name: String { url.lastPathComponent }
        let size: Int64
        let modificationDate: Date
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }

    func loadFiles() async {
        guard let dir = Self.logsDirectoryURL else {
            directoryExists = false
            return
        }
        // Check existence dynamically each load so the view refreshes correctly
        // after RetroArch creates the logs directory for the first time.
        let exists = FileManager.default.fileExists(atPath: dir.path)
        directoryExists = exists
        guard exists else {
            logFiles = []
            return
        }
        isLoading = true
        let loadResult = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            do {
                let urls = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles)
                let entries = urls
                    .filter { !$0.hasDirectoryPath }
                    .compactMap { url -> LogFileEntry? in
                        let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                        let size = Int64(resources?.fileSize ?? 0)
                        let date = resources?.contentModificationDate ?? Date.distantPast
                        return LogFileEntry(url: url, size: size, modificationDate: date)
                    }
                    .sorted { $0.modificationDate > $1.modificationDate }
                return Result<[LogFileEntry], Error>.success(entries)
            } catch {
                return Result<[LogFileEntry], Error>.failure(error)
            }
        }.value
        switch loadResult {
        case .success(let entries):
            logFiles = entries
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteFile(_ entry: LogFileEntry) {
        do {
            try FileManager.default.removeItem(at: entry.url)
            logFiles.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = "Failed to delete \(entry.name): \(error.localizedDescription)"
        }
    }

    func deleteAllFiles() {
        for entry in logFiles {
            try? FileManager.default.removeItem(at: entry.url)
        }
        logFiles.removeAll()
    }
}

// MARK: - Log Browser

/// Lists all RetroArch log files with options to view, share, and delete them.
public struct RetroArchLogBrowserView: View {
    @State private var viewModel = RetroArchLogBrowserViewModel()
    @State private var selectedEntry: RetroArchLogBrowserViewModel.LogFileEntry?
    @State private var showingDeleteAllConfirm = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !viewModel.directoryExists {
                emptyStateView(
                    icon: "folder.badge.questionmark",
                    title: "No RetroArch Logs",
                    subtitle: "RetroArch hasn't written any logs yet.\nLogs appear in Documents/RetroArch/logs/ after running a game."
                )
            } else if viewModel.isLoading {
                ProgressView()
                    .tint(RetroTheme.retroPink)
            } else if viewModel.logFiles.isEmpty {
                emptyStateView(
                    icon: "doc.text",
                    title: "No Log Files",
                    subtitle: "The RetroArch logs folder is empty."
                )
            } else {
                logList
            }
        }
        .navigationTitle("RetroArch Logs")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { toolbarContent }
        .task { await viewModel.loadFiles() }
        .sheet(item: $selectedEntry) { entry in
            LogFileViewerSheet(fileURL: entry.url)
        }
        .alert("Delete All Logs?", isPresented: $showingDeleteAllConfirm) {
            Button("Delete All", role: .destructive) { viewModel.deleteAllFiles() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(viewModel.logFiles.count) RetroArch log files.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Log List

    private var logList: some View {
        List {
            ForEach(viewModel.logFiles) { entry in
                logFileRow(entry)
            }
#if !os(tvOS)
            .onDelete { offsets in
                // Collect entries first so index shifts from removeAll don't affect iteration
                let entries = offsets.map { viewModel.logFiles[$0] }
                entries.forEach { viewModel.deleteFile($0) }
            }
#endif
        }
        #if !os(tvOS)
        .scrollContentBackground(.hidden)
        #endif
        .background(Color.black)
        .listStyle(.plain)
    }

    private func logFileRow(_ entry: RetroArchLogBrowserViewModel.LogFileEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.formattedSize)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue.opacity(0.8))

                    Text(entry.modificationDate, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            HStack(spacing: 12) {
#if !os(tvOS)
                ShareLink(item: entry.url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(RetroTheme.retroBlue)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
#endif
                Button {
                    selectedEntry = entry
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(RetroTheme.retroPink)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.black.opacity(0.01))
#if os(tvOS)
        .retroFocusButtonStyle(showBorder: false)
        .onTapGesture {
            selectedEntry = entry
        }
#endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !viewModel.logFiles.isEmpty {
                Button(role: .destructive) {
                    showingDeleteAllConfirm = true
                } label: {
                    Label("Delete All", systemImage: "trash")
                        .foregroundColor(RetroTheme.retroPink)
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(RetroTheme.retroBlue.opacity(0.5))
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Log File Viewer Sheet

struct LogFileViewerSheet: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(RetroTheme.retroPink)
                } else {
                    ScrollView {
                        Text(content)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
#if !os(tvOS)
                            .textSelection(.enabled)
#endif
                    }
                }
            }
            .navigationTitle(fileURL.lastPathComponent)
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RetroTheme.retroPink)
                }
#if !os(tvOS)
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: fileURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(RetroTheme.retroBlue)
                }
#endif
            }
        }
        .task {
            await loadContent()
        }
    }

    private func loadContent() async {
        let url = fileURL
        content = await Task.detached(priority: .userInitiated) {
            (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) ?? "Unable to read file."
        }.value
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
#Preview("RetroArch Logs") {
    NavigationStack {
        RetroArchLogBrowserView()
    }
    .preferredColorScheme(.dark)
}
#endif
