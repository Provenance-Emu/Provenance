// LibretroChtParserTests.swift
// PVLibraryTests
//
// Verifies parsing of Flycast/RetroArch memory `.cht` entries (empty `cheatN_code`).

import Testing
@testable import PVLibrary

struct LibretroChtParserTests {

    @Test("Dreamcast-style address cheats produce entries when code is empty")
    func dreamcastAddressCheats() {
        let fixture = """
        cheats = "2"
        cheat0_desc = "Story Mode Codes-Max Bombs P1"
        cheat0_code = ""
        cheat0_address = "8867886"
        cheat0_value = "35975"
        cheat0_cheat_type = "4"
        cheat1_desc = "Second code"
        cheat1_code = "DEADBEEF CAFEBABE"
        """
        let entries = parseLibretroCheatIniText(
            fixture,
            romTitle: "Bomberman Online",
            systemName: "Sega - Dreamcast",
            idOffset: 0
        )
        #expect(entries.count == 2)
        #expect(entries[0].cheatName.contains("Max Bombs"))
        #expect(entries[0].cheatCode == "8867886 35975 4")
        #expect(entries[1].cheatCode == "DEADBEEF CAFEBABE")
    }

    @Test("Classic code-only cheats still parse")
    func classicCodeLines() {
        let fixture = """
        cheats = 1
        cheat0_desc = "Infinite lives"
        cheat0_code = "01FF99C5"
        """
        let entries = parseLibretroCheatIniText(fixture, romTitle: "Test", systemName: nil, idOffset: 0)
        #expect(entries.count == 1)
        #expect(entries[0].cheatCode == "01FF99C5")
    }
}
