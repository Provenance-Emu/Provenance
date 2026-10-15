//
//  MultiFileImportSet.swift
//  PVLibrary
//
//  Pure rules for games that arrive as several files, one at a time (a sibling
//  app's share sheet hands over a .gdi and then each track, an .m3u and then each
//  disc, a NAOMI zip and then its GD-ROM CHD). Foundation only, no file system:
//  `MultiFileImportGate` gathers the inputs and applies the results.
//
//  The settle rule:
//  1. Nothing is decided until the import folder has been quiet (no new file)
//     for `quietWindow` seconds.
//  2. Then the fix-ups run: a track renamed on a name clash (`track01-1.bin`) is
//     renamed back when the original name is free, or the index file's reference
//     is rewritten to the renamed copy; a flat NAOMI GD-ROM CHD is nested under
//     its zip's stem.
//  3. An index file (cue, gdi, m3u) whose references all exist is released with
//     every file it references, index first. One with a missing reference is held
//     until `incompleteSetTimeout` seconds after the last arrival, then released
//     as it is (the importer reports it as partial).
//  4. A file no index references is released, except a GDI-style track
//     (`.raw`, `trackNN.bin`), which is held like an incomplete set because its
//     index may still be on the way.
//

import Foundation

// MARK: - Index files

/// A file that lists other files a game needs.
public enum MultiFileIndexKind: String, CaseIterable, Sendable {
    case cue
    case gdi
    case m3u

    public init?(fileName: String) {
        self.init(rawValue: (fileName as NSString).pathExtension.lowercased())
    }
}

/// Reads and rewrites the file references inside cue sheets, GDI track tables and m3u playlists.
public enum MultiFileIndexReferences {

    /// The files `contents` references, in order, as written (relative to the index file).
    /// m3u entries are reduced to their last path component, as the importer does.
    public static func referencedFiles(of kind: MultiFileIndexKind, contents: String) -> [String] {
        lines(of: contents).compactMap { line in
            reference(in: line.text, kind: kind, isFirstLine: line.isFirst)?.name
        }
    }

    /// `contents` with every reference to `oldName` (case-insensitive) replaced by `newName`.
    /// Line endings and every other line are kept as they are.
    public static func rewritingReference(
        in contents: String,
        kind: MultiFileIndexKind,
        from oldName: String,
        to newName: String
    ) -> String {
        var output: [String] = []
        for line in lines(of: contents) {
            guard let found = reference(in: line.text, kind: kind, isFirstLine: line.isFirst),
                  found.name.caseInsensitiveCompare(oldName) == .orderedSame else {
                output.append(line.text + line.ending)
                continue
            }
            let replacement: String
            switch kind {
            case .cue:
                replacement = "\"\(newName)\""
            case .gdi:
                replacement = newName.contains(" ") ? "\"\(newName)\"" : newName
            case .m3u:
                let prefix = found.name == found.token ? "" : String(found.token.dropLast(found.name.count))
                replacement = prefix + newName
            }
            let text = line.text
            let rewritten = text.replacingCharacters(in: found.range, with: replacement)
            output.append(rewritten + line.ending)
        }
        return output.joined()
    }

    // MARK: Parsing

    private struct Line {
        let text: String
        let ending: String
        let isFirst: Bool
    }

