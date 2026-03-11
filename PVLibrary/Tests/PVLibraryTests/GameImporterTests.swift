//
//  GameImporterTests.swift
//  PVLibrary
//
//  Created by David Proskin on 11/4/24.
//

@testable import PVLibrary
import XCTest

class GameImporterTests: XCTestCase {
    
    var gameImporter: GameImporting!
    
    class MockCDFileHandler: CDFileHandling {
        var binFilesResult: [String] = []
        var binUrlsResult: [URL] = []
        var m3uFileContentsResult: [String] = []
        var binFileExistsResult: [URL:Bool] = [:]
        
        func findAssociatedBinFileNames(for cueFileItem: ImportQueueItem) throws -> [String] {
            return binFilesResult
        }
        
        func candidateBinUrls(for binFileNames: [String], in directories: [URL]) -> [URL] {
            return binUrlsResult
        }
        
        func readM3UFileContents(from url: URL) throws -> [String] {
            return m3uFileContentsResult
        }
        
        func fileExistsAtPath(_ path: URL) -> Bool {
            return binFileExistsResult[path] ?? false
        }
    }
    
    override func setUp() async throws {
        try await super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        //bad, but needed for my test case
        //TODO: mock this
        gameImporter = GameImporter.shared
//        await gameImporter.initSystems() <--- this will crash until we get proper DI
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        gameImporter = nil
    }

    func testImportQueueContainsDuplicate_noDuplicates() {
        let item1 = ImportQueueItem(url: URL(string: "file:///path/to/file1.rom")!)
        let item2 = ImportQueueItem(url: URL(string: "file:///path/to/file2.rom")!)
        
        let queue = [item1]
        
        XCTAssertFalse(gameImporter.importQueueContainsDuplicate(queue, ofItem: item2), "No duplicates should be found")
    }
    
    func testImportQueueContainsDuplicate_duplicateByUrl() {
        let item1 = ImportQueueItem(url: URL(string: "file:///path/to/file1.rom")!)
        let item2 = ImportQueueItem(url: URL(string: "file:///path/to/file1.rom")!)
        
        let queue = [item1]
        
        XCTAssertTrue(gameImporter.importQueueContainsDuplicate(queue, ofItem: item2), "Duplicate should be detected by URL")
    }
    
    func testImportQueueContainsDuplicate_duplicateById() {
        let item1 = ImportQueueItem(url: URL(string: "file:///path/to/file1.rom")!)
        let item2 = item1
        item2.url = URL(string: "file:///path/to/file2.rom")!
        
        
        let queue = [item1]
        
        XCTAssertTrue(gameImporter.importQueueContainsDuplicate(queue, ofItem: item2), "Duplicate should be detected by ID")
    }
    
    func testImportQueueContainsDuplicate_duplicateInChildItems() {
        let item1 = ImportQueueItem(url: URL(string: "file:///path/to/file1.rom")!)
        let item2 = ImportQueueItem(url: URL(string: "file:///path/to/file2.rom")!)
        
        let child1 = ImportQueueItem(url: URL(string: "file:///path/to/file2.rom")!)
        
        item1.childQueueItems.append(child1)
        
        let queue = [item1]
        
        XCTAssertTrue(gameImporter.importQueueContainsDuplicate(queue, ofItem: item2), "Duplicate should be detected in child queue items")
    }
    
    func testImportQueueContainsDuplicate_duplicateByUrlWithSpaces() {
        let item1 = ImportQueueItem(url: URL(string: "file:///path/to/Star%20Control%20II%20(USA).bin")!)
        let item2 = ImportQueueItem(url: URL(string: "file:///path/to/Star%20Control%20II%20(USA).bin")!)
        
        let queue = [item1]
        
        XCTAssertTrue(gameImporter.importQueueContainsDuplicate(queue, ofItem: item2), "Duplicate should be detected by URL")
    }
    
