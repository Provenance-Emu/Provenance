//
//  BatchFileMoveTests.swift
//  PVUIBaseTests
//

import Foundation
import Testing
@testable import PVUIBase

// MARK: - BatchFileMove Tests

@Suite("BatchFileMove")
struct BatchFileMoveTests {

    private func makeDirectories() throws -> (source: URL, destination: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatchFileMoveTests-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("src", isDirectory: true)
        let destination = root.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return (source, destination)
    }

    private func touch(_ name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(name.utf8).write(to: url)
        return url
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    @Test("Moves the primary file and its companions together")
    func movesAllFiles() throws {
        let dirs = try makeDirectories()
        let cue = try touch("game.cue", in: dirs.source)
        let bin = try touch("game.bin", in: dirs.source)

        let move = BatchFileMove(files: [cue, bin], into: dirs.destination)
        try move.perform()

        #expect(!exists(cue) && !exists(bin))
        #expect(exists(dirs.destination.appendingPathComponent("game.cue")))
        #expect(exists(dirs.destination.appendingPathComponent("game.bin")))
    }

    @Test("A primary file also listed as related is moved once")
    func dropsDuplicateSources() throws {
        let dirs = try makeDirectories()
        let cue = try touch("game.cue", in: dirs.source)
        let bin = try touch("game.bin", in: dirs.source)

        let move = BatchFileMove(files: [cue, cue, bin], into: dirs.destination)

        #expect(move.pairs.map(\.source) == [cue, bin])
        try move.perform()
    }

    @Test("A failed move puts back the files already moved")
    func rollsBackOnFailure() throws {
        let dirs = try makeDirectories()
        let cue = try touch("game.cue", in: dirs.source)
        let bin = try touch("game.bin", in: dirs.source)
        // A file already at the destination makes the second move fail.
        _ = try touch("game.bin", in: dirs.destination)

        let move = BatchFileMove(files: [cue, bin], into: dirs.destination)
        #expect(throws: (any Error).self) { try move.perform() }

        #expect(exists(cue) && exists(bin))
        #expect(!exists(dirs.destination.appendingPathComponent("game.cue")))
    }

    @Test("revert() undoes a completed move")
    func revertRestoresSources() throws {
        let dirs = try makeDirectories()
        let cue = try touch("game.cue", in: dirs.source)
        let bin = try touch("game.bin", in: dirs.source)

        let move = BatchFileMove(files: [cue, bin], into: dirs.destination)
        try move.perform()
        move.revert()

        #expect(exists(cue) && exists(bin))
        #expect(!exists(dirs.destination.appendingPathComponent("game.cue")))
        #expect(!exists(dirs.destination.appendingPathComponent("game.bin")))
    }
}
