//
//  ContentlessSetupGuideView.swift
//  PVUI
//
//  Created by Provenance on 3/15/26.
//

#if canImport(SwiftUI)
import SwiftUI
import PVThemes

/// Setup guidance for contentless cores (Doom, Wolf3D, Quake) that need
/// specific data files to run. Shown on the system page when no games
/// have been imported yet.
struct ContentlessSetupGuideView: View {
    let systemIdentifier: String
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Returns the setup instructions for known contentless systems,
    /// or nil if the system does not need special guidance.
    private var guide: SetupGuide? {
        Self.guide(for: systemIdentifier)
    }

    var body: some View {
        if let guide = guide {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    Text("Setup Required")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                }

                // Description
                Text(guide.description)
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor?.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                // Required files
                VStack(alignment: .leading, spacing: 6) {
                    Text("Required Files")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)

                    ForEach(guide.requiredFiles, id: \.self) { file in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\u{2022}")
                                .font(.system(size: 12))
                            Text(file)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor?.opacity(0.85))
                    }
                }

                // Placement hint
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                    Text(guide.placementHint)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor?.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        themeManager.currentPalette.dark
                            ? Color.blue.opacity(0.1)
                            : Color.blue.opacity(0.06)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
    }

    // MARK: - Guide Data

    struct SetupGuide {
        let description: String
        let requiredFiles: [String]
        let placementHint: String
    }

    static func guide(for systemIdentifier: String) -> SetupGuide? {
        switch systemIdentifier {
        case "com.provenance.doom":
            return SetupGuide(
                description: "Doom is a contentless core that needs WAD data files to run. These files contain the game levels, textures, and audio.",
                requiredFiles: [
                    "DOOM.WAD (Doom shareware/registered)",
                    "DOOM2.WAD (Doom II)",
                    "FreeDOOM WADs (free alternative, freedoom.github.io)"
                ],
                placementHint: "Import WAD files via the web server or Files app. They will appear as playable games."
            )
        case "com.provenance.wolf3d":
            return SetupGuide(
                description: "Wolfenstein 3D needs the original game data files to run. You also need the ecwolf.pk3 engine file placed in the BIOS folder.",
                requiredFiles: [
                    "*.WL6 files (full version: 8 files such as VSWAP.WL6, MAPHEAD.WL6, etc.)",
                    "*.WL1 files (shareware version)",
                    "*.SOD / *.SDM files (Spear of Destiny)",
                    "ecwolf.pk3 (required BIOS - download from maniacsvault.net/ecwolf/)"
                ],
                placementHint: "Import the game data files via the web server or Files app. Ensure ecwolf.pk3 is in the BIOS folder."
            )
        case "com.provenance.quake":
            return SetupGuide(
                description: "Quake needs PAK data files from the original game to run. These contain all game assets.",
                requiredFiles: [
                    "PAK0.PAK (shareware episode, available freely)",
                    "PAK1.PAK (full registered version, all episodes)"
                ],
                placementHint: "Import PAK files via the web server or Files app. Place them in the Quake ROMs folder."
            )
        default:
            return nil
        }
    }

    /// Returns true if the given system identifier has a setup guide available.
    static func hasGuide(for systemIdentifier: String) -> Bool {
        return guide(for: systemIdentifier) != nil
    }
}

#if DEBUG
struct ContentlessSetupGuideView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ContentlessSetupGuideView(systemIdentifier: "com.provenance.doom")
            ContentlessSetupGuideView(systemIdentifier: "com.provenance.quake")
            ContentlessSetupGuideView(systemIdentifier: "com.provenance.wolf3d")
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif

#endif
