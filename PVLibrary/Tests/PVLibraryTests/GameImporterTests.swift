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
        gameImporter = GameImporter(FileManager.default)
//        await gameImporter.initSystems() <--- this will crash until we get proper DI
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        gameImporter = nil
    }
    
    func testImportSingleGame_Success() {
            // Arrange
            let testData = "Test Game Data".data(using: .utf8)
        }
}
