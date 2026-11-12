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

    @Test("CGA highlights keep the primary accent hue", arguments: CGAThemes.allCases)
    func cgaAccentHue(theme: CGAThemes) {
        let palette = theme.palette
        let traits = UITraitCollection(userInterfaceStyle: palette.dark ? .dark : .light)
        let primary = RetroThemeColors.resolvedColor(.primary, palette: palette, traits: traits)
        for role in [RetroThemeColors.Role.secondary, .tertiary] {
            let accent = RetroThemeColors.resolvedColor(role, palette: palette, traits: traits)
            #expect(abs(hue(accent) - hue(primary)) < 0.001)
        }
    }

    @Test("The light canvas remains light and the dark canvas remains dark")
    func canvasContrast() {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let light = RetroThemeColors.resolvedColor(.background, palette: ProvenanceThemes.light.palette, traits: traits)
        let dark = RetroThemeColors.resolvedColor(.background, palette: ProvenanceThemes.dark.palette, traits: traits)
        #expect(brightness(light) > 0.9)
        #expect(brightness(dark) < 0.1)
    }

    #if !os(tvOS)
    @Test("Dark status-bar color survives palette protocol dispatch")
    func darkStatusBar() {
        let palette: any UXThemePalette = ProvenanceThemes.dark.palette
        #expect(palette.statusBarColor != nil)
        #expect(palette.statusBarColor != UIColor.white)
    }
    #endif

    private func hue(_ color: UIColor) -> CGFloat {
        var value: CGFloat = 0
        color.getHue(&value, saturation: nil, brightness: nil, alpha: nil)
        return value
    }

    private func brightness(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return red * 0.299 + green * 0.587 + blue * 0.114
    }
}
