//
//  BezelProjectTests.swift
//  PVSettings
//
//  Matching a game to its artwork, and reading The Bezel Project's lists.
//

import Foundation
import Testing
@testable import PVSettings

@Suite("BezelNameMatcher")
struct BezelNameMatcherTests {

    /// Names in the style of the SNES pack.
    private let candidates = [
        "ActRaiser (USA)",
        "ActRaiser (USA) (Beta)",
        "ActRaiser (USA) (Arcade)",
        "ActRaiser 2 (USA)",
        "Addams Family, The (USA)",
        "Addams Family Values (USA) (En,Fr,De)",
        "Legend of Zelda, The - A Link to the Past (USA)",
        "Legend of Zelda, The - A Link to the Past (Europe)",
        "Pokémon Stadium (Japan)",
        "Final Fight (Japan)",
        "Final Fight (Europe)",
        "Tom & Jerry (USA)"
    ]

    private func match(_ romName: String, title: String? = nil, exactOnly: Bool = false) -> String? {
        BezelNameMatcher.match(romName: romName, title: title, candidates: candidates, exactOnly: exactOnly)
    }

    @Test("The same name matches, whatever its case or accents")
    func sameName() {
        #expect(match("ActRaiser (USA)") == "ActRaiser (USA)")
        #expect(match("actraiser (usa) (beta)") == "ActRaiser (USA) (Beta)")
        #expect(match("Pokemon Stadium (Japan)") == "Pokémon Stadium (Japan)")
    }

    @Test("The same title picks the entry with the closest tags")
    func closestTags() {
        // A revision the pack does not have: the plain USA entry, not the beta.
        #expect(match("ActRaiser (USA) (Rev 1)") == "ActRaiser (USA)")
        // No tags at all: the entry with the fewest.
        #expect(match("ActRaiser") == "ActRaiser (USA)")
        #expect(match("actraiser 2") == "ActRaiser 2 (USA)")
        // Bracket tags from other naming schemes count as tags too.
        #expect(match("ActRaiser (USA) [!]") == "ActRaiser (USA)")
    }

    @Test("The game's region wins, then USA, World, Europe, Japan")
    func regions() {
        #expect(match("Legend of Zelda, The - A Link to the Past (Europe) (Rev 1)") == "Legend of Zelda, The - A Link to the Past (Europe)")
        #expect(match("Legend of Zelda, The - A Link to the Past (France)") == "Legend of Zelda, The - A Link to the Past (USA)")
        #expect(match("Final Fight (USA)") == "Final Fight (Europe)")
        #expect(match("Final Fight (USA, Europe)") == "Final Fight (Europe)")
    }

    @Test("Articles, punctuation and ampersands do not matter")
    func articlesAndPunctuation() {
        #expect(match("The Addams Family") == "Addams Family, The (USA)")
        #expect(match("The Legend of Zelda: A Link to the Past (USA)") == "Legend of Zelda, The - A Link to the Past (USA)")
        #expect(match("Tom and Jerry (USA)") == "Tom & Jerry (USA)")
    }

    @Test("The library title is tried when the file name finds nothing")
    func titleFallback() {
        #expect(match("slus-00001", title: "ActRaiser 2") == "ActRaiser 2 (USA)")
        #expect(match("slus-00001", title: "Unknown Game") == nil)
        #expect(match("slus-00001", title: "") == nil)
    }

    @Test("Near misses do not match", arguments: ["ActRaiser 3 (USA)", "Act Raiser Deluxe", "Addams Family", "Zelda", "", "   ", "(USA)"])
    func nearMisses(name: String) {
        #expect(match(name) == nil)
    }

    @Test("Arcade names match exactly or not at all")
    func arcade() {
        let sets = ["1942", "1943", "sf2", "sf2ce"]
        #expect(BezelNameMatcher.match(romName: "SF2", candidates: sets, exactOnly: true) == "sf2")
        #expect(BezelNameMatcher.match(romName: "sf2 (World)", candidates: sets, exactOnly: true) == nil)
        #expect(match("ActRaiser", exactOnly: true) == nil)
    }

    @Test("The answer does not depend on the order of the list")
    func orderIndependent() {
        let shuffled = candidates.reversed() as [String]
        for name in ["ActRaiser", "Final Fight (USA)", "The Addams Family"] {
            #expect(BezelNameMatcher.match(romName: name, candidates: shuffled) == match(name))
        }
    }
}

@Suite("BezelProject")
struct BezelProjectTests {

