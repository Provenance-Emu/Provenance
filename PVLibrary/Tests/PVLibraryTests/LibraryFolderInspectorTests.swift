//
//  LibraryFolderInspectorTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryFolderInspectorTests: XCTestCase {
    private var base = URL(fileURLWithPath: "/")
    private var documents = URL(fileURLWithPath: "/")

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryFolderInspectorTests")
        documents = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documents.appendingPathComponent("ROMs/com.provenance.snes"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func inspector(roots: [URL]? = nil) -> LibraryFolderInspector {
        let documents = self.documents
        let roots = roots ?? [documents]
        return LibraryFolderInspector(appDocuments: documents, libraryRoots: { roots }, availableCapacity: { _ in 42 })
    }

    private func folder(_ relative: String) throws -> URL {
        let url = base.appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testClassificationTable() {
        let docs = "/private/var/mobile/Containers/Data/Application/A/Documents"
        XCTAssertEqual(LibraryFolderInspector.classify(path: docs + "/MyLib", appDocumentsPath: docs, isUbiquitous: false), .ownDocuments)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/private/var/mobile/Containers/Data/Application/B/Documents/Lib", appDocumentsPath: docs, isUbiquitous: false), .otherAppDocuments)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Lib", appDocumentsPath: docs, isUbiquitous: false), .iCloudDrive)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/x/y", appDocumentsPath: docs, isUbiquitous: true), .iCloudDrive)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/private/var/mobile/Containers/Shared/AppGroup/C/File Provider Storage/Lib", appDocumentsPath: docs, isUbiquitous: false), .filesFolder)
    }

    func testSiblingSubfolderOfDocumentsIsAllowed() throws {
        // Review Focus 1: "On My iPhone › Provenance › MyLib" is the recommended pick.
        let picked = try folder("app/Documents/MyLib")
        let inspection = try inspector().inspect(picked)
        XCTAssertEqual(inspection.kind, .ownDocuments)
        XCTAssertFalse(inspection.hasManifest)
        XCTAssertEqual(inspection.availableBytes, 42)
    }

    func testTheRootItselfIsRefused() {
        XCTAssertThrowsError(try inspector().inspect(documents)) { error in
            guard case LibraryFolderError.isCurrentRoot = error else { return XCTFail("\(error)") }
        }
    }

    func testAFolderInsideALibraryFolderIsRefused() throws {
        let inside = try folder("app/Documents/ROMs/com.provenance.snes/Sub")
        XCTAssertThrowsError(try inspector().inspect(inside)) { error in
            guard case LibraryFolderError.isCurrentRoot = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try inspector().inspect(documents.appendingPathComponent("ROMs", isDirectory: true)))
        let saves = try folder("app/Documents/Save States/Game")
        XCTAssertThrowsError(try inspector().inspect(saves))
    }

    func testAFolderContainingTheRootIsRefused() {
        XCTAssertThrowsError(try inspector().inspect(base.appendingPathComponent("app", isDirectory: true))) { error in
            guard case LibraryFolderError.isCurrentRoot = error else { return XCTFail("\(error)") }
        }
    }

    func testManifestIsDetected() throws {
        let picked = try folder("shared")
        try LibraryManifest.writeIfAbsent(in: picked, createdBy: "com.ifly")
        XCTAssertTrue(try inspector().inspect(picked).hasManifest)
    }

    func testNotADirectory() throws {
        let file = try LibraryMoveTestSupport.write(base, "file.txt", "x")
        XCTAssertThrowsError(try inspector().inspect(file)) { error in
            guard case LibraryFolderError.notADirectory = error else { return XCTFail("\(error)") }
        }
    }

    func testReadOnlyFolderIsNotWritable() throws {
        let picked = try folder("readonly")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: picked.path)
        addTeardownBlock { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: picked.path) }
        XCTAssertThrowsError(try inspector().inspect(picked)) { error in
            guard case LibraryFolderError.notWritable = error else { return XCTFail("\(error)") }
        }
        XCTAssertNil(try? FileManager.default.contentsOfDirectory(atPath: picked.path).first { $0.hasPrefix(".provenance-write-probe") })
    }

    func testProbeFileIsRemoved() throws {
        let picked = try folder("clean")
        _ = try inspector().inspect(picked)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: picked.path), [])
    }
}
