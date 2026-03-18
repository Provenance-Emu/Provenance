//
//  RumbleProfilesView.swift
//  PVUI
//
//  Settings view for customising haptic rumble profiles per system and per controller type.
//  Users can pick from built-in presets, tune custom presets with live sliders, and
//  share/import presets as JSON files.
//

import SwiftUI
import PVPrimitives
import PVSettings
import Defaults
import PVThemes
import PVLogging
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - RumbleProfilesView

/// Top-level view navigated from Settings → Controllers → Rumble Profiles.
struct RumbleProfilesView: View {

    // MARK: Persisted state

    @Default(.rumbleSystemOverrides) private var systemOverrides
    @Default(.rumbleControllerOverrides) private var controllerOverrides
    @Default(.rumbleCustomPresets) private var rawCustomPresets

    // MARK: Ephemeral UI state

    @State private var customPresets: [RumblePreset] = []
    @State private var showNewPresetAlert = false
    @State private var newPresetName = ""
    @State private var showImportPicker = false
    @State private var showExportSheet = false
    @State private var presetToExport: RumblePreset?
    @State private var importError: String?
    @State private var showImportError = false
    @State private var presetToDelete: RumblePreset?
    @State private var showDeleteConfirm = false

    @ObservedObject private var themeManager = ThemeManager.shared

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    // MARK: - Computed helpers

    /// Decode custom presets from stored Data blobs.
    private func loadCustomPresets() {
        customPresets = rawCustomPresets.compactMap { data in
            try? JSONDecoder().decode(RumblePreset.self, from: data)
        }
    }

    /// Persist the current `customPresets` array back to Defaults.
    private func saveCustomPresets() {
        rawCustomPresets = customPresets.compactMap { try? JSONEncoder().encode($0) }
    }

    // MARK: - Body

