// WhatsNewLoader.swift
// PVSwiftUI
//
// Loads WhatsNew version data from whats-new.json (PVUI bundle resource).
// Agents can add new release notes by editing whats-new.json without touching Swift code.
//
// JSON schema per entry:
//   {
//     "version": "3.4.0",          -- semver string matching CFBundleShortVersionString
//     "title": "Feature Title",    -- shown as the sheet heading
//     "features": [
//       {
//         "symbolName": "gamecontroller.fill",  -- SF Symbol name
//         "symbolColor": "blue",                -- named color (see color(from:)) or hex "#RRGGBB"
//         "title": "Feature Name",
//         "subtitle": "One-sentence description"
//       }
//     ]
//   }

#if canImport(WhatsNewKit)
import WhatsNewKit
import SwiftUI
import PVLogging

// MARK: - JSON model

private struct WhatsNewJSONEntry: Codable {
    let version: String
    let title: String
    let features: [FeatureJSON]

    struct FeatureJSON: Codable {
        let symbolName: String
        let symbolColor: String
        let title: String
        let subtitle: String
    }
}

// MARK: - Loader

/// Loads `WhatsNew` entries from the bundled `whats-new.json` resource.
///
/// Usage in `ProvenanceApp`:
/// ```swift
/// var whatsNewCollection: WhatsNewCollection {
///     WhatsNewLoader.loadAll(
///         primaryActionBackground: ThemeManager.shared.currentPalette.switchON?.swiftUIColor ?? .accentColor,
///         primaryActionForeground: ThemeManager.shared.currentPalette.switchThumb?.swiftUIColor ?? .white
///     )
/// }
/// ```
public enum WhatsNewLoader {

    /// Loads all version entries from `whats-new.json` in the PVUI module bundle.
    ///
    /// - Parameters:
    ///   - primaryActionBackground: Background color of the "Continue" button.
    ///   - primaryActionForeground: Foreground/text color of the "Continue" button.
    /// - Returns: Array of `WhatsNew` values in JSON order (oldest → newest).
    /// Decoded once per process, on first access.
    ///
    /// `loadAll` is called from `ProvenanceApp.body`, which SwiftUI re-evaluates
    /// every time the observed `AppState` publishes — and the boot sequence
    /// publishes progress repeatedly while the splash is up. Without this cache
    /// the bundle read plus `JSONDecoder` ran on the main thread once per
    /// re-evaluation, throughout the launch window. The colour-dependent mapping
    /// below stays per-call so a theme change is still reflected.
    private static let decodedEntries: [WhatsNewJSONEntry] = {
        guard let url = Bundle.module.url(forResource: "whats-new", withExtension: "json") else {
            ELOG("WhatsNewLoader: whats-new.json not found in PVUI bundle")
            return []
        }

        guard let data = try? Data(contentsOf: url) else {
            ELOG("WhatsNewLoader: failed to read whats-new.json")
            return []
        }

        do {
            return try JSONDecoder().decode([WhatsNewJSONEntry].self, from: data)
        } catch {
            ELOG("WhatsNewLoader: JSON decode error — \(error)")
            return []
        }
    }()

    public static func loadAll(
        primaryActionBackground: Color = .accentColor,
        primaryActionForeground: Color = .white
    ) -> [WhatsNew] {
        return decodedEntries.compactMap { entry in
            let features: [WhatsNew.Feature] = entry.features.map { f in
                WhatsNew.Feature(
                    image: .init(systemName: f.symbolName, foregroundColor: color(from: f.symbolColor)),
                    title: WhatsNew.Text(f.title),
                    subtitle: WhatsNew.Text(f.subtitle)
                )
            }
            return WhatsNew(
                version: .init(stringLiteral: entry.version),
                title: WhatsNew.Title(stringLiteral: entry.title),
                features: features,
                primaryAction: .init(
                    title: "Continue",
                    backgroundColor: primaryActionBackground,
                    foregroundColor: primaryActionForeground,
                    hapticFeedback: .notification(.success)
                )
            )
        }
    }

    // MARK: - Color helper

    /// Maps color name strings (from JSON) to SwiftUI `Color` values.
    /// Accepts standard color names (case-insensitive) or 6-digit hex strings prefixed with `#`.
    private static func color(from name: String) -> Color {
        switch name.lowercased() {
        case "blue":            return .blue
        case "green":           return .green
        case "orange":          return .orange
        case "purple":          return .purple
        case "red":             return .red
        case "pink":            return .pink
        case "yellow":          return .yellow
        case "gray", "grey":    return .gray
        case "white":           return .white
        case "black":           return .black
        case "teal":            return .teal
        case "indigo":          return .indigo
        case "mint":            return .mint
        case "cyan":            return .cyan
        case "brown":           return .brown
        default:
            if name.hasPrefix("#"), name.count == 7,
               let rgb = UInt32(name.dropFirst(), radix: 16) {
                let r = Double((rgb >> 16) & 0xFF) / 255
                let g = Double((rgb >>  8) & 0xFF) / 255
                let b = Double( rgb        & 0xFF) / 255
                return Color(red: r, green: g, blue: b)
            }
            WLOG("WhatsNewLoader: unknown color '\(name)', falling back to accentColor")
            return .accentColor
        }
    }
}
#endif
