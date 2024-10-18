//
//  Test.swift
//  PVPokeMini
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing

@testable import libpokemini
@testable import PokeMiniC
@testable import PVPokeMini
@testable import PVPokeMiniBridge

struct Test {
    @Test func testAllocDealloc() async throws {
        let core = PVPokeMiniEmulatorCore()
        #expect(core != nil)
    }
}
