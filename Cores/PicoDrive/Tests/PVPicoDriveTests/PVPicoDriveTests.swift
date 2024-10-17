//
//  Test.swift
//  PVPicoDrive
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
@testable import PVPicoDrive
@testable import PVPicoDriveSwift

struct Test {
    @Test func testAllocDealloc() async throws {
        let core = PicodriveGameCore()
        #expect(core != nil)
    }
}
