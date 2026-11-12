//
//  ExternalDisplayOptionsView.swift
//  PVUI
//
//  What an external display and the device show during a game. Shared by Settings and
//  the pause menu.
//

#if os(iOS)
import SwiftUI
import Defaults
import PVSettings
import PVShaders

/// The external display options. Every change applies to a running game at once
/// (`PVEmulatorViewController.observeExternalDisplay`).
public struct ExternalDisplayOptionsView: View {
    @Default(.externalDisplayMode) private var mode
    @Default(.externalDisplayDevicePicture) private var devicePicture
    @Default(.externalDisplaySkin) private var externalSkin
    @Default(.hideOnScreenControlsWithController) private var hideControlsWithController
    private let store = ShaderLibraryStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                Picker(String(localized: "External display shows"), selection: $mode) {
                    ForEach(ExternalDisplayMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("On the External Display")
            } footer: {
                Text(mode.subtitle)
            }

            if mode == .dedicated {
                Section {
                    Picker(String(localized: "Skin Around the Picture"), selection: $externalSkin) {
                        ForEach(ExternalDisplaySkin.allCases, id: \.self) { choice in
                            Text(choice.displayName).tag(choice)
                        }
                    }
                } footer: {
                    Text("Draws this device's skin around the picture as artwork, when the skin has a landscape layout that frames the game screen. Real skins are the ones you installed.")
                }

                Section {
                    Picker(String(localized: "Game picture on this device"), selection: $devicePicture) {
                        ForEach(ExternalDisplayDevicePicture.allCases, id: \.self) { choice in
                            Text(choice.displayName).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Game Picture on This Device")
                } footer: {
                    Text("Auto keeps the picture here when you play with a controller or a skin with its own artwork, and hides it when this device only shows touch controls.")
                }

                Section {
                    Toggle(String(localized: "Hide Touch Controls with a Controller"), isOn: $hideControlsWithController)
                } header: {
                    Text("Controls on This Device")
                } footer: {
                    Text("Turn off to keep the touch controls on this device while a hardware controller is connected.")
                }

                Section {
                    NavigationLink {
                        ExternalDisplayFilterPicker()
                    } label: {
                        LabeledContent(String(localized: "Screen Filter"), value: filterSummary)
                    }
                } footer: {
                    Text("The external display can use a different filter from this device. Cores that draw into their own view, such as Dolphin and Azahar, are always mirrored.")
                }
            }
        }
        .navigationTitle(String(localized: "External Display"))
    }

    private var filterSummary: String {
        switch store.selection(for: .screen(.external)) {
        case nil:
            return String(localized: "Same as Device")
        case .always(let id):
            return ShaderCatalog.shared.entry(for: id)?.displayName ?? String(localized: "Off")
        case .off, .auto, .skinFilter:
            return String(localized: "Off")
        }
    }
}

/// Picks the external display's own filter, or hands it back to the game's.
private struct ExternalDisplayFilterPicker: View {
    private let store = ShaderLibraryStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if store.selection(for: .screen(.external)) != nil {
                Button(String(localized: "Use the same filter as this device")) {
                    store.setSelection(nil, for: .screen(.external))
                }
                .font(.footnote)
                .padding(.vertical, 8)
            }
            ShaderBrowserView(current: store.selection(for: .screen(.external)).map(ShaderBrowserChoice.init)) { choice in
                store.setSelection(choice.selection, for: .screen(.external))
            }
        }
        .shaderPreviews()
        .navigationTitle(String(localized: "External Display Filter"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The options as a sheet over a paused game.
struct ExternalDisplayPauseSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExternalDisplayOptionsView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done")) { dismiss() }
                    }
                }
        }
        // Leave the game visible above the sheet so changes show on it.
        .presentationDetents([.medium, .large])
    }
}
#endif
