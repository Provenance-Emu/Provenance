import Testing
@testable import PVSwiftUI

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