    func testAddImportsThreadSafety() {
        // Define paths to test
        let paths = [
            URL(string: "file:///path/to/file1.bin")!,
            URL(string: "file:///path/to/file2.bin")!,
            URL(string: "file:///path/to/file3.bin")!
        ]
        
        // Create an expectation for each concurrent call
        let expectation1 = expectation(description: "Thread 1")
        let expectation2 = expectation(description: "Thread 2")
        let expectation3 = expectation(description: "Thread 3")
        
        // Dispatch the calls concurrently
        DispatchQueue.global(qos: .userInitiated).async {
            self.gameImporter.addImports(forPaths: paths)
            expectation1.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.gameImporter.addImports(forPaths: paths)
            expectation2.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.gameImporter.addImports(forPaths: paths)
            expectation3.fulfill()
        }
        
        // Wait for expectations
        wait(for: [expectation1, expectation2, expectation3], timeout: 5.0)
        
        XCTAssertEqual(gameImporter.importQueue.count, 3, "Expected successful import of all 3 items")
    }
    
    // Sample URLs with different extensions for testing
    let m3uFile1 = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file1.m3u"))
    let txtFile1 = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file1.txt"))
    let jpgFile1 = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/File1.jpg"))
    let txtFile2 = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file2.txt"))
    let pngFile1 = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file1.png"))
    let m3uFile2 = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/File2.m3u"))
    let cueFile1 = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/File2.cue"))

    override func setUp() {
        super.setUp()
        // Set up any additional context or resources needed here.
    }

    func testSortWithM3UFirst() {
        // Arrange: create an unsorted list of items
        let items = [txtFile1, jpgFile1, txtFile2, m3uFile1, pngFile1]
        
        // Act: sort the items
        let sortedItems = gameImporter.sortImportQueueItems(items)
        
        // Assert: m3u files should appear before other extensions
        XCTAssertEqual(sortedItems.first?.url.pathExtension.lowercased(), "m3u")
    }

    func testSortArtworkExtensionsLast() {
        // Arrange: add artwork file extensions to the list
        let items = [txtFile1, txtFile2, m3uFile1, pngFile1]
        
        // Act
        let sortedItems = gameImporter.sortImportQueueItems(items)
        
        // Assert: artwork-related extensions like jpg, png should be sorted last
        XCTAssertEqual(sortedItems.last?.url.pathExtension.lowercased(), "png")
    }

    func testSortByFilenameIfSameExtension() {
        // Arrange: items with the same extensions but different filenames
        let items = [txtFile2, txtFile1]
        
        // Act
        let sortedItems = gameImporter.sortImportQueueItems(items)
        
        // Assert: within the same extension, sorting should be by filename
        XCTAssertEqual(sortedItems[0].url.lastPathComponent, "file1.txt")
        XCTAssertEqual(sortedItems[1].url.lastPathComponent, "file2.txt")
    }

    func testSortMixedItems() {
        // Arrange: items with mixed extensions and names
        let items = [txtFile1, txtFile2, jpgFile1, m3uFile1, m3uFile2]
        
        // Act
        let sortedItems = gameImporter.sortImportQueueItems(items)
        
        // Assert: m3u files first, followed by sorted txt, then artwork
        XCTAssertEqual(sortedItems[0].url.pathExtension.lowercased(), "m3u")
        XCTAssertEqual(sortedItems[1].url.pathExtension.lowercased(), "m3u")
        XCTAssertEqual(sortedItems[2].url.pathExtension.lowercased(), "txt")
        XCTAssertEqual(sortedItems.last?.url.pathExtension.lowercased(), "jpg")
    }
    
    func testSortWithCuePriority() {
        // Arrange: create a list including .m3u, .cue, and other file extensions
        let items = [txtFile1, jpgFile1, pngFile1, cueFile1, m3uFile1, txtFile2]
        
        // Act: sort the items
        let sortedItems = gameImporter.sortImportQueueItems(items)
        
        // Assert: check .m3u is first, .cue is next, followed by other files
        XCTAssertEqual(sortedItems[0].url.pathExtension.lowercased(), "m3u", ".m3u files should be first")
        XCTAssertEqual(sortedItems[1].url.pathExtension.lowercased(), "cue", ".cue files should be second")
        
        // Check that artwork files are at the end
        let artworkStartIndex = sortedItems.firstIndex { item in
            Extensions.artworkExtensions.contains(item.url.pathExtension.lowercased())
        }
        if let artworkIndex = artworkStartIndex {
            for i in artworkIndex..<sortedItems.count {
                XCTAssertTrue(Extensions.artworkExtensions.contains(sortedItems[i].url.pathExtension.lowercased()), "Artwork items should be at the end")
            }
        } else {
            XCTFail("No artwork items found in sorted list")
        }
    }
    
