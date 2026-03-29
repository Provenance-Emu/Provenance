//
//  AUFilterSettingsView.swift
//  PVUI
//
//  Created by Claude on 3/25/26.
//  Part of #3489 — AU filter support
//

import SwiftUI
import Defaults
import PVCoreAudio
import PVUIBase

// MARK: - AUFilterSettingsView

/// Settings page for the AU audio effects chain.
/// Allows the user to:
///   • Enable / disable the effects chain
///   • Add, reorder, enable/disable, and remove individual effects
///   • Adjust per-effect parameters via sliders
///   • Save named presets and load them back
struct AUFilterSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Default(.auFiltersEnabled) private var auFiltersEnabled
    @Default(.auEffectsChain) private var chain
    @Default(.auEffectsPresets) private var savedPresets

    @State private var showingAddEffect = false
    @State private var showingSavePreset = false
    @State private var newPresetName = ""
    @State private var expandedNodeID: UUID?

    var body: some View {
        List {
            masterToggleSection
            if auFiltersEnabled {
                effectsChainSection
                presetsSection
            }
        }
        .navigationTitle("Audio Effects")
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAddEffect) {
            AddEffectSheet { effectType in
                addEffect(effectType)
            }
            #if os(tvOS)
            .settingsSheetDetachedFromSubpageDepth()
            #endif
        }
        .sheet(isPresented: $showingSavePreset) {
            SavePresetSheet(presetName: $newPresetName) {
                saveCurrentChainAsPreset()
            }
            #if os(tvOS)
            .settingsSheetDetachedFromSubpageDepth()
            #endif
        }
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
    }

    // MARK: - Sections

    private var masterToggleSection: some View {
        Section {
            Toggle(isOn: $auFiltersEnabled) {
                Label {
                    VStack(alignment: .leading) {
                        Text("Audio Effects")
                            .font(.body)
                        Text("Post-process emulator audio with AU effects")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "waveform.badge.plus")
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private var effectsChainSection: some View {
        Section {
            if chain.nodes.isEmpty {
                ContentUnavailableLabel(
                    "No Effects",
                    systemImage: "waveform",
                    description: Text("Tap + to add an audio effect")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach($chain.nodes) { $node in
                    EffectNodeRow(
                        node: $node,
                        isExpanded: expandedNodeID == $node.wrappedValue.id,
                        onToggleExpand: {
                            let nodeID = $node.wrappedValue.id
                            expandedNodeID = expandedNodeID == nodeID ? nil : nodeID
                        },
                        onDelete: {
                            chain.nodes.removeAll { $0.id == $node.wrappedValue.id }
                        }
                    )
                }
                .onMove { source, destination in
                    chain.nodes.move(fromOffsets: source, toOffset: destination)
                }
                .onDelete { indices in
                    chain.nodes.remove(atOffsets: indices)
                }
            }
        } header: {
            HStack {
                Text("Effects Chain")
                Spacer()
                Button {
                    showingAddEffect = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        } footer: {
            #if os(tvOS)
            Text("Effects are applied in order from top to bottom. Use the Load button to apply a preset.")
                .font(.caption)
            #else
            Text("Effects are applied in order from top to bottom. Drag to reorder, swipe to remove.")
                .font(.caption)
            #endif
        }
    }

    private var presetsSection: some View {
        SwiftUI.Section {
            // Built-in presets
            ForEach(AUEffectsPreset.builtinPresets) { preset in
                PresetRow(preset: preset, isBuiltin: true) {
                    loadPreset(preset)
                }
            }

            // User-saved presets
            ForEach(savedPresets) { preset in
                PresetRow(preset: preset, isBuiltin: false) {
                    loadPreset(preset)
                } onDelete: {
                    deletePreset(preset)
                }
            }

            Button {
                newPresetName = ""
                showingSavePreset = true
            } label: {
                Label("Save Current Chain", systemImage: "square.and.arrow.down")
            }
            .disabled(chain.nodes.isEmpty)
        } header: {
            Text("Presets")
        }
    }

    // MARK: - Actions

    private func addEffect(_ effectType: AUEffectType) {
        let node = AUEffectNode(effectType: effectType)
        chain.nodes.append(node)
        auFiltersEnabled = true
    }

    private func loadPreset(_ preset: AUEffectsPreset) {
        chain = preset.chain
    }

    private func saveCurrentChainAsPreset() {
        guard !newPresetName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let preset = AUEffectsPreset(name: newPresetName, chain: chain)
        savedPresets.append(preset)
        newPresetName = ""
    }

    private func deletePreset(_ preset: AUEffectsPreset) {
        savedPresets.removeAll { $0.id == preset.id }
    }
}

// MARK: - EffectNodeRow

private struct EffectNodeRow: View {
    @Binding var node: AUEffectNode
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Image(systemName: node.effectType.sfSymbolName)
                    .foregroundStyle(node.isEnabled ? .blue : .secondary)
                    .frame(width: 24)

                Text(node.effectType.description)
                    .foregroundStyle(node.isEnabled ? .primary : .secondary)

                Spacer()

                Toggle("", isOn: $node.isEnabled)
                    .labelsHidden()
                    .tint(.blue)

                #if os(tvOS)
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                #endif

                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            // Parameter sliders (expanded)
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(node.effectType.parameterDefinitions, id: \.key) { param in
                        ParameterSliderRow(
                            param: param,
                            value: Binding(
                                get: { node.parameters[param.key] ?? param.min },
                                set: { node.parameters[param.key] = $0 }
                            )
                        )
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - ParameterSliderRow

private struct ParameterSliderRow: View {
    let param: AUEffectParameterDefinition
    @Binding var value: Double

    private var displayValue: String {
        if param.unit.isEmpty {
            return String(format: "%.2f", value)
        }
        if param.unit == "%" || param.unit == "dB" {
            return String(format: "%.0f%@", value, param.unit)
        }
        if param.unit == "Hz" {
            return value >= 1000
                ? String(format: "%.1fk%@", value / 1000, param.unit)
                : String(format: "%.0f%@", value, param.unit)
        }
        return String(format: "%.3f%@", value, param.unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(param.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(displayValue)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            RetroWaveSlider(value: $value, in: param.min...param.max)
                .tint(.blue)
        }
    }
}

// MARK: - PresetRow

private struct PresetRow: View {
    let preset: AUEffectsPreset
    let isBuiltin: Bool
    let onLoad: () -> Void
    let onDelete: (() -> Void)?
    
    init(
        preset: AUEffectsPreset,
        isBuiltin: Bool,
        onLoad: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.preset = preset
        self.isBuiltin = isBuiltin
        self.onLoad = onLoad
        self.onDelete = onDelete
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(preset.name)
                    if isBuiltin {
                        Text("Built-in")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                Text("\(preset.chain.nodes.count) effect\(preset.chain.nodes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Load") {
                onLoad()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .font(.caption)

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - AddEffectSheet

private struct AddEffectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (AUEffectType) -> Void

    var body: some View {
        NavigationStack {
            List(AUEffectType.allCases, id: \.self) { effectType in
                Button {
                    onAdd(effectType)
                    dismiss()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(effectType.description)
                            Text(effectType.parameterDefinitions.map(\.name).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: effectType.sfSymbolName)
                            .foregroundStyle(.blue)
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Add Effect")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SavePresetSheet

private struct SavePresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var presetName: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Preset Name") {
                    TextField("e.g. My Retro Mix", text: $presetName)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Save Preset")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - ContentUnavailableLabel

/// Polyfill for ContentUnavailableView on older OS versions.
private struct ContentUnavailableLabel: View {
    let title: String
    let systemImage: String
    let description: Text?

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            description?
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
