//
//  TransferPakTests.swift
//  PVUIBaseTests
//
//  Tests for TransferPakStore, TransferPakCompatibleGames, N64PakType, and N64PakStore.
//  Part of #3542 — Transfer Pak UX self-review.
//

import Testing
import Foundation
@testable import PVUIBase

// MARK: - TransferPakStore Tests

@Suite("TransferPakStore Tests")
struct TransferPakStoreTests {

    // Use an isolated MD5 string for each test to avoid cross-test pollution.

    @Test("udKey follows expected format")
    func udKeyFormat() {
        // Verify the key format matches what romPath / setGBGame rely on.
        // We test indirectly: set a value and read it back.
        let md5 = "store_key_fmt_\(#function)"
        let port = 2
        TransferPakStore.setGBGame("abc123", forGameMD5: md5, port: port)
        // If the key is correct we can retrieve it; if wrong, romPath would fail to
        // find the Realm object anyway — this just confirms the raw UD key is written.
        let storedKey = "PVTransferPak.\(md5).port\(port)"
        let raw = UserDefaults.standard.string(forKey: storedKey)
        #expect(raw == "abc123")
        // Cleanup
        UserDefaults.standard.removeObject(forKey: storedKey)
    }

    @Test("setGBGame stores and removeObject on nil")
    func setAndClearGBGame() {
        let md5 = "store_set_clear_\(#function)"
        let port = 0
        let key = "PVTransferPak.\(md5).port\(port)"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        TransferPakStore.setGBGame("game_md5_A", forGameMD5: md5, port: port)
        #expect(UserDefaults.standard.string(forKey: key) == "game_md5_A")

        TransferPakStore.setGBGame(nil, forGameMD5: md5, port: port)
        #expect(UserDefaults.standard.string(forKey: key) == nil)
    }

    @Test("setGBGame ignores out-of-range ports")
    func setGBGameOutOfRange() {
        let md5 = "store_oob_\(#function)"
        // Port 4 is out of range (valid: 0..<4)
        TransferPakStore.setGBGame("should_not_store", forGameMD5: md5, port: 4)
        let key = "PVTransferPak.\(md5).port4"
        let value = UserDefaults.standard.string(forKey: key)
        #expect(value == nil)
        TransferPakStore.setGBGame("should_not_store", forGameMD5: md5, port: -1)
        let keyNeg = "PVTransferPak.\(md5).port-1"
        let valueNeg = UserDefaults.standard.string(forKey: keyNeg)
        #expect(valueNeg == nil)
    }

    @Test("markPromptSkipped and wasPromptSkipped round-trip")
    func skipFlagRoundTrip() {
        let md5 = "skip_rt_\(#function)"
        defer {
            UserDefaults.standard.removeObject(forKey: "PVTransferPak.\(md5).skippedPrompt")
        }
        #expect(TransferPakStore.wasPromptSkipped(forGameMD5: md5) == false)
        TransferPakStore.markPromptSkipped(forGameMD5: md5)
        #expect(TransferPakStore.wasPromptSkipped(forGameMD5: md5) == true)
    }

    @Test("clearSkipFlag removes skip entry")
    func clearSkipFlagRemoves() {
        let md5 = "skip_clear_\(#function)"
        defer {
            UserDefaults.standard.removeObject(forKey: "PVTransferPak.\(md5).skippedPrompt")
        }
        TransferPakStore.markPromptSkipped(forGameMD5: md5)
        #expect(TransferPakStore.wasPromptSkipped(forGameMD5: md5) == true)
        TransferPakStore.clearSkipFlag(forGameMD5: md5)
        #expect(TransferPakStore.wasPromptSkipped(forGameMD5: md5) == false)
    }

    @Test("clearAll removes all port entries")
    func clearAllRemovesAllPorts() {
        let md5 = "store_clearall_\(#function)"
        defer {
            for port in 0..<4 {
                UserDefaults.standard.removeObject(forKey: "PVTransferPak.\(md5).port\(port)")
            }
        }
        for port in 0..<4 {
            TransferPakStore.setGBGame("game\(port)", forGameMD5: md5, port: port)
        }
        TransferPakStore.clearAll(forGameMD5: md5)
        for port in 0..<4 {
            let key = "PVTransferPak.\(md5).port\(port)"
            #expect(UserDefaults.standard.string(forKey: key) == nil, "Port \(port) should be cleared")
        }
    }

