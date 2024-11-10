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
}

