//
//  ShaderCatalog.swift
//  PVShaders
//
//  Every filter the app can offer: the hand-written Provenance filters plus the
//  slang library bundled as SlangShaders/ (Scripts/shaders/fetch_slang_shaders.py).
//

import Foundation
import PVLogging
import PVSettings

/// One filter in the catalog.
public struct ShaderCatalogEntry: Identifiable, Hashable, Sendable {
    public let id: ShaderID
    public let name: String
    /// Library folder (`crt`, `handheld`, …); `ShaderCatalog.nativeCategory` for Provenance filters.
    public let category: String
    public let passes: Int
    public let historyFrames: Int
    public let usesFeedback: Bool
    public let lutCount: Int
    public let parameters: [ShaderParameterDescriptor]
    /// Unpacked preset directory; `nil` for native filters.
    public let directory: URL?

    /// Editable parameters (headings removed).
    public var editableParameters: [ShaderParameterDescriptor] { parameters.filter { !$0.isHeading } }

    /// Parameters split into titled sections for the editor.
    public var parameterGroups: [ShaderParameterGroup] { ShaderParameterGroup.groups(for: parameters) }

    /// Many passes or frame history: noticeably more GPU work per frame.
    public var isHeavy: Bool { passes >= ShaderCatalog.heavyPassCount || historyFrames > 0 || usesFeedback }

    /// The look families this filter belongs to, for the browser's filter chips.
    public var looks: Set<ShaderLook> { ShaderLook.looks(for: self) }
}

/// Broad visual families used to narrow the browser, independent of folders.
public enum ShaderLook: String, CaseIterable, Sendable, Identifiable {
    case crt, lcd, handheld, ntsc, vhs, bezel, pixelArt, smoothing, effects

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .crt: return "CRT"
        case .lcd: return "LCD"
        case .handheld: return "Handheld"
        case .ntsc: return "NTSC / PAL"
        case .vhs: return "VHS"
        case .bezel: return "Bezels"
        case .pixelArt: return "Pixel Art"
        case .smoothing: return "Smoothing"
        case .effects: return "Effects"
        }
    }

    static func looks(for entry: ShaderCatalogEntry) -> Set<ShaderLook> {
        if let option = entry.id.nativeOption {
            switch option {
            case .lcd: return [.lcd]
            case .gameBoy: return [.lcd, .handheld]
            case .vhs: return [.vhs]
            case .none: return []
            default: return [.crt]
            }
        }
        let hay = entry.id.path.lowercased()
        var looks: Set<ShaderLook> = []
        func has(_ needles: String...) -> Bool { needles.contains { hay.contains($0) } }
        if has("crt", "pvm", "bvm", "scanline", "trinitron", "lottes", "royale", "geom") { looks.insert(.crt) }
        if has("lcd", "dot", "gameboy", "gbc", "gba", "palm", "zfast-lcd") { looks.insert(.lcd) }
        if entry.category == "handheld" || has("handheld", "gameboy", "gbc", "gba", "dmg", "psp", "nds") {
            looks.insert(.handheld)
        }
        if has("ntsc", "pal/", "composite", "rf", "blargg") { looks.insert(.ntsc) }
        if has("vhs") { looks.insert(.vhs) }
        if has("bezel", "border") { looks.insert(.bezel) }
        if entry.category == "pixel-art-scaling" || entry.category == "edge-smoothing" || has("xbr", "scalefx", "hqx", "sabr", "pixel") {
            looks.insert(.pixelArt)
        }
        if ["interpolation", "anti-aliasing", "blurs", "sharpen", "denoisers", "deblur", "linear"].contains(entry.category) {
            looks.insert(.smoothing)
        }
        if ["native-metal", "misc", "reshade", "film", "cel", "dithering", "warp"].contains(entry.category) {
            looks.insert(.effects)
        }
        return looks
    }
}

/// Every filter the app can offer, searchable and grouped.
public final class ShaderCatalog: @unchecked Sendable {
    public static let shared = ShaderCatalog(libraryURL: ShaderCatalog.bundledLibraryURL)

