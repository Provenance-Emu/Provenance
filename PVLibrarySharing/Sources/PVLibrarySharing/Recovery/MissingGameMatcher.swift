//
//  MissingGameMatcher.swift
//  PVLibrarySharing
//
//  Finds a missing library game in another library's catalogue. Pure; no network.
//

import Foundation

public enum MissingGameMatcher {
    /// Items on the query's system with the query's MD5, and the same size when both sides
    /// know one. Empty for multi-file games, whose library MD5 is not the image's.
    public static func hashMatches(for query: MissingGameQuery, in catalogue: RemoteCatalogue) -> [RemoteLibraryItem] {
        guard query.isSingleFileImage, !query.md5.isEmpty else { return [] }
        let wanted = query.md5.lowercased()
        let size = query.primaryFile?.size ?? 0
        return catalogue.items.filter { item in
            guard item.systemIdentifier == query.system, let md5 = item.md5, md5.lowercased() == wanted else {
                return false
            }
            return size <= 0 || item.sizeBytes <= 0 || item.sizeBytes == size
        }
    }

    /// Items on the query's system whose title is the game's title or primary file name once
    /// case, extension and punctuation are dropped. Never fuzzy. An equal size sorts first.
    public static func nameCandidates(for query: MissingGameQuery, in catalogue: RemoteCatalogue) -> [RemoteLibraryItem] {
        var names: Set<String> = [normalised(query.title)]
        if let primary = query.primaryFile { names.insert(normalised(primary.name)) }
        names.remove("")
        guard !names.isEmpty else { return [] }
        let size = query.files.reduce(0) { $0 + $1.size }
        let titleKey = normalised(query.title)
        return catalogue.items
            .filter { $0.systemIdentifier == query.system && names.contains(normalised($0.title)) }
            .enumerated()
            .sorted { lhs, rhs in
                let left = rank(lhs.element, size: size, titleKey: titleKey)
                let right = rank(rhs.element, size: size, titleKey: titleKey)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    /// What `manifest` is to the missing game, or nil when it cannot fill the hole.
    public static func classify(_ manifest: RemoteManifest, for query: MissingGameQuery) -> RecoveryMatchKind? {
        let remote = manifest.gameFiles
        guard !remote.isEmpty, !query.files.isEmpty else { return nil }
        var byName: [String: RemoteFile] = [:]
        for file in remote { byName[file.fileName.lowercased()] = file }
        let pairs = query.files.map { ($0, byName[$0.name.lowercased()]) }
        if pairs.allSatisfy({ $0.1 != nil }) {
            let sameSizes = pairs.allSatisfy { local, file in local.size > 0 && file?.size == local.size }
            return sameSizes ? .exact : .standIn
        }
        // One file for one file: the stand-in takes the old file's name.
        return query.files.count == 1 && remote.count == 1 ? .standIn : nil
    }

    /// Lowercased letters and digits of `name` without its extension or diacritics.
    static func normalised(_ name: String) -> String {
        let base = (name as NSString).deletingPathExtension
        let folded = base.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return String(String.UnicodeScalarView(folded.unicodeScalars.filter(CharacterSet.alphanumerics.contains))).lowercased()
    }

    private static func rank(_ item: RemoteLibraryItem, size: Int64, titleKey: String) -> Int {
        let sameSize = size > 0 && item.sizeBytes == size
        let sameTitle = normalised(item.title) == titleKey
        return (sameSize ? 0 : 2) + (sameTitle ? 0 : 1)
    }
}
