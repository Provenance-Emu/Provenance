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
    @Default(.externalDisplayBezel) private var bezelID
    @Default(.externalDisplayBezelMatchesSystem) private var bezelMatchesSystem
    @Default(.externalDisplayBezelLightsRoom) private var bezelLightsRoom
    @Default(.externalDisplayGameBezels) private var gameBezels
    @Default(.externalDisplayBezelByGame) private var pins
    @Default(.hideOnScreenControlsWithController) private var hideControlsWithController
    private let store = ShaderLibraryStore.shared
    /// The running game, when the options are open over one.
    private let game: ExternalDisplayGameContext?
    /// What surrounds the running game's picture right now.
    private let showing: () -> TVBezel?
    /// Bumped when the bezel library changes, so names and the summary are read again.
    @State private var libraryRevision = 0

    /// - Parameters:
    ///   - game: the running game, to choose a TV for it alone. `nil` in Settings.
    ///   - showing: the TV around that game's picture now (`PVEmulatorViewController.externalDisplayBezel`).
    public init(game: ExternalDisplayGameContext? = nil, showing: @escaping () -> TVBezel? = { nil }) {
        self.game = game
        self.showing = showing
    }

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
                if let game {
                    Section {
                        NavigationLink {
                            TVBezelPickerView(selection: pin(for: game), allowsAutomatic: true, game: game)
                        } label: {
                            LabeledContent(String(localized: "This Game"), value: showingSummary(for: game).name)
                        }
                    } header: {
                        Text("Around the Picture")
                    } footer: {
                        Text(showingSummary(for: game).reason)
                    }
                }

                Section {
                    NavigationLink {
                        TVBezelPickerView(selection: Binding(get: { bezelID }, set: { bezelID = $0 ?? ExternalDisplayBezelRules.noBezelID }))
                    } label: {
                        LabeledContent(String(localized: "TV"), value: chosenBezel?.name ?? String(localized: "None"))
                    }
                    if hasBezel {
                        Toggle(String(localized: "Match the System's Screen"), isOn: $bezelMatchesSystem)
                        Toggle(String(localized: "Light the Room"), isOn: $bezelLightsRoom)
                    }
                } header: {
                    Text(game == nil ? "Around the Picture" : "For Every Game")
                } footer: {
                    Text(hasBezel
                         ? "Systems with a screen of their own, such as home computers, use that TV instead of this one. "
                           + "Lighting the room applies to the built-in TVs and takes more graphics power; turn it off if the picture stutters."
                         : "Puts the game inside an old TV, with the picture reflected in its frame, or inside a bezel you import.")
                }

                Section {
                    Toggle(String(localized: "Game Bezels"), isOn: $gameBezels)
                    NavigationLink(String(localized: "The Bezel Project")) {
                        BezelProjectBrowserView(game: game)
                    }
                } footer: {
                    Text("Shows artwork made for the game you are playing, from The Bezel Project, downloaded the first time you play it. "
                         + "A game with none shows your TV.")
                }

                if !hasBezel {
                    Section {
                        Picker(String(localized: "Skin Around the Picture"), selection: $externalSkin) {
                            ForEach(ExternalDisplaySkin.allCases, id: \.self) { choice in
                                Text(choice.displayName).tag(choice)
                            }
                        }
                    } footer: {
                        Text("Draws this device's skin around the picture as artwork, when the skin has a landscape layout "
                             + "that frames the game screen. Real skins are the ones you installed.")
                    }
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
                        ExternalDisplayFilterPicker(insideTV: hasGlassTV)
                    } label: {
                        LabeledContent(String(localized: "Screen Filter"), value: filterSummary)
                    }
                } footer: {
                    Text(hasGlassTV
                         ? "The filter runs inside the TV's glass. Each TV comes with a look of its own, used until you pick another. "
                           + "Cores that draw into their own view, such as Dolphin and Azahar, are always mirrored."
                         : "The external display can use a different filter from this device. "
                           + "Cores that draw into their own view, such as Dolphin and Azahar, are always mirrored.")
                }
            }
        }
        .navigationTitle(String(localized: "External Display"))
        .onReceive(NotificationCenter.default.publisher(for: TVBezelLibrary.didChangeNotification)) { _ in
            libraryRevision += 1
        }
        .task { TVBezelLibrary.shared.refreshIfNeeded() }
    }

    private var chosenBezel: TVBezel? {
        // Read so a library change redraws the names.
        _ = libraryRevision
        return TVBezelCatalog.bezel(id: bezelID)
    }

    /// A TV is chosen (the one shown may be another, when the system has a screen of its own).
    private var hasBezel: Bool { chosenBezel != nil }

    /// The chosen TV is a built-in one, with glass and a look of its own.
    private var hasGlassTV: Bool {
        chosenBezel.map { $0.image == nil } ?? false
    }

    /// The TV pinned to `game`: `nil` is automatic.
    private func pin(for game: ExternalDisplayGameContext) -> Binding<String?> {
        Binding(get: { pins[game.md5] }, set: { pins[game.md5] = $0 })
    }

    /// What surrounds the running game's picture, and which rule put it there.
    private func showingSummary(for game: ExternalDisplayGameContext) -> (name: String, reason: String) {
        _ = libraryRevision
        let bezel = showing()
        let name = bezel?.name ?? String(localized: "None")
        if pins[game.md5] != nil {
            return (name, String(localized: "Chosen for this game."))
        }
        guard let bezel else {
            return (name, String(localized: "No TV is chosen and this game has no artwork of its own."))
        }
        if bezel.source == .bezelProject, !bezel.isListed {
            return (name, String(localized: "Game art from The Bezel Project."))
        }
        return (name, bezel.id == bezelID ? String(localized: "Your TV.") : String(localized: "The system's screen."))
    }

    private var filterSummary: String {
        switch store.selection(for: .screen(.external)) {
        case nil:
            return hasGlassTV ? String(localized: "The TV's Own") : String(localized: "Same as Device")
        case .always(let id):
            guard let entry = ShaderCatalog.shared.entry(for: id) else { return String(localized: "Off") }
            // A filter with a frame of its own cannot go inside a TV.
            if hasBezel, TVBezelShader.isBezelFilter(entry) { return String(localized: "Off (has its own frame)") }
            return entry.displayName
        case .off, .auto, .skinFilter:
            return String(localized: "Off")
        }
    }
}

/// Picks the external display's own filter, or hands it back to the game's.
private struct ExternalDisplayFilterPicker: View {
    /// A TV surrounds the picture, so an unset filter means the TV's own look.
    let insideTV: Bool
    private let store = ShaderLibraryStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if store.selection(for: .screen(.external)) != nil {
                Button(insideTV ? String(localized: "Use the TV's own look") : String(localized: "Use the same filter as this device")) {
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
    let emulatorVC: PVEmulatorViewController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExternalDisplayOptionsView(game: emulatorVC.externalDisplayGameContext) { [weak emulatorVC] in
                guard let emulatorVC, emulatorVC.externalDisplayPlan.bezelOnExternalDisplay else { return nil }
                return emulatorVC.externalDisplayBezel
            }
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