    /// Category of the hand-written Provenance filters.
    public static let nativeCategory = "provenance"
    /// Pass count at which a preset is labelled heavy.
    public static let heavyPassCount = 6
    /// Folder name of the bundled library inside the app bundle.
    public static let bundledFolderName = "SlangShaders"

    static var bundledLibraryURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent(bundledFolderName, isDirectory: true)
    }

    /// All usable entries: native filters first, then the library sorted by id.
    public let entries: [ShaderCatalogEntry]
    private let byID: [ShaderID: ShaderCatalogEntry]

    public init(libraryURL: URL?) {
        var entries = Self.nativeEntries()
        if let libraryURL {
            entries += Self.loadLibrary(at: libraryURL)
        }
        self.entries = entries
        byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func entry(for id: ShaderID) -> ShaderCatalogEntry? { byID[id] }

    /// Categories in display order: Provenance first, then the library folders alphabetically.
    public var categories: [String] {
        var seen = Set<String>()
        let ordered = entries.map(\.category).filter { seen.insert($0).inserted }
        return [Self.nativeCategory] + ordered.filter { $0 != Self.nativeCategory }
            .sorted { Self.categoryTitle($0).localizedCaseInsensitiveCompare(Self.categoryTitle($1)) == .orderedAscending }
    }

    /// Entries matching `query` (name, category and path, case/diacritic-insensitive)
    /// and every look in `looks`.
    public func search(_ query: String, looks: Set<ShaderLook> = []) -> [ShaderCatalogEntry] {
        let terms = query.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        return entries.filter { entry in
            guard looks.isSubset(of: entry.looks) else { return false }
            let hay = "\(entry.name) \(Self.categoryTitle(entry.category)) \(entry.id.path)"
            return terms.allSatisfy { hay.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// Display title for a category folder.
    public static func categoryTitle(_ category: String) -> String {
        switch category {
        case nativeCategory: return "Provenance"
        case "native-metal": return "Provenance Effects"
        case "crt": return "CRT"
        case "ntsc": return "NTSC"
        case "pal": return "PAL"
        case "vhs": return "VHS"
        case "gpu": return "GPU"
        case "subframe-bfi": return "Subframe BFI"
        case "nes_raw_palette": return "NES Raw Palette"
        case "stereoscopic-3d": return "Stereoscopic 3D"
        case "": return "Other"
        default:
            return category.split(whereSeparator: { $0 == "-" || $0 == "_" })
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    // MARK: - Loading

    static func nativeEntries() -> [ShaderCatalogEntry] {
        MetalFilterSelectionOption.allCases.filter { $0 != .none }.map { option in
            ShaderCatalogEntry(id: .native(option), name: option.description, category: nativeCategory,
                               passes: 1, historyFrames: 0, usesFeedback: false, lutCount: 0,
                               parameters: NativeShaderParameters.descriptors(for: option), directory: nil)
        }
    }

    struct Manifest: Decodable {
        struct Preset: Decodable {
            let id: String
            let name: String
            let category: String
            let passes: Int
            let history: Int
            let feedback: Bool
            let luts: Int
            let parameters: [ShaderParameterDescriptor]
            let excluded: String?
        }
        let formatVersion: Int
        let presets: [Preset]
    }

    static let manifestName = "manifest.json"
    static let supportedFormatVersion = 1

    static func loadLibrary(at url: URL) -> [ShaderCatalogEntry] {
        let manifestURL = url.appendingPathComponent(manifestName)
        guard let data = try? Data(contentsOf: manifestURL) else {
            WLOG("Shader library: no manifest at \(manifestURL.path)")
            return []
        }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            guard manifest.formatVersion == supportedFormatVersion else {
                ELOG("Shader library: manifest format \(manifest.formatVersion), expected \(supportedFormatVersion)")
                return []
            }
            return manifest.presets.filter { $0.excluded == nil }.map { preset in
                ShaderCatalogEntry(id: .slang(preset.id), name: preset.name, category: preset.category,
                                   passes: preset.passes, historyFrames: preset.history,
                                   usesFeedback: preset.feedback, lutCount: preset.luts,
                                   parameters: preset.parameters,
                                   directory: url.appendingPathComponent(preset.id, isDirectory: true))
            }
        } catch {
            ELOG("Shader library: unreadable manifest: \(error)")
            return []
        }
    }
}