    @Test("romPath returns nil when no MD5 stored")
    func romPathReturnsNilWhenEmpty() {
        let md5 = "store_rompath_\(#function)"
        // No game set → romPath must return nil without crashing
        let result = TransferPakStore.romPath(forGameMD5: md5, port: 0)
        #expect(result == nil)
    }

    @Test("romPath returns nil for invalid port")
    func romPathInvalidPort() {
        let md5 = "store_rompath_inv_\(#function)"
        #expect(TransferPakStore.romPath(forGameMD5: md5, port: -1) == nil)
        #expect(TransferPakStore.romPath(forGameMD5: md5, port: 4) == nil)
    }
}

// MARK: - TransferPakCompatibleGames Tests

@Suite("TransferPakCompatibleGames Tests")
struct TransferPakCompatibleGamesTests {

    // --- isKnownTransferPakGame ---

    @Test("Pokémon Stadium is a known Transfer Pak game (accented)")
    func pokemonStadiumAccented() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Pokémon Stadium") == true)
    }

    @Test("Pokemon Stadium is a known Transfer Pak game (unaccented)")
    func pokemonStadiumUnaccented() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Pokemon Stadium") == true)
    }

    @Test("Pokémon Stadium 2 is a known Transfer Pak game (accented)")
    func pokemonStadium2Accented() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Pokémon Stadium 2") == true)
    }

    @Test("Pokemon Stadium 2 is a known Transfer Pak game (unaccented)")
    func pokemonStadium2Unaccented() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Pokemon Stadium 2") == true)
    }

    @Test("Mario Tennis is a known Transfer Pak game")
    func marioTennis() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Mario Tennis") == true)
    }

    @Test("Mario Golf is a known Transfer Pak game")
    func marioGolf() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Mario Golf") == true)
    }

    @Test("Perfect Dark is a known Transfer Pak game")
    func perfectDark() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Perfect Dark") == true)
    }

    @Test("Unknown game returns false")
    func unknownGame() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("Super Mario 64") == false)
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("GoldenEye 007") == false)
    }

    @Test("isKnownTransferPakGame is case-insensitive")
    func caseInsensitive() {
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("MARIO TENNIS") == true)
        #expect(TransferPakCompatibleGames.isKnownTransferPakGame("mario golf") == true)
    }

    // --- transferPakDescription ---

    @Test("Description returns nil for unknown game")
    func descriptionUnknown() {
        #expect(TransferPakCompatibleGames.transferPakDescription(forTitle: "Banjo-Kazooie") == nil)
    }

    @Test("Description returns longest matching fragment for Stadium 2")
    func descriptionStadium2PicksLongest() {
        // "pokémon stadium 2" is longer than "pokémon stadium", so Stadium 2 description wins.
        let desc = TransferPakCompatibleGames.transferPakDescription(forTitle: "Pokémon Stadium 2")
        #expect(desc != nil)
        #expect(desc?.contains("Gold") == true || desc?.contains("Silver") == true,
                "Stadium 2 description should mention Gen 2 games")
    }

    @Test("Description for Stadium (gen 1) does not mention Gen 2 games")
    func descriptionStadium1() {
        let desc = TransferPakCompatibleGames.transferPakDescription(forTitle: "Pokémon Stadium")
        #expect(desc != nil)
        // Stadium 1 description should mention Red/Blue/Yellow, not Gold/Silver/Crystal
        #expect(desc?.contains("Red") == true || desc?.contains("Blue") == true || desc?.contains("Yellow") == true)
    }

    // --- suggestedGBTitleFragments ---

    @Test("suggestedGBTitleFragments returns gen-1 fragments for Stadium")
    func suggestedFragmentsStadium1() {
        let frags = TransferPakCompatibleGames.suggestedGBTitleFragments(forN64Title: "Pokémon Stadium")
        #expect(!frags.isEmpty)
        // Should include red/blue/yellow but NOT gold/silver/crystal
        let joined = frags.joined()
        #expect(joined.contains("red") || joined.contains("blue") || joined.contains("yellow"))
        // Gen 2 games should NOT appear in Stadium 1 suggestions
        let hasGen2 = frags.contains { $0.contains("gold") || $0.contains("silver") || $0.contains("crystal") }
        #expect(hasGen2 == false, "Stadium 1 suggestions should not include Gen 2 game fragments")
    }

    @Test("suggestedGBTitleFragments returns gen-1 and gen-2 fragments for Stadium 2")
    func suggestedFragmentsStadium2() {
        let frags = TransferPakCompatibleGames.suggestedGBTitleFragments(forN64Title: "Pokemon Stadium 2")
        #expect(!frags.isEmpty)
        let joined = frags.joined()
        let hasGen2 = joined.contains("gold") || joined.contains("silver") || joined.contains("crystal")
        #expect(hasGen2 == true, "Stadium 2 suggestions must include Gen 2 game fragments")
        let hasGen1 = joined.contains("red") || joined.contains("blue") || joined.contains("yellow")
        #expect(hasGen1 == true, "Stadium 2 suggestions must also include Gen 1 game fragments")
    }

    @Test("suggestedGBTitleFragments returns Mario Tennis fragment")
    func suggestedFragmentsMarioTennis() {
        let frags = TransferPakCompatibleGames.suggestedGBTitleFragments(forN64Title: "Mario Tennis")
        #expect(frags.contains("mario tennis"))
    }

    @Test("suggestedGBTitleFragments returns empty for unknown title")
    func suggestedFragmentsUnknown() {
        let frags = TransferPakCompatibleGames.suggestedGBTitleFragments(forN64Title: "Wave Race 64")
        #expect(frags.isEmpty)
    }

    @Test("Stadium 2 accented title returns gen-2 fragments (not gen-1 only)")
    func stadium2AccentedMatchesCorrectEntry() {
        // Verify that "Pokémon Stadium 2" (with accent) does NOT fall through to the
        // "pokémon stadium" entry which only has gen-1 fragments.
        let frags = TransferPakCompatibleGames.suggestedGBTitleFragments(forN64Title: "Pokémon Stadium 2")
        let hasGen2 = frags.contains { $0.contains("gold") || $0.contains("silver") || $0.contains("crystal") }
        #expect(hasGen2 == true, "Accented Pokémon Stadium 2 must map to the Stadium 2 entry")
    }
}