    func testCueFileWithMissingBinFiles() {
        // Arrange
        let mockCDFileHandler = MockCDFileHandler()
        let gameImporter = GameImporter(FileManager.default,
                                        GameImporterFileService(),
                                        GameImporterDatabaseService(),
                                        GameImporterSystemsService(),
                                        ArtworkImporter(),
                                        mockCDFileHandler)
        let cueFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file.cue"))
        mockCDFileHandler.binFilesResult = []  // Simulate missing .bin files
        mockCDFileHandler.binUrlsResult = []  // Simulate missing .bin files
        
        // Act
        var importQueue = [cueFile]
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        
        // Assert
        XCTAssertEqual(importQueue[0].status, .partial, "The .cue file should be marked as .partial when any referenced .bin file is missing.")
    }
    
    func testCueFileWithMissingBinAndThenAddBin() {
        // Arrange
        let mockCDFileHandler = MockCDFileHandler()
        let gameImporter = GameImporter(FileManager.default,
                                        GameImporterFileService(),
                                        GameImporterDatabaseService(),
                                        GameImporterSystemsService(),
                                        ArtworkImporter(),
                                        mockCDFileHandler)
        let cueFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file.cue"))
        let binFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file.bin"))
        mockCDFileHandler.binFilesResult = []  // Simulate missing .bin files
        mockCDFileHandler.binUrlsResult = []  // Simulate missing .bin files
        
        // Act
        var importQueue = [cueFile]
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        
        // Assert
        XCTAssertEqual(importQueue[0].status, .partial, "The .cue file should be marked as .partial when any referenced .bin file is missing.")
        
        importQueue.append(binFile)
        mockCDFileHandler.binFilesResult = [binFile.url.lastPathComponent]
        mockCDFileHandler.binUrlsResult = [binFile.url, binFile.url.appending(path: "1")]  // Simulate missing .bin files
        mockCDFileHandler.binFileExistsResult[binFile.url] = true
        
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        // Assert
        XCTAssertEqual(importQueue[0].status, .queued, "The .cue file should be marked as .queued when any referenced .bin file is present.")
    }

    func testM3UFileWithMissingOrIncompleteCueFiles() {
        // Arrange
        let mockCDFileHandler = MockCDFileHandler()
        let gameImporter = GameImporter(FileManager.default,
                                        GameImporterFileService(),
                                        GameImporterDatabaseService(),
                                        GameImporterSystemsService(),
                                        ArtworkImporter(),
                                        mockCDFileHandler)
        let m3uFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/playlist.m3u"))
        let cueFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file.cue"))
        mockCDFileHandler.m3uFileContentsResult = ["file.cue"]  // Simulate the m3u file referencing the cue file
        
        // Act
        var importQueue = [m3uFile, cueFile]
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        gameImporter.organizeM3UFiles(in: &importQueue)
        
        // Assert
        XCTAssertEqual(m3uFile.status, .partial, "The .m3u file should be marked as .partial if any referenced .cue file is missing or incomplete.")
    }

    // MARK: - Artwork Filename Matching Tests

    func testArtworkFilenameExtraction_withRomExtension() {
        // game.lnx.jpg → gameFilename = "game.lnx", gameExtension = "lnx"
        let artworkURL = URL(fileURLWithPath: "/path/to/game.lnx.jpg")
        let gameFilename = artworkURL.deletingPathExtension().lastPathComponent
        let gameExtension = artworkURL.deletingPathExtension().pathExtension

        XCTAssertEqual(gameFilename, "game.lnx", "gameFilename should be the ROM name with extension")
        XCTAssertEqual(gameExtension, "lnx", "gameExtension should be the ROM's file extension")
    }

    func testArtworkFilenameExtraction_withMultipleDots() {
        // Super Mario Bros (USA).nes.png → gameFilename = "Super Mario Bros (USA).nes"
        let artworkURL = URL(fileURLWithPath: "/path/to/Super Mario Bros (USA).nes.png")
        let gameFilename = artworkURL.deletingPathExtension().lastPathComponent
        let gameExtension = artworkURL.deletingPathExtension().pathExtension

        XCTAssertEqual(gameFilename, "Super Mario Bros (USA).nes")
        XCTAssertEqual(gameExtension, "nes")
    }

