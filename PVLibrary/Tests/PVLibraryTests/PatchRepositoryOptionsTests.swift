//
//  PatchRepositoryOptionsTests.swift
//  PVLibraryTests
//
//  The cross-app patch rules in PatchRepository that need no Realm rows: which patched versions
//  get a library item of their own, and the remembered "Apply anyway" choice.
//

import XCTest
import PVPatching
@testable import PVLibrary

@MainActor
final class PatchRepositoryOptionsTests: XCTestCase {
    private var patchIDs: [String] = []

    override func tearDown() {
        for id in patchIDs {
            PatchRepository.shared.setIgnoresSourceChecksum(false, patchID: id)
        }
        patchIDs = []
        super.tearDown()
    }

    func testSeparateItemsSettingShowsEveryVariant() {
        XCTAssertFalse(PatchRepository.isVariantHidden(showAsLibraryTile: false, isDefaultLaunch: false, showPatchedSeparately: true))
        XCTAssertFalse(PatchRepository.isVariantHidden(showAsLibraryTile: true, isDefaultLaunch: false, showPatchedSeparately: true))
    }

    func testWithTheSettingOffOnlyAddTileShowsAVariant() {
        XCTAssertTrue(PatchRepository.isVariantHidden(showAsLibraryTile: false, isDefaultLaunch: false, showPatchedSeparately: false))
        XCTAssertFalse(PatchRepository.isVariantHidden(showAsLibraryTile: true, isDefaultLaunch: false, showPatchedSeparately: false))
    }

    /// "Play with the Patch" makes the patch the default launch: the base game's entry plays it,
    /// so the variant must not get a second entry whatever the setting says.
    func testTheDefaultLaunchVersionNeverGetsASecondEntry() {
        for showSeparately in [true, false] {
            for addTile in [true, false] {
                XCTAssertTrue(PatchRepository.isVariantHidden(
                    showAsLibraryTile: addTile, isDefaultLaunch: true, showPatchedSeparately: showSeparately
                ))
            }
        }
    }

    func testApplyAnywayIsRememberedPerPatch() {
        let first = "patches/PRO-\(UUID().uuidString).bps"
        let second = "patches/PRO-\(UUID().uuidString).ups"
        patchIDs += [first, second]
        let repository = PatchRepository.shared

        XCTAssertFalse(repository.ignoresSourceChecksum(patchID: first))
        repository.setIgnoresSourceChecksum(true, patchID: first)
        XCTAssertTrue(repository.ignoresSourceChecksum(patchID: first))
        XCTAssertFalse(repository.ignoresSourceChecksum(patchID: second))

        repository.setIgnoresSourceChecksum(false, patchID: first)
        XCTAssertFalse(repository.ignoresSourceChecksum(patchID: first))
    }

    func testPlacementsAreTheThreeCrossAppChoices() {
        XCTAssertEqual(PatchPlacement.allCases, [.onDemand, .newLibraryEntry, .replaceOriginal])
    }

    func testXDeltaPatchesAreImportable() {
        XCTAssertTrue(PatchFormat.implementedFileExtensions.contains("xdelta"))
        XCTAssertTrue(PatchFormat.xdelta.isImplemented)
    }
}
