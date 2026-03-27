//
//  ROMMetadataMergePreservingTests.swift
//  PVLookup
//
//  Tests for ROMMetadata.merged(with:preserving:) — the user-customization-aware overload.
//

import Testing
import PVLookupTypes
import PVSystems
import PVPrimitives

struct ROMMetadataMergePreservingTests {

    // MARK: - Nil secondary

    @Test("Nil secondary returns self unchanged regardless of preserved fields")
    func preservingMergeWithNilSecondaryReturnsSelf() {
        let primary = ROMMetadata(
            gameTitle: "My Game",
            gameDescription: "A great game",
            developer: "Dev Co",
            systemID: .NES
        )
        let preserved: GameCustomizedFields = [.title, .developer]
        let result = primary.merged(with: nil, preserving: preserved)
        #expect(result.gameTitle == "My Game")
        #expect(result.gameDescription == "A great game")
    }

    // MARK: - Preserved fields are not overwritten

    @Test("Preserved title is not overwritten even when primary title is empty")
    func preservedTitleNotOverwrittenWhenEmpty() {
        let primary = ROMMetadata(gameTitle: "", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Secondary Title", systemID: .NES)

        // With title preserved: should keep primary's "" (user explicitly cleared it)
        let preserved: GameCustomizedFields = [.title]
        let result = primary.merged(with: secondary, preserving: preserved)
        #expect(result.gameTitle == "")
    }

    @Test("Non-preserved empty title is filled from secondary")
    func nonPreservedEmptyTitleFilledFromSecondary() {
        let primary = ROMMetadata(gameTitle: "", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Secondary Title", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [])
        #expect(result.gameTitle == "Secondary Title")
    }

    @Test("Preserved developer is not overwritten by secondary")
    func preservedDeveloperNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", developer: "User's Dev", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", developer: "DB Dev", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.developer])
        #expect(result.developer == "User's Dev")
    }

    @Test("Preserved publisher is not overwritten by secondary")
    func preservedPublisherNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", publisher: "User's Pub", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", publisher: "DB Pub", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.publisher])
        #expect(result.publisher == "User's Pub")
    }

