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

    private static let sectionSpacing: CGFloat = 24

    private static func clipDurationLabel(for seconds: Int) -> String {
        clipDurationOptions.first { $0.value == seconds }?.label ?? "\(seconds) seconds"
    }

    var body: some View {
        ZStack {
            RetroSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    #if os(tvOS)
                    if !gamepadManager.hasPhysicalGamepad {
                        infoRow(
                            title: "Controller Required",
                            subtitle: "Connect a game controller to enable recording and live streaming on Apple TV.",
                            icon: "gamecontroller.fill"
                        )
                    }
                    #endif

                    audioSection
                    #if os(iOS)
                    cameraSection
                    #endif
                    storageSection
                    hudSection
                    clipDurationSection
                    streamingSection
                }
                .tvOSSettingsHorizontalPadding()
                #if os(tvOS)
                .padding(.vertical, 24)
                #else
                .padding()
                #endif
            }
        }
        .navigationTitle("Recording & Streaming")
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }

    // MARK: - Sections

    private var audioSection: some View {
        SettingsPageSection(icon: "mic", title: "Audio") {
            ThemedToggle(isOn: $recordingMicEnabled) {
                SettingsRow(
                    title: "Microphone",
                    subtitle: "Include microphone audio in recordings.",
                    icon: .sfSymbol("mic.fill"),
                    showChevron: false
                )
            }
        }
    }

#if os(iOS)
    private var cameraSection: some View {
        SettingsPageSection(icon: "camera", title: "Camera Overlay") {
            ThemedToggle(isOn: $recordingCameraEnabled) {
                SettingsRow(
                    title: "Face-Cam Overlay",
                    subtitle: "Show a front-camera picture-in-picture during recordings.",
                    icon: .sfSymbol("camera.fill"),
                    showChevron: false
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
                        icon: .sfSymbol("pip"),
                        showChevron: false
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
                        icon: .sfSymbol("magnifyingglass"),
                        showChevron: false
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
                        icon: .sfSymbol("circle.square"),
                        showChevron: false
                    )
                }
            }
        }
    }
#endif

    private var storageSection: some View {
        SettingsPageSection(
            icon: "externaldrive",
            title: "Storage",
            footer: "Preference saved; automatic save on recording stop will be applied in a future update."
        ) {
            ThemedToggle(isOn: $recordingAutoSave) {
                SettingsRow(
                    title: "Auto-save to Photos",
                    subtitle: "Automatically save completed recordings to the Photos library.",
                    icon: .sfSymbol("photo.on.rectangle.angled"),
                    showChevron: false
                )
            }
        }
    }

    private var hudSection: some View {
        SettingsPageSection(
            icon: "display",
            title: "HUD",
            footer: "Preference saved; HUD overlay integration will be applied in a future update."
        ) {
            ThemedToggle(isOn: $showRecordingOSD) {
                SettingsRow(
                    title: "Show Recording Button in HUD",
                    subtitle: "Display the recording start/stop button in the in-game overlay.",
                    icon: .sfSymbol("record.circle"),
                    showChevron: false
                )
            }
        }
    }

    private var clipDurationSection: some View {
        SettingsPageSection(
            icon: "timer",
            title: "Clip Duration",
            footer: "Default length for each recording clip. Clip buffer enforcement will be applied in a future update."
        ) {
            SettingsChoiceGroup(
                title: "Length",
                caption: "How long each recording clip runs by default.",
                icon: "scissors",
                options: Self.clipDurationOptions.map { $0.value },
                optionTitle: { Self.clipDurationLabel(for: $0) },
                selection: $recordingClipDuration
            )
        }
    }

    private var streamingSection: some View {
        SettingsPageSection(
            icon: "dot.radiowaves.left.and.right",
            title: "Live Streaming",
            footer: "Direct RTMP streaming to Twitch, YouTube, and Kick is planned. See the streaming settings when available."
        ) {
            infoRow(
                title: "Broadcast via App Extensions",
                subtitle: "Use 'Go Live' in the pause menu to stream via installed broadcast apps (e.g. Twitch).",
                icon: "dot.radiowaves.left.and.right"
            )
            infoRow(
                title: "Direct RTMP Streaming",
                subtitle: "Coming soon — stream directly to Twitch, YouTube, or Kick without a third-party app.",
                icon: "antenna.radiowaves.left.and.right"
            )
            #if os(tvOS)
            infoRow(
                title: "Apple TV Requirement",
                subtitle: "Recording and live streaming on Apple TV require a physical game controller to be connected.",
                icon: "gamecontroller.fill"
            )
            #endif
        }
    }

    /// A static informational row. Focusable on tvOS so a page that ends in info rows can still scroll to them.
    @ViewBuilder
    private func infoRow(title: String, subtitle: String, icon: String) -> some View {
        let row = SettingsRow(title: title, subtitle: subtitle, icon: .sfSymbol(icon), showChevron: false)
        #if os(tvOS)
        row.focusable()
        #else
        row
        #endif
    }
}
