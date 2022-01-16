//
//  PVLibraryTests.swift
//  PVLibraryTests
//
//  Created by Joseph Mattiello on 7/24/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

@testable import PVLibrary
import XCTest

class PVLibraryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        try! RomDatabase.initDefaultDatabase()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSQLSearch() {
        let importer = GameImporter.shared

        // Expected test data
        // Two entries share the same romFileName,
        let expected1: [String: Any] = ["romID": 55288, "systemID": 34, "regionID": 21, "romHashCRC": "5AD4DE86", "romHashMD5": "C43FA61C0D031D85B357BDDC055B24F7", "romHashSHA1": "377AE436A8FAEED2AB8E48939D6DE824232F8F2D", "romSize": 853, "romFileName": "NHL 97 (USA).cue", "romExtensionlessFileName": "NHL 97 (USA)", "romSerial": "T-5016H", "romHeader": "53454741205345474153415455524E205345474120545020542D353020202020542D353031364820202056312E303030313939363130323543442D312F312020552020202020202020202020202020204A4154202020202020202020202020204E484C2039372053617475726E2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000001000000000000000000000000000002F0000000000000000000000000000", "romLanguage": "English", "TEMPromRegion": "USA", "romDumpSource": "Redump"]

        let expected2: [String: Any?] = ["romID": 67221, "systemID": 38, "regionID": 21, "romHashCRC": "E8293371", "romHashMD5": "C02F86B655B981E04959AADEFC8103F6", "romHashSHA1": "BF8BD066BEBF5451E4CDD5D09D841C83E9D14EEF", "romSize": 936, "romFileName": "NHL 97 (USA).cue", "romExtensionlessFileName": "NHL 97 (USA)", "romSerial": "SLUS-00030", "romHeader": nil, "romLanguage": "English", "TEMPromRegion": "USA", "romDumpSource": "Redump"]

        let md5SearchResult = try! importer.searchDatabase(usingKey: "romHashMD5", value: expected1["romHashMD5"]! as! String)
        let md5SearchCorrectSystemResult = try! importer.searchDatabase(usingKey: "romHashMD5", value: expected1["romHashMD5"]! as! String, systemID: 34)
        let md5SearchIncorrectSystemResult = try! importer.searchDatabase(usingKey: "romHashMD5", value: expected1["romHashMD5"]! as! String, systemID: 99)

        XCTAssertNotNil(md5SearchResult)
        XCTAssertNotNil(md5SearchCorrectSystemResult)
        XCTAssertNil(md5SearchIncorrectSystemResult)

        XCTAssertNotNil(md5SearchResult?.first)
        XCTAssertNotNil(md5SearchCorrectSystemResult?.first)

        XCTAssertEqual(md5SearchResult!.count, 1)
        XCTAssertEqual(md5SearchCorrectSystemResult!.count, 1)

        let first1 = md5SearchResult!.first!
        XCTAssertEqual(first1["serial"] as! String, expected1["romSerial"]! as! String)

        let fileNameSearch = try! importer.searchDatabase(usingKey: "romFileName", value: expected1["romFileName"]! as! String)
        XCTAssertNotNil(md5SearchResult?.first)
        XCTAssertGreaterThan(fileNameSearch!.count, 1)

        XCTAssertEqual(fileNameSearch![0]["serial"] as! String, expected1["romSerial"]! as! String)
        XCTAssertEqual(fileNameSearch![1]["serial"] as! String, expected2["romSerial"]! as! String)
    }
}