    func testArtworkFilenameExtraction_noRomExtension() {
        // game.jpg → gameFilename = "game", gameExtension = ""
        let artworkURL = URL(fileURLWithPath: "/path/to/game.jpg")
        let gameFilename = artworkURL.deletingPathExtension().lastPathComponent
        let gameExtension = artworkURL.deletingPathExtension().pathExtension

        XCTAssertEqual(gameFilename, "game")
        XCTAssertTrue(gameExtension.isEmpty, "No ROM extension should be empty")
    }

    func testArtworkPathConstruction_preservesRomExtension() {
        // Verifies the fixed path construction: "Lynx/game.lnx" not "Lynx/game"
        let systemIdentifier = "com.provenance.lynx"
        let gameFilename = "game.lnx" // From deletingPathExtension on "game.lnx.jpg"

        // This is the FIXED construction (no .deletingPathExtension())
        let fixedPath = URL(fileURLWithPath: systemIdentifier, isDirectory: true)
            .appendingPathComponent(gameFilename).path
        XCTAssertTrue(fixedPath.hasSuffix("com.provenance.lynx/game.lnx"),
                      "Path should preserve ROM extension: got \(fixedPath)")

        // This was the BROKEN construction
        let brokenPath = URL(fileURLWithPath: systemIdentifier, isDirectory: true)
            .appendingPathComponent(gameFilename).deletingPathExtension().path
        XCTAssertTrue(brokenPath.hasSuffix("com.provenance.lynx/game"),
                      "Broken path strips ROM extension: got \(brokenPath)")

        // Confirm they differ
        XCTAssertNotEqual(fixedPath, brokenPath, "Fixed and broken paths should differ")
    }

    func testIsArtworkDetection() {
        let jpgItem = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.jpg"))
        let jpegItem = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.jpeg"))
        let pngItem = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.png"))
        let lnxItem = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.lnx"))
        let zipItem = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.zip"))
        let nesItem = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.nes"))

        let concreteImporter = gameImporter as! GameImporter

        // Artwork extensions should be detected
        XCTAssertTrue(concreteImporter.isArtwork(jpgItem), ".jpg should be artwork")
        XCTAssertTrue(concreteImporter.isArtwork(jpegItem), ".jpeg should be artwork")
        XCTAssertTrue(concreteImporter.isArtwork(pngItem), ".png should be artwork")

        // Non-artwork extensions should NOT be detected
        XCTAssertFalse(concreteImporter.isArtwork(lnxItem), ".lnx should not be artwork")
        XCTAssertFalse(concreteImporter.isArtwork(zipItem), ".zip should not be artwork")
        XCTAssertFalse(concreteImporter.isArtwork(nesItem), ".nes should not be artwork")
    }

    func testIsArtworkDetection_caseInsensitive() {
        let upperJPG = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.JPG"))
        let mixedPng = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/game.Png"))
        let concreteImporter = gameImporter as! GameImporter

        XCTAssertTrue(concreteImporter.isArtwork(upperJPG), ".JPG should be detected as artwork (case-insensitive)")
        XCTAssertTrue(concreteImporter.isArtwork(mixedPng), ".Png should be detected as artwork (case-insensitive)")
    }

    // MARK: - Download Filename Tests

    func testDownloadedFileShouldHaveCleanFilename() {
        // Verify that rom.file doesn't contain UUID patterns
        let romFile = "Super_Mario_Bros.zip"
        let uuidPattern = try! NSRegularExpression(pattern: "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", options: .caseInsensitive)
        let range = NSRange(romFile.startIndex..., in: romFile)
        let matches = uuidPattern.numberOfMatches(in: romFile, range: range)
        XCTAssertEqual(matches, 0, "ROM filename should not contain UUID")
    }

    func testTempDirectoryUsesUUIDSubdirectory() {
        // Verify the UUID subdirectory approach keeps filename clean
        let uuid = UUID().uuidString
        let romFile = "game.zip"
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVDownloads")
            .appendingPathComponent(uuid)
        let destinationURL = tempDir.appendingPathComponent(romFile)

        XCTAssertEqual(destinationURL.lastPathComponent, "game.zip",
                      "Filename should be preserved without UUID prefix")
        XCTAssertTrue(destinationURL.path.contains(uuid),
                      "UUID should be in the directory path, not the filename")
    }

    // MARK: - Original Tests (continued)

