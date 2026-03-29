/// DiscRipperView.swift
/// PVUI
///
/// SwiftUI view for ripping a disc from a USB optical drive.
/// Shows the disc's track list, lets the user start a rip, and displays progress.
///
/// This view depends on PVOpticalDiscReader for disc metadata.
/// On tvOS / iPhone it shows an unavailability message.
///
/// Intended to be presented as a sheet when an optical drive with a disc is detected.

import SwiftUI
import PVOpticalDiscReader

// MARK: - Main View

public struct DiscRipperView: View {

    @Environment(\.dismiss) private var dismiss

    let client: OpticalDiscClient

    @State private var toc: DiscTOC?
    @State private var isLoadingTOC = false
    @State private var tocError: String?
    @State private var isRipping = false
    @State private var ripError: String?
    @State private var showConfirmRip = false
    @State private var selectedTracks: Set<Int> = []

    public init(client: OpticalDiscClient) {
        self.client = client
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "disc_ripper.nav_title"))
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "disc_ripper.cancel")) { dismiss() }
                            .disabled(isRipping)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ripButton
                    }
                }
        }
        .task { await loadTOC() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        unavailableView
        #else
        if isLoadingTOC {
            loadingView
        } else if let error = tocError {
            errorView(message: error)
        } else if let toc {
            trackListView(toc: toc)
        } else {
            loadingView
        }
        #endif
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("disc_ripper.loading_toc")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            String(localized: "disc_ripper.error.title"),
            systemImage: "exclamationmark.circle",
            description: Text(verbatim: message)
        )
    }

    #if os(tvOS)
    private var unavailableView: some View {
        ContentUnavailableView(
            String(localized: "disc_ripper.unavailable.title"),
            systemImage: "opticaldisc",
            description: Text("disc_ripper.unavailable.description")
        )
    }
    #endif

    @ViewBuilder
    private func trackListView(toc: DiscTOC) -> some View {
        List {
            discInfoSection(toc: toc)
            trackSelectionSection(toc: toc)
            if isRipping, let progress = client.ripProgress {
                ripProgressSection(progress: progress)
            }
            if let ripError {
                Section {
                    Label(ripError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func discInfoSection(toc: DiscTOC) -> some View {
        Section {
            LabeledContent(
                String(localized: "disc_ripper.disc_type"),
                value: toc.discType.rawValue
            )
            LabeledContent(
                String(localized: "disc_ripper.total_tracks"),
                value: "\(toc.trackCount)"
            )
            LabeledContent(
                String(localized: "disc_ripper.total_sectors"),
                value: "\(toc.totalSectors)"
            )
        } header: {
            Text("disc_ripper.disc_info_header")
        }
    }

    @ViewBuilder
    private func trackSelectionSection(toc: DiscTOC) -> some View {
        Section {
            ForEach(toc.tracks) { track in
                TrackRowView(
                    track: track,
                    isSelected: selectedTracks.contains(track.trackNumber),
                    onToggle: { toggleTrack(track.trackNumber) }
                )
                .disabled(isRipping)
            }
        } header: {
            HStack {
                Text("disc_ripper.tracks_header")
                Spacer()
                Button(allTracksSelected ? "disc_ripper.deselect_all" : "disc_ripper.select_all") {
                    toggleAllTracks(toc: toc)
                }
                .font(.caption)
                .disabled(isRipping)
            }
        } footer: {
            Text("disc_ripper.tracks_footer")
        }
    }

    @ViewBuilder
    private func ripProgressSection(progress: RipProgress) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "disc_ripper.ripping_track",
                                defaultValue: "Track \(progress.currentTrack) of \(progress.totalTracks)"))
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f%%", progress.fraction * 100))
                        .font(.subheadline)
                        .monospacedDigit()
                }
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
            }
            .padding(.vertical, 4)
        } header: {
            Text("disc_ripper.progress_header")
        }
    }

    // MARK: - Toolbar Button

    @ViewBuilder
    private var ripButton: some View {
        if isRipping {
            ProgressView()
                .controlSize(.small)
        } else {
            Button(String(localized: "disc_ripper.rip_button")) {
                showConfirmRip = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTracks.isEmpty || toc == nil)
            .confirmationDialog(
                String(localized: "disc_ripper.confirm_title"),
                isPresented: $showConfirmRip,
                titleVisibility: .visible
            ) {
                Button(String(localized: "disc_ripper.confirm_rip")) { startRip() }
                Button(String(localized: "disc_ripper.cancel"), role: .cancel) {}
            } message: {
                Text("disc_ripper.confirm_message")
            }
        }
    }

    // MARK: - Actions

    private func loadTOC() async {
        isLoadingTOC = true
        tocError = nil
        do {
            let fetched = try await client.readTOC()
            toc = fetched
            // Pre-select all tracks
            selectedTracks = Set(fetched.tracks.map(\.trackNumber))
        } catch {
            tocError = error.localizedDescription
        }
        isLoadingTOC = false
    }

    private func startRip() {
        guard let _ = toc else { return }
        isRipping = true
        ripError = nil
        Task {
            do {
                let destDir = FileManager.default.temporaryDirectory
                    .appending(path: "DiscRips", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                _ = try await client.ripDisc(to: destDir, trackSelection: selectedTracks)
                // TODO(Phase 2): Import ripped image to PVLibrary game library
                await MainActor.run {
                    isRipping = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isRipping = false
                    ripError = error.localizedDescription
                }
            }
        }
    }

    private func toggleTrack(_ number: Int) {
        if selectedTracks.contains(number) {
            selectedTracks.remove(number)
        } else {
            selectedTracks.insert(number)
        }
    }

    private func toggleAllTracks(toc: DiscTOC) {
        if allTracksSelected {
            selectedTracks.removeAll()
        } else {
            selectedTracks = Set(toc.tracks.map(\.trackNumber))
        }
    }

    private var allTracksSelected: Bool {
        guard let toc else { return false }
        return selectedTracks.count == toc.trackCount
    }
}

// MARK: - Track Row

private struct TrackRowView: View {
    let track: DiscTrackInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .accentColor : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(verbatim: trackTitle)
                            .font(.body)
                        Spacer()
                        Text(verbatim: sizeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack(spacing: 8) {
                        Label(track.isAudio ? "Audio" : "Data", systemImage: track.isAudio ? "music.note" : "doc.fill")
                            .font(.caption2)
                            .foregroundStyle(track.isAudio ? .purple : .blue)
                        Text(verbatim: "LBA \(track.startLBA)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var trackTitle: String {
        track.isAudio
            ? "Track \(track.trackNumber) (Audio)"
            : "Track \(track.trackNumber) (Data)"
    }

    private var sizeString: String {
        let mb = Double(track.sizeBytes) / 1_048_576
        return mb >= 1 ? String(format: "%.1f MB", mb) : "\(track.sectorCount) sectors"
    }
}

#Preview {
    DiscRipperView(client: OpticalDiscClient())
}