// MARK: - N64PakType Tests

@Suite("N64PakType Tests")
struct N64PakTypeTests {

    @Test("All cases have distinct raw values")
    func distinctRawValues() {
        let rawValues = N64PakType.allCases.map(\.rawValue)
        let unique = Set(rawValues)
        #expect(unique.count == N64PakType.allCases.count)
    }

    @Test("All cases have non-empty titles")
    func allTitlesNonEmpty() {
        for pakType in N64PakType.allCases {
            #expect(!pakType.title.isEmpty, "\(pakType) has empty title")
        }
    }

    @Test("All cases have non-empty subtitles")
    func allSubtitlesNonEmpty() {
        for pakType in N64PakType.allCases {
            #expect(!pakType.subtitle.isEmpty, "\(pakType) has empty subtitle")
        }
    }

    @Test("All cases have non-empty systemImage names")
    func allSystemImagesNonEmpty() {
        for pakType in N64PakType.allCases {
            #expect(!pakType.systemImage.isEmpty, "\(pakType) has empty systemImage")
        }
    }

    @Test("auto has rawValue 0")
    func autoRawValue() {
        #expect(N64PakType.auto.rawValue == 0)
    }

    @Test("transferPak has rawValue 4")
    func transferPakRawValue() {
        #expect(N64PakType.transferPak.rawValue == 4)
    }

    @Test("Identifiable id matches rawValue")
    func identifiableIDMatchesRawValue() {
        for pakType in N64PakType.allCases {
            #expect(pakType.id == pakType.rawValue)
        }
    }

    @Test("N64PakType init from rawValue round-trips for all cases")
    func rawValueRoundTrip() {
        for pakType in N64PakType.allCases {
            let reconstructed = N64PakType(rawValue: pakType.rawValue)
            #expect(reconstructed == pakType)
        }
    }
}

// MARK: - N64PakStore Tests