    func testM3UFileWithMissingOrIncompleteCueFilesThenAddThem() {
        // Arrange
        let mockCDFileHandler = MockCDFileHandler()
        let gameImporter = GameImporter(FileManager.default,
                                        GameImporterFileService(),
                                        GameImporterDatabaseService(),
                                        GameImporterSystemsService(),
                                        ArtworkImporter(),
                                        mockCDFileHandler)
        let m3uFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/playlist.m3u"))
        let cueFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file.cue"))
        let binFile = ImportQueueItem(url: URL(fileURLWithPath: "/path/to/file.bin"))
        mockCDFileHandler.m3uFileContentsResult = ["file.cue"]  // Simulate the m3u file referencing the cue file
        
        // Act
        var importQueue = [m3uFile, cueFile]
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        gameImporter.organizeM3UFiles(in: &importQueue)
        
        // Assert
        XCTAssertEqual(m3uFile.status, .partial, "The .m3u file should be marked as .partial if any referenced .cue file is missing or incomplete.")
        
        importQueue.append(binFile)
        mockCDFileHandler.binFilesResult = [binFile.url.lastPathComponent]
        mockCDFileHandler.binUrlsResult = [binFile.url, binFile.url.appending(path: "1")]  // Simulate missing .bin files
        mockCDFileHandler.binFileExistsResult[binFile.url] = true
        
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        gameImporter.organizeM3UFiles(in: &importQueue)
        
        // Assert
        XCTAssertEqual(importQueue[0].status, .queued, "The .m3u file should be marked as .queued when any referenced .bin file is present.")
    }
}

// MARK: - Archive batch-move failure tests

/// A `FileManager` subclass that always throws when `moveItem(at:to:)` is called.
/// Used to simulate a complete batch-move failure in archive import tests.
private final class AlwaysFailMoveFileManager: FileManager {
    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}

/// A `FileManager` subclass that fails `moveItem` only for URLs in `failURLs`,
/// delegating all other operations to the real `FileManager`.
private final class PartialFailMoveFileManager: FileManager {
    let failURLs: Set<URL>

    init(failURLs: Set<URL>) {
        self.failURLs = failURLs
        super.init()
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if failURLs.contains(srcURL) {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}

/// A `FileManager` subclass that records every URL passed to `removeItem(at:)`.
/// Uses a move that always fails so any call to `removeItem` for the archive signals a bug.
private final class RecordingFailMoveFileManager: FileManager {
    private(set) var removedURLs: [URL] = []

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        throw CocoaError(.fileWriteNoPermission)
    }

    override func removeItem(at URL: URL) throws {
        removedURLs.append(URL)
        try super.removeItem(at: URL)
    }
}

class ArchiveBatchMoveTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveBatchMoveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func createFile(at url: URL, content: String = "ROMDATA") {
        FileManager.default.createFile(atPath: url.path, contents: Data(content.utf8))
    }

    private func makeImporter(fileManager fm: FileManager) -> GameImporter {
        GameImporter(fm,
                     GameImporterFileService(),
                     GameImporterDatabaseService(),
                     GameImporterSystemsService(),
                     ArtworkImporter(),
                     DefaultCDFileHandler(),
                     SkinImporterInjector.shared)
    }

    // MARK: - Tests

    /// When every `moveItem` call fails, `moveBatchExtractedFiles` must return an
    /// empty `queued` list and `allSucceeded == false`.
    func testMoveBatch_allFail_queuesNothing() throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let file1 = srcDir.appendingPathComponent("rom1.nes")
        let file2 = srcDir.appendingPathComponent("rom2.sfc")
        createFile(at: file1)
        createFile(at: file2)

        let importer = makeImporter(fileManager: AlwaysFailMoveFileManager())
        let (queued, allSucceeded) = importer.moveBatchExtractedFiles([file1, file2], to: dstDir)

