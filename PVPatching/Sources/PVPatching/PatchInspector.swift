//
//  PatchInspector.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Information extracted from a patch file without applying it.
public struct PatchInspection: Sendable, Equatable {
    public var format: PatchFormat
    public var title: String?
    public var author: String?
    public var version: String?
    public var patchDescription: String?
    /// CRC32 of the expected source ROM, when the format embeds one.
    public var sourceCRC32: UInt32?
    /// CRC32 of the expected patched ROM, when the format embeds one.
    public var targetCRC32: UInt32?
    public var sourceSize: Int?
    public var targetSize: Int?
    public var patchSHA256: String

    public init(
        format: PatchFormat,
        title: String? = nil,
        author: String? = nil,
        version: String? = nil,
        patchDescription: String? = nil,
        sourceCRC32: UInt32? = nil,
        targetCRC32: UInt32? = nil,
        sourceSize: Int? = nil,
        targetSize: Int? = nil,
        patchSHA256: String
    ) {
        self.format = format
        self.title = title
        self.author = author
        self.version = version
        self.patchDescription = patchDescription
        self.sourceCRC32 = sourceCRC32
        self.targetCRC32 = targetCRC32
        self.sourceSize = sourceSize
        self.targetSize = targetSize
        self.patchSHA256 = patchSHA256
    }
}

/// How confidently a patch matches a candidate ROM.
public enum PatchMatchConfidence: String, Sendable, Codable, Comparable {
    case none
    case low
    case medium
    case high
    case exact

    private var rank: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .exact: return 4
        }
    }

    public static func < (lhs: PatchMatchConfidence, rhs: PatchMatchConfidence) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct PatchMatchCandidate: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var md5: String
    public var crc32: UInt32?
    public var filename: String
    public var confidence: PatchMatchConfidence
    public var score: Double

    public init(
        id: String,
        title: String,
        md5: String,
        crc32: UInt32? = nil,
        filename: String,
        confidence: PatchMatchConfidence,
        score: Double
    ) {
        self.id = id
        self.title = title
        self.md5 = md5
        self.crc32 = crc32
        self.filename = filename
        self.confidence = confidence
        self.score = score
    }
}

/// Reads format-specific headers and scores ROM candidates for auto-matching.
public struct PatchInspector: Sendable {
    public init() {}

    public func inspect(patchURL: URL) throws -> PatchInspection {
        guard let format = PatchFormat.detect(from: patchURL) else {
            throw PatchError.unsupportedFormat(patchURL.pathExtension)
        }
        let data = try Data(contentsOf: patchURL, options: .mappedIfSafe)
        return try inspect(patchData: data, format: format, fallbackTitle: patchURL.deletingPathExtension().lastPathComponent)
    }

    public func inspect(patchData: Data, format: PatchFormat, fallbackTitle: String? = nil) throws -> PatchInspection {
        let sha = PatchHashing.sha256Hex(patchData)
        switch format {
        case .bps:
            return try inspectBPS(patchData, sha: sha, fallbackTitle: fallbackTitle)
        case .ups:
            return try inspectUPS(patchData, sha: sha, fallbackTitle: fallbackTitle)
        case .ips, .ips32, .ppf, .xdelta, .xdelta3, .aps, .rup, .nsp:
            return PatchInspection(
                format: format,
                title: fallbackTitle,
                patchSHA256: sha
            )
        }
    }

