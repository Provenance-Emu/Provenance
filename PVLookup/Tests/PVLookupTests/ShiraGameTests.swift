//
//  ShiraGameTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Testing
@testable import PVLookup
@testable import ShiraGame

struct ShiraGameTests {
    
    let database = ShiraGameDB()

    @Test func testSearchGameByID() {
        let idToSearch = 1
        
        let expectedEntryName = "3-D Genesis (USA) (Proto)"
        let expectedEntryTitle = "3-D Genesis"

        let resultMaybe = database.getGame(byID: idToSearch)
        #expect(resultMaybe != nil)
        let result = resultMaybe!

        #expect(result.entryName == expectedEntryName)
        #expect(result.entryTitle == expectedEntryTitle)
    }
    
    @Test func testSearchROMByMD5() {
        let md5 = "cac9928a84e1001817b223f0cecaa3f2"
        
        let expectedGameID = 1
        
        let resultMaybe = database.searchROM(byMD5: md5)
        #expect(resultMaybe != nil)
        let result = resultMaybe!

        #expect(result == expectedGameID)
    }
    
//    @Test func testgetROMsByID() {
//        let md5 = "cac9928a84e1001817b223f0cecaa3f2"
//        
//        let expectedFileName = "3-D Genesis (USA) (Proto).a26"
//        let expectedMD5 = "cac9928a84e1001817b223f0cecaa3f2"
//        let expectedCRC = "931a0bdc"
//        let expectedSHA1 = "0e146e5eb1a68cba4f8fa55ec6f125438efcfcb4"
//        let expectedSize = 8192
//        let expectedGameID = 1
//        
//        let resultMaybe = database.searchROM(byMD5: md5)
//        #expect(resultMaybe != nil)
//        let result = resultMaybe!
//
//        #expect(result == expectedGameID)
//    }
}
