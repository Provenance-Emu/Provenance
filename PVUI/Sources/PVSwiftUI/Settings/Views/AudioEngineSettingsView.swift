import SwiftUI
import PVLibrary
import Defaults
import PVCoreAudio
import PVAudio

struct AudioEngineSettingsView: View {
    /// Audio Engine Selection
    @Default(.audioEngine) var audioEngine
    @Default(.audioRingBufferType) var ringBufferType
    @Default(.audioLatency) var audioLatency
    @Default(.monoAudio) var monoAudio
    @Default(.audioEngineDSPAlgorithm) var dspAlgorithm

    var audioLatencySubLabelText: String {
        "Increase latency to improve performance on slower devices.(\(Int(audioLatency))ms)"
    }

    var body: some View {
        List {
            Section(header: Text("Audio Engine")) {
                Picker("Audio Engine", selection: $audioEngine) {
                    ForEach(AudioEngines.allCases, id: \.self) { engine in
                        Text(engine.description).tag(engine)
                    }
                }
                .pickerStyle(.automatic)

                Text("Select which audio engine to use for game audio playback")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Only show DSP algorithm picker when DSP engine is selected
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
            }
            #if !os(tvOS)
            Section(header: Text("Latency")) {
                HStack {
                    Text("Audio Latency")
                    Slider(value: $audioLatency, in: 5.0...25.0, step: 0.5) {
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
            }
            #endif
            #if DEBUG
            Section(header: Text("Debug Options")) {
                ThemedToggle(isOn: $monoAudio) {
                    SettingsRow(title: "Mono Audio",
                               subtitle: "Combine left and right audio channels.",
                               icon: .sfSymbol("speaker.wave.1"))
                }
            }
            #endif
        }
        .navigationTitle("Audio Engine")
    }
}