    /// Splits on \n, \r\n and \r, keeping each line's own ending so a rewrite is byte-faithful.
    private static func lines(of contents: String) -> [Line] {
        var result: [Line] = []
        var current = ""
        var iterator = contents.makeIterator()
        var pending: Character? = iterator.next()
        while let character = pending {
            pending = iterator.next()
            if character == "\r\n" || character == "\n" || character == "\r" {
                result.append(Line(text: current, ending: String(character), isFirst: result.isEmpty))
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            result.append(Line(text: current, ending: "", isFirst: result.isEmpty))
        }
        return result
    }

    private struct Found {
        /// The file name as the index means it (quotes and m3u path prefix removed).
        let name: String
        /// The text the range covers (quotes included).
        let token: String
        let range: Range<String.Index>
    }

    private static let quoteCharacters: Set<Character> = ["\"", "\u{201C}", "\u{201D}"]

    private static func reference(in line: String, kind: MultiFileIndexKind, isFirstLine: Bool) -> Found? {
        switch kind {
        case .cue: return cueReference(in: line)
        case .gdi: return isFirstLine ? nil : gdiReference(in: line)
        case .m3u: return m3uReference(in: line)
        }
    }

    /// `FILE "name.bin" BINARY` or `FILE name.bin BINARY`.
    private static func cueReference(in line: String) -> Found? {
        guard let start = line.firstIndex(where: { !$0.isWhitespace }),
              line[start...].uppercased().hasPrefix("FILE") else { return nil }
        let afterKeyword = line.index(start, offsetBy: 4)
        guard afterKeyword < line.endIndex, line[afterKeyword].isWhitespace else { return nil }
        guard let nameStart = line[afterKeyword...].firstIndex(where: { !$0.isWhitespace }) else { return nil }
        if quoteCharacters.contains(line[nameStart]) {
            return quoted(in: line, from: nameStart)
        }
        // Unquoted: everything up to the file type, the last word.
        let rest = line[nameStart...]
        guard let lastSpace = rest.lastIndex(where: { $0.isWhitespace }) else { return nil }
        let nameEnd = rest[..<lastSpace].lastIndex(where: { !$0.isWhitespace }).map { line.index(after: $0) } ?? nameStart
        guard nameEnd > nameStart else { return nil }
        let name = String(line[nameStart..<nameEnd])
        return Found(name: name, token: name, range: nameStart..<nameEnd)
    }

    /// `<track> <lba> <type> <sector size> <file name> <offset>`; the name may be quoted and contain spaces.
    private static func gdiReference(in line: String) -> Found? {
        var index = line.startIndex
        for _ in 0..<4 {
            guard let fieldStart = line[index...].firstIndex(where: { !$0.isWhitespace }) else { return nil }
            let fieldEnd = line[fieldStart...].firstIndex(where: { $0.isWhitespace }) ?? line.endIndex
            guard Int(line[fieldStart..<fieldEnd]) != nil else { return nil }
            index = fieldEnd
        }
        guard let nameStart = line[index...].firstIndex(where: { !$0.isWhitespace }) else { return nil }
        if quoteCharacters.contains(line[nameStart]) {
            return quoted(in: line, from: nameStart)
        }
        // Unquoted: everything up to the trailing offset field (names with spaces exist in the wild).
        let rest = line[nameStart...]
        let trimmedEnd = rest.lastIndex(where: { !$0.isWhitespace }).map { line.index(after: $0) } ?? line.endIndex
        let body = line[nameStart..<trimmedEnd]
        var nameEnd = trimmedEnd
        if let lastSpace = body.lastIndex(where: { $0.isWhitespace }), Int(body[body.index(after: lastSpace)...]) != nil {
            nameEnd = body[..<lastSpace].lastIndex(where: { !$0.isWhitespace }).map { line.index(after: $0) } ?? nameStart
        }
        guard nameEnd > nameStart else { return nil }
        let name = String(line[nameStart..<nameEnd])
        return Found(name: name, token: name, range: nameStart..<nameEnd)
    }

    /// One file per line; `#` lines are comments.
    private static func m3uReference(in line: String) -> Found? {
        guard let start = line.firstIndex(where: { !$0.isWhitespace }), line[start] != "#" else { return nil }
        let end = line.lastIndex(where: { !$0.isWhitespace }).map { line.index(after: $0) } ?? line.endIndex
        let token = String(line[start..<end])
        let name = token.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? token
        guard !name.isEmpty else { return nil }
        return Found(name: name, token: token, range: start..<end)
    }

    private static func quoted(in line: String, from openQuote: String.Index) -> Found? {
        let nameStart = line.index(after: openQuote)
        guard let closeQuote = line[nameStart...].firstIndex(where: { quoteCharacters.contains($0) }) else { return nil }
        let name = String(line[nameStart..<closeQuote]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let range = openQuote..<line.index(after: closeQuote)
        return Found(name: name, token: String(line[range]), range: range)
    }
}

// MARK: - Renamed copies

/// Names a receiver gives a second file with the same name: `name-1.ext`, `name-2.ext`, …
/// (Provenance's own import destination and the iOS document Inbox both do this).
public enum RenamedCopyName {

    /// For `track01-2.bin`, the original `track01.bin` and copy number 2; nil when the name has no `-N` suffix.
    public static func original(of fileName: String) -> (name: String, copy: Int)? {
        let ns = fileName as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension
        guard let dash = stem.lastIndex(of: "-") else { return nil }
        let digits = stem[stem.index(after: dash)...]
        guard !digits.isEmpty, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber),
              let copy = Int(digits), copy > 0 else { return nil }
        let base = String(stem[..<dash])
        guard !base.isEmpty else { return nil }
        return (ext.isEmpty ? base : "\(base).\(ext)", copy)
    }
}

// MARK: - Archive companions (NAOMI GD-ROM)

/// Where a NAOMI GD-ROM image lives relative to its zip: `{zip stem}/{gdrom name}.chd`,
/// the layout flycast (and iFly, which sends the CHD as `{stem}/{gdromName}.chd`) expects.
public enum ArchiveCompanionLayout {

