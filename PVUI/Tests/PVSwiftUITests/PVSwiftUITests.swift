import Testing
@testable import PVSwiftUI

// MARK: - SaveImportMatchingService Tests

@Suite("SaveImportMatchingService")
struct SaveImportMatchingServiceTests {

    // MARK: normalize

    @Test("Region and revision annotations are stripped")
    func normalizeStripsAnnotations() {
        #expect(SaveImportMatchingService.normalize("Super Mario Bros. (USA)") == "super mario bros")
        #expect(SaveImportMatchingService.normalize("Kirby's Adventure [!]") == "kirby s adventure")
        #expect(SaveImportMatchingService.normalize("Zelda II (Rev A)") == "zelda ii")
    }

    @Test("Output is lowercased")
    func normalizeLowercases() {
        #expect(SaveImportMatchingService.normalize("SONIC THE HEDGEHOG") == "sonic the hedgehog")
    }

    @Test("Whitespace is collapsed and tokens joined by single spaces")
    func normalizeCollapsesWhitespace() {
        let result = SaveImportMatchingService.normalize("My  Game  (USA)  [h1]")
        #expect(!result.contains("  "))
    }

    @Test("Empty string normalizes to empty string")
    func normalizeEmptyString() {
        #expect(SaveImportMatchingService.normalize("") == "")
    }

    // MARK: similarity

    @Test("Identical strings score 100")
    func similarityIdentical() {
        #expect(SaveImportMatchingService.similarity("super mario world", "super mario world") == 100)
    }

    @Test("Completely different strings score 0")
    func similarityDisjoint() {
        #expect(SaveImportMatchingService.similarity("sonic hedgehog", "zelda link") == 0)
    }

    @Test("Partial overlap scores between 0 and 100")
    func similarityPartial() {
        let score = SaveImportMatchingService.similarity("super mario world", "super mario bros")
        #expect(score > 0 && score < 100)
    }

    @Test("Empty inputs score 0")
    func similarityEmptyInputs() {
        #expect(SaveImportMatchingService.similarity("", "super mario") == 0)
        #expect(SaveImportMatchingService.similarity("super mario", "") == 0)
        #expect(SaveImportMatchingService.similarity("", "") == 0)
    }

    @Test("Token order does not affect score")
    func similarityTokenOrderIndependent() {
        let s1 = SaveImportMatchingService.similarity("mario super world", "super mario world")
        let s2 = SaveImportMatchingService.similarity("super mario world", "mario super world")
        #expect(s1 == s2)
    }
}

// MARK: - ROMTitleNormalizer Tests

@Suite("ROMTitleNormalizer")
struct ROMTitleNormalizerTests {

    @Test("Region tags are removed")
    func regionTagsRemoved() {
        #expect(ROMTitleNormalizer.normalize("Super Mario Bros. (USA)") == "Super Mario Bros.")
        #expect(ROMTitleNormalizer.normalize("Sonic the Hedgehog (Europe)") == "Sonic the Hedgehog")
        #expect(ROMTitleNormalizer.normalize("Kirby's Adventure (USA) (Rev A)") == "Kirby's Adventure")
    }

    @Test("Multi-language tags are removed")
    func multiLanguageTagsRemoved() {
        #expect(ROMTitleNormalizer.normalize("Street Fighter II (En,Fr,De)") == "Street Fighter II")
        #expect(ROMTitleNormalizer.normalize("Mega Man (En,Ja)") == "Mega Man")
    }

    @Test("Version and revision tags are removed")
    func versionTagsRemoved() {
        #expect(ROMTitleNormalizer.normalize("Tetris (USA) (Rev 1)") == "Tetris")
        #expect(ROMTitleNormalizer.normalize("Zelda II (USA) (v1.1)") == "Zelda II")
        #expect(ROMTitleNormalizer.normalize("Game (Rev A)") == "Game")
    }

    @Test("Disc and volume markers are removed")
    func discMarkersRemoved() {
        #expect(ROMTitleNormalizer.normalize("Final Fantasy VII (Disc 1) (USA)") == "Final Fantasy VII")
        #expect(ROMTitleNormalizer.normalize("Some Game (Disk 2)") == "Some Game")
    }

    @Test("Release status tags are removed")
    func releaseStatusTagsRemoved() {
        #expect(ROMTitleNormalizer.normalize("Mystery Game (Proto)") == "Mystery Game")
        #expect(ROMTitleNormalizer.normalize("Demo Title (Demo)") == "Demo Title")
        #expect(ROMTitleNormalizer.normalize("Early Build (Beta)") == "Early Build")
    }

    @Test("GoodTools bracket tags are removed")
    func bracketTagsRemoved() {
        #expect(ROMTitleNormalizer.normalize("Game [!]") == "Game")
        #expect(ROMTitleNormalizer.normalize("Game [h1]") == "Game")
        #expect(ROMTitleNormalizer.normalize("Game [T-En]") == "Game")
    }

    @Test("Trailing article is moved to front")
    func trailingArticleFixed() {
        #expect(ROMTitleNormalizer.normalize("Legend of Zelda, The") == "The Legend of Zelda")
        #expect(ROMTitleNormalizer.normalize("Incredible Crash Dummies, The") == "The Incredible Crash Dummies")
        // Lowercase article from caseInsensitive match must be capitalised
        #expect(ROMTitleNormalizer.normalize("Legend of Zelda, the") == "The Legend of Zelda")
        #expect(ROMTitleNormalizer.normalize("Adventures of Lolo, an") == "An Adventures of Lolo")
    }

    @Test("Already-normalized titles are unchanged")
    func alreadyNormalizedUnchanged() {
        let clean = "Super Mario World"
        #expect(ROMTitleNormalizer.normalize(clean) == clean)
        #expect(ROMTitleNormalizer.needsNormalization(clean) == false)
    }

    @Test("needsNormalization returns true for dirty titles")
    func needsNormalizationDetectsDirtyTitle() {
        #expect(ROMTitleNormalizer.needsNormalization("Sonic (USA)") == true)
        #expect(ROMTitleNormalizer.needsNormalization("Sonic") == false)
    }

    @Test("Whitespace is collapsed after stripping")
    func whitespaceCollapsed() {
        let result = ROMTitleNormalizer.normalize("My Game  (USA)  (Rev A)")
        #expect(result == "My Game")
    }
}
