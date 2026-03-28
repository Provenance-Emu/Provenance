//
//  ExternalEmulatorMigrationView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/28/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Guides users through importing saves from Delta, RetroArch, Manic Emu,
//  PPSSPP, and Gamma into Provenance.
//

import SwiftUI
import PVPrimitives
import PVThemes

// MARK: - Root view

/// "Import from Another Emulator" entry in Settings → Library.
///
/// Shows a list of detected third-party emulators and a step-by-step
/// export guide for each one. Because iOS sandboxing prevents direct
/// file access, the flow is fully manual/instructional.
public struct ExternalEmulatorMigrationView: View {
    @State private var installedEmulators: [KnownEmulator] = []
    @State private var selectedEmulator: KnownEmulator?
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if installedEmulators.isEmpty {
                        emptyStateSection
                    } else {
                        detectedSection
                    }

                    manualImportSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Import from Another Emulator")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEmulator) { emulator in
            NavigationStack {
                EmulatorMigrationGuideView(emulator: emulator)
            }
        }
        .task {
            await loadInstalledEmulators()
        }
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

            Text("Bring Your Saves Over")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.retroPink, .retroPurple, .retroBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("iOS prevents apps from reading each other's files directly. Tap an emulator below to see step-by-step export instructions.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.bottom, 8)
    }

    // MARK: Detected emulators

    private var detectedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Detected Emulators", icon: "checkmark.circle.fill", color: .green)

            ForEach(installedEmulators, id: \.rawValue) { emulator in
                EmulatorRowView(emulator: emulator) {
                    selectedEmulator = emulator
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            sectionHeader(title: "No Emulators Detected", icon: "magnifyingglass", color: .orange)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "app.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Delta, RetroArch, PPSSPP, Manic Emu, and Gamma were not found on this device.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        Text("You can still import save files manually using Files.app.")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 20)
                )
                .frame(minHeight: 120)

            VStack(alignment: .leading, spacing: 8) {
                Text("Want step-by-step instructions anyway?")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(KnownEmulator.allCases, id: \.rawValue) { emulator in
                    Button {
                        selectedEmulator = emulator
                    } label: {
                        HStack {
                            Image(systemName: emulator.symbolName)
                                .frame(width: 24)
                                .foregroundColor(.retroBlue)
                            Text(emulator.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: Manual import

    private var manualImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Manual Import", icon: "folder.fill", color: .blue)

            EmulatorRowView(
                icon: "folder.badge.plus",
                iconColor: .blue,
                title: "Import via Files.app",
                subtitle: "Copy .sav / .srm / .state files into Provenance's folder using the Files app",
                action: { selectedEmulator = nil }
            )
            .overlay(
                NavigationLink(destination: ManualFileImportGuideView()) {
                    EmptyView()
                }
                .opacity(0)
            )
        }
    }

    // MARK: Section header helper

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: Detection

    @MainActor
    private func loadInstalledEmulators() {
        installedEmulators = KnownEmulator.installedEmulators
    }
}

// MARK: - KnownEmulator + Identifiable (for sheet(item:))

extension KnownEmulator: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Emulator row

private struct EmulatorRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    init(emulator: KnownEmulator, action: @escaping () -> Void) {
        self.icon = emulator.symbolName
        self.iconColor = .retroBlue
        self.title = emulator.displayName
        self.subtitle = emulator.systemSummary
        self.action = action
    }

    init(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(iconColor.opacity(0.2), lineWidth: 1)
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
                .edgesIgnoringSafeArea(.all)

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

                        Text("Export from \(emulator.displayName)")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        Text(emulator.systemSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: Steps content

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 1 — Export from \(emulator.displayName)")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(Array(exportSteps.enumerated()), id: \.offset) { index, step in
                StepRowView(number: index + 1, text: step)
            }
        }
    }

    private var provenanceImportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 2 — Import into Provenance")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(Array(importSteps.enumerated()), id: \.offset) { index, step in
                StepRowView(number: index + 1, text: step)
            }
        }
    }

    private var saveFormatNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.retroBlue)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Save File Extensions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text("Look for files ending in: \(emulator.saveExtensions.map { ".\($0)" }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if emulator == .retroArch {
                    Text("Save states use numbered extensions (.state0, .state1…). Battery saves use .srm.")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
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
        case .delta:
            return [
                "Open Delta and go to the game you want to export.",
                "Long-press the game thumbnail to reveal the context menu.",
                "Tap 'Save States' to see your saves.",
                "Tap the share icon (square with arrow) on the save you want.",
                "Use the share sheet to send the file to Files.app or AirDrop to your Mac.",
                "Repeat for each game you want to migrate."
            ]
        case .manic:
            return [
                "Open Manic Emu and navigate to your game library.",
                "Long-press a game to bring up options.",
                "Tap 'Export Save' or 'Share Save'.",
                "Save the .sav file to the Files app (iCloud Drive or local storage).",
                "Repeat for each game."
            ]
        case .retroArch:
            return [
                "Open RetroArch and go to Main Menu → Load Content, then load your game.",
                "Open the Quick Menu (tap the screen or press the menu button).",
                "Tap 'Save State' to ensure a state is saved, then return to Quick Menu.",
                "Go to Quick Menu → Close Content to return to the main menu.",
                "In the main menu, navigate to 'Load Content' path to find your saves folder.",
                "Use the RetroArch file browser or Files.app to locate the 'saves' folder inside the RetroArch app group.",
                "Copy the .srm (battery save) or .state files to a location accessible to Provenance."
            ]
        case .ppsspp:
            return [
                "Open PPSSPP and navigate to your UMD images.",
                "Tap the game to open its settings page.",
                "Look for 'Save State' or check PPSSPP's memstick/PSP/SAVEDATA folder.",
                "Use Files.app to navigate to PPSSPP's folder and copy .ppst files.",
                "Note: PSP save data (.VMP files) may need conversion — standard .ppst states import directly."
            ]
        case .gamma:
            return [
                "Open Gamma and go to your game library.",
                "Long-press a game to see options.",
                "Tap 'Share Save' to export the .sav file.",
                "Save it to Files.app (iCloud Drive recommended for easy access).",
                "Repeat for each GB/GBC game."
            ]
        }
    }

    private var importSteps: [String] {
        [
            "Open Provenance and launch the web server via Settings → Library → Web Server, or use Files.app.",
            "Navigate to the ROM directory for the matching system (e.g. /ROMS/GBA/).",
            "Place the save file in the same folder as the ROM, with the same filename (only the extension differs).",
            "For example: 'MyGame.gba' needs 'MyGame.srm' or 'MyGame.sav' alongside it.",
            "Launch the game in Provenance — it will automatically detect and load the save.",
            "If the save does not load, verify the filename matches the ROM exactly (case-sensitive on some systems)."
        ]
    }
}

