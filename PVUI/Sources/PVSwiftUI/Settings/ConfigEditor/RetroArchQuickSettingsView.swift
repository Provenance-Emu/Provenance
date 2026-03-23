import SwiftUI
import PVThemes
import PVLogging

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
