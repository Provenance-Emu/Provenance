//
//  ExternalEmulatorMigrationView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/28/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Guides users through importing saves from Delta, RetroArch, Manic EMU,
//  Consoles, PPSSPP, and Gamma into Provenance.
//

import SwiftUI
import PVLibrary
import PVUIBase
import PVFeatureFlags

// MARK: - KnownEmulator UI extensions

/// UI-layer properties for the migration guide.
/// These belong in PVUI, not in PVLibrary, to keep PVLibrary free of SwiftUI/UIKit display concerns.
private extension KnownEmulator {
    /// SF Symbol name that best represents this emulator's primary platform(s).
    var symbolName: String {
        switch self {
        case .delta, .deltaLite: return "gamecontroller.fill"
        case .manicEmu:          return "bolt.fill"
        case .consoles:          return "tv.and.hifispeaker.fill"
        case .retroArch:         return "cpu.fill"
        case .ppsspp:            return "memorychip"
        case .gamma:             return "squareshape.dotted.squareshape"
        }
    }

    /// Short description of which systems/games this emulator handles.
    var systemSummary: String {
        switch self {
        case .delta, .deltaLite: return "NES, SNES, N64, GBA, GBC, DS"
        case .manicEmu:          return "GBA, NES, SNES, Genesis, N64, and more"
        case .consoles:          return "Multi-system iOS/tvOS emulator"
        case .retroArch:         return "60+ systems"
        case .ppsspp:            return "PlayStation Portable (PSP)"
        case .gamma:             return "Game Boy, Game Boy Color"
        }
    }

    /// Returns all emulators detected as installed on the current device.
    ///
    /// `deltaLite` is excluded because it shares the same URL scheme and guide
    /// steps as `delta`; only one "Delta" row should appear in the UI.
    @MainActor
    static var installedEmulators: [KnownEmulator] {
        KnownEmulator.allCases.filter { $0 != .deltaLite && $0.isInstalled }
    }
}

// MARK: - KnownEmulator + Identifiable (for sheet(item:))

extension KnownEmulator: @retroactive Identifiable {
    public var id: String { rawValue }
}

// MARK: - Root view

/// "Import from Another Emulator" entry in Settings → Library.
///
/// Shows a list of detected third-party emulators and a step-by-step
/// export guide for each one. Because iOS sandboxing prevents direct
/// file access, the flow is fully manual/instructional.
///
/// The Ecosystem Integration section (XeniOS, MeloNX, MeloCafe) is gated
/// behind the `thirdPartyEcosystemIntegration` feature flag and hidden by default.
public struct ExternalEmulatorMigrationView: View {
    @State private var installedEmulators: [KnownEmulator] = []
    @State private var selectedEmulator: KnownEmulator?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var featureFlags = PVFeatureFlagsManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if installedEmulators.isEmpty {
                        emptyStateSection
                    } else {
                        detectedSection
                    }

                    manualImportSection

