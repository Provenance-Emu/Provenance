//
//  Test.swift
//  PVPokeMini
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
@testable import PVPokeMini
@testable import PokeMiniSwift

struct Test {
    @Test func testAllocDealloc() async throws {
        let core = PVPokeMiniEmulatorCore()
        #expect(core != nil)
    }
}
