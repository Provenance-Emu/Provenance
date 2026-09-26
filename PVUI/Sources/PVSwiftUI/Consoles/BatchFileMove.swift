//
//  BatchFileMove.swift
//  PVUI
//

import Foundation
import PVLogging

/// Moves a game's files into another directory as a unit.
///
/// A game can span several files — the primary ROM plus `relatedFiles` such as
/// `.cue`/`.bin` pairs or other discs. Moving them one at a time with no undo can
/// leave a game split across two system directories. `perform()` moves every file
/// or none: if one move fails, the moves already made are put back and the error
/// is rethrown. `revert()` undoes a completed move when a later step (the database
/// write) fails.
struct BatchFileMove {
    struct Pair: Equatable {
        let source: URL
        let destination: URL
    }

    let pairs: [Pair]

    /// - Parameters:
    ///   - files: Files to move. Duplicate source paths are dropped, since
    ///     `relatedFiles` may also list the primary file.
    ///   - directory: Destination directory; each file keeps its name.
    init(files: [URL], into directory: URL) {
        var seenSources = Set<String>()
        pairs = files.compactMap { url in
            guard seenSources.insert(url.standardizedFileURL.path).inserted else { return nil }
            return Pair(source: url, destination: directory.appendingPathComponent(url.lastPathComponent))
        }
    }

    /// Moves every file. If any move fails, the files already moved are moved back
    /// and the error is rethrown.
    func perform(using fileManager: FileManager = .default) throws {
        var moved: [Pair] = []
        do {
            for pair in pairs {
                try fileManager.moveItem(at: pair.source, to: pair.destination)
                moved.append(pair)
            }
        } catch {
            Self.moveBack(moved, using: fileManager)
            throw error
        }
    }

    /// Moves every file back to its source, for when a step after `perform()` fails.
    func revert(using fileManager: FileManager = .default) {
        Self.moveBack(pairs, using: fileManager)
    }

    private static func moveBack(_ moved: [Pair], using fileManager: FileManager) {
        for pair in moved.reversed() {
            do {
                try fileManager.moveItem(at: pair.destination, to: pair.source)
            } catch {
                ELOG("BatchFileMove: could not restore \(pair.destination.lastPathComponent) to \(pair.source.path): \(error)")
            }
        }
    }
}
