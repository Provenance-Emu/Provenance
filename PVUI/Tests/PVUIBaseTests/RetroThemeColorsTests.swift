import Testing
import UIKit
import PVThemes
@testable import PVUIBase

@Suite("Coordinated library accents")
struct RetroThemeColorsTests {
    @Test("Every built-in appearance keeps distinct accent roles", arguments: [ProvenanceThemes.dark, .light, .retrowave])
    func distinctRoles(theme: ProvenanceThemes) {
        let traits = UITraitCollection(userInterfaceStyle: theme == .light ? .light : .dark)
        let palette = theme.palette
        let primary = RetroThemeColors.resolvedColor(.primary, palette: palette, traits: traits)
        let secondary = RetroThemeColors.resolvedColor(.secondary, palette: palette, traits: traits)
        let tertiary = RetroThemeColors.resolvedColor(.tertiary, palette: palette, traits: traits)
        #expect(primary != secondary)
        #expect(primary != tertiary)
        #expect(secondary != tertiary)
    }

    @Test("The light canvas remains light and the dark canvas remains dark")
    func canvasContrast() {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let light = RetroThemeColors.resolvedColor(.background, palette: ProvenanceThemes.light.palette, traits: traits)
        let dark = RetroThemeColors.resolvedColor(.background, palette: ProvenanceThemes.dark.palette, traits: traits)
        #expect(brightness(light) > 0.9)
        #expect(brightness(dark) < 0.1)
    }

    @Test("Dark status-bar color survives palette protocol dispatch")
    func darkStatusBar() {
        let palette: any UXThemePalette = ProvenanceThemes.dark.palette
        #expect(palette.statusBarColor != nil)
        #expect(palette.statusBarColor != UIColor.white)
    }

    private func brightness(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return red * 0.299 + green * 0.587 + blue * 0.114
    }
}
