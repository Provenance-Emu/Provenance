import Testing
@testable import PVSwiftUI

@Suite("SettingsSearchIndex")
struct SettingsSearchIndexTests {

    // MARK: Index integrity

    @Test("Entry ids are unique")
    func idsAreUnique() {
        let ids = SettingsSearchIndex.entries.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every entry points at a known section title")
    func sectionsAreKnownTitles() {
        for entry in SettingsSearchIndex.entries {
            #expect(SettingsSectionTitle.all.contains(entry.section), "\(entry.id) uses unknown section \(entry.section)")
        }
    }

    @Test("Section title values stay stable because they are the persisted collapse keys")
    func sectionTitlesAreStable() {
        #expect(SettingsSectionTitle.controller == "Controller")
        #expect(SettingsSectionTitle.libraryManagement == "Library Management")
        #expect(SettingsSectionTitle.recording == "Recording & Streaming")
    }

    @Test("tvOS folds the iOS controller sub-sections and legal rows into the sections tvOS actually has")
    func tvOSSectionMapping() {
        let rumble = SettingsSearchIndex.entries.first { $0.id == "haptics.rumble" }
        let licenses = SettingsSearchIndex.entries.first { $0.id == "legal.licenses" }
        #expect(rumble?.tvOSSection == SettingsSectionTitle.controller)
        #expect(licenses?.tvOSSection == SettingsSectionTitle.tvOSAbout)
    }

    // MARK: Query handling

    @Test("Queries under the minimum length return nothing")
    func minimumLength() {
        #expect(SettingsSearchIndex.search("").isEmpty)
        #expect(SettingsSearchIndex.search("a").isEmpty)
        #expect(SettingsSearchIndex.search("  a ").isEmpty)
        #expect(!SettingsSearchIndex.search("fp").isEmpty)
    }

    @Test("Matching ignores case and diacritics")
    func caseAndDiacriticInsensitive() {
        let lower = SettingsSearchIndex.search("pokemon").map(\.id)
        let accented = SettingsSearchIndex.search("POKÉMON").map(\.id)
        #expect(lower.contains("adv.transferpak"))
        #expect(lower == accented)
    }

    @Test("Every token must match somewhere")
    func allTokensMustMatch() {
        let both = SettingsSearchIndex.search("auto save").map(\.id)
        #expect(both.contains("saves.autosave"))
        #expect(SettingsSearchIndex.search("auto zzzzqqq").isEmpty)
    }

    @Test("Tokens may match across title, subtitle, keywords and section")
    func tokensMatchAcrossFields() {
        // "crt" is a keyword and "video" is the section; neither is in the title.
        let ids = SettingsSearchIndex.search("crt video").map(\.id)
        #expect(ids.contains("video.filters"))
    }

    // MARK: Ranking

    @Test("Title-prefix matches come before title-contains, which come before other matches")
    func ranking() throws {
        let ids = SettingsSearchIndex.search("rumble").map(\.id)
        let titlePrefix = try #require(ids.firstIndex(of: "haptics.profiles")) // "Rumble Profiles"
        let titleContains = try #require(ids.firstIndex(of: "haptics.rumble")) // "Game Rumble"
        let otherMatch = try #require(ids.firstIndex(of: "haptics.feedback")) // only the section name matches
        #expect(titlePrefix < titleContains)
        #expect(titleContains < otherMatch)
    }

    // MARK: Real queries

    @Test("autosave finds the auto save and timed auto save rows")
    func autosave() {
        let ids = SettingsSearchIndex.search("autosave").map(\.id)
        #expect(ids.contains("saves.autosave"))
        #expect(ids.contains("saves.timed"))
    }

    @Test("rumble finds the rumble rows in the Controller tab")
    func rumble() {
        let results = SettingsSearchIndex.search("rumble")
        #expect(results.contains { $0.id == "haptics.motors" && $0.tab == .controller })
        #expect(results.contains { $0.id == "haptics.test" })
    }

    @Test("icloud finds cloud sync entries")
    func icloud() {
        let ids = SettingsSearchIndex.search("icloud").map(\.id)
        #expect(ids.contains("libman.cloudsync"))
        #expect(ids.contains("adv.icloudsync"))
    }

    @Test("deadzone finds the analog deadzone rows")
    func deadzone() {
        let ids = SettingsSearchIndex.search("deadzone").map(\.id)
        #expect(ids.contains("deadzone.universal"))
    }
}
