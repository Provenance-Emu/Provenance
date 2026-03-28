//
//  NormalizeTitlePreviewSheet.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(SwiftUI)
import SwiftUI

/// A single row in the preview list.
struct NormalizeTitlePreviewRow: Identifiable {
    let id: String       // md5Hash — used as stable identity
    let currentTitle: String
    let proposedTitle: String
    var willChange: Bool { currentTitle != proposedTitle }
}

/// Sheet that shows a before/after preview of ROM title normalization
/// for a selected batch of games, then applies changes on confirmation.
struct NormalizeTitlePreviewSheet: View {

    // MARK: - Init

    /// Pre-computed rows. Caller builds these from `GameCellModel` array.
    let rows: [NormalizeTitlePreviewRow]
    /// Called on confirmation; implementation writes to Realm.
    let onConfirm: ([NormalizeTitlePreviewRow]) -> Void
    let onCancel: () -> Void

    // MARK: - State

    @State private var isApplying = false

    private var changingRows: [NormalizeTitlePreviewRow] { rows.filter { $0.willChange } }
    private var unchangedRows: [NormalizeTitlePreviewRow] { rows.filter { !$0.willChange } }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if changingRows.isEmpty {
                    Section {
                        Label(
                            "All selected titles are already normalized.",
                            systemImage: "checkmark.seal.fill"
                        )
                        .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        ForEach(changingRows) { row in
                            changeRow(row)
                        }
                    } header: {
                        Text("Will Be Renamed (\(changingRows.count))")
                    }
                }

                if !unchangedRows.isEmpty {
                    Section {
                        ForEach(unchangedRows) { row in
                            Label(row.currentTitle, systemImage: "checkmark.circle")
                                .foregroundColor(.secondary)
                                .font(.footnote)
                        }
                    } header: {
                        Text("Already Normalized (\(unchangedRows.count))")
                    }
                }
            }
            .navigationTitle("Normalize Titles")
            #if !os(tvOS)
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .disabled(isApplying)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isApplying {
                        ProgressView()
                    } else {
                        Button("Apply") {
                            guard !changingRows.isEmpty else { onCancel(); return }
                            isApplying = true
                            onConfirm(changingRows)
                        }
                        .disabled(changingRows.isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        #if !os(tvOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isApplying)
        #endif
    }

    // MARK: - Private

    @ViewBuilder
    private func changeRow(_ row: NormalizeTitlePreviewRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.proposedTitle)
                .font(.body)
                .foregroundColor(.primary)
            Text(row.currentTitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .strikethrough(true, color: .secondary)
        }
        .padding(.vertical, 2)
    }
}
#endif
