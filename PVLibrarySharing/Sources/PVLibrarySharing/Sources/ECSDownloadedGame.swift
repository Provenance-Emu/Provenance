import Foundation

/// Checks descriptor references before handing untrusted server files to the importer.
public enum ECSDownloadedGame {
    public static func validate(_ game: PulledGame) throws {
        let files = Set(game.gameFiles.map { $0.standardizedFileURL.path })
        for file in game.gameFiles {
            let ext = file.pathExtension.lowercased()
            guard ["m3u", "cue", "gdi", "toc"].contains(ext) else { continue }
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_048_576 else { throw LibrarySharingError.unsafePath(file.lastPathComponent) }
            let body = try String(contentsOf: file, encoding: .utf8).replacingOccurrences(of: "\u{feff}", with: "")
            var references: [String] = []
            for raw in body.components(separatedBy: .newlines) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if ext == "m3u" {
                    if !line.isEmpty, !line.hasPrefix("#") { references.append(line.components(separatedBy: "|")[0]) }
                } else if ext == "gdi" {
                    if line.isEmpty || Int(line) != nil { continue }
                    let pattern = #"^\d+\s+\d+\s+\d+\s+\d+\s+(?:"([^"]+)"|([^\s]+))\s+\d+\s*$"#
                    guard let reference = capture(line, pattern: pattern) else { throw LibrarySharingError.unsafePath(line) }
                    references.append(reference)
                } else if ["FILE", "DATAFILE", "AUDIOFILE"].contains(line.split(whereSeparator: { $0.isWhitespace }).first?.uppercased() ?? "") {
                    guard let reference = capture(line, pattern: #"(?i)^(?:FILE|DATAFILE|AUDIOFILE)\s+"([^"]+)""#) else {
                        throw LibrarySharingError.unsafePath(line)
                    }
                    references.append(reference)
                }
            }
            guard !references.isEmpty else { throw LibrarySharingError.unsafePath(file.lastPathComponent) }
            for reference in references {
                let reference = reference.trimmingCharacters(in: .whitespaces)
                guard !reference.isEmpty, !reference.hasPrefix("/"), !reference.contains(":"), !reference.contains("\\"),
                      files.contains(file.deletingLastPathComponent().appendingPathComponent(reference).standardizedFileURL.path) else {
                    throw LibrarySharingError.unsafePath(reference)
                }
            }
        }
    }

    private static func capture(_ line: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        for index in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: index), in: line) { return String(line[range]) }
        }
        return nil
    }
}