    /// Hidden folder in the import directory where a flat CHD waits for its archive to be imported.
    /// Hidden so the directory watcher never queues it as a game of its own.
    public static let stagingDirectoryName = ".archive-companions"

    /// Archive types that can carry a companion folder.
    public static let hostExtensions: Set<String> = ["zip", "7z"]

    public static func isHost(_ fileName: String) -> Bool {
        hostExtensions.contains((fileName as NSString).pathExtension.lowercased())
    }

    /// The archive name without its extension: the folder its companions live in.
    public static func stem(of archiveName: String) -> String {
        (archiveName as NSString).deletingPathExtension
    }

    /// `ikaruga.zip` + `gdl-0010.chd` → `ikaruga/gdl-0010.chd`.
    public static func relativePath(archiveName: String, companionName: String) -> String {
        "\(stem(of: archiveName))/\(companionName)"
    }

    /// The folder next to an imported archive that holds its companions.
    public static func companionDirectory(forArchiveAt archive: URL) -> URL {
        archive.deletingLastPathComponent()
            .appendingPathComponent(stem(of: archive.lastPathComponent), isDirectory: true)
    }

    /// The staging folder for an archive's companions inside the import directory.
    public static func stagingDirectory(importDirectory: URL, archiveName: String) -> URL {
        importDirectory
            .appendingPathComponent(stagingDirectoryName, isDirectory: true)
            .appendingPathComponent(stem(of: archiveName), isDirectory: true)
    }

    /// MAME's GD-ROM image names: `gdl-0010.chd`, `gds-0005a.chd`, `gdt-0011.chd`, `cdp-10001c.chd`.
    /// Only CHDs named like this are paired with an archive; a Dreamcast CHD is a game on its own.
    public static func isGDROMImageName(_ fileName: String) -> Bool {
        let ns = fileName as NSString
        guard ns.pathExtension.lowercased() == "chd" else { return false }
        let stem = ns.deletingPathExtension.lowercased()
        return stem.range(of: #"^(gd[a-z]|cdp)-\d{4,5}[a-z]?$"#, options: .regularExpression) != nil
    }
}

// MARK: - Settle rule

public struct MultiFileImportSettlePolicy: Sendable, Equatable {
    /// Seconds without a new file before anything is released.
    public var quietWindow: TimeInterval
    /// Seconds after the last arrival that an incomplete set (or a lone track) is held.
    public var incompleteSetTimeout: TimeInterval

    public init(quietWindow: TimeInterval = 3, incompleteSetTimeout: TimeInterval = 20) {
        self.quietWindow = quietWindow
        self.incompleteSetTimeout = incompleteSetTimeout
    }
}

/// What the import folder looks like when the gate decides.
public struct MultiFileImportSnapshot: Sendable, Equatable {
    /// Files waiting for a decision, oldest arrival first.
    public var pending: [String]
    /// Every file in the import folder (pending or not), top level only.
    public var present: [String]
    /// Text of the index files in `present`, by file name.
    public var indexContents: [String: String]
    /// Seconds since the newest pending file arrived.
    public var secondsSinceLastArrival: TimeInterval

