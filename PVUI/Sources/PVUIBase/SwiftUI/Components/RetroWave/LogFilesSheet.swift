//
//  LogFilesSheet.swift
//  PVUI
//
//  Lists the date-stamped session log files `PVLogFileManager` writes, from the
//  log viewer. Each file can be viewed in the viewer, shared (iOS) or deleted;
//  the file currently being written can only be viewed (#3612).
//

import SwiftUI
import PVLogging

/// Sheet listing session log files with view, share and delete actions.
public struct LogFilesSheet: View {
    // MARK: - Properties

    @ObservedObject var viewModel: RetroLogViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var files: [LogExportFile] = []
    @State private var isFileLoggingActive = false
    @State private var pendingDelete: LogExportFile?
    @State private var errorMessage: String?
    #if os(tvOS)
    /// Row whose actions are being chosen; tvOS rows have no inline buttons.
    @State private var actionTarget: LogExportFile?
    #endif

    public init(viewModel: RetroLogViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    statusRow
                    Divider().background(RetroTheme.retroPink.opacity(0.3))
                    if files.isEmpty {
                        emptyState
                    } else {
                        fileList
                    }
                }
            }
            .navigationTitle("Log Files")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RetroTheme.retroPink)
                }
            }
        }
        .onAppear { refresh() }
        #if os(tvOS)
        .onExitCommand { dismiss() }
        .confirmationDialog(
            actionTarget?.name ?? "",
            isPresented: Binding(get: { actionTarget != nil }, set: { if !$0 { actionTarget = nil } }),
            titleVisibility: .visible,
            presenting: actionTarget
        ) { file in
            Button("View") { view(file) }
            if !viewModel.isActiveSessionFile(file.url) {
                Button("Delete", role: .destructive) { pendingDelete = file }
            }
            Button("Cancel", role: .cancel) {}
        }
        #endif
        .alert(
            "Delete Log File?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { file in
            Button("Delete", role: .destructive) { delete(file) }
            Button("Cancel", role: .cancel) {}
        } message: { file in
            Text("\(file.name) will be permanently deleted.")
        }
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    /// Whether file logging is running, with a start/stop control.
    private var statusRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isFileLoggingActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .shadow(color: isFileLoggingActive ? .green : .clear, radius: 4)

            Text(isFileLoggingActive ? "Writing logs to disk" : "File logging off")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Button {
                if isFileLoggingActive {
                    PVLogFileManager.shared.stopLogging()
                } else {
                    PVLogFileManager.shared.startLogging()
                }
                refresh()
            } label: {
                Text(isFileLoggingActive ? "Stop" : "Start")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isFileLoggingActive ? RetroTheme.retroPink : RetroTheme.retroBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isFileLoggingActive ? RetroTheme.retroPink : RetroTheme.retroBlue, lineWidth: 1)
                    )
            }
            .retroFocusButtonStyle(cornerRadius: 4, showBorder: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    @ViewBuilder
    private var fileList: some View {
        #if os(tvOS)
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(files) { file in
                    Button { actionTarget = file } label: {
                        fileRow(file)
                    }
                    .retroFocusButtonStyle(focusScale: 1.02, cornerRadius: 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .focusSection()
        #else
        List {
            ForEach(files) { file in
                fileRow(file)
                    .listRowBackground(Color.black.opacity(0.01))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !viewModel.isActiveSessionFile(file.url) {
                            Button(role: .destructive) { pendingDelete = file } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .listStyle(.plain)
        #endif
    }

    private func fileRow(_ file: LogExportFile) -> some View {
        let isActive = viewModel.isActiveSessionFile(file.url)
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if isActive {
                        Image(systemName: "record.circle")
                            .foregroundColor(.green)
                            .font(.system(size: 10))
                    }
                    Text(file.name)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(isActive ? Color.green : .white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                    Text(file.modificationDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            #if os(tvOS)
            // The whole row is the button on tvOS; a nested button would take focus away from it.
            Image(systemName: "chevron.right")
                .foregroundColor(RetroTheme.retroPink)
                .font(.system(size: 14))
            #else
            HStack(spacing: 14) {
                Button { view(file) } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(RetroTheme.retroPink)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(file.name)")

                ShareLink(item: file.url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(RetroTheme.retroBlue)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

                Button { pendingDelete = file } label: {
                    Image(systemName: "trash")
                        .foregroundColor(isActive ? .gray : RetroTheme.retroPink.opacity(0.7))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .disabled(isActive)
                .accessibilityLabel(isActive ? "Active log file can't be deleted" : "Delete \(file.name)")
            }
            #endif
        }
        .padding(.vertical, 8)
        #if os(tvOS)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: isFileLoggingActive ? "doc.text.below.ecg" : "doc.text")
                .font(.system(size: 48))
                .foregroundColor(RetroTheme.retroBlue.opacity(0.5))
            Text("No Log Files")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(isFileLoggingActive
                 ? "Files appear here as they are written."
                 : "Start file logging to keep logs between launches.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Actions

    private func refresh() {
        isFileLoggingActive = PVLogFileManager.shared.isLogging
        files = viewModel.sessionLogFiles()
    }

    /// Loads `file` into the viewer in place of the live logs and closes this sheet.
    private func view(_ file: LogExportFile) {
        Task { @MainActor in
            do {
                try await viewModel.importLog(from: file.url)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ file: LogExportFile) {
        do {
            try viewModel.deleteSessionLogFile(at: file.url)
            files.removeAll { $0.id == file.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LogFilesSheet(viewModel: RetroLogViewModel())
        .preferredColorScheme(.dark)
}
#endif