// MARK: - Manual file import guide

/// Guide for users who want to import saves without a specific third-party app.
struct ManualFileImportGuideView: View {
    var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .edgesIgnoringSafeArea(.all)

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
                        Text("Manual Save Import")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Import .sav, .srm, or .state files from any source")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    methodSection(
                        title: "Via Web Server (recommended)",
                        icon: "wifi",
                        steps: [
                            "Open Provenance and go to Settings → Library.",
                            "Tap 'Launch Web Server' and note the IP address shown.",
                            "On your computer, open a browser and go to that address.",
                            "Upload your save files through the web interface.",
                            "Place each file in the same ROM directory as the matching game.",
                            "Ensure the save filename matches the ROM filename (different extension only)."
                        ]
                    )

                    methodSection(
                        title: "Via Files.app (iPhone/iPad)",
                        icon: "folder",
                        steps: [
                            "Open the Files app on your iPhone or iPad.",
                            "Navigate to 'On My iPhone' (or iPad) → Provenance.",
                            "Find the ROMs folder for the relevant system.",
                            "Copy or move your .sav / .srm / .state file here.",
                            "Name the file to match the ROM exactly (same base name, different extension).",
                            "Launch the game in Provenance — the save loads automatically."
                        ]
                    )

                    namingTipBox
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Manual Import")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func methodSection(title: String, icon: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.retroBlue)
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
                .foregroundColor(.yellow)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Naming Convention")
                    .font(.subheadline.weight(.semibold))
                Text("ROM: Super Mario World (USA).sfc")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("Save: Super Mario World (USA).srm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("Only the file extension changes — the base name must match exactly.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
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
                    .foregroundColor(.retroBlue)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - RetroTheme helper (matches existing pattern)

private enum RetroTheme {
    static var retroBackground: Color { Color.black }
}
