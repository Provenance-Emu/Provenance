//
//  PVTGBDualTests.swift
//  PVTGBDual
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
@testable import PVTGBDual
@testable import PVTGBDualSwift

struct Test {

    @Test func testAllocDealloc() async throws {
        let core = PVTGBDualCore()
        #expect(core != nil)
    }
}
