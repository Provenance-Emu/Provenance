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
import PVUIBase
import PVLogging
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ViewModel

@MainActor
final class RetroArchLogBrowserViewModel: ObservableObject {
    @Published var logFiles: [LogFileEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Well-known RetroArch logs directory inside the app's Documents folder.
    static let logsDirectory: URL? = {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("RetroArch/logs")
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
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

    func loadFiles() {
        guard let dir = Self.logsDirectory else {
            logFiles = []
            return
        }
        isLoading = true
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles)
            logFiles = urls
                .filter { $0.pathExtension.lowercased() == "log" || $0.pathExtension.lowercased() == "txt" || !$0.hasDirectoryPath }
                .compactMap { url -> LogFileEntry? in
                    let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let size = Int64(resources?.fileSize ?? 0)
                    let date = resources?.contentModificationDate ?? Date.distantPast
                    return LogFileEntry(url: url, size: size, modificationDate: date)
                }
                .sorted { $0.modificationDate > $1.modificationDate }
        } catch {
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
    @StateObject private var viewModel = RetroArchLogBrowserViewModel()
    @State private var selectedEntry: RetroArchLogBrowserViewModel.LogFileEntry?
    @State private var showingDeleteAllConfirm = false
#if !os(tvOS)
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
#endif

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if RetroArchLogBrowserViewModel.logsDirectory == nil {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { viewModel.loadFiles() }
        .sheet(item: $selectedEntry) { entry in
            LogFileViewerSheet(fileURL: entry.url)
        }
#if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            if !shareItems.isEmpty {
                ShareSheetViewController(activityItems: shareItems)
                    .ignoresSafeArea()
            }
        }
#endif
        .alert("Delete All Logs?", isPresented: $showingDeleteAllConfirm) {
            Button("Delete All", role: .destructive) { viewModel.deleteAllFiles() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(viewModel.logFiles.count) RetroArch log files.")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
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
            .onDelete { offsets in
                for i in offsets {
                    viewModel.deleteFile(viewModel.logFiles[i])
                }
            }
        }
        .scrollContentBackground(.hidden)
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
                Button {
                    shareItems = [entry.url]
                    showingShareSheet = true
                } label: {
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
        ToolbarItem(placement: .navigationBarTrailing) {
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
#if !os(tvOS)
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
#endif

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

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
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle(fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RetroTheme.retroPink)
                }
#if !os(tvOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        shareItems = [fileURL]
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(RetroTheme.retroBlue)
                }
#endif
            }
#if !os(tvOS)
            .sheet(isPresented: $showingShareSheet) {
                if !shareItems.isEmpty {
                    ShareSheetViewController(activityItems: shareItems)
                        .ignoresSafeArea()
                }
            }
#endif
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

// MARK: - UIActivityViewController wrapper (iOS only)

#if !os(tvOS)
private struct ShareSheetViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#if DEBUG
#Preview("RetroArch Logs") {
    NavigationStack {
        RetroArchLogBrowserView()
    }
    .preferredColorScheme(.dark)
}
#endif