    @Test("Preserved artwork URL is not overwritten by secondary")
    func preservedArtworkNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", boxImageURL: "custom://art.jpg", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", boxImageURL: "db://art.jpg", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.artwork])
        #expect(result.boxImageURL == "custom://art.jpg")
    }

    @Test("Preserved box back art URL is not overwritten by secondary")
    func preservedBoxBackArtNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", boxBackURL: "custom://back.jpg", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", boxBackURL: "db://back.jpg", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.boxBackArt])
        #expect(result.boxBackURL == "custom://back.jpg")
    }

    @Test("Preserved description is not overwritten by secondary")
    func preservedDescriptionNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", gameDescription: "User desc", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", gameDescription: "DB desc", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.description])
        #expect(result.gameDescription == "User desc")
    }

    @Test("Preserved genres are not overwritten by secondary")
    func preservedGenresNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", genres: "Action, RPG", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", genres: "Platformer", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.genres])
        #expect(result.genres == "Action, RPG")
    }

    @Test("Preserved release date is not overwritten by secondary")
    func preservedReleaseDateNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", releaseDate: "1990", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", releaseDate: "1992", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.releaseDate])
        #expect(result.releaseDate == "1990")
    }

    @Test("Preserved reference URL is not overwritten by secondary")
    func preservedReferenceURLNotOverwritten() {
        let primary = ROMMetadata(gameTitle: "Game", referenceURL: "https://custom.example.com", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", referenceURL: "https://db.example.com", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.referenceURL])
        #expect(result.referenceURL == "https://custom.example.com")
    }

    // MARK: - Non-preserved nil fields ARE filled from secondary

    @Test("Non-preserved nil developer is filled from secondary")
    func nonPreservedNilDeveloperFilledFromSecondary() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", developer: "DB Dev", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [])
        #expect(result.developer == "DB Dev")
    }

    @Test("Non-preserved nil artwork is filled from secondary")
    func nonPreservedNilArtworkFilledFromSecondary() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", boxImageURL: "db://art.jpg", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [])
        #expect(result.boxImageURL == "db://art.jpg")
    }

    // MARK: - Non-preserved non-nil fields keep their value

    @Test("Non-preserved non-nil developer is kept from primary")
    func nonPreservedNonNilDeveloperKeptFromPrimary() {
        let primary = ROMMetadata(gameTitle: "Game", developer: "Primary Dev", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", developer: "DB Dev", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [])
        #expect(result.developer == "Primary Dev")
    }

    // MARK: - Mixed preserved and non-preserved fields

    @Test("Multiple preserved fields all protected while non-preserved nil fields filled")
    func multiplePreservedFieldsProtectedAndNilFilled() {
        let primary = ROMMetadata(
            gameTitle: "My Title",
            developer: "My Dev",
            systemID: .SNES
        )
        let secondary = ROMMetadata(
            gameTitle: "DB Title",
            gameDescription: "DB Desc",
            developer: "DB Dev",
            publisher: "DB Pub",
            systemID: .SNES
        )

        let preserved: GameCustomizedFields = [.title, .developer]
        let result = primary.merged(with: secondary, preserving: preserved)

        // Preserved fields should be protected
        #expect(result.gameTitle == "My Title")
        #expect(result.developer == "My Dev")

        // Non-preserved nil fields filled from secondary
        #expect(result.gameDescription == "DB Desc")
        #expect(result.publisher == "DB Pub")
    }

    // MARK: - Unchanged fields (not in either metadata set)

    @Test("Fields not present in either metadata use correct fallback behaviour")
    func fieldsAbsentFromBothReturnNil() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES)
        let secondary = ROMMetadata(gameTitle: "Game", systemID: .NES)

        let result = primary.merged(with: secondary, preserving: [.title, .developer])
        // Neither has description or genres → result should be nil
        #expect(result.gameDescription == nil)
        #expect(result.genres == nil)
    }

    // MARK: - System ID and source behave same as base merge

    @Test("System ID resolution follows same rules as base merge")
    func systemIDResolutionMatchesBaseMerge() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .Unknown)
        let secondary = ROMMetadata(gameTitle: "Game", systemID: .SNES)

        let result = primary.merged(with: secondary, preserving: [])
        #expect(result.systemID == .SNES)
    }

    @Test("Sources are concatenated same as base merge")
    func sourcesConcatenated() {
        let primary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "OpenVGDB")
        let secondary = ROMMetadata(gameTitle: "Game", systemID: .NES, source: "LibretroDB")

        let result = primary.merged(with: secondary, preserving: [])
        #expect(result.source == "OpenVGDB,LibretroDB")
    }

    // MARK: - Empty GameCustomizedFields behaves like base merge

    @Test("Empty preservedFields set is identical to base merged(with:)")
    func emptyPreservedFieldsMatchesBaseMerge() {
        let primary = ROMMetadata(
            gameTitle: "Primary",
            boxImageURL: "primary-art",
            gameDescription: nil,
            developer: "Primary Dev",
            systemID: .NES,
            source: "P"
        )
        let secondary = ROMMetadata(
            gameTitle: "Secondary",
            gameDescription: "Secondary Desc",
            developer: "Secondary Dev",
            publisher: "Secondary Pub",
            systemID: .NES,
            source: "S"
        )

        let baseResult = primary.merged(with: secondary)
        let preservingResult = primary.merged(with: secondary, preserving: [])

        #expect(baseResult.gameTitle == preservingResult.gameTitle)
        #expect(baseResult.developer == preservingResult.developer)
        #expect(baseResult.gameDescription == preservingResult.gameDescription)
        #expect(baseResult.publisher == preservingResult.publisher)
        #expect(baseResult.source == preservingResult.source)
    }
}
