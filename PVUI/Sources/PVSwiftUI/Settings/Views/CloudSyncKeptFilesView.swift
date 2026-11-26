//
//  CloudSyncKeptFilesView.swift
//  PVUI
//

import SwiftUI
import PVLibrary
import PVLogging

/// Local files that an iCloud download replaced, kept for 30 days by `CloudSyncSafetyNet`.
/// Each can be put back or removed for good.
struct CloudSyncKeptFilesView: View {
    @State private var files: [CloudSyncSafetyNet.ReplacedFile] = []
    @State private var hasLoaded = false
    @State private var pendingDelete: CloudSyncSafetyNet.ReplacedFile?
    @State private var failureMessage: String?

    var body: some View {
        List {
            if files.isEmpty {
                Section {
                    Text(hasLoaded
                         ? "Nothing here. When an iCloud download replaces one of your files, your copy is kept here for 30 days."
                         : "Loading…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(files) { file in
                        row(for: file)
                    }
                } footer: {
                    Text("Restore puts your copy back and keeps the one it replaces here. The restored file syncs to your other devices.")
                }
            }
        }
        .navigationTitle("Replaced Files")
        .task { await reload() }
        .confirmationDialog(
            "Delete this copy for good?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let file = pendingDelete {
                    perform("delete", file) { try await CloudSyncSafetyNet.delete($0) }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .alert(
            "That did not work",
            isPresented: Binding(
                get: { failureMessage != nil },
                set: { if !$0 { failureMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { failureMessage = nil }
        } message: {
            Text(failureMessage ?? "")
        }
    }

    private func row(for file: CloudSyncSafetyNet.ReplacedFile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file.relativePath)
                .font(.footnote)
                .lineLimit(2)
                .truncationMode(.head)
            HStack(spacing: 12) {
                Text(file.replacedAt.formatted(date: .abbreviated, time: .shortened))
                Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                Spacer()
                Button("Restore") {
                    perform("restore", file) { try await CloudSyncSafetyNet.restore($0) }
                }
                Button("Delete", role: .destructive) {
                    pendingDelete = file
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            #if !os(tvOS)
            .buttonStyle(.borderless)
            #endif
        }
    }

    private func reload() async {
        files = await CloudSyncSafetyNet.replacedFiles()
        hasLoaded = true
    }

    private func perform(
        _ name: String,
        _ file: CloudSyncSafetyNet.ReplacedFile,
        _ action: @escaping (CloudSyncSafetyNet.ReplacedFile) async throws -> Void
    ) {
        Task {
            do {
                try await action(file)
            } catch {
                ELOG("Could not \(name) kept file \(file.relativePath): \(error.localizedDescription)")
                failureMessage = error.localizedDescription
            }
            await reload()
        }
    }
}
