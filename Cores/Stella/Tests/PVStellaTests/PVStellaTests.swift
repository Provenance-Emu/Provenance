//
//  Test.swift
//  PVStella
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
@testable import PVStella
@testable import PVStellaSwift

struct Test {
    @Test func testAllocDealloc() async throws {
        let core = PVStellaGameCore()
        #expect(core != nil)
    }
}