    public init(pending: [String], present: [String], indexContents: [String: String], secondsSinceLastArrival: TimeInterval) {
        self.pending = pending
        self.present = present
        self.indexContents = indexContents
        self.secondsSinceLastArrival = secondsSinceLastArrival
    }
}

/// A file-system change the gate makes before it releases files.
public enum MultiFileImportFixup: Sendable, Equatable {
    /// Rename a renamed copy back to the name its index file references.
    case rename(from: String, to: String)
    /// Point an index file at a renamed copy (the original name belongs to another set).
    case rewriteReference(indexFile: String, from: String, to: String)
    /// Move a flat GD-ROM CHD to the staging folder of the archive it belongs to.
    case nestCompanion(file: String, archive: String)
}

public struct MultiFileImportDecision: Sendable, Equatable {
    /// Files to import now, each set's index file first.
    public var release: [String]
    /// Files still waiting.
    public var hold: [String]
    /// When to look again, in seconds; nil when nothing is held.
    public var recheckAfter: TimeInterval?
}

public enum MultiFileImportSettler {

    // MARK: Fix-ups

    /// Renames and companion moves to make before deciding. Empty until the folder is quiet.
    public static func fixups(for snapshot: MultiFileImportSnapshot, policy: MultiFileImportSettlePolicy) -> [MultiFileImportFixup] {
        guard snapshot.secondsSinceLastArrival >= policy.quietWindow else { return [] }
        let model = Model(snapshot)
        return renameFixups(model) + companionFixups(model)
    }

    /// Branch A: the original name is free, so the copy takes it back.
    /// Branch B: the original belongs to the set that arrived first, so a later set's
    /// index file is pointed at the copy (copies in `-N` order go to later sets in arrival order).
    private static func renameFixups(_ model: Model) -> [MultiFileImportFixup] {
        var copiesByOriginal: [String: [(file: String, copy: Int)]] = [:]
        for file in model.pending where !model.isReferenced(file) {
            guard let (original, copy) = RenamedCopyName.original(of: file),
                  !model.indexes(referencing: original).isEmpty else { continue }
            copiesByOriginal[original.lowercased(), default: []].append((file, copy))
        }

        var fixups: [MultiFileImportFixup] = []
        for key in copiesByOriginal.keys.sorted() {
            var copies = copiesByOriginal[key, default: []].sorted { $0.copy < $1.copy }
            let owners = model.indexes(referencing: key)
            guard let spelling = model.referenceSpelling(key, in: owners[0]) else { continue }
            var nextOwner = 1
            if !model.isPresent(key) {
                let first = copies.removeFirst()
                fixups.append(.rename(from: first.file, to: spelling))
            }
            for copy in copies {
                guard nextOwner < owners.count else { break }
                let index = owners[nextOwner]
                nextOwner += 1
                let written = model.referenceSpelling(key, in: index) ?? spelling
                fixups.append(.rewriteReference(indexFile: index, from: written, to: copy.file))
            }
        }
        return fixups
    }

    /// A pending GD-ROM CHD no index references goes with the newest archive that arrived
    /// before it, or with the only pending archive when it came first.
    private static func companionFixups(_ model: Model) -> [MultiFileImportFixup] {
        let archives = model.pending.filter(ArchiveCompanionLayout.isHost)
        guard !archives.isEmpty else { return [] }
        var fixups: [MultiFileImportFixup] = []
        for (position, file) in model.pending.enumerated()
        where ArchiveCompanionLayout.isGDROMImageName(file) && !model.isReferenced(file) {
            let earlier = model.pending[..<position].last(where: ArchiveCompanionLayout.isHost)
            guard let archive = earlier ?? (archives.count == 1 ? archives[0] : nil) else { continue }
            fixups.append(.nestCompanion(file: file, archive: archive))
        }
        return fixups
    }

    // MARK: Decision

