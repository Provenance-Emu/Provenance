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
}

