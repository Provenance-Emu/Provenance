//
//  Test.swift
//  PVVirtualJaguar
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
@testable import libgambatte
@testable import PVGambatte

struct Test {
    
    let testRomFilename: String = ""

    @Test func PVGBEmulatorCoreTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let core = PVGBEmulatorCore()
        #expect(core != nil)
    }
    
    @Test func LoadFileTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let core = PVGBEmulatorCore()
        #expect(core != nil)

//        do {
//            try core.loadFile(atPath: testRomFilename)
//        } catch {
//            print("Failed to load file: \(error.localizedDescription)")
//            throw error
//        }
    }
}
