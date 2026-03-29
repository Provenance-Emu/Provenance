/// DiscRipperView.swift
/// PVUI
///
/// SwiftUI view for ripping a physical disc from a USB optical drive.
///
/// Shows:
///   - Drive status badge (No Drive / No Disc / Disc Ready)
///   - Disc info card (system type, track count, total size)
///   - "Rip Disc" primary action → presents RipperProgressSheet
///   - Recent rips list
///
/// On tvOS the view is hidden with an unavailability banner (USB optical drives
/// are not practically connectable to Apple TV).
///
/// Requires: PVOpticalDiscReader

import SwiftUI
import PVOpticalDiscReader

// MARK: - Main View

public struct DiscRipperView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RipperViewModel

    public init(client: OpticalDiscClient) {
        _viewModel = State(wrappedValue: RipperViewModel(client: client))
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
                            .disabled(viewModel.isRipping)
                    }
                }
        }
        .sheet(isPresented: $viewModel.showRipperSheet) {
            RipperProgressSheet(viewModel: viewModel)
        }
        .task { await viewModel.connect() }
    }

    // MARK: - Top-level content

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        unavailableView
        #else
        mainContent
        #endif
    }

    #if os(tvOS)
    private var unavailableView: some View {
        ContentUnavailableView(
            String(localized: "disc_ripper.unavailable.title"),
            systemImage: "opticaldisc",
            description: Text("disc_ripper.unavailable.description")
        )
    }
    #else

    // MARK: - Main Content (non-tvOS)

    @ViewBuilder
    private var mainContent: some View {
        List {
            driveStatusSection
            if viewModel.isLoadingTOC {
                loadingSection
            } else if let error = viewModel.tocError {
                errorSection(message: error)
            } else if let toc = viewModel.toc {
                discInfoSection(toc: toc)
                trackSelectionSection(toc: toc)
            }
            if !viewModel.recentRips.isEmpty {
                recentRipsSection
            }
        }
        .safeAreaInset(edge: .bottom) {
            ripDiscButton
                .padding()
                .background(.regularMaterial)
        }
    }

    // MARK: - Drive Status Section

    private var driveStatusSection: some View {
        Section {
            HStack {
                Image(systemName: driveStatusIcon)
                    .font(.title2)
                    .foregroundStyle(driveStatusColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(driveStatusTitle)
                        .font(.headline)
                    Text(driveStatusSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                driveStatusBadge
            }
            .padding(.vertical, 4)
        } header: {
            Text("disc_ripper.drive_status_header")
        }
    }

    private var driveStatusIcon: String {
        switch viewModel.driveStatus {
        case .unknown:      return "opticaldisc"
        case .noDisc:       return "opticaldisc"
        case .trayOpen:     return "tray.2"
        case .discPresent:  return "opticaldisc.fill"
        case .reading:      return "opticaldisc.fill"
        }
    }

    private var driveStatusColor: Color {
        switch viewModel.driveStatus {
        case .unknown:      return .gray
        case .noDisc:       return .orange
        case .trayOpen:     return .yellow
        case .discPresent:  return .green
        case .reading:      return .blue
        }
    }

    private var driveStatusTitle: String {
        switch viewModel.driveStatus {
        case .unknown:      return String(localized: "disc_ripper.status.no_drive")
        case .noDisc:       return String(localized: "disc_ripper.status.no_disc")
        case .trayOpen:     return String(localized: "disc_ripper.status.tray_open")
        case .discPresent:  return String(localized: "disc_ripper.status.disc_ready")
        case .reading:      return String(localized: "disc_ripper.status.reading")
        }
    }

    private var driveStatusSubtitle: String {
        switch viewModel.driveStatus {
        case .unknown:      return String(localized: "disc_ripper.status.no_drive.subtitle")
        case .noDisc:       return String(localized: "disc_ripper.status.no_disc.subtitle")
        case .trayOpen:     return String(localized: "disc_ripper.status.tray_open.subtitle")
        case .discPresent:  return String(localized: "disc_ripper.status.disc_ready.subtitle")
        case .reading:      return String(localized: "disc_ripper.status.reading.subtitle")
        }
    }

    @ViewBuilder
    private var driveStatusBadge: some View {
        Text(driveStatusBadgeLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(driveStatusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(driveStatusColor)
    }

    private var driveStatusBadgeLabel: String {
        switch viewModel.driveStatus {
        case .unknown:      return String(localized: "disc_ripper.badge.no_drive")
        case .noDisc:       return String(localized: "disc_ripper.badge.no_disc")
        case .trayOpen:     return String(localized: "disc_ripper.badge.tray_open")
        case .discPresent:  return String(localized: "disc_ripper.badge.ready")
        case .reading:      return String(localized: "disc_ripper.badge.reading")
        }
    }

    // MARK: - Loading / Error Sections

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                Text("disc_ripper.loading_toc")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func errorSection(message: String) -> some View {
        Section {
            Label {
                VStack(alignment: .leading) {
                    Text("disc_ripper.error.title")
                        .fontWeight(.semibold)
                    Text(verbatim: message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            Button("disc_ripper.retry") {
                Task { await viewModel.loadTOC() }
            }
        }
    }

    // MARK: - Disc Info Section

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
                String(localized: "disc_ripper.total_size"),
                value: discTotalSizeString(toc: toc)
            )
            LabeledContent(
                String(localized: "disc_ripper.total_sectors"),
                value: toc.totalSectors.formatted()
            )
        } header: {
            Text("disc_ripper.disc_info_header")
        }
    }

    private func discTotalSizeString(toc: DiscTOC) -> String {
        let totalBytes = toc.tracks.reduce(0) { $0 + $1.sizeBytes }
        let mb = Double(totalBytes) / 1_048_576
        return mb >= 1024
            ? String(format: "%.2f GB", mb / 1024)
            : String(format: "%.1f MB", mb)
    }

    // MARK: - Track Selection Section

    @ViewBuilder
    private func trackSelectionSection(toc: DiscTOC) -> some View {
        Section {
            ForEach(toc.tracks) { track in
                TrackRowView(
                    track: track,
                    isSelected: viewModel.selectedTracks.contains(track.trackNumber),
                    onToggle: { viewModel.toggleTrack(track.trackNumber) }
                )
                .disabled(viewModel.isRipping)
            }
        } header: {
            HStack {
                Text("disc_ripper.tracks_header")
                Spacer()
                Button(viewModel.allTracksSelected
                       ? String(localized: "disc_ripper.deselect_all")
                       : String(localized: "disc_ripper.select_all")) {
                    viewModel.toggleAllTracks()
                }
                .font(.caption)
                .disabled(viewModel.isRipping)
            }
        } footer: {
            Text("disc_ripper.tracks_footer")
        }
    }

    // MARK: - Recent Rips Section

    private var recentRipsSection: some View {
        Section {
            ForEach(viewModel.recentRips) { rip in
                RecentRipRowView(rip: rip)
            }
        } header: {
            Text("disc_ripper.recent_rips_header")
        }
    }

    // MARK: - Rip Disc Button

    private var ripDiscButton: some View {
        Button {
            viewModel.startRip()
        } label: {
            Label(
                String(localized: "disc_ripper.rip_button"),
                systemImage: "opticaldiscdrive.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.selectedTracks.isEmpty || viewModel.toc == nil || viewModel.isRipping)
    }

    #endif // !os(tvOS)
}

// MARK: - Track Row

#if !os(tvOS)
private struct TrackRowView: View {
    let track: DiscTrackInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)

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
                        Label(
                            track.isAudio
                                ? String(localized: "disc_ripper.track_type.audio")
                                : String(localized: "disc_ripper.track_type.data"),
                            systemImage: track.isAudio ? "music.note" : "doc.fill"
                        )
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
        let typeLabel = track.isAudio
            ? String(localized: "disc_ripper.track_type.audio")
            : String(localized: "disc_ripper.track_type.data")
        return "Track \(track.trackNumber) (\(typeLabel))"
    }

    private var sizeString: String {
        let mb = Double(track.sizeBytes) / 1_048_576
        return mb >= 1 ? String(format: "%.1f MB", mb) : "\(track.sectorCount) sectors"
    }
}

// MARK: - Recent Rip Row

private struct RecentRipRowView: View {
    let rip: RippedDisc

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rip.isSuccess ? "opticaldisc.fill" : "exclamationmark.circle")
                .foregroundStyle(rip.isSuccess ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: rip.discType.rawValue)
                    .font(.body)
                HStack(spacing: 8) {
                    Text(verbatim: "\(rip.trackCount) track\(rip.trackCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: rip.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if case .failed(let reason) = rip.status {
                    Text(verbatim: reason)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            if rip.isSuccess {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
#endif // !os(tvOS)

// MARK: - Previews

#if DEBUG
#Preview("Disc Ready") {
    let client = OpticalDiscClient()
    DiscRipperView(client: client)
}
#endif
