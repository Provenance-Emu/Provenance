//
//  RelativeRootPickedFolderTests.swift
//  PVLibraryTests
//
//  A picked folder under iCloud Drive or a file provider has "Documents/" inside its own path, so the
//  pattern matching in `createRelativePath` stores a wrong partial path unless the root is stripped first.
//

import XCTest
@testable import PVFileSystem

final class RelativeRootPickedFolderTests: XCTestCase {
    private let expected = "ROMs/com.provenance.snes/Game.sfc"

    func testPickedICloudFolderIsStrippedBeforePatterns() {
        let root = URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Retro", isDirectory: true)
        let url = root.appendingPathComponent(expected)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: [root]), expected)
        // Without the root, the "Documents/" pattern inside "Mobile Documents/" wins.
        XCTAssertNotEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: []), expected)
    }

    func testFilesFolderIsStripped() {
        let root = URL(fileURLWithPath: "/private/var/mobile/Containers/Shared/AppGroup/0A1B/File Provider Storage/Retro", isDirectory: true)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: root.appendingPathComponent(expected), stripping: [root]), expected)
    }

    func testOwnDocumentsSubfolderIsStripped() {
        let root = URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application/0A1B/Documents/MyLib", isDirectory: true)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: root.appendingPathComponent(expected), stripping: [root]), expected)
    }

    func testTrailingSlashAndVarPrefixAreTolerated() {
        let root = URL(fileURLWithPath: "/var/mobile/Containers/Shared/AppGroup/0A1B/File Provider Storage/Retro/", isDirectory: true)
        let url = URL(fileURLWithPath: "/var/mobile/Containers/Shared/AppGroup/0A1B/File Provider Storage/Retro/" + expected)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: [root]), expected)
    }

    func testUnrelatedURLFallsThroughToTheOldRules() {
        let root = URL(fileURLWithPath: "/picked", isDirectory: true)
        let url = URL(fileURLWithPath: "/private/var/mobile/Containers/Shared/AppGroup/0A1B/Documents/" + expected)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: [root]), expected)
    }
}
