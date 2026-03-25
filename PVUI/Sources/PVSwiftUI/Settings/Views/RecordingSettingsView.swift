//
//  RecordingSettingsView.swift
//  PVUI
//
//  Created by Provenance Emu on 3/21/26.
//

import SwiftUI
import Defaults
import PVSettings
import PVUIBase

struct RecordingSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Default(.recordingMicEnabled) var recordingMicEnabled
    @Default(.recordingAutoSave) var recordingAutoSave
    @Default(.showRecordingOSD) var showRecordingOSD
    @Default(.recordingClipDuration) var recordingClipDuration

#if os(iOS)
    @Default(.recordingCameraEnabled) var recordingCameraEnabled
    @Default(.recordingCameraPosition) var recordingCameraPosition
    @Default(.cameraOverlaySize) var cameraOverlaySize
    @Default(.cameraOverlayShape) var cameraOverlayShape
#endif

    #if os(tvOS)
    @ObservedObject private var gamepadManager = GamepadManager.shared
    #endif

    private static let clipDurationOptions: [(label: String, value: Int)] = [
        ("15 seconds", 15),
        ("30 seconds", 30),
        ("60 seconds", 60)
    ]

    var body: some View {
        List {
            #if os(tvOS)
            if !gamepadManager.isControllerConnected {
                SwiftUI.Section {
                    SettingsRow(
                        title: "Controller Required",
                        subtitle: "Connect a game controller to enable recording and live streaming on Apple TV.",
                        icon: .sfSymbol("gamecontroller.fill")
                    )
                }
            }
            #endif

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
            SwiftUI.Section(header: Text("Camera Overlay")) {
                ThemedToggle(isOn: $recordingCameraEnabled) {
                    SettingsRow(
                        title: "Face-Cam Overlay",
                        subtitle: "Show a front-camera picture-in-picture during recordings.",
                        icon: .sfSymbol("camera.fill")
                    )
                }

                if recordingCameraEnabled {
                    Picker(selection: $recordingCameraPosition) {
                        ForEach(CameraPosition.allCases, id: \.self) { position in
                            Label(position.displayName, systemImage: position.symbolName)
                                .tag(position)
                        }
                    } label: {
                        SettingsRow(
                            title: "Position",
                            subtitle: "Corner where the camera preview appears.",
                            icon: .sfSymbol("pip")
                        )
                    }
                    .pickerStyle(.automatic)

                    Picker(selection: $cameraOverlaySize) {
                        ForEach(CameraOverlaySize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    } label: {
                        SettingsRow(
                            title: "Size",
                            subtitle: "Diameter of the overlay.",
                            icon: .sfSymbol("magnifyingglass")
                        )
                    }

                    Picker(selection: $cameraOverlayShape) {
                        ForEach(CameraOverlayShape.allCases, id: \.self) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    } label: {
                        SettingsRow(
                            title: "Shape",
                            subtitle: "Mask shape for the overlay.",
                            icon: .sfSymbol("circle.square")
                        )
                    }
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

            SwiftUI.Section(
                header: Text("Live Streaming"),
                footer: Text("Direct RTMP streaming to Twitch, YouTube, and Kick is planned. See the streaming settings when available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            ) {
                SettingsRow(
                    title: "Broadcast via App Extensions",
                    subtitle: "Use 'Go Live' in the pause menu to stream via installed broadcast apps (e.g. Twitch).",
                    icon: .sfSymbol("dot.radiowaves.left.and.right")
                )
                SettingsRow(
                    title: "Direct RTMP Streaming",
                    subtitle: "Coming soon — stream directly to Twitch, YouTube, or Kick without a third-party app.",
                    icon: .sfSymbol("antenna.radiowaves.left.and.right")
                )
                #if os(tvOS)
                SettingsRow(
                    title: "Apple TV Requirement",
                    subtitle: "Recording and live streaming on Apple TV require a physical game controller to be connected.",
                    icon: .sfSymbol("gamecontroller.fill")
                )
                #endif
            }
        }
        .navigationTitle("Recording & Streaming")
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
    }
}
