//
//  ConsoleSystemInstructionView.swift
//  PVUI
//
//  Persistent setup hints on the per-console games screen (unlike `ContentlessSetupGuideView`,
//  which only appears when the library is empty). Used for Wolf3D file layout, etc.
//

#if canImport(SwiftUI)
import SwiftUI
import PVThemes

/// Long-form instructions for specific systems (Wolf3D file layout, etc.).
struct ConsoleSystemInstructionView: View {
    let systemIdentifier: String
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        if let block = Self.content(for: systemIdentifier) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: block.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                    Text(block.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                }
                ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.currentPalette.dark ? Color.purple.opacity(0.12) : Color.purple.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.purple.opacity(0.35), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
    }

    private struct InstructionBlock {
        let iconName: String
        let title: String
        let lines: [String]
    }

    /// Returns content when this console page should show extra guidance.
    private static func content(for id: String) -> InstructionBlock? {
        switch id {
        case "com.provenance.wolf3d":
            return InstructionBlock(
                iconName: "doc.text.fill",
                title: "Wolfenstein 3D (ECWolf) — data files",
                lines: [
                    "This is not Doom: ECWolf needs Wolf3D data (VSWAP, MAPHEAD, AUDIO, etc. as .WL6 / .WL1, or Spear .SOD / .SDM) — not Doom .wad IWADs.",
                    "Engine pack: ecwolf.pk3 goes in BIOS for this system (see the BIOS strip below). When online, the app can download it from the libretro system-assets mirror.",
                    "Import all episode files into the same Wolf3D ROM folder (folder import, or select every loose file in one batch). Launch from VSWAP.WL6 or VSWAP.WL1 (shareware)."
                ]
            )
        default:
            return nil
        }
    }
}

#if DEBUG
struct ConsoleSystemInstructionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ConsoleSystemInstructionView(systemIdentifier: "com.provenance.wolf3d")
            ConsoleSystemInstructionView(systemIdentifier: "com.provenance.ps2")
        }
        .padding()
        .background(Color.black)
    }
}
#endif

#endif // canImport(SwiftUI)
