//
//  ROMTitleNormalizationView.swift
//  PVUI
//
//  Displays a preview of which game titles would be cleaned up by the ROM
//  title normalization service and allows bulk or selective application.
//

import SwiftUI
import PVLibrary
import PVPrimitives
import PVLogging

// MARK: - Main View

public struct ROMTitleNormalizationView: View {

    // MARK: State

    @State private var isLoading = false
    @State private var isApplying = false
    @State private var proposals: [ROMTitleRenameProposal] = []
    @State private var selected: Set<String> = []   // ids of proposals to apply
    @State private var resultMessage: String?
    @State private var resultIsError = false
    @State private var showResult = false

    private let service = ROMTitleNormalizationService()

    // MARK: Body

    public var body: some View {
        List {
            if !isLoading && !proposals.isEmpty {
                selectionHeader
            }

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Scanning library...")
                        Spacer()
                    }
                    .padding()
                }
            } else if proposals.isEmpty {
                Section {
                    Text("All game titles are already clean — no changes needed.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            } else {
                proposalsList
            }
        }
        .navigationTitle("Normalize ROM Titles")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
#endif
        .task { await load() }
        .alert(resultIsError ? "Error" : "Done", isPresented: $showResult, actions: {
            Button("OK") {}
        }, message: {
            Text(resultMessage ?? "")
        })
    }

    // MARK: Subviews

    private var selectionHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(proposals.count) title(s) can be cleaned up.")
                    .font(.subheadline)
                Text("Select which renames to apply, then tap Apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button("Select All") {
                    selected = Set(proposals.map(\.id))
                }
                .buttonStyle(.bordered)

                Button("Select None") {
                    selected = []
                }
                .buttonStyle(.bordered)

                Spacer()

                if isApplying {
                    ProgressView()
                } else {
                    Button("Apply (\(selected.count))") {
                        Task { await applySelected() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var proposalsList: some View {
        Section(header: Text("Proposed Renames")) {
            ForEach(proposals) { proposal in
                ProposalRow(
                    proposal: proposal,
                    isSelected: selected.contains(proposal.id)
                ) {
                    if selected.contains(proposal.id) {
                        selected.remove(proposal.id)
                    } else {
                        selected.insert(proposal.id)
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if isApplying {
                ProgressView()
            } else {
                Button("Apply All") {
                    Task { await applyAll() }
                }
                .disabled(proposals.isEmpty || isApplying)
            }
        }
    }

    // MARK: Actions

    @MainActor
    private func load() async {
        isLoading = true
        proposals = await service.buildProposals()
        selected = Set(proposals.map(\.id))  // default: all selected
        isLoading = false
    }

    @MainActor
    private func applySelected() async {
        let toApply = proposals.filter { selected.contains($0.id) }
        await apply(toApply)
    }

    @MainActor
    private func applyAll() async {
        await apply(proposals)
    }

    @MainActor
    private func apply(_ toApply: [ROMTitleRenameProposal]) async {
        guard !toApply.isEmpty else { return }
        isApplying = true
        let appliedIDs = Set(toApply.map(\.id))
        do {
            try await service.applyProposals(toApply)
            resultIsError = false
            resultMessage = "Applied \(toApply.count) title rename(s) successfully."
            proposals.removeAll { appliedIDs.contains($0.id) }
            selected.subtract(appliedIDs)
        } catch {
            ELOG("ROMTitleNormalizationView: apply failed: \(error)")
            resultIsError = true
            resultMessage = "Failed to apply renames: \(error.localizedDescription)"
        }
        showResult = true
        isApplying = false
    }
}

// MARK: - Proposal Row

private struct ProposalRow: View {
    let proposal: ROMTitleRenameProposal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .accentColor : .secondary)
                    .font(.title3)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(proposal.currentTitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .strikethrough()

                    Label {
                        Text(proposal.proposedTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationView {
        ROMTitleNormalizationView()
    }
}
#endif
