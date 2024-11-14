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
        var binFilesResult: [URL] = []
        var m3uFileContentsResult: [String] = []
        var binFileExistsResult: [URL:Bool] = [:]
        
        func findAssociatedBinFiles(for cueFileItem: ImportQueueItem) throws -> [URL] {
            return binFilesResult
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
        
        // Act
        var importQueue = [cueFile]
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        
        // Assert
        XCTAssertEqual(importQueue[0].status, .partial, "The .cue file should be marked as .partial when any referenced .bin file is missing.")
        
        importQueue.append(binFile)
        mockCDFileHandler.binFilesResult = [binFile.url]
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
        mockCDFileHandler.binFilesResult = [binFile.url]
        mockCDFileHandler.binFileExistsResult[binFile.url] = true
        
        gameImporter.organizeCueAndBinFiles(in: &importQueue)
        gameImporter.organizeM3UFiles(in: &importQueue)
        
        // Assert
        XCTAssertEqual(importQueue[0].status, .queued, "The .m3u file should be marked as .queued when any referenced .bin file is present.")
    }
}