    /// Score candidate ROMs against a patch inspection.
    ///
    /// Auto-link only when a single candidate reaches `.exact` or `.high` and
    /// no other candidate is within 0.15 of its score.
    public func rank(
        candidates: [PatchMatchCandidate],
        inspection: PatchInspection,
        patchFilename: String
    ) -> [PatchMatchCandidate] {
        let patchStem = normalizedStem(patchFilename)
        return candidates.map { candidate in
            var score = 0.0
            var confidence = PatchMatchConfidence.none

            if let expected = inspection.sourceCRC32, let actual = candidate.crc32, expected == actual {
                score += 1.0
                confidence = .exact
            }

            let romStem = normalizedStem(candidate.filename)
            let titleStem = normalizedStem(candidate.title)
            if !patchStem.isEmpty {
                if romStem == patchStem || titleStem == patchStem {
                    score += 0.75
                    confidence = max(confidence, .high)
                } else if romStem.contains(patchStem) || patchStem.contains(romStem)
                            || titleStem.contains(patchStem) || patchStem.contains(titleStem) {
                    score += 0.45
                    confidence = max(confidence, .medium)
                } else {
                    let distance = levenshtein(patchStem, romStem.isEmpty ? titleStem : romStem)
                    let maxLen = max(patchStem.count, max(romStem.count, titleStem.count), 1)
                    let similarity = 1.0 - (Double(distance) / Double(maxLen))
                    if similarity >= 0.7 {
                        score += similarity * 0.4
                        confidence = max(confidence, .low)
                    }
                }
            }

            var updated = candidate
            updated.score = score
            updated.confidence = confidence
            return updated
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
    }

    public func unambiguousMatch(from ranked: [PatchMatchCandidate]) -> PatchMatchCandidate? {
        guard let best = ranked.first, best.confidence >= .high else { return nil }
        if ranked.count == 1 { return best }
        let second = ranked[1]
        guard best.score - second.score >= 0.15 else { return nil }
        return best
    }

    // MARK: - Private

    private func inspectBPS(_ data: Data, sha: String, fallbackTitle: String?) throws -> PatchInspection {
        guard data.count >= 19, data[0..<4].elementsEqual("BPS1".utf8) else {
            throw PatchError.corruptPatchFile("Invalid BPS header")
        }
        var pos = 4
        let sourceSize = readVLI(data, pos: &pos)
        let targetSize = readVLI(data, pos: &pos)
        let metadataLength = readVLI(data, pos: &pos)
        var title = fallbackTitle
        var author: String?
        var version: String?
        var description: String?
        if metadataLength > 0, pos + metadataLength <= data.count {
            let metaData = data[pos..<(pos + metadataLength)]
            if let json = try? JSONSerialization.jsonObject(with: Data(metaData)) as? [String: Any] {
                title = (json["title"] as? String) ?? title
                author = json["author"] as? String
                version = json["version"] as? String
                description = (json["description"] as? String) ?? (json["desc"] as? String)
            } else if let text = String(data: Data(metaData), encoding: .utf8), !text.isEmpty {
                description = text
            }
        }
        let sourceCRC = data.readLE32(at: data.count - 12)
        let targetCRC = data.readLE32(at: data.count - 8)
        return PatchInspection(
            format: .bps,
            title: title,
            author: author,
            version: version,
            patchDescription: description,
            sourceCRC32: sourceCRC,
            targetCRC32: targetCRC,
            sourceSize: sourceSize,
            targetSize: targetSize,
            patchSHA256: sha
        )
    }

    private func inspectUPS(_ data: Data, sha: String, fallbackTitle: String?) throws -> PatchInspection {
        // UPS: "UPS1" + sourceSize VLI + targetSize VLI + ... + sourceCRC + targetCRC + patchCRC
        guard data.count >= 16, data[0..<4].elementsEqual("UPS1".utf8) else {
            throw PatchError.corruptPatchFile("Invalid UPS header")
        }
        var pos = 4
        let sourceSize = readVLI(data, pos: &pos)
        let targetSize = readVLI(data, pos: &pos)
        let sourceCRC = data.readLE32(at: data.count - 12)
        let targetCRC = data.readLE32(at: data.count - 8)
        return PatchInspection(
            format: .ups,
            title: fallbackTitle,
            sourceCRC32: sourceCRC,
            targetCRC32: targetCRC,
            sourceSize: sourceSize,
            targetSize: targetSize,
            patchSHA256: sha
        )
    }

    private func normalizedStem(_ value: String) -> String {
        let noExt = (value as NSString).deletingPathExtension
        let scalars = noExt.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : Character(" ")
        }
        return String(scalars)
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }
        var previous = Array(0...bChars.count)
        var current = Array(repeating: 0, count: bChars.count + 1)
        for (i, aChar) in aChars.enumerated() {
            current[0] = i + 1
            for (j, bChar) in bChars.enumerated() {
                let cost = aChar == bChar ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + cost
                )
            }
            previous = current
        }
        return previous[bChars.count]
    }
}
