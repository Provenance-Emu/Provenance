//
//  Test.swift
//  PVFreeDO
//
//  Created by Joseph Mattiello on 9/4/24.
//

import Testing
import PVEmulatorCore
@testable import PVFreeDOGameCore
@testable import PVFreeDOGameCoreSwift
@testable import libfreedo

struct Test {
    
    let testRomFilename: String = "3DO 240p Calibration Suite V1C.iso"

    @Test func VirtualJaguarTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let core = PVFreeDOGameCore()
        #expect(core != nil)
    }
    
    @Test func LoadFileTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let core = PVFreeDOGameCoreBridge()
        #expect(core != nil)

        do {
            try core.loadFile(atPath: testRomFilename)
        } catch {
            print("Failed to load file: \(error.localizedDescription)")
            throw error
        }
    }
}
