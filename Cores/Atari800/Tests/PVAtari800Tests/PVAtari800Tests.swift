//
//  PVAtari800Tests.swift
//  PVAtari800
//
//  Created by Joseph Mattiello on 8/5/24.
//

import Testing
import PVAtari800
import PVAtari800Swift

struct Test {

    @Test func testAllocDealloc() async throws {
        let core = ATR800GameCore()
        #expect(core != nil)
    }
}
