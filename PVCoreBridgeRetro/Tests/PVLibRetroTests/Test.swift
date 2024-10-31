//
//  Test.swift
//  PVLibRetro
//
//  Created by Joseph Mattiello on 10/5/24.
//

import Testing
@testable import libretro
@testable import PVLibRetro

struct Test {

    @Test func LibRetroTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let bridge = PVLibRetroCoreBridge()
        #expect(bridge != nil)
    }
    
//    @Test func LoadFileTest() async throws {
//        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
//        let core = PVLibRetroCoreBridge()
//        #expect(core != nil)

//        do {
//            try core.loadFile(atPath: testRomFilename)
//        } catch {
//            print("Failed to load file: \(error.localizedDescription)")
//            throw error
//        }
//    }
}
