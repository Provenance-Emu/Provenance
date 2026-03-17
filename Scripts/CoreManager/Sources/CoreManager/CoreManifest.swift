import Foundation

// MARK: - BuildbotConfig

/// Configuration for the libretro buildbot download server.
struct BuildbotConfig: Codable {
    /// Base URL of the buildbot (e.g., "https://buildbot.libretro.com/nightly/apple")
    let baseURL: String
    /// Path component for iOS nightly builds (e.g., "ios-arm64/latest")
    let iosPath: String
    /// Path component for tvOS nightly builds (e.g., "tvos-arm64/latest")
    let tvosPath: String

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case iosPath = "ios_path"
        case tvosPath = "tvos_path"
    }

    /// Full base URL for iOS nightly downloads.
    var iosBase: String { "\(baseURL)/\(iosPath)" }

    /// Full base URL for tvOS nightly downloads.
    var tvosBase: String { "\(baseURL)/\(tvosPath)" }
}

// MARK: - CoreEntry

/// A single libretro core entry in the manifest.
struct CoreEntry: Codable {
    /// Core name used to derive filenames (e.g., "fceumm", "2048").
    let name: String

    /// Whether this core is included in iOS builds.
    let ios: Bool

    /// Whether this core is included in tvOS builds.
    let tvos: Bool

    /// Whether this core is allowed in App Store builds.
    /// When false, the core is commented out in appstore url lists and
    /// commented out in appstore xcfilelists.
    let appstore: Bool

    /// Whether this core is currently enabled.
    /// When false, the core appears as a commented line in ALL generated files
    /// (both url lists and xcfilelists use the same commented-line convention).
    let enabled: Bool

    /// Optional custom filename for platform-neutral builds (no _ios/_tvos suffix).
    /// For example: "flycast_libretro.dylib".
    /// When nil, the standard platform-suffixed filename is derived from `name`.
    let filename: String?

    /// Optional iOS-specific filename override (e.g., for cores with non-standard naming).
    /// Takes precedence over `filename` for iOS.
    let iosFilenameOverride: String?

    /// Optional tvOS-specific filename override (e.g., for cores with non-standard naming).
    /// Takes precedence over `filename` for tvOS.
    let tvosFilenameOverride: String?

    /// Optional human-readable reason for the appstore exclusion.
    let appstoreExcludedReason: String?

    enum CodingKeys: String, CodingKey {
        case name, ios, tvos, appstore, enabled, filename
        case iosFilenameOverride = "ios_filename"
        case tvosFilenameOverride = "tvos_filename"
        case appstoreExcludedReason = "appstore_excluded_reason"
    }

    /// Whether this core uses a platform-neutral filename (no _ios/_tvos suffix).
    var isPlatformNeutral: Bool { filename != nil }

    /// The dylib filename for iOS builds.
    var iosFilename: String {
        iosFilenameOverride ?? filename ?? "\(name)_libretro_ios.dylib"
    }

    /// The dylib filename for tvOS builds.
    var tvosFilename: String {
        tvosFilenameOverride ?? filename ?? "\(name)_libretro_tvos.dylib"
    }

    /// The full download URL for iOS.
    func iosURL(buildbot: BuildbotConfig) -> String {
        "\(buildbot.iosBase)/\(iosFilename).zip"
    }

    /// The full download URL for tvOS.
    func tvosURL(buildbot: BuildbotConfig) -> String {
        "\(buildbot.tvosBase)/\(tvosFilename).zip"
    }
}

// MARK: - CoreManifest

/// The top-level structure of `cores.yml`.
struct CoreManifest: Codable {
    let buildbot: BuildbotConfig
    let cores: [CoreEntry]

    /// Returns cores applicable to iOS builds, optionally filtered for App Store.
    func iosCores(appstore: Bool = false) -> [CoreEntry] {
        cores.filter { $0.ios && (!appstore || $0.appstore) }
    }

    /// Returns cores applicable to tvOS builds, optionally filtered for App Store.
    func tvosCores(appstore: Bool = false) -> [CoreEntry] {
        cores.filter { $0.tvos && (!appstore || $0.appstore) }
    }
}

// MARK: - YAML Loading

extension CoreManifest {
    /// Load and decode a CoreManifest from a YAML file at the given path.
    ///
    /// Uses a lightweight regex-based YAML-to-JSON converter since
    /// Foundation does not include a YAML decoder. This handles the
    /// simple flat structure of cores.yml without anchors/tags/flow collections.
    static func load(from url: URL) throws -> CoreManifest {
        let text = try String(contentsOf: url, encoding: .utf8)
        let jsonData = try yamlToJSON(text)
        let decoder = JSONDecoder()
        return try decoder.decode(CoreManifest.self, from: jsonData)
    }

    /// Minimal YAML-to-JSON converter for the subset of YAML used in cores.yml.
    private static func yamlToJSON(_ yaml: String) throws -> Data {
        // Simple line-by-line parser for the flat structure of cores.yml.
        var lines = yaml.components(separatedBy: .newlines)

        // Strip comment-only lines and blank lines for easier processing
        lines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }

