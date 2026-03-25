import SwiftUI
import PVThemes
import PVLogging
import PVCoreBridge

struct RetroArchQuickSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RetroArchQuickSettingsViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading RetroArch settings...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                settingsList
            }
        }
        .navigationTitle("RetroArch Settings")
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
        .task {
            await viewModel.loadConfig()
        }
    }

    private var settingsList: some View {
        List {
            ForEach(CuratedSettingCategory.allCases) { category in
                Section {
                    ForEach(RetroArchCuratedSettings.settings(for: category)) { setting in
                        settingRow(for: setting)
                    }
                } header: {
                    Label(category.rawValue, systemImage: category.icon)
                }
            }

            // MIDI device picker — iOS/macOS/macCatalyst (CoreMIDI not available on tvOS)
#if canImport(CoreMIDI) && !os(tvOS)
            if #available(iOS 14.0, macCatalyst 14.0, macOS 11.0, *) {
                MIDIDevicePickerSection(palette: palette)
            }
#endif

            // Advanced section with link to full editor
            Section {
                NavigationLink(destination: RetroArchConfigEditorWrapper()) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(palette.defaultTintColor.swiftUIColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All RetroArch Settings")
                                .font(.body)
                            Text("View and edit all \u{2248}3,350 config keys")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Label("Advanced", systemImage: "wrench.and.screwdriver")
            }
        }
        #if os(tvOS)
        .listStyle(.grouped)
        #else
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Setting Row

    @ViewBuilder
    private func settingRow(for setting: CuratedSetting) -> some View {
        switch setting.controlType {
        case .toggle:
            toggleRow(for: setting)
        case .slider(let min, let max, let step):
            sliderRow(for: setting, min: min, max: max, step: step)
        case .picker(let options):
            pickerRow(for: setting, options: options)
        }
    }

    private func toggleRow(for setting: CuratedSetting) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.boolValue(for: setting.key) },
            set: { viewModel.setBoolValue($0, for: setting.key) }
        )) {
            settingLabel(for: setting)
        }
    }

    private func sliderRow(for setting: CuratedSetting, min: Double, max: Double, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                settingLabel(for: setting)
                Spacer()
                Text(formattedSliderValue(viewModel.doubleValue(for: setting.key), step: step))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
            }

            #if os(tvOS)
            // tvOS doesn't have Slider — use +/- buttons
            HStack {
                Button(action: {
                    let current = viewModel.doubleValue(for: setting.key)
                    let newVal = Swift.max(min, current - step)
                    let fmt = step == Double(Int(step)) ? "%.0f" : "%g"
                    viewModel.setDoubleValue(newVal, for: setting.key, format: fmt)
                }) {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                ProgressView(value: viewModel.doubleValue(for: setting.key) - min, total: max - min)
                    .progressViewStyle(.linear)

                Button(action: {
                    let current = viewModel.doubleValue(for: setting.key)
                    let newVal = Swift.min(max, current + step)
                    let fmt = step == Double(Int(step)) ? "%.0f" : "%g"
                    viewModel.setDoubleValue(newVal, for: setting.key, format: fmt)
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            #else
            Slider(
                value: Binding(
                    get: { viewModel.doubleValue(for: setting.key) },
                    set: {
                        let fmt = step == Double(Int(step)) ? "%.0f" : "%g"
                        viewModel.setDoubleValue($0, for: setting.key, format: fmt)
                    }
                ),
                in: min...max,
                step: step
            )
            #endif
        }
        .padding(.vertical, 2)
    }

    private func pickerRow(for setting: CuratedSetting, options: [(label: String, value: String)]) -> some View {
        Picker(selection: Binding(
            get: { viewModel.stringValue(for: setting.key) },
            set: { viewModel.setValue($0, for: setting.key) }
        )) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        } label: {
            settingLabel(for: setting)
        }
    }

    private func settingLabel(for setting: CuratedSetting) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(setting.title)
                    .font(.body)
                if viewModel.isModified(setting.key) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            Text(setting.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }

    private func formattedSliderValue(_ value: Double, step: Double) -> String {
        if step == Double(Int(step)) {
            return String(format: "%.0f", value)
        }
        return String(format: "%g", value)
    }
}

// MARK: - MIDIDevicePickerSection

#if canImport(CoreMIDI) && !os(tvOS)
/// A List section embedding multi-select pickers for MIDI input sources and output destinations.
/// Shown below the MIDI settings category in `RetroArchQuickSettingsView`.
@available(iOS 14.0, macCatalyst 14.0, macOS 11.0, *)
private struct MIDIDevicePickerSection: View {
    let palette: UXThemePalette
    @ObservedObject private var midi = MIDIDeviceManager.shared

    var body: some View {
        Section {
            // Input sources — multi-select
            ForEach(midi.sources) { source in
                MultiSelectRow(
                    name: source.name,
                    isSelected: midi.selectedSourceIDs.contains(source.id),
                    systemImage: "arrow.down.circle",
                    palette: palette
                ) {
                    midi.toggleSource(source.id)
                }
            }
            if midi.sources.isEmpty {
                Label("No MIDI inputs found", systemImage: "exclamationmark.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        } header: {
            HStack(spacing: 6) {
                Label("MIDI Inputs", systemImage: "arrow.down.circle")
                Spacer()
                if midi.rxActivity {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.1), value: midi.rxActivity)
        } footer: {
            Text(midi.selectedSourceIDs.isEmpty
                 ? "All sources active (auto-detect mode)"
                 : "\(midi.selectedSourceIDs.count) source\(midi.selectedSourceIDs.count == 1 ? "" : "s") selected")
                .font(.caption2)
        }

        Section {
            // Output destinations — multi-select
            ForEach(midi.destinations) { destination in
                MultiSelectRow(
                    name: destination.name,
                    isSelected: midi.selectedDestinationIDs.contains(destination.id),
                    systemImage: "arrow.up.circle",
                    palette: palette
                ) {
                    midi.toggleDestination(destination.id)
                }
            }
            if midi.destinations.isEmpty {
                Label("No MIDI outputs found", systemImage: "exclamationmark.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        } header: {
            HStack(spacing: 6) {
                Label("MIDI Outputs", systemImage: "arrow.up.circle")
                Spacer()
                if midi.txActivity {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.1), value: midi.txActivity)
        } footer: {
            Text(midi.selectedDestinationIDs.isEmpty
                 ? "No output destination selected"
                 : "\(midi.selectedDestinationIDs.count) destination\(midi.selectedDestinationIDs.count == 1 ? "" : "s") selected")
                .font(.caption2)
        }
    }
}

// MARK: - MultiSelectRow

@available(iOS 14.0, macCatalyst 14.0, macOS 11.0, *)
private struct MultiSelectRow: View {
    let name: String
    let isSelected: Bool
    let systemImage: String
    let palette: UXThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
                    .frame(width: 24)
                Text(name)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
#endif // canImport(CoreMIDI) && !os(tvOS)