                    #if !os(tvOS)
                    if featureFlags.thirdPartyEcosystemIntegration {
                        ecosystemSection
                    }
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(Text("migration.nav.title", bundle: .module))
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selectedEmulator) { emulator in
            NavigationStack {
                EmulatorMigrationGuideView(emulator: emulator)
            }
        }
        .task {
            await loadInstalledEmulators()
        }
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.retroBlue, .retroPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .retroBlue.opacity(0.4), radius: 8)

            Text("migration.header.title", bundle: .module)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.retroPink, .retroPurple, .retroBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            #if os(tvOS)
            Text("migration.header.subtitle.tvos", bundle: .module)
            #else
            Text("migration.header.subtitle.ios", bundle: .module)
            #endif
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.bottom, 8)
    }

    // MARK: Detected emulators

    private var detectedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: Text("migration.section.detected", bundle: .module), icon: "checkmark.circle.fill", color: .green)

            ForEach(installedEmulators) { emulator in
                EmulatorRowView(emulator: emulator) {
                    selectedEmulator = emulator
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            #if os(tvOS)
            sectionHeader(title: Text("migration.section.not_detected.tvos", bundle: .module), icon: "info.circle", color: .orange)
            #else
            sectionHeader(title: Text("migration.section.not_detected.ios", bundle: .module), icon: "magnifyingglass", color: .orange)
            #endif

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "app.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        #if os(tvOS)
                        Text("migration.empty.body.tvos", bundle: .module)
                        #else
                        Text("migration.empty.body.ios", bundle: .module)
                        #endif
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        #if os(tvOS)
                        Text("migration.empty.footer.tvos", bundle: .module)
                        #else
                        Text("migration.empty.footer.ios", bundle: .module)
                        #endif
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 20)
                )
                .frame(minHeight: 120)

            #if !os(tvOS)
            // iOS/macOS only — these emulators don't run on Apple TV
            VStack(alignment: .leading, spacing: 8) {
                Text("migration.empty.want_instructions", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Show one entry per distinct app (skip deltaLite — same steps as delta)
                ForEach(KnownEmulator.allCases.filter { $0 != .deltaLite }) { emulator in
                    Button {
                        selectedEmulator = emulator
                    } label: {
                        HStack {
                            Image(systemName: emulator.symbolName)
                                .frame(width: 24)
                                .foregroundStyle(.retroBlue)
                            Text(emulator.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            #endif
        }
    }

    // MARK: Manual import

    private var manualImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: Text("migration.section.manual", bundle: .module), icon: "folder.fill", color: .blue)

            NavigationLink(destination: ManualFileImportGuideView()) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        #if os(tvOS)
                        Image(systemName: "wifi")
                        #else
                        Image(systemName: "folder.badge.plus")
                        #endif
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        #if os(tvOS)
                        Text("migration.manual.title.tvos", bundle: .module)
                        #else
                        Text("migration.manual.title.ios", bundle: .module)
                        #endif
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        #if os(tvOS)
                        Text("migration.manual.subtitle.tvos", bundle: .module)
                        #else
                        Text("migration.manual.subtitle.ios", bundle: .module)
                        #endif
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Ecosystem section (feature-flagged, iOS only)

    #if !os(tvOS)
    private var ecosystemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: Text("migration.section.ecosystem", bundle: .module), icon: "link.circle.fill", color: .purple)

            NavigationLink(destination: EcosystemIntegrationView()) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.purple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ecosystem.nav.title", bundle: .module)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("ecosystem.header.subtitle", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    // MARK: Section header helper

    private func sectionHeader(title: Text, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline.weight(.semibold))
            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: Detection

    @MainActor
    private func loadInstalledEmulators() async {
        installedEmulators = KnownEmulator.installedEmulators
    }
}

// MARK: - Emulator row

private struct EmulatorRowView: View {
    let emulator: KnownEmulator
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.retroBlue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: emulator.symbolName)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.retroBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(emulator.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(emulator.systemSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.retroBlue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Per-emulator migration guide

/// Step-by-step export/import guide for a specific third-party emulator.
struct EmulatorMigrationGuideView: View {
    let emulator: KnownEmulator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: emulator.symbolName)
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.retroBlue, .retroPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(String(format: NSLocalizedString("migration.guide.export_from", bundle: .module, comment: ""), emulator.displayName))
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(emulator.systemSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)

                    // Steps
                    stepsSection

                    // Import into Provenance
                    provenanceImportSection

                    // Save format note
                    saveFormatNote
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(emulator.displayName)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("migration.guide.done", bundle: .module, comment: "")) { dismiss() }
            }
        }
        #endif
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
    }

    // MARK: Steps content

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: NSLocalizedString("migration.guide.export_step1_title", bundle: .module, comment: ""), emulator.displayName))
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(Array(exportSteps.enumerated()), id: \.offset) { index, step in
                StepRowView(number: index + 1, text: step)
            }
        }
    }

    private var provenanceImportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("migration.guide.import_step2_title", bundle: .module)
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(Array(importSteps.enumerated()), id: \.offset) { index, step in
                StepRowView(number: index + 1, text: step)
            }
        }
    }

    private var saveFormatNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.retroBlue)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("migration.save_formats.title", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(String(format: NSLocalizedString("migration.save_formats.battery", bundle: .module, comment: ""),
                            emulator.saveFileExtensions.map { ".\($0)" }.joined(separator: ", ")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !emulator.stateFileExtensions.isEmpty && emulator != .retroArch {
                    Text(String(format: NSLocalizedString("migration.save_formats.states", bundle: .module, comment: ""),
                                emulator.stateFileExtensions.map { ".\($0)" }.joined(separator: ", ")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if emulator == .retroArch {
                    Text("migration.save_formats.retroarch_note", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            }
        }
        .padding(14)
        .background(Color.retroBlue.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: Per-emulator steps

    private var exportSteps: [String] {
        switch emulator {
        case .delta, .deltaLite:
            return [
                NSLocalizedString("migration.delta.export.step1", bundle: .module, comment: "Open Delta and go to the game you want to export."),
                NSLocalizedString("migration.delta.export.step2", bundle: .module, comment: "Long-press the game thumbnail to reveal the context menu."),
                NSLocalizedString("migration.delta.export.step3", bundle: .module, comment: "Tap 'Save States' to see your saves."),
                NSLocalizedString("migration.delta.export.step4", bundle: .module, comment: "Tap the share icon (square with arrow) on the save you want."),
                NSLocalizedString("migration.delta.export.step5", bundle: .module, comment: "Use the share sheet to send the file to Files.app or AirDrop to your Mac."),
                NSLocalizedString("migration.delta.export.step6", bundle: .module, comment: "Repeat for each game you want to migrate.")
            ]
        case .manicEmu:
            return [
                NSLocalizedString("migration.manicemu.export.step1", bundle: .module, comment: "Open Manic EMU and navigate to your game library."),
                NSLocalizedString("migration.manicemu.export.step2", bundle: .module, comment: "Long-press a game to bring up options."),
                NSLocalizedString("migration.manicemu.export.step3", bundle: .module, comment: "Tap 'Export Save' or 'Share Save'."),
                NSLocalizedString("migration.manicemu.export.step4", bundle: .module, comment: "Save the .sav file to the Files app (iCloud Drive or local storage)."),
                NSLocalizedString("migration.manicemu.export.step5", bundle: .module, comment: "Repeat for each game.")
            ]
        case .consoles:
            return [
                NSLocalizedString("migration.consoles.export.step1", bundle: .module, comment: "Open Consoles and navigate to your game library."),
                NSLocalizedString("migration.consoles.export.step2", bundle: .module, comment: "Long-press a game to bring up options."),
                NSLocalizedString("migration.consoles.export.step3", bundle: .module, comment: "Tap 'Export Save' or 'Share Save'."),
                NSLocalizedString("migration.consoles.export.step4", bundle: .module, comment: "Save the .sav file to the Files app (iCloud Drive or local storage)."),
                NSLocalizedString("migration.consoles.export.step5", bundle: .module, comment: "Repeat for each game.")
            ]
        case .retroArch:
            return [
                NSLocalizedString("migration.retroarch.export.step1", bundle: .module, comment: "Open RetroArch and go to Main Menu → Load Content, then load your game."),
                NSLocalizedString("migration.retroarch.export.step2", bundle: .module, comment: "Open the Quick Menu (tap the screen or press the menu button)."),
                NSLocalizedString("migration.retroarch.export.step3", bundle: .module, comment: "Tap 'Save State' to ensure a state is saved, then return to Quick Menu."),
                NSLocalizedString("migration.retroarch.export.step4", bundle: .module, comment: "Go to Quick Menu → Close Content to return to the main menu."),
                NSLocalizedString("migration.retroarch.export.step5", bundle: .module, comment: "In the main menu, navigate to 'Load Content' path to find your saves folder."),
                NSLocalizedString("migration.retroarch.export.step6", bundle: .module, comment: "Use the RetroArch file browser or Files.app to locate the 'saves' folder inside the RetroArch app group."),
                NSLocalizedString("migration.retroarch.export.step7", bundle: .module, comment: "Copy the .srm (battery save) or .state files to a location accessible to Provenance.")
            ]
        case .ppsspp:
            return [
                NSLocalizedString("migration.ppsspp.export.step1", bundle: .module, comment: "Open PPSSPP and navigate to your UMD images."),
                NSLocalizedString("migration.ppsspp.export.step2", bundle: .module, comment: "Tap the game to open its settings page."),
                NSLocalizedString("migration.ppsspp.export.step3", bundle: .module, comment: "Look for 'Save State' or check PPSSPP's memstick/PSP/SAVEDATA folder."),
                NSLocalizedString("migration.ppsspp.export.step4", bundle: .module, comment: "Use Files.app to navigate to PPSSPP's folder and copy .ppst files."),
                NSLocalizedString("migration.ppsspp.export.step5", bundle: .module, comment: "Note: PSP save data (.VMP files) may need conversion — standard .ppst states import directly.")
            ]
        case .gamma:
            return [
                NSLocalizedString("migration.gamma.export.step1", bundle: .module, comment: "Open Gamma and go to your game library."),
                NSLocalizedString("migration.gamma.export.step2", bundle: .module, comment: "Long-press a game to see options."),
                NSLocalizedString("migration.gamma.export.step3", bundle: .module, comment: "Tap 'Share Save' to export the .sav file."),
                NSLocalizedString("migration.gamma.export.step4", bundle: .module, comment: "Save it to Files.app (iCloud Drive recommended for easy access)."),
                NSLocalizedString("migration.gamma.export.step5", bundle: .module, comment: "Repeat for each GB/GBC game.")
            ]
        }
    }

    private var importSteps: [String] {
        #if os(tvOS)
        let step1 = NSLocalizedString("migration.import.step1.tvos", bundle: .module,
                                      comment: "Open Provenance and launch the web server via Settings → Library → Web Server.")
        #else
        let step1 = NSLocalizedString("migration.import.step1.ios", bundle: .module,
                                      comment: "Open Provenance and launch the web server via Settings → Library → Web Server, or use Files.app.")
        #endif
        return [
            step1,
            NSLocalizedString("migration.import.step2", bundle: .module, comment: "Navigate to the ROM directory for the matching system (e.g. ROMs/GBA/)."),
            NSLocalizedString("migration.import.step3", bundle: .module, comment: "Place the save file in the same folder as the ROM, with the same filename (only the extension differs)."),
            NSLocalizedString("migration.import.step4", bundle: .module, comment: "For example: 'MyGame.gba' needs 'MyGame.srm' or 'MyGame.sav' alongside it."),
            NSLocalizedString("migration.import.step5", bundle: .module, comment: "Launch the game in Provenance — it will automatically detect and load the save."),
            NSLocalizedString("migration.import.step6", bundle: .module, comment: "If the save does not load, verify the filename matches the ROM exactly (case-sensitive on some systems).")
        ]
    }
}

// MARK: - Manual file import guide

/// Guide for users who want to import saves without a specific third-party app.
struct ManualFileImportGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("manual.header.title", bundle: .module)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("manual.header.subtitle", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    methodSection(
                        title: NSLocalizedString("manual.method.webserver.title", bundle: .module, comment: ""),
                        icon: "wifi",
                        steps: [
                            NSLocalizedString("manual.method.webserver.step1", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.webserver.step2", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.webserver.step3", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.webserver.step4", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.webserver.step5", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.webserver.step6", bundle: .module, comment: "")
                        ]
                    )

                    #if !os(tvOS)
                    methodSection(
                        title: NSLocalizedString("manual.method.filesapp.title", bundle: .module, comment: ""),
                        icon: "folder",
                        steps: [
                            NSLocalizedString("manual.method.filesapp.step1", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.filesapp.step2", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.filesapp.step3", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.filesapp.step4", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.filesapp.step5", bundle: .module, comment: ""),
                            NSLocalizedString("manual.method.filesapp.step6", bundle: .module, comment: "")
                        ]
                    )
                    #endif

                    namingTipBox
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(Text("manual.nav.title", bundle: .module))
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }

    private func methodSection(title: String, icon: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.retroBlue)
                Text(title)
                    .font(.headline)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                StepRowView(number: index + 1, text: step)
            }
        }
    }

    private var namingTipBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("manual.tip.title", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                Text("manual.tip.rom_example", bundle: .module)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("manual.tip.save_example", bundle: .module)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("manual.tip.note", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Step row

private struct StepRowView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.retroBlue.opacity(0.2))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.retroBlue)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
