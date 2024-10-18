//
//  Test.swift
//  PVVirtualJaguar
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
import PVEmulatorCore
@testable import libvisualboyadvance
@testable import PVVisualBoyAdvance

struct Test {
    
    let testRomFilename: String = ""

    @Test func VisualBoyAdvanceCoreTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let core = PVVisualBoyAdvanceCore()
        #expect(core != nil)
    }
    
    @Test func LoadFileTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let core = PVVisualBoyAdvanceCore()
        #expect(core != nil)

//        do {
//            try core.loadFile(atPath: testRomFilename)
//        } catch {
//            print("Failed to load file: \(error.localizedDescription)")
//            throw error
//        }
    }
}
