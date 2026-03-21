//
//  RecordingSettingsView.swift
//  PVUI
//
//  Created by Provenance Emu on 3/21/26.
//

import SwiftUI
import Defaults
import PVSettings

struct RecordingSettingsView: View {

    @Default(.recordingMicEnabled) var recordingMicEnabled
    @Default(.recordingAutoSave) var recordingAutoSave
    @Default(.showRecordingOSD) var showRecordingOSD
    @Default(.recordingClipDuration) var recordingClipDuration

#if os(iOS)
    @Default(.recordingCameraEnabled) var recordingCameraEnabled
#endif

    private static let clipDurationOptions: [(label: String, value: Int)] = [
        ("15 seconds", 15),
        ("30 seconds", 30),
        ("60 seconds", 60)
    ]

    var body: some View {
        List {
            Section(header: Text("Audio")) {
                ThemedToggle(isOn: $recordingMicEnabled) {
                    SettingsRow(
                        title: "Microphone",
                        subtitle: "Include microphone audio in recordings.",
                        icon: .sfSymbol("mic.fill")
                    )
                }
            }

#if os(iOS)
            Section(header: Text("Camera")) {
                ThemedToggle(isOn: $recordingCameraEnabled) {
                    SettingsRow(
                        title: "Camera",
                        subtitle: "Include front camera in recordings (picture-in-picture).",
                        icon: .sfSymbol("camera.fill")
                    )
                }
            }
#endif

            Section(header: Text("Storage")) {
                ThemedToggle(isOn: $recordingAutoSave) {
                    SettingsRow(
                        title: "Auto-save to Photos",
                        subtitle: "Automatically save completed recordings to the Photos library.",
                        icon: .sfSymbol("photo.on.rectangle.angled")
                    )
                }
            }

            Section(header: Text("HUD")) {
                ThemedToggle(isOn: $showRecordingOSD) {
                    SettingsRow(
                        title: "Show Recording Button in HUD",
                        subtitle: "Display the recording start/stop button in the in-game overlay.",
                        icon: .sfSymbol("record.circle")
                    )
                }
            }

            Section(header: Text("Clip Duration")) {
                Picker("Clip Duration", selection: $recordingClipDuration) {
                    ForEach(Self.clipDurationOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.automatic)

                Text("Maximum length for each recording session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Recording & Streaming")
    }
}