    public static func decide(_ snapshot: MultiFileImportSnapshot, policy: MultiFileImportSettlePolicy) -> MultiFileImportDecision {
        let quiet = snapshot.secondsSinceLastArrival
        guard quiet >= policy.quietWindow else {
            return MultiFileImportDecision(release: [], hold: snapshot.pending, recheckAfter: policy.quietWindow - quiet)
        }
        let model = Model(snapshot)
        let timedOut = quiet >= policy.incompleteSetTimeout
        let pendingKeys = Set(snapshot.pending.map { $0.lowercased() })

        var release: [String] = []
        var hold: [String] = []
        var claimed = Set<String>()

        // Sets, outermost first: an m3u claims its discs, and a disc claims its tracks.
        let indexes = snapshot.pending.filter { MultiFileIndexKind(fileName: $0) != nil }
        let nested = Set(indexes.flatMap { model.references(of: $0) }.map { $0.lowercased() })
        for index in indexes where !nested.contains(index.lowercased()) {
            let members = model.transitiveReferences(of: index)
            let missing = members.filter { !model.isPresent($0) }
            let group = [index] + members.filter { pendingKeys.contains($0.lowercased()) }.map { model.actualName($0) }
            let fresh = group.filter { claimed.insert($0.lowercased()).inserted }
            if missing.isEmpty || timedOut {
                release += fresh
            } else {
                hold += fresh
            }
        }

        for file in snapshot.pending where !claimed.contains(file.lowercased()) {
            if !timedOut, !model.isReferenced(file), isLoneTrack(file) {
                hold.append(file)
            } else {
                release.append(file)
            }
        }

        return MultiFileImportDecision(
            release: release,
            hold: hold,
            recheckAfter: hold.isEmpty ? nil : max(policy.incompleteSetTimeout - quiet, 0)
        )
    }

    /// A file that is only ever a track of a disc set, so it waits for its index.
    static func isLoneTrack(_ fileName: String) -> Bool {
        let lower = (RenamedCopyName.original(of: fileName)?.name ?? fileName).lowercased()
        if (lower as NSString).pathExtension == "raw" { return true }
        return lower.range(of: #"^track\s?\d{1,3}\.(bin|raw|iso|wav)$"#, options: .regularExpression) != nil
    }

    // MARK: Model

    /// Case-insensitive view of the snapshot.
    private struct Model {
        let pending: [String]
        let presentByKey: [String: String]
        let referencesByIndex: [String: [String]]
        /// Index files in arrival order: those already present before this batch first, then pending ones.
        let indexOrder: [String]

        init(_ snapshot: MultiFileImportSnapshot) {
            pending = snapshot.pending
            var present: [String: String] = [:]
            for name in snapshot.present + snapshot.pending { present[name.lowercased()] = present[name.lowercased()] ?? name }
            presentByKey = present
            var refs: [String: [String]] = [:]
            for (name, text) in snapshot.indexContents {
                guard let kind = MultiFileIndexKind(fileName: name) else { continue }
                refs[name.lowercased()] = MultiFileIndexReferences.referencedFiles(of: kind, contents: text)
            }
            referencesByIndex = refs
            let pendingKeys = Set(snapshot.pending.map { $0.lowercased() })
            let older = snapshot.present
                .filter { MultiFileIndexKind(fileName: $0) != nil && !pendingKeys.contains($0.lowercased()) }
                .sorted { $0.lowercased() < $1.lowercased() }
            let newer = snapshot.pending.filter { MultiFileIndexKind(fileName: $0) != nil }
            indexOrder = older + newer
        }

        func isPresent(_ name: String) -> Bool { presentByKey[name.lowercased()] != nil }
        func actualName(_ name: String) -> String { presentByKey[name.lowercased()] ?? name }
        func references(of index: String) -> [String] { referencesByIndex[index.lowercased()] ?? [] }

        func isReferenced(_ file: String) -> Bool {
            referencesByIndex.values.contains { $0.contains { $0.caseInsensitiveCompare(file) == .orderedSame } }
        }

        /// Index files that reference `name`, oldest arrival first.
        func indexes(referencing name: String) -> [String] {
            indexOrder.filter { index in
                references(of: index).contains { $0.caseInsensitiveCompare(name) == .orderedSame }
            }
        }

        func referenceSpelling(_ name: String, in index: String) -> String? {
            references(of: index).first { $0.caseInsensitiveCompare(name) == .orderedSame }
        }

        /// An m3u's discs, each followed by its tracks, or a cue/gdi's tracks.
        func transitiveReferences(of index: String) -> [String] {
            var result: [String] = []
            var seen: Set<String> = [index.lowercased()]
            var stack = Array(references(of: index).reversed())
            while let name = stack.popLast() {
                guard seen.insert(name.lowercased()).inserted else { continue }
                result.append(name)
                if MultiFileIndexKind(fileName: name) != nil {
                    stack += references(of: name).reversed()
                }
            }
            return result
        }
    }
}
