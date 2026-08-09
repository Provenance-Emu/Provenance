//
//  ArchiveContentClassifierTests.swift
//  PVArchiving
//
//  Pins the "is this zip an optical-disc bundle, or an arcade ROM set?"
//  decision. Regression cover for the MAME misclassification described in
//  `ArchiveContentClassifier` — arcade chip dumps are routinely named `.bin`,
//  so a bare `.bin` entry must never by itself mean "CD image".
//

import Testing
import Foundation
@testable import PVArchivingFormats

private let kib: Int64 = 1024
private let mib: Int64 = 1024 * 1024

/// Builds a file entry; `size` defaults to a chip-dump-sized value.
private func entry(_ name: String, _ size: Int64 = 32 * kib) -> ArchiveEntryInfo {
    ArchiveEntryInfo(name: name, size: size, isDirectory: false)
}

struct ArchiveContentClassifierTests {

    // MARK: - The regression this class exists for

    /// `dkong.zip`'s real contents. Every member is a `.bin` chip dump, which
    /// the previous detector read as "CD image" — extracting the romset and
    /// destroying it (MAME only accepts zip/cmd/chd/7z, so the loose members
    /// could not be re-imported).
    @Test func mameRomsetOfBinChipDumpsIsNotADiscBundle() {
        let dkong = [
            entry("c_5et_g.bin", 4 * kib),
            entry("c_5ct_g.bin", 4 * kib),
            entry("c_5bt_g.bin", 4 * kib),
            entry("c_5at_g.bin", 4 * kib),
            entry("v_5h_b.bin", 2 * kib),
            entry("l_4m_b.bin", 2 * kib),
            entry("s_3i_b.bin", 2 * kib)
        ]

        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: dkong) == false)
    }

    /// NeoGeo/CPS sets mix `.bin` with chip-position extensions. Still not a disc.
    @Test func mixedChipDumpExtensionsAreNotADiscBundle() {
        let entries = [
            entry("201-p1.p1", 1 * mib),
            entry("202-c1.bin", 4 * mib),
            entry("sfix.sfix", 128 * kib),
            entry("pacman.6e", 4 * kib)
        ]

        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: entries) == false)
    }

    // MARK: - Unambiguous optical formats

    /// The case the original detector was added for: a Dreamcast arcade port
    /// whose outer filename collides with a MAME romset name.
    @Test func dreamcastCdiIsADiscBundle() {
        let crazyTaxi = [entry("Crazy Taxi.cdi", 800 * mib)]

        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: crazyTaxi))
    }

    @Test func gdiIsADiscBundle() {
        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: [entry("game.gdi", 1 * kib)]))
    }

    @Test func isoIsADiscBundle() {
        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: [entry("game.iso", 600 * mib)]))
    }

    /// A descriptor file is decisive even when it is tiny — its presence is
    /// what distinguishes a disc dump from a pile of chip dumps.
    @Test func cueSheetAlongsideBinTracksIsADiscBundle() {
        let psxDisc = [
            entry("Game.cue", 1 * kib),
            entry("Game (Track 1).bin", 600 * mib),
            entry("Game (Track 2).bin", 30 * mib)
        ]

        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: psxDisc))
    }

    // MARK: - Ambiguous extensions fall back to size

    /// A bare disc image with no descriptor inside the zip. Nothing but the
    /// size distinguishes it from a chip dump.
    @Test func oversizedBareBinIsADiscBundle() {
        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: [entry("Game.bin", 650 * mib)]))
    }

    /// `.img` is as generic as `.bin` and gets the same treatment.
    @Test func smallImgIsNotADiscBundle() {
        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: [entry("boot.img", 512 * kib)]) == false)
    }

    /// Unknown size must not be guessed as "large" — that would resurrect the
    /// bug for any backend that omits sizes.
    @Test func binWithUnknownSizeIsNotADiscBundle() {
        let unsized = [ArchiveEntryInfo(name: "c_5et_g.bin", size: nil, isDirectory: false)]

        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: unsized) == false)
    }

    // MARK: - Structural cases

    @Test func directoryEntriesAreIgnored() {
        let entries = [ArchiveEntryInfo(name: "discs.iso", size: nil, isDirectory: true)]

        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: entries) == false)
    }

    @Test func extensionMatchingIsCaseInsensitive() {
        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: [entry("GAME.CDI", 1 * mib)]))
    }

    @Test func emptyArchiveIsNotADiscBundle() {
        #expect(ArchiveContentClassifier.looksLikeOpticalDiscBundle(entries: []) == false)
    }
}
