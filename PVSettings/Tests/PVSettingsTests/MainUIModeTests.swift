//
//  MainUIModeTests.swift
//  PVSettings
//
//  The legacy UIKit main UI was removed; installs that stored it must still decode.
//

import Testing
@testable import PVSettings
import Foundation

@Suite("MainUIMode decoding", .serialized)
struct MainUIModeTests {

    private func decode(_ rawValue: String) throws -> MainUIMode {
        let json = try JSONEncoder().encode(rawValue)
        return try JSONDecoder().decode(MainUIMode.self, from: json)
    }

    @Test("The removed UIKit value decodes to the platform default")
    func legacyUIKitDecodesToDefault() throws {
        let mode = try decode(MainUIMode.legacyUIKitRawValue)
        #expect(mode == Defaults.Keys.mainUIMode.defaultValue)
    }

    @Test("Every current mode round-trips through Codable")
    func currentModesRoundTrip() throws {
        for mode in MainUIMode.allCases {
            let data = try JSONEncoder().encode(mode)
            #expect(try JSONDecoder().decode(MainUIMode.self, from: data) == mode)
        }
    }

    @Test("An unknown value still fails to decode")
    func unknownValueThrows() {
        #expect(throws: DecodingError.self) {
            _ = try decode("Not A Mode")
        }
    }

    @Test("A stored UIKit preference reads back as the platform default")
    func storedLegacyPreferenceReadsAsDefault() {
        let key = Defaults.Keys.mainUIMode
        defer { Defaults.reset(key) }
        let stored = String(data: (try? JSONEncoder().encode(MainUIMode.legacyUIKitRawValue)) ?? Data(), encoding: .utf8)
        UserDefaults.standard.set(stored, forKey: key.name)
        #expect(Defaults[key] == key.defaultValue)
    }
}