    /// A cut-down answer from GitHub's tree API for `retroarch/overlay`.
    private let treeJSON = Data("""
    {
      "sha": "abc", "url": "https://api.github.com/repos/thebezelproject/bezelproject-SNES/git/trees/abc",
      "tree": [
        {"path": "GameBezels", "mode": "040000", "type": "tree", "sha": "1"},
        {"path": "GameBezels/SNES", "mode": "040000", "type": "tree", "sha": "2"},
        {"path": "GameBezels/SNES/ActRaiser (USA).cfg", "mode": "100644", "type": "blob", "sha": "3", "size": 105},
        {"path": "GameBezels/SNES/ActRaiser (USA).png", "mode": "100644", "type": "blob", "sha": "4", "size": 317286},
        {"path": "GameBezels/SNES/Addams Family, The (USA).png", "mode": "100644", "type": "blob", "sha": "5", "size": 173528},
        {"path": "ArcadeBezels/1942.png", "mode": "100644", "type": "blob", "sha": "6", "size": 200000},
        {"path": "Super-Nintendo-Entertainment-System.cfg", "mode": "100644", "type": "blob", "sha": "7", "size": 122},
        {"path": "Super-Nintendo-Entertainment-System.png", "mode": "100644", "type": "blob", "sha": "8", "size": 498000},
        {"path": "Extras/notes/readme.png", "mode": "100644", "type": "blob", "sha": "9", "size": 10}
      ],
      "truncated": false
    }
    """.utf8)

    @Test("Only the images are listed, each with its kind, name and size")
    func listing() throws {
        let listing = try BezelProjectListing(treeJSON: treeJSON)
        #expect(listing.isTruncated == false)
        #expect(listing.entries.map(\.name) == ["ActRaiser (USA)", "Addams Family, The (USA)", "1942", "Super-Nintendo-Entertainment-System"])
        #expect(listing.entries.map(\.kind) == [.game, .game, .arcade, .system])
        #expect(listing.entries.first?.size == 317_286)
        #expect(listing.entries.first?.path == "GameBezels/SNES/ActRaiser (USA).png")
    }

    @Test("A game finds its entry; arcade sets only by exact name")
    func entryForGame() throws {
        let listing = try BezelProjectListing(treeJSON: treeJSON)
        #expect(listing.entry(romName: "The Addams Family (USA) (Rev 1)", title: nil)?.name == "Addams Family, The (USA)")
        #expect(listing.entry(romName: "x", title: "ActRaiser")?.name == "ActRaiser (USA)")
        #expect(listing.entry(romName: "1942", title: nil)?.kind == .arcade)
        #expect(listing.entry(romName: "1942 (World)", title: nil) == nil)
        #expect(listing.entry(romName: "Super-Nintendo-Entertainment-System", title: nil) == nil)
    }

    @Test("A list survives being cached")
    func roundTrip() throws {
        let listing = try BezelProjectListing(treeJSON: treeJSON)
        let decoded = try JSONDecoder().decode(BezelProjectListing.self, from: JSONEncoder().encode(listing))
        #expect(decoded == listing)
    }

    @Test("An answer that is not a tree throws")
    func notATree() {
        #expect(throws: (any Error).self) {
            try BezelProjectListing(treeJSON: Data(#"{"message": "API rate limit exceeded"}"#.utf8))
        }
    }

    @Test("Repository names and addresses for both styles")
    func repositories() {
        let game = BezelProjectRepository(style: .gameArt, suffix: "SNES")
        let system = BezelProjectRepository(style: .systemArt, suffix: "MegaDrive")
        #expect(game.name == "bezelproject-SNES")
        #expect(system.name == "bezelprojectSA-MegaDrive")
        #expect(game.listingURL?.absoluteString
                == "https://api.github.com/repos/thebezelproject/bezelproject-SNES/git/trees/HEAD:retroarch/overlay?recursive=1")
        #expect(game.imageURL(path: "GameBezels/SNES/Addams Family, The (USA).png")?.absoluteString
                == "https://raw.githubusercontent.com/thebezelproject/bezelproject-SNES/HEAD/retroarch/overlay/GameBezels/SNES/Addams%20Family,%20The%20(USA).png")
        #expect(BezelProjectRepository.projectURL?.host == "github.com")
    }

    @Test("The rate limit answer gives the time requests work again")
    func rateLimit() {
        let limited = ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1794455672"]
        #expect(BezelProjectRateLimit.resetDate(statusCode: 403, headers: limited) == Date(timeIntervalSince1970: 1_794_455_672))
        #expect(BezelProjectRateLimit.resetDate(statusCode: 429, headers: limited) != nil)
        #expect(BezelProjectRateLimit.resetDate(statusCode: 200, headers: limited) == nil)
        #expect(BezelProjectRateLimit.resetDate(statusCode: 403, headers: ["x-ratelimit-remaining": "12", "x-ratelimit-reset": "1"]) == nil)
        #expect(BezelProjectRateLimit.resetDate(statusCode: 403, headers: [:]) == nil)
    }
}
