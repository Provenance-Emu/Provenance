import Foundation

/// Pure string heuristics for recovering `retro_system_info` fields from a libretro
/// dylib's `__TEXT,__cstring` table without `dlopen`.
///
/// Shared by `LibretroMetadataReader` and `PVDynamicLibretroCoreScanner` so the two
/// Mach-O probes can't drift apart.
///
/// A core defines `retro_system_info` as `{ library_name, library_version, valid_extensions }`,
/// so in the cstring table the version is normally the string immediately BEFORE
/// `valid_extensions`, right after the library name. Strings AFTER `valid_extensions`
/// belong to whatever code the linker placed next (e.g. `DEBUGBREAK!`) and are the
/// last resort.
enum LibretroCstringHeuristics {

    /// Bump whenever the heuristic changes in a way that can alter results, so metadata
    /// persisted by an older heuristic (possibly a wrong version) is re-probed.
    /// Used as the schema version of both on-disk probe caches.
    static let cacheRevision = 5

    /// Real versions can be `git describe` output such as
    /// `pre-upstream-merge-2026-10-12-23-g7957775f5` (43 chars).
    static let maxVersionLength = 64
    static let maxNameLength = 60

    struct Guess: Equatable {
        let name: String
        let version: String
    }

    /// How far (in strings) either side of `valid_extensions` the fallback search looks.
    private static let fallbackWindow = 6

    private static let extensionsRegex = try? NSRegularExpression(
        pattern: #"^[a-zA-Z0-9]{1,8}(\|[a-zA-Z0-9]{1,8})+$"#
    )
    private static let dateRegex = try? NSRegularExpression(pattern: #"^\d{4}[.\-]\d{2}[.\-]\d{2}$"#)

    // MARK: - valid_extensions

    /// Index of the first pipe-separated short-token string such as `gb|gbc|dmg`.
    static func validExtensionsIndex(in strings: [String]) -> Int? {
        strings.firstIndex(where: { s in
            let range = NSRange(s.startIndex..., in: s)
            return extensionsRegex?.firstMatch(in: s, range: range) != nil
        })
    }

    // MARK: - Name / version

    /// Picks `library_name` and `library_version` around `strings[extensionsIndex]`.
    /// Returns `nil` when no plausible library name is found.
    static func pickNameAndVersion(strings: [String], extensionsIndex extIdx: Int) -> Guess? {
        guard strings.indices.contains(extIdx) else { return nil }

        // 1. Struct order: [library_name, library_version, valid_extensions].
        if extIdx >= 2 {
            let name = strings[extIdx - 2]
            let version = strings[extIdx - 1]
            if isPlausibleName(name),
               version != name,
               isPlausibleVersion(version),
               version.contains(where: \.isNumber) {
                return Guess(name: name, version: version)
            }
        }

        // 2. Fallback: nearest-window search. Strings before valid_extensions are tried
        //    before strings after it.
        let extStr = strings[extIdx]
        let lo = max(0, extIdx - fallbackWindow)
        let hi = min(strings.count - 1, extIdx + fallbackWindow)
        let before = Array(strings[lo..<extIdx]).filter { $0 != extStr }
        let after = hi > extIdx ? Array(strings[(extIdx + 1)...hi]).filter { $0 != extStr } : []

        guard let name = (before + after).first(where: isPlausibleName) else { return nil }

        let versionsBefore = before.filter { $0 != name && isPlausibleVersion($0) }
        let versionsAfter = after.filter { $0 != name && isPlausibleVersion($0) }
        let hasLetter: (String) -> Bool = { $0.contains(where: \.isLetter) }

        let version = versionsBefore.first(where: hasLetter)
            ?? versionsAfter.first(where: hasLetter)
            ?? versionsBefore.first
            ?? versionsAfter.first
            ?? ""
        return Guess(name: name, version: version)
    }

    // MARK: - Validation

    /// Strings that look like C format specifiers, file extensions, paths or other
    /// non-name metadata that can appear in `__cstring`.
    static func looksLikeJunk(_ s: String) -> Bool {
        s.contains("%") ||                                          // printf format ("%d.mcr", "%*lld")
        s.hasPrefix(".") ||                                         // file extension (".mv", ".srm")
        s.hasPrefix("/") ||                                         // file path
        s.hasPrefix("\\") ||                                        // Windows path
        s.contains("\t") ||                                         // tab-separated data
        s.unicodeScalars.contains(where: { $0.value < 0x20 })       // control chars
    }

    /// Pure build dates such as `2024.10.29` are not library versions and would cause
    /// false save-state version-mismatch warnings.
    static func isDate(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        return dateRegex?.firstMatch(in: s, range: range) != nil
    }

    static func isPlausibleName(_ s: String) -> Bool {
        !s.contains("|") && s.count >= 2 && s.count <= maxNameLength &&
            !looksLikeJunk(s) &&
            s.first?.isLetter == true &&
            s.filter({ $0.isLetter }).count >= 2
    }

    static func isPlausibleVersion(_ s: String) -> Bool {
        !s.contains("|") && s.count >= 1 && s.count <= maxVersionLength &&
            !isDate(s) && !looksLikeJunk(s)
    }
}