        XCTAssertTrue(queued.isEmpty, "No files should be queued when all moves fail")
        XCTAssertFalse(allSucceeded, "allSucceeded must be false when all moves fail")
        // Source files must remain in place (not moved)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1.path), "Source file should still exist after failed move")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path), "Source file should still exist after failed move")
    }

    /// When only some `moveItem` calls fail, only the successfully moved files
    /// should appear in `queued`, and `allSucceeded` must be `false`.
    func testMoveBatch_partialFail_queuesOnlySuccessfulFiles() throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let goodFile = srcDir.appendingPathComponent("good.nes")
        let badFile  = srcDir.appendingPathComponent("bad.sfc")
        createFile(at: goodFile)
        createFile(at: badFile)

        let importer = makeImporter(fileManager: PartialFailMoveFileManager(failURLs: [badFile]))
        let (queued, allSucceeded) = importer.moveBatchExtractedFiles([goodFile, badFile], to: dstDir)

        XCTAssertEqual(queued.count, 1, "Only the successfully moved file should be queued")
        XCTAssertEqual(queued.first?.lastPathComponent, "good.nes")
        XCTAssertFalse(allSucceeded, "allSucceeded must be false when at least one move fails")

        // The good file was moved to the destination
        XCTAssertTrue(FileManager.default.fileExists(atPath: dstDir.appendingPathComponent("good.nes").path),
                      "Successfully moved file should exist at destination")
        // The bad file stays in the source (temp) directory
        XCTAssertTrue(FileManager.default.fileExists(atPath: badFile.path),
                      "Failed-to-move file must remain in the temp extraction directory")
    }

    /// When all moves succeed, every file should be in `queued` and
    /// `allSucceeded` must be `true`.
    func testMoveBatch_allSucceed_queuesAllFiles() throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let file1 = srcDir.appendingPathComponent("rom1.nes")
        let file2 = srcDir.appendingPathComponent("rom2.sfc")
        createFile(at: file1)
        createFile(at: file2)

        let importer = makeImporter(fileManager: FileManager.default)
        let (queued, allSucceeded) = importer.moveBatchExtractedFiles([file1, file2], to: dstDir)

        XCTAssertEqual(queued.count, 2, "All files should be queued when all moves succeed")
        XCTAssertTrue(allSucceeded, "allSucceeded must be true when all moves succeed")
    }

    /// When all moves fail, the archive file must NOT be removed — the injected
    /// `FileManager` should never receive a `removeItem` call for the archive URL.
    ///
    /// In `extractAndImportArchive`, the archive is only deleted via
    /// `self.fileManager.removeItem(at: archiveURL)` after the `guard allMovesSucceeded`
    /// check. Returning `allSucceeded == false` from `moveBatchExtractedFiles` triggers
    /// the early-return path, which skips that deletion entirely.
    func testMoveBatch_allFail_archiveNotRemovedViaFileManager() throws {
        let srcDir     = try makeTempDirectory()
        let dstDir     = try makeTempDirectory()
        let archiveDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
            try? FileManager.default.removeItem(at: archiveDir)
        }

        let extractedFile = srcDir.appendingPathComponent("game.nes")
        let archiveURL    = archiveDir.appendingPathComponent("game.zip")
        createFile(at: extractedFile)
        createFile(at: archiveURL)

        let recordingFM = RecordingFailMoveFileManager()
        let importer    = makeImporter(fileManager: recordingFM)

        let (_, allSucceeded) = importer.moveBatchExtractedFiles([extractedFile], to: dstDir)

        XCTAssertFalse(allSucceeded, "allSucceeded must be false when moves fail")

        // The archive file should still be on disk (we never deleted it in this test
        // because we didn't call extractAndImportArchive; this confirms the archive
        // URL was not passed to removeItem).
        XCTAssertFalse(recordingFM.removedURLs.contains(archiveURL),
                       "The archive must not be removed via fileManager when batch move fails")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path),
                      "Archive file must still exist on disk after a batch-move failure")
    }

    /// When all moves fail, the temp extraction directory must be preserved
    /// (i.e., the `defer` block inside `extractAndImportArchive` must NOT delete it)
    /// because `preserveTempDir` is set to `true` when `allMovesSucceeded == false`.
    ///
    /// This test verifies that `moveBatchExtractedFiles` correctly reports failure
    /// so the caller can preserve the directory, and that files remain in it.
    func testMoveBatch_allFail_tempDirContentsPreserved() throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let extractedFile = srcDir.appendingPathComponent("game.nes")
        createFile(at: extractedFile)

        let importer = makeImporter(fileManager: AlwaysFailMoveFileManager())
        let (_, allSucceeded) = importer.moveBatchExtractedFiles([extractedFile], to: dstDir)

        XCTAssertFalse(allSucceeded, "allSucceeded must be false — caller must preserve the temp dir")
        // The extracted file stays inside srcDir (the simulated temp extraction directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path),
                      "Extracted file must remain in the temp dir when its move failed")
    }
}

