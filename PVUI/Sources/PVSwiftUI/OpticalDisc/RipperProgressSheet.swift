/// RipperProgressSheet.swift
/// PVUI
///
/// Modal sheet shown while a disc rip is in progress.
/// Displays a circular progress ring, sector/track counters, speed, ETA,
/// and a cancel button with confirmation.
///
/// On tvOS this sheet is never presented (see DiscRipperView's tvOS guard).

import SwiftUI
import PVOpticalDiscReader

// MARK: - Sheet

public struct RipperProgressSheet: View {

    @Bindable var viewModel: RipperViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: RipperViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                progressRing
                statsGrid
                Spacer()
                cancelButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .navigationTitle(String(localized: "ripper_sheet.title"))
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .interactiveDismissDisabled(true)
        }
        .confirmationDialog(
            String(localized: "ripper_sheet.cancel_confirm.title"),
            isPresented: $viewModel.showCancelRipConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "ripper_sheet.cancel_confirm.stop"), role: .destructive) {
                viewModel.cancelRip()
            }
            Button(String(localized: "ripper_sheet.cancel_confirm.continue"), role: .cancel) {
                viewModel.showCancelRipConfirmation = false
            }
        } message: {
            Text("ripper_sheet.cancel_confirm.message")
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 14)

            // Filled arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .purple, .blue],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: fraction)

            VStack(spacing: 4) {
                Text(verbatim: percentageText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let progress = viewModel.currentProgress {
                    Text(verbatim: "\(progress.currentTrack) / \(progress.totalTracks)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 200, height: 200)
        .padding(.top, 8)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            if let progress = viewModel.currentProgress {
                StatCell(
                    title: String(localized: "ripper_sheet.stat.sectors"),
                    value: "\(progress.currentSector.formatted()) / \(progress.totalSectors.formatted())",
                    icon: "opticaldiscdrive"
                )
                StatCell(
                    title: String(localized: "ripper_sheet.stat.tracks"),
                    value: "\(progress.currentTrack) / \(progress.totalTracks)",
                    icon: "music.note.list"
                )
            } else {
                StatCell(
                    title: String(localized: "ripper_sheet.stat.sectors"),
                    value: "—",
                    icon: "opticaldiscdrive"
                )
                StatCell(
                    title: String(localized: "ripper_sheet.stat.tracks"),
                    value: "—",
                    icon: "music.note.list"
                )
            }
            StatCell(
                title: String(localized: "ripper_sheet.stat.speed"),
                value: speedText,
                icon: "gauge.with.dots.needle.33percent"
            )
            StatCell(
                title: String(localized: "ripper_sheet.stat.eta"),
                value: etaText,
                icon: "clock"
            )
        }
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button(role: .destructive) {
            viewModel.showCancelRipConfirmation = true
        } label: {
            Label(
                String(localized: "ripper_sheet.cancel_rip"),
                systemImage: "stop.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .padding(.bottom, 8)
    }

    // MARK: - Computed Strings

    private var fraction: Double {
        viewModel.currentProgress?.fraction ?? 0
    }

    private var percentageText: String {
        String(format: "%.0f%%", fraction * 100)
    }

    private var speedText: String {
        let s = viewModel.ripSpeedMBps
        if s < 0.1 { return "—" }
        return String(format: "%.1f MB/s", s)
    }

    private var etaText: String {
        guard let eta = viewModel.etaSeconds else { return "—" }
        if eta < 60 {
            return String(format: "%.0fs", eta)
        } else if eta < 3600 {
            return String(format: "%dm %02ds", Int(eta) / 60, Int(eta) % 60)
        } else {
            return String(format: "%dh %dm", Int(eta) / 3600, (Int(eta) % 3600) / 60)
        }
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let client = OpticalDiscClient()
    let vm = RipperViewModel(client: client)
    vm.isRipping = true
    vm.currentProgress = RipProgress(
        currentSector: 45_000,
        totalSectors: 300_000,
        currentTrack: 2,
        totalTracks: 9
    )
    vm.ripSpeedMBps = 3.4
    vm.etaSeconds = 182
    return RipperProgressSheet(viewModel: vm)
}
#endif
