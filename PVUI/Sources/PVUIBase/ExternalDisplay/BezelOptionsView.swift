//
//  BezelOptionsView.swift
//  PVUI
//
//  Settings page for the TV or bezel around the game picture.
//

#if os(iOS) || os(tvOS)
import Defaults
import PVSettings
import SkinKitBezelsUI
import SwiftUI

/// The bezel settings outside a game: the choice for every game, room light and game artwork.
/// In a game the pause menu's switcher edits the same choice.
public struct BezelOptionsView: View {
    @Default(.externalDisplayBezel) private var bezelID
    /// Stored only once the player sets it; until then it goes by the device.
    @Default(.externalDisplayBezelLightsRoom) private var storedLightsRoom
    @Default(.externalDisplayBezelSeat) private var seat
    @Default(.externalDisplayGameBezels) private var gameBezels

    public init() {
        ProvenanceBezels.configure()
    }

    private var choiceName: String {
        switch bezelID {
        case ExternalDisplayBezelRules.automaticBezelID: return String(localized: "Automatic")
        case ExternalDisplayBezelRules.noBezelID: return String(localized: "None")
        default: return TVBezelCatalog.bezel(id: bezelID)?.name ?? String(localized: "None")
        }
    }

    public var body: some View {
        Form {
            Section {
                NavigationLink {
                    TVBezelPickerView(selection: Binding(get: { bezelID },
                                                         set: { bezelID = $0 ?? ExternalDisplayBezelRules.noBezelID }),
                                      offersSystemAutomatic: true)
                } label: {
                    LabeledContent(String(localized: "Bezel"), value: choiceName)
                }
                Toggle(String(localized: "Light the Room"),
                       isOn: Binding(get: { storedLightsRoom ?? TVBezelRoomLight.gpuIsRecent },
                                     set: { storedLightsRoom = $0 }))
                Picker(String(localized: "Seat"), selection: $seat) {
                    ForEach(TVBezelSeat.allCases, id: \.self) { Text($0.name).tag($0) }
                }
            } footer: {
                Text("Automatic shows a TV for consoles and computers in landscape, and none for handhelds. "
                     + "Lighting the room takes more graphics power; turn it off if the picture stutters. "
                     + "Seat is how close you sit to a built-in TV: Whole Room shows all of it, with bars on a screen that is not 16:9.")
            }

            Section {
                Toggle(String(localized: "Game Bezels"), isOn: $gameBezels)
                NavigationLink(String(localized: "The Bezel Project")) {
                    BezelProjectBrowserView(game: nil)
                }
            } footer: {
                Text("Automatically look for matching artwork from The Bezel Project.")
            }
        }
        .navigationTitle(String(localized: "Bezels"))
    }
}
#endif
