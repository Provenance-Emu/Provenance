import Foundation
import Testing
import PVRealm
import RealmSwift
@testable import PVUIBase

@MainActor
struct NetplayLibraryGamesTests {
    @Test func hostingIncludesUnplayedGamesButExcludesUnavailableEntries() throws {
        let realm = try makeRealm()
        let unplayed = game("Unplayed")
        let cloudOnly = game("Cloud")
        cloudOnly.isDownloaded = false
        let contentless = game("No ROM")
        contentless.contentless = true
        let hiddenPatch = game("Hidden Patch")
        hiddenPatch.isHiddenPatchVariant = true
        try realm.write { realm.add([unplayed, cloudOnly, contentless, hiddenPatch]) }

        let selection = NetplayLibraryLobbyView.localGames(in: realm, matching: "")

        #expect(selection.games.map(\.md5Hash) == [unplayed.md5Hash])
        #expect(selection.games.first?.lastPlayed == nil)
        #expect(selection.games.first?.isFrozen == true)
    }

    @Test func searchFindsTitlesAndSystemsIgnoringCaseAndAccents() throws {
        let realm = try makeRealm()
        let titleMatch = game("Pokémon")
        let systemMatch = game("Another Game")
        let system = PVSystem()
        system.identifier = UUID().uuidString
        system.name = "Handheld"
        systemMatch.system = system
        try realm.write { realm.add([titleMatch, systemMatch]) }

        #expect(NetplayLibraryLobbyView.localGames(in: realm, matching: " POKEMON ").games.map(\.md5Hash) == [titleMatch.md5Hash])
        #expect(NetplayLibraryLobbyView.localGames(in: realm, matching: "handheld").games.map(\.md5Hash) == [systemMatch.md5Hash])
    }

    @Test func renderingLimitKeepsFullMatchCountAndStableTitleOrder() throws {
        let realm = try makeRealm()
        try realm.write { realm.add([game("Zebra"), game("Alpha")]) }

        let selection = NetplayLibraryLobbyView.localGames(in: realm, matching: "", limit: 1)

        #expect(selection.total == 2)
        #expect(selection.games.map(\.title) == ["Alpha"])
    }

    private func makeRealm() throws -> Realm {
        try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
    }

    private func game(_ title: String) -> PVGame {
        let game = PVGame()
        game.md5Hash = UUID().uuidString
        game.title = title
        return game
    }
}