    var body: some View {
        List {
            systemProfilesSection
            controllerOverridesSection
            customPresetsSection
            importExportSection
        }
        #if os(tvOS)
        .listStyle(.plain)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Rumble Profiles")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { loadCustomPresets() }
        .alert("New Custom Preset", isPresented: $showNewPresetAlert) {
            TextField("Preset name", text: $newPresetName)
            Button("Create") {
                let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                newPresetName = ""
                guard !name.isEmpty else { return }
                let preset = RumblePreset(name: name)
                customPresets.append(preset)
                saveCustomPresets()
            }
            Button("Cancel", role: .cancel) { newPresetName = "" }
        } message: {
            Text("Enter a name for the new custom rumble preset.")
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .confirmationDialog(
            "Delete preset \"\(presetToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let preset = presetToDelete {
                    deletePreset(preset)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        #if canImport(UIKit) && !os(tvOS)
        .sheet(isPresented: $showImportPicker) {
            RumblePresetDocumentPicker { result in
                handleImport(result: result)
            }
        }
        .sheet(item: $presetToExport) { preset in
            if let data = try? preset.jsonData(),
               let tempURL = writeTempFile(data: data, name: "\(sanitize(preset.name)).rumble.json") {
                RumbleShareSheet(items: [tempURL])
            }
        }
        #endif
    }

    // MARK: - Sections

    /// Section listing every built-in system that supports rumble with a profile picker.
    @ViewBuilder
    private var systemProfilesSection: some View {
        Section {
            ForEach(systemRows, id: \.id) { row in
                SystemProfileRow(
                    row: row,
                    overrideKey: row.id,
                    systemOverrides: $systemOverrides,
                    customPresets: customPresets,
                    accentColor: accentColor
                )
                #if os(tvOS)
                .buttonStyle(.card)
                .retroThemedFocus(cornerRadius: 12)
                #endif
            }
        } header: {
            Label("System Profiles", systemImage: "gamecontroller.fill")
                .font(.headline)
                #if os(tvOS)
                .foregroundColor(.retroPink)
                #endif
        } footer: {
            Text("Override the default haptic profile used for each system. Custom presets appear alongside the built-in options.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Section for per-controller-type overrides.
    @ViewBuilder
    private var controllerOverridesSection: some View {
        Section {
            ForEach(controllerTypeRows, id: \.key) { row in
                ControllerOverrideRow(
                    row: row,
                    controllerOverrides: $controllerOverrides,
                    customPresets: customPresets,
                    accentColor: accentColor
                )
                #if os(tvOS)
                .buttonStyle(.card)
                .retroThemedFocus(cornerRadius: 12)
                #endif
            }
        } header: {
            Label("Controller Type Overrides", systemImage: "waveform.path")
                .font(.headline)
                #if os(tvOS)
                .foregroundColor(.retroPink)
                #endif
        } footer: {
            Text("These overrides apply for a specific controller type regardless of system, and take priority over system overrides.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Section listing user-created custom presets.
    @ViewBuilder
    private var customPresetsSection: some View {
        Section {
            ForEach(customPresets) { preset in
                NavigationLink(
                    destination: RumblePresetEditorView(
                        preset: preset,
                        onSave: { updated in
                            if let idx = customPresets.firstIndex(where: { $0.id == updated.id }) {
                                customPresets[idx] = updated
                                saveCustomPresets()
                            }
                        }
                    )
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.headline)
                            Text(presetSummary(preset))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        #if !os(tvOS)
                        Button {
                            presetToExport = preset
                            showExportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(accentColor)
                        }
                        .buttonStyle(.borderless)
                        #endif
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        presetToDelete = preset
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #if os(tvOS)
                .buttonStyle(.card)
                .retroThemedFocus(cornerRadius: 12)
                #endif
            }

            Button {
                showNewPresetAlert = true
            } label: {
                Label("New Custom Preset", systemImage: "plus.circle")
                    .foregroundColor(accentColor)
            }
            #if os(tvOS)
            .buttonStyle(.card)
            .retroThemedFocus(cornerRadius: 12)
            #endif
        } header: {
            Label("Custom Presets", systemImage: "slider.horizontal.3")
                .font(.headline)
                #if os(tvOS)
                .foregroundColor(.retroPink)
                #endif
        } footer: {
            Text("Custom presets can be applied to any system or controller. Swipe left to delete.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Import/Export section.
    @ViewBuilder
    private var importExportSection: some View {
        Section {
            #if !os(tvOS)
            Button {
                showImportPicker = true
            } label: {
                Label("Import Preset from File\u{2026}", systemImage: "square.and.arrow.down")
                    .foregroundColor(accentColor)
            }
            #endif
            Button {
                resetAllOverrides()
            } label: {
                Label("Reset All Overrides to Defaults", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.red)
            }
            #if os(tvOS)
            .buttonStyle(.card)
            .retroThemedFocus(cornerRadius: 12)
            #endif
        } header: {
            Label("Import / Export", systemImage: "arrow.up.arrow.down.circle")
                .font(.headline)
                #if os(tvOS)
                .foregroundColor(.retroPink)
                #endif
        } footer: {
            Text("Presets are exported as .rumble.json files and can be shared with other users.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Data

    struct SystemRow: Identifiable {
        let id: String      // Provenance system identifier
        let displayName: String
        let icon: String    // SF Symbol
    }

    private var systemRows: [SystemRow] {
        [
            SystemRow(id: SystemIdentifier.N64.rawValue,       displayName: "Nintendo 64",      icon: "gamecontroller.fill"),
            SystemRow(id: SystemIdentifier.PSX.rawValue,       displayName: "PlayStation",       icon: "gamecontroller.fill"),
            SystemRow(id: SystemIdentifier.PS2.rawValue,       displayName: "PlayStation 2",     icon: "gamecontroller.fill"),
            SystemRow(id: SystemIdentifier.PS3.rawValue,       displayName: "PlayStation 3",     icon: "gamecontroller.fill"),
            SystemRow(id: SystemIdentifier.GBA.rawValue,       displayName: "Game Boy Advance",  icon: "gamecontroller"),
            SystemRow(id: SystemIdentifier.GameCube.rawValue,  displayName: "GameCube",          icon: "gamecontroller.fill"),
            SystemRow(id: "xbox",                              displayName: "Xbox",              icon: "gamecontroller.fill"),
            SystemRow(id: "switch",                            displayName: "Nintendo Switch",   icon: "gamecontroller.fill"),
        ]
    }

    struct ControllerTypeRow {
        let key: String     // UserDefaults key suffix, e.g. "dualSense"
        let displayName: String
        let icon: String
    }

    private var controllerTypeRows: [ControllerTypeRow] {
        [
            ControllerTypeRow(key: "dualSense",  displayName: "DualSense",        icon: "gamecontroller.fill"),
            ControllerTypeRow(key: "dualShock4", displayName: "DualShock 4",      icon: "gamecontroller.fill"),
            ControllerTypeRow(key: "xbox",       displayName: "Xbox Series",      icon: "gamecontroller.fill"),
            ControllerTypeRow(key: "switchPro",  displayName: "Switch Pro",       icon: "gamecontroller"),
            ControllerTypeRow(key: "joycon",     displayName: "Joy-Con",          icon: "gamecontroller"),
        ]
    }

    // MARK: - Helpers

    private func presetSummary(_ preset: RumblePreset) -> String {
        String(format: "Low %.0f%%  High %.0f%%  Sharp %.0f%%",
               preset.lowFrequencyScale * 100,
               preset.highFrequencyScale * 100,
               preset.sharpness * 100)
    }

    private func deletePreset(_ preset: RumblePreset) {
        customPresets.removeAll { $0.id == preset.id }
        saveCustomPresets()
        // Clear any overrides that pointed to this preset
        let idStr = preset.id.uuidString
        systemOverrides = systemOverrides.filter { $0.value != idStr }
        controllerOverrides = controllerOverrides.filter { $0.value != idStr }
    }

    private func resetAllOverrides() {
        systemOverrides = [:]
        controllerOverrides = [:]
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let data = try Data(contentsOf: url)
                let preset = try RumblePreset.from(jsonData: data)
                // Check for duplicate ID — re-identify if already stored.
                let existing = customPresets.first { $0.id == preset.id }
                let toStore = existing != nil ? preset.reidentified() : preset
                customPresets.append(toStore)
                saveCustomPresets()
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func sanitize(_ name: String) -> String {
        name.components(separatedBy: .init(charactersIn: "/\\:*?\"<>|")).joined(separator: "-")
    }

    private func writeTempFile(data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

// MARK: - SystemProfileRow

private struct SystemProfileRow: View {
    let row: RumbleProfilesView.SystemRow
    let overrideKey: String
    @Binding var systemOverrides: [String: String]
    let customPresets: [RumblePreset]
    let accentColor: Color

    private var currentValue: String {
        systemOverrides[overrideKey] ?? "default"
    }

    private var allOptions: [(id: String, label: String)] {
        var opts = [("default", "System Default")]
        opts += RumblePreset.builtIns.map { ("builtin:\($0.name)", $0.name) }
        opts += customPresets.map { ($0.id.uuidString, $0.name) }
        return opts
    }

    private var currentLabel: String {
        allOptions.first { $0.id == currentValue }?.label ?? "System Default"
    }

    var body: some View {
        HStack {
            Image(systemName: row.icon)
                .imageScale(.medium)
                .foregroundColor(accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(.body)
                Text(currentLabel)
                    .font(.caption)
                    .foregroundColor(currentValue == "default" ? .secondary : accentColor)
            }

            Spacer()

            Menu {
                ForEach(allOptions, id: \.id) { option in
                    Button {
                        if option.id == "default" {
                            systemOverrides.removeValue(forKey: overrideKey)
                        } else {
                            systemOverrides[overrideKey] = option.id
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                            if currentValue == option.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ControllerOverrideRow

private struct ControllerOverrideRow: View {
    let row: RumbleProfilesView.ControllerTypeRow
    @Binding var controllerOverrides: [String: String]
    let customPresets: [RumblePreset]
    let accentColor: Color

    private var currentValue: String {
        controllerOverrides[row.key] ?? "default"
    }

    private var allOptions: [(id: String, label: String)] {
        var opts = [("default", "System Default")]
        opts += RumblePreset.builtIns.map { ("builtin:\($0.name)", $0.name) }
        opts += customPresets.map { ($0.id.uuidString, $0.name) }
        return opts
    }

    private var currentLabel: String {
        allOptions.first { $0.id == currentValue }?.label ?? "System Default"
    }

    var body: some View {
        HStack {
            Image(systemName: row.icon)
                .imageScale(.medium)
                .foregroundColor(accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(.body)
                Text(currentLabel)
                    .font(.caption)
                    .foregroundColor(currentValue == "default" ? .secondary : accentColor)
            }

            Spacer()

            Menu {
                ForEach(allOptions, id: \.id) { option in
                    Button {
                        if option.id == "default" {
                            controllerOverrides.removeValue(forKey: row.key)
                        } else {
                            controllerOverrides[row.key] = option.id
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                            if currentValue == option.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - RumblePresetEditorView

/// Full-page editor for a custom rumble preset with live sliders.
struct RumblePresetEditorView: View {
    let preset: RumblePreset
    let onSave: (RumblePreset) -> Void

    @State private var name: String
    @State private var lowFrequency: Double
    @State private var highFrequency: Double
    @State private var sharpness: Double
    @State private var minBurstDuration: Double

    @ObservedObject private var themeManager = ThemeManager.shared

    init(preset: RumblePreset, onSave: @escaping (RumblePreset) -> Void) {
        self.preset = preset
        self.onSave = onSave
        _name             = State(initialValue: preset.name)
        _lowFrequency     = State(initialValue: Double(preset.lowFrequencyScale))
        _highFrequency    = State(initialValue: Double(preset.highFrequencyScale))
        _sharpness        = State(initialValue: Double(preset.sharpness))
        _minBurstDuration = State(initialValue: preset.minBurstDuration * 1000) // display in ms
    }

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    private var hasChanges: Bool {
        name != preset.name
        || Float(lowFrequency) != preset.lowFrequencyScale
        || Float(highFrequency) != preset.highFrequencyScale
        || Float(sharpness) != preset.sharpness
        || minBurstDuration / 1000 != preset.minBurstDuration
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Name")
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("Preset name", text: $name)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { save() }
                }
            } header: {
                Text("Preset Name")
            }

            Section {
                sliderRow(
                    title: "Low-Frequency Scale",
                    subtitle: "Heavy/grip motor intensity (e.g. N64 thump). 0 = silent, 1 = full.",
                    value: $lowFrequency,
                    range: 0...1,
                    format: "%.0f%%",
                    displayMultiplier: 100
                )
                sliderRow(
                    title: "High-Frequency Scale",
                    subtitle: "Buzz/light motor intensity (e.g. GBA cartridge). 0 = silent, 1 = full.",
                    value: $highFrequency,
                    range: 0...1,
                    format: "%.0f%%",
                    displayMultiplier: 100
                )
                sliderRow(
                    title: "Sharpness",
                    subtitle: "0 = soft/dull thump (N64 ERM). 1 = sharp/precise buzz (GBA pager).",
                    value: $sharpness,
                    range: 0...1,
                    format: "%.0f%%",
                    displayMultiplier: 100
                )
                sliderRow(
                    title: "Min Burst Duration",
                    subtitle: "Bursts shorter than this (ms) are suppressed as noise.",
                    value: $minBurstDuration,
                    range: 0...200,
                    format: "%.0f ms",
                    displayMultiplier: 1
                )
            } header: {
                Text("Parameters")
            } footer: {
                Text("Changes are saved automatically when you leave this screen.")
                    .font(.caption)
            }

            Section {
                HStack(spacing: 12) {
                    previewBox(label: "Low",   value: lowFrequency,  color: .blue)
                    previewBox(label: "High",  value: highFrequency, color: .orange)
                    previewBox(label: "Sharp", value: sharpness,     color: .purple)
                }
                .listRowBackground(Color.clear)
            } header: {
                Text("Preview")
            }
        }
        #if os(tvOS)
        .listStyle(.plain)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(name.isEmpty ? "Edit Preset" : name)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { save() }
    }

    @ViewBuilder
    private func sliderRow(
        title: String,
        subtitle: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        displayMultiplier: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                Text(String(format: format, value.wrappedValue * displayMultiplier))
                    .font(.body.monospacedDigit())
                    .foregroundColor(accentColor)
                    .frame(minWidth: 55, alignment: .trailing)
            }
            Slider(value: value, in: range, step: range.upperBound > 1 ? 5 : 0.01)
                .tint(accentColor)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func previewBox(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15 + value * 0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.4 + value * 0.5), lineWidth: 1.5)
                )
                .frame(height: 44)
                .overlay(
                    Text(String(format: "%.0f%%", value * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(color)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let updated = RumblePreset(
            id: preset.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            lowFrequencyScale: Float(lowFrequency),
            highFrequencyScale: Float(highFrequency),
            sharpness: Float(sharpness),
            minBurstDuration: minBurstDuration / 1000
        )
        onSave(updated)
    }
}

// MARK: - ShareSheet (iOS only)

#if canImport(UIKit) && !os(tvOS)
private struct RumbleShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - RumblePresetDocumentPicker

private struct RumblePresetDocumentPicker: UIViewControllerRepresentable {
    let onPick: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType]
        if #available(iOS 14.0, *) {
            types = [.json]
        } else {
            types = [UTType(filenameExtension: "json") ?? .data]
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Result<URL, Error>) -> Void
        init(onPick: @escaping (Result<URL, Error>) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                // Write to temp dir so we have a stable path
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try data.write(to: tmp)
                onPick(.success(tmp))
            } catch {
                onPick(.failure(error))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct RumbleProfilesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RumbleProfilesView()
        }
    }
}
#endif