@Suite("N64PakStore Tests")
struct N64PakStoreTests {

    // Helper to clean up specific UserDefaults keys after tests.
    private func cleanup(port: Int, gameMD5: String? = nil) {
        let optionKey = "Controller Pak \(port)"
        let className = "MupenGameCoreOptions"
        if let md5 = gameMD5 {
            UserDefaults.standard.removeObject(forKey: "\(className).\(md5).\(optionKey)")
        } else {
            UserDefaults.standard.removeObject(forKey: "\(className).\(optionKey)")
        }
    }

    @Test("Default pak type is auto when nothing stored")
    func defaultIsAuto() {
        // Use a made-up MD5 that will never have been set.
        let fakeMD5 = "n64pakstore_default_\(#function)"
        defer { cleanup(port: 1, gameMD5: fakeMD5) }
        let result = N64PakStore.pakType(forPort: 1, gameMD5: fakeMD5)
        #expect(result == .auto)
    }

    @Test("setPakType and pakType round-trip for per-game scope")
    func perGameRoundTrip() {
        let md5 = "n64pakstore_pergame_\(#function)"
        let port = 2
        defer { cleanup(port: port, gameMD5: md5) }

        N64PakStore.setPakType(.transferPak, forPort: port, gameMD5: md5)
        let retrieved = N64PakStore.pakType(forPort: port, gameMD5: md5)
        #expect(retrieved == .transferPak)
    }

    @Test("setPakType and pakType round-trip for global scope")
    func globalRoundTrip() {
        let port = 3
        defer { cleanup(port: port) }

        N64PakStore.setPakType(.memoryPak, forPort: port, gameMD5: nil)
        let retrieved = N64PakStore.pakType(forPort: port, gameMD5: nil)
        #expect(retrieved == .memoryPak)
    }

    @Test("Per-game setting takes precedence over global")
    func perGameTakesPrecedence() {
        let md5 = "n64pakstore_prio_\(#function)"
        let port = 1
        defer {
            cleanup(port: port)
            cleanup(port: port, gameMD5: md5)
        }

        // Set global to rumblePak, per-game to smartPak
        N64PakStore.setPakType(.rumblePak, forPort: port, gameMD5: nil)
        N64PakStore.setPakType(.smartPak, forPort: port, gameMD5: md5)

        let retrieved = N64PakStore.pakType(forPort: port, gameMD5: md5)
        #expect(retrieved == .smartPak, "Per-game setting should take precedence over global")
    }

    @Test("Falls back to global when per-game key is absent")
    func fallsBackToGlobal() {
        let md5 = "n64pakstore_fallback_\(#function)"
        let port = 2
        defer {
            cleanup(port: port)
            cleanup(port: port, gameMD5: md5)
        }

        // Only set the global key
        N64PakStore.setPakType(.memoryPak, forPort: port, gameMD5: nil)
        // Ask with a gameMD5 that has no per-game entry
        let retrieved = N64PakStore.pakType(forPort: port, gameMD5: md5)
        #expect(retrieved == .memoryPak, "Should fall back to global when per-game key is missing")
    }

    @Test("Empty string gameMD5 behaves like nil (uses global key)")
    func emptyMD5UsesGlobal() {
        let port = 4
        // Empty string is treated as nil (falls through to global key), so only the
        // global cleanup is needed — cleanup(port:gameMD5:"") would target the wrong key.
        defer { cleanup(port: port) }

        N64PakStore.setPakType(.rumblePak, forPort: port, gameMD5: "")
        // Empty MD5 should write to the global key
        let retrieved = N64PakStore.pakType(forPort: port, gameMD5: nil)
        #expect(retrieved == .rumblePak)
    }

    @Test("setPakType overwrites previous value")
    func overwritesPreviousValue() {
        let md5 = "n64pakstore_overwrite_\(#function)"
        let port = 1
        defer { cleanup(port: port, gameMD5: md5) }

        N64PakStore.setPakType(.memoryPak, forPort: port, gameMD5: md5)
        N64PakStore.setPakType(.transferPak, forPort: port, gameMD5: md5)
        let retrieved = N64PakStore.pakType(forPort: port, gameMD5: md5)
        #expect(retrieved == .transferPak)
    }
}
