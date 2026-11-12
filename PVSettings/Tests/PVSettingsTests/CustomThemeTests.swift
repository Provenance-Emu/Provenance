import Foundation
import Testing
@testable import PVSettings

struct CustomThemeTests {
    @Test("Each console preset and the custom selection round trip through Defaults")
    func selectionRoundTrip() {
        let bridge = ThemeOptionBridge()
        let options = ConsoleThemePreset.allCases.map(ThemeOption.console) + [.custom]
        for option in options {
            #expect(bridge.deserialize(bridge.serialize(option)) == option)
        }
    }

    @Test("Every palette round trips as JSON with hex colors")
    func jsonRoundTrip() throws {
        for theme in ConsoleThemePreset.allCases.map(\.theme) + [.starter] {
            let data = try JSONEncoder().encode(theme)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["background"] as? String == theme.background.hex)
            #expect(try JSONDecoder().decode(CustomTheme.self, from: data) == theme)
        }
    }

    @Test("Console text and accent colors meet 4.5:1 contrast", arguments: ConsoleThemePreset.allCases)
    func presetContrast(preset: ConsoleThemePreset) {
        let theme = preset.theme
        for background in [theme.background, theme.surface] {
            #expect(theme.text.contrastRatio(with: background) >= 4.5)
            #expect(theme.accent.contrastRatio(with: background) >= 4.5)
        }
    }

    @Test("Invalid hex colors are rejected", arguments: ["#abc", "#AAZZCC", "#+12345", "1234567", "#123456FF"])
    func rejectsInvalidColors(value: String) throws {
        let data = try JSONEncoder().encode(value)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ThemeColor.self, from: data)
        }
    }
}
