//
//  PVLogSessionBrowserView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 3/30/26.
//  Copyright 2025 Provenance Emu. All rights reserved.
//
//  Browse, view, share, and delete Provenance session log files
//  written by PVLogFileManager.

import SwiftUI
import PVUIBase
import PVLogging
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ViewModel

@MainActor
final class PVLogSessionViewModel: ObservableObject {
    @Published var logFiles: [SessionLogEntry] = []
    @Published var isLoggingEnabled = false
    @Published var errorMessage: String?

    struct SessionLogEntry: Identifiable {
        let id = UUID()
        let url: URL
        var name: String { url.lastPathComponent }
        let size: Int64
        let modificationDate: Date
        var formattedSize: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
        var isCurrentSession: Bool = false
    }

    func refresh() {
        isLoggingEnabled = PVLogFileManager.shared.isLogging
        let fm = FileManager.default
        let currentURL = PVLogFileManager.shared.currentSessionURL
        logFiles = PVLogFileManager.shared.logFiles().compactMap { url in
            let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(resources?.fileSize ?? 0)
            let date = resources?.contentModificationDate ?? .distantPast
            return SessionLogEntry(
                url: url,
                size: size,
                modificationDate: date,
                isCurrentSession: url == currentURL
            )
        }
        _ = fm // suppress unused warning
    }

    func startLogging() {
        PVLogFileManager.shared.startLogging()
        isLoggingEnabled = true
    }

    func stopLogging() {
        PVLogFileManager.shared.stopLogging()
        isLoggingEnabled = false
    }

    func deleteFile(_ entry: SessionLogEntry) {
        do {
            try PVLogFileManager.shared.deleteFile(at: entry.url)
            logFiles.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = "Failed to delete \(entry.name): \(error.localizedDescription)"
        }
    }

    func deleteAllFiles() {
        PVLogFileManager.shared.deleteAllFiles()
        logFiles.removeAll()
    }
}

// MARK: - Session Log Browser

/// Lists Provenance session log files with view, share, and delete actions.
public struct PVLogSessionBrowserView: View {
    @StateObject private var viewModel = PVLogSessionViewModel()
    @State private var selectedEntry: PVLogSessionViewModel.SessionLogEntry?
    @State private var showingDeleteAllConfirm = false
#if !os(tvOS)
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
#endif

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Status bar
                statusBar

                Divider().background(RetroTheme.retroPink.opacity(0.3))

                if viewModel.logFiles.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
        }
        .navigationTitle("Session Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { viewModel.refresh() }
        .sheet(item: $selectedEntry) { entry in
            LogFileViewerSheet(entry: entry)
        }
#if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            if !shareItems.isEmpty {
                ActivityShareSheet(activityItems: shareItems).ignoresSafeArea()
            }
        }
#endif
        .alert("Delete All Logs?", isPresented: $showingDeleteAllConfirm) {
            Button("Delete All", role: .destructive) { viewModel.deleteAllFiles() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all \(viewModel.logFiles.count) session log files.")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var statusBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(viewModel.isLoggingEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .shadow(color: viewModel.isLoggingEnabled ? .green : .clear, radius: 4)

            Text(viewModel.isLoggingEnabled ? "Logging active" : "Logging inactive")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Button {
                if viewModel.isLoggingEnabled {
                    viewModel.stopLogging()
                } else {
                    viewModel.startLogging()
                }
                viewModel.refresh()
            } label: {
                Text(viewModel.isLoggingEnabled ? "Stop" : "Start")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.isLoggingEnabled ? RetroTheme.retroPink : RetroTheme.retroBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(viewModel.isLoggingEnabled ? RetroTheme.retroPink : RetroTheme.retroBlue, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    private var fileList: some View {
        List {
            ForEach(viewModel.logFiles) { entry in
                fileRow(entry)
            }
            .onDelete { offsets in
                for i in offsets { viewModel.deleteFile(viewModel.logFiles[i]) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .listStyle(.plain)
    }

    private func fileRow(_ entry: PVLogSessionViewModel.SessionLogEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if entry.isCurrentSession {
                        Image(systemName: "record.circle")
                            .foregroundColor(.green)
                            .font(.system(size: 10))
                    }
                    Text(entry.name)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(entry.isCurrentSession ? Color.green : .white)
                        .lineLimit(1)
                }
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
                Button { selectedEntry = entry } label: {
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
        .onTapGesture { selectedEntry = entry }
#endif
    }

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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: viewModel.isLoggingEnabled ? "doc.text.below.ecg" : "doc.text")
                .font(.system(size: 48))
                .foregroundColor(RetroTheme.retroBlue.opacity(0.5))
            Text("No Session Logs")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(viewModel.isLoggingEnabled
                 ? "Logs will appear here as they are written."
                 : "Start logging to capture log files from this session.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Log File Viewer Sheet

private struct LogFileViewerSheet: View {
    let entry: PVLogSessionViewModel.SessionLogEntry
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var isLoading = true
#if !os(tvOS)
    @State private var shareItems: [Any] = []
    @State private var showingShare = false
#endif

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                if isLoading {
                    ProgressView().tint(RetroTheme.retroPink)
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
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(RetroTheme.retroPink)
                }
#if !os(tvOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        shareItems = [entry.url]
                        showingShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(RetroTheme.retroBlue)
                }
#endif
            }
#if !os(tvOS)
            .sheet(isPresented: $showingShare) {
                if !shareItems.isEmpty {
                    ActivityShareSheet(activityItems: shareItems).ignoresSafeArea()
                }
            }
#endif
        }
        .task { await loadContent() }
    }

    private func loadContent() async {
        let url = entry.url
        content = await Task.detached(priority: .userInitiated) {
            (try? String(contentsOf: url, encoding: .utf8)) ?? "Unable to read file."
        }.value
        isLoading = false
    }
}

// MARK: - Share Sheet Wrapper

#if !os(tvOS)
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        PVLogSessionBrowserView()
    }
    .preferredColorScheme(.dark)
}
#endif
