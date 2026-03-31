import SwiftUI
import PVUIBase
import Defaults
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

    var audioLatencySubLabelText: String {
        "Increase latency to improve performance on slower devices. (\(Int(audioLatency)) ms)"
    }

    var body: some View {
        ZStack {
            #if os(tvOS)
            RetroSettingsBackground()
            #endif

            List {
                engineSection
                #if !os(tvOS)
                latencySection
                effectsSection
                #endif
                #if DEBUG
                debugSection
                #endif
            }
            #if os(tvOS)
            .listStyle(.plain)
            #else
            .scrollContentBackground(.hidden)
            #endif
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
        Section {
            Picker("Audio Engine", selection: $audioEngine) {
                ForEach(AudioEngines.allCases, id: \.self) { engine in
                    Text(engine.description).tag(engine)
                }
            }
            .pickerStyle(.automatic)

            Text("Select which audio engine to use for game audio playback")
                .font(.caption)
                .foregroundColor(.secondary)

            if audioEngine == .dspGameAudioEngine {
                Picker("DSP Algorithm", selection: $dspAlgorithm) {
                    ForEach(DSPAudioEngineAlgorithms.allCases, id: \.self) { algorithm in
                        Text(algorithm.description).tag(algorithm)
                    }
                }
                .pickerStyle(.automatic)

                Text("Select which DSP algorithm to use for audio processing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Picker("Ring Buffer Type", selection: $ringBufferType) {
                ForEach(RingBufferType.allCases, id: \.self) { type in
                    Text(type.description).tag(type)
                }
            }
            .pickerStyle(.automatic)

            Text("Select which ring buffer implementation to use")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            RetroSettingsSectionHeader(icon: "waveform", title: "Audio Engine")
        }
    }

    // MARK: - Latency section (iOS only)

    #if !os(tvOS)
    @ViewBuilder
    private var latencySection: some View {
        Section {
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
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            RetroSettingsSectionHeader(icon: "timer", title: "Latency")
        }
    }

    @ViewBuilder
    private var effectsSection: some View {
        if audioEngine == .avAudioEngineGameAudioEngine {
            Section {
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
            } header: {
                RetroSettingsSectionHeader(icon: "waveform.badge.plus", title: "Effects")
            }
        }
    }
    #endif

    // MARK: - Debug section

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        Section {
            ThemedToggle(isOn: $monoAudio) {
                SettingsRow(title: "Mono Audio",
                           subtitle: "Combine left and right audio channels.",
                           icon: .sfSymbol("speaker.wave.1"),
                           showChevron: false)
            }
        } header: {
            RetroSettingsSectionHeader(icon: "ant", title: "Debug Options")
        }
    }
    #endif
}
