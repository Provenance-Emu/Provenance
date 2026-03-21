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
            SwiftUI.Section(header: Text("Audio")) {
                ThemedToggle(isOn: $recordingMicEnabled) {
                    SettingsRow(
                        title: "Microphone",
                        subtitle: "Include microphone audio in recordings.",
                        icon: .sfSymbol("mic.fill")
                    )
                }
            }

#if os(iOS)
            SwiftUI.Section(header: Text("Camera")) {
                ThemedToggle(isOn: $recordingCameraEnabled) {
                    SettingsRow(
                        title: "Camera",
                        subtitle: "Include front camera in recordings (picture-in-picture).",
                        icon: .sfSymbol("camera.fill")
                    )
                }
            }
#endif

            SwiftUI.Section(
                header: Text("Storage"),
                footer: Text("Preference saved; automatic save on recording stop will be applied in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            ) {
                ThemedToggle(isOn: $recordingAutoSave) {
                    SettingsRow(
                        title: "Auto-save to Photos",
                        subtitle: "Automatically save completed recordings to the Photos library.",
                        icon: .sfSymbol("photo.on.rectangle.angled")
                    )
                }
            }

            SwiftUI.Section(
                header: Text("HUD"),
                footer: Text("Preference saved; HUD overlay integration will be applied in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            ) {
                ThemedToggle(isOn: $showRecordingOSD) {
                    SettingsRow(
                        title: "Show Recording Button in HUD",
                        subtitle: "Display the recording start/stop button in the in-game overlay.",
                        icon: .sfSymbol("record.circle")
                    )
                }
            }

            SwiftUI.Section(
                header: Text("Clip Duration"),
                footer: Text("Default length for each recording clip. Clip buffer enforcement will be applied in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            ) {
                Picker("Clip Duration", selection: $recordingClipDuration) {
                    ForEach(Self.clipDurationOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.automatic)
            }

            SwiftUI.Section(header: Text("Live Streaming")) {
                SettingsRow(
                    title: "About Live Streaming",
                    subtitle: "Live streaming support via ReplayKit is planned for a future release.",
                    icon: .sfSymbol("info.circle")
                )
            }
        }
        .navigationTitle("Recording & Streaming")
    }
}