        // Build a JSON string from the YAML structure
        let json = try convertYAMLLinesToJSON(lines)
        return json
    }

    private static func convertYAMLLinesToJSON(_ lines: [String]) throws -> Data {
        // This is a simplified converter for the specific structure of cores.yml.
        // It handles two levels: top-level keys and list items under "cores:".
        var result: [String: Any] = [:]
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let indent = line.prefix(while: { $0 == " " }).count
            let content = stripInlineComment(String(line.dropFirst(indent)))

            if indent == 0 {
                if content.hasSuffix(":") {
                    // Top-level mapping key with no value (e.g., "buildbot:", "cores:")
                    let key = String(content.dropLast())
                    i += 1
                    // Check what's next
                    if i < lines.count {
                        let next = lines[i]
                        let nextIndent = next.prefix(while: { $0 == " " }).count
                        let nextContent = stripInlineComment(String(next.dropFirst(nextIndent)))
                        if nextContent.hasPrefix("- ") {
                            // It's a list
                            let (list, newI) = try parseList(lines, start: i, baseIndent: nextIndent)
                            result[key] = list
                            i = newI
                        } else {
                            // It's a nested mapping
                            let (map, newI) = try parseMapping(lines, start: i, baseIndent: nextIndent)
                            result[key] = map
                            i = newI
                        }
                    }
                } else if let (key, value) = splitYAMLKeyValue(content) {
                    // Top-level "key: value"
                    result[key] = parseScalar(value)
                    i += 1
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }

        return try JSONSerialization.data(withJSONObject: result)
    }

    private static func parseMapping(_ lines: [String], start: Int, baseIndent: Int) throws -> ([String: Any], Int) {
        var map: [String: Any] = [:]
        var i = start

        while i < lines.count {
            let line = lines[i]
            let indent = line.prefix(while: { $0 == " " }).count
            if indent < baseIndent { break }

            let content = stripInlineComment(String(line.dropFirst(indent)))
            if content.hasPrefix("- ") { break }

            if content.hasSuffix(":") {
                // Bare "key:" — nested block follows
                let key = String(content.dropLast())
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                i += 1
                if i < lines.count {
                    let nextIndent = lines[i].prefix(while: { $0 == " " }).count
                    if nextIndent > baseIndent {
                        let nextContent = stripInlineComment(String(lines[i].dropFirst(nextIndent)))
                        if nextContent.hasPrefix("- ") {
                            let (list, newI) = try parseList(lines, start: i, baseIndent: nextIndent)
                            map[key] = list
                            i = newI
                        } else {
                            let (nested, newI) = try parseMapping(lines, start: i, baseIndent: nextIndent)
                            map[key] = nested
                            i = newI
                        }
                    }
                }
            } else if let (rawKey, value) = splitYAMLKeyValue(content) {
                let key = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                map[key] = parseScalar(value)
                i += 1
            } else {
                i += 1
            }
        }

        return (map, i)
    }

    private static func parseList(_ lines: [String], start: Int, baseIndent: Int) throws -> ([[String: Any]], Int) {
        var list: [[String: Any]] = []
        var i = start

        while i < lines.count {
            let line = lines[i]
            let indent = line.prefix(while: { $0 == " " }).count
            if indent < baseIndent { break }

            let content = stripInlineComment(String(line.dropFirst(indent)))
            if !content.hasPrefix("- ") { break }

            let itemContent = String(content.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            var item: [String: Any] = [:]

            // First field on same line as "- "
            if let (rawKey, value) = splitYAMLKeyValue(itemContent) {
                let key = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                item[key] = parseScalar(value)
            }

            i += 1
            // Collect subsequent fields at deeper indent
            let fieldIndent = baseIndent + 2
            while i < lines.count {
                let fLine = lines[i]
                let fIndent = fLine.prefix(while: { $0 == " " }).count
                if fIndent < fieldIndent { break }

                let fContent = stripInlineComment(String(fLine.dropFirst(fIndent)))
                if fContent.hasPrefix("- ") { break }

                if let (rawKey, value) = splitYAMLKeyValue(fContent) {
                    let key = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    item[key] = parseScalar(value)
                }
                i += 1
            }

            list.append(item)
        }

        return (list, i)
    }

    /// Split a YAML "key: value" line into (key, value), accepting any whitespace after colon.
    /// Returns nil if the content is not a valid key-value mapping.
    private static func splitYAMLKeyValue(_ s: String) -> (key: String, value: String)? {
        guard let colonIdx = s.firstIndex(of: ":") else { return nil }
        let afterColon = s.index(after: colonIdx)
        // Colon must be followed by whitespace or be at end of string
        guard afterColon == s.endIndex || s[afterColon].isWhitespace else { return nil }
        let key = String(s[s.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let value = afterColon < s.endIndex
            ? String(s[afterColon...]).trimmingCharacters(in: .whitespaces)
            : ""
        return key.isEmpty ? nil : (key, value)
    }

    private static func stripInlineComment(_ s: String) -> String {
        var inSingle = false
        var inDouble = false
        var result = ""
        for ch in s {
            if ch == "'" && !inDouble { inSingle = !inSingle }
            else if ch == "\"" && !inSingle { inDouble = !inDouble }
            else if ch == "#" && !inSingle && !inDouble { break }
            result.append(ch)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func parseScalar(_ value: String) -> Any {
        let v = value.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        switch v.lowercased() {
        case "true": return true
        case "false": return false
        case "null", "~": return NSNull()
        default: return v
        }
    }
}
