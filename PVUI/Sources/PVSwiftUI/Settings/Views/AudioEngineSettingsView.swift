import SwiftUI
import PVUIBase
import Defaults
import PVThemes
import PVCoreAudio
import PVAudio

struct AudioEngineSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    /// Audio Engine Selection
    @Default(.audioEngine) var audioEngine
    @Default(.audioRingBufferType) var ringBufferType
    @Default(.audioLatency) var audioLatency
    @Default(.monoAudio) var monoAudio
    @Default(.audioEngineDSPAlgorithm) var dspAlgorithm
    @Default(.auEffectsChain) var auEffectsChain
    @Default(.auFiltersEnabled) var auFiltersEnabled

    private static let sectionSpacing: CGFloat = 24

    var audioLatencySubLabelText: String {
        "Increase latency to improve performance on slower devices. (\(Int(audioLatency)) ms)"
    }

    var body: some View {
        ZStack {
            RetroSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    engineSection
                    #if !os(tvOS)
                    latencySection
                    effectsSection
                    #endif
                    #if DEBUG
                    debugSection
                    #endif
                }
                .tvOSSettingsHorizontalPadding()
                #if os(tvOS)
                .padding(.vertical, 24)
                #else
                .padding()
                #endif
            }
        }
        .navigationTitle("Audio Engine")
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }

    // MARK: - Engine section

    @ViewBuilder
    private var engineSection: some View {
        SettingsPageSection(icon: "waveform", title: "Audio Engine") {
            SettingsChoiceGroup(
                title: "Audio Engine",
                caption: "Select which audio engine to use for game audio playback",
                icon: "waveform",
                options: AudioEngines.allCases,
                optionTitle: { $0.description },
                selection: $audioEngine
            )

            if audioEngine == .dspGameAudioEngine {
                RetroSettingsDivider()

                SettingsChoiceGroup(
                    title: "DSP Algorithm",
                    caption: "Select which DSP algorithm to use for audio processing",
                    icon: "function",
                    options: DSPAudioEngineAlgorithms.allCases,
                    optionTitle: { $0.description },
                    selection: $dspAlgorithm
                )
            }

            RetroSettingsDivider()

            SettingsChoiceGroup(
                title: "Ring Buffer Type",
                caption: "Select which ring buffer implementation to use",
                icon: "memorychip",
                options: RingBufferType.allCases,
                optionTitle: { $0.description },
                selection: $ringBufferType
            )
        }
    }

    // MARK: - Latency section (iOS only)

    #if !os(tvOS)
    @ViewBuilder
    private var latencySection: some View {
        SettingsPageSection(icon: "timer", title: "Latency") {
            HStack {
                Text("Audio Latency")
                RetroWaveSlider(value: $audioLatency, in: 5.0...25.0, step: 0.5) {
                    Text("Audio Latency (\(Int(audioLatency)) ms)")
                } minimumValueLabel: {
                    Image(systemName: "hare")
                } maximumValueLabel: {
                    Image(systemName: "tortoise")
                }
            }
            Text(audioLatencySubLabelText)
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var effectsSection: some View {
        if audioEngine == .avAudioEngineGameAudioEngine {
            SettingsPageSection(icon: "waveform.badge.plus", title: "Effects") {
                NavigationLink(destination: AUFilterSettingsView()) {
                    HStack {
                        let effectsActive = auFiltersEnabled && auEffectsChain.nodes.contains(where: { $0.isEnabled })
                        let activeCount = auEffectsChain.nodes.filter(\.isEnabled).count
                        SettingsRow(
                            title: "Audio Effects",
                            subtitle: effectsActive
                                ? "\(activeCount) effect\(activeCount == 1 ? "" : "s") active"
                                : "Add reverb, delay, EQ and more",
                            icon: .sfSymbol("waveform.badge.plus")
                        )
                        if effectsActive {
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    #endif

    // MARK: - Debug section

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        SettingsPageSection(icon: "ant", title: "Debug Options") {
            ThemedToggle(isOn: $monoAudio) {
                SettingsRow(title: "Mono Audio",
                           subtitle: "Combine left and right audio channels.",
                           icon: .sfSymbol("speaker.wave.1"),
                           showChevron: false)
            }
        }
    }
    #endif
}

// MARK: - Shared page building blocks

/// Spacing shared by `SettingsPageSection`. Generic types cannot hold static stored properties, hence the namespace.
enum SettingsPageLayout {
    static let rowSpacing: CGFloat = 12
}

/// A retrowave section: icon header above a stack of rows, with an optional footnote below.
/// Replaces a stock `List` `Section` in settings pages built on `ScrollView`.
struct SettingsPageSection<Content: View>: View {
    let icon: String
    let title: String
    var footer: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsPageLayout.rowSpacing) {
            RetroSettingsSectionHeader(icon: icon, title: title)
            content()
            if let footer {
                Text(footer)
                    .font(.retroSettingsRowSubtitle)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// A titled single-choice setting. tvOS shows radio rows (`RetroSettingsPickerRow`); other platforms show a menu `Picker`.
struct SettingsChoiceGroup<Value: Hashable>: View {
    let title: String
    let caption: String
    let icon: String
    let options: [Value]
    let optionTitle: (Value) -> String
    @Binding var selection: Value

    @ObservedObject private var themeManager = ThemeManager.shared

    private var titleColor: Color {
        themeManager.currentPalette.settingsCellText?.swiftUIColor
            ?? themeManager.currentPalette.gameLibraryText.swiftUIColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if os(tvOS)
            Label(title, systemImage: icon)
                .font(.retroSettingsLabel)
                .foregroundColor(titleColor)

            Text(caption)
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)

            ForEach(options, id: \.self) { option in
                RetroSettingsPickerRow(
                    symbolName: icon,
                    title: optionTitle(option),
                    subtitle: "",
                    isSelected: selection == option
                ) {
                    selection = option
                }
            }
            #else
            HStack {
                Label(title, systemImage: icon)
                    .font(.retroSettingsLabel)
                    .foregroundColor(titleColor)
                Spacer()
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(optionTitle(option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.retroBlue)
            }

            Text(caption)
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)
            #endif
        }
    }
}
