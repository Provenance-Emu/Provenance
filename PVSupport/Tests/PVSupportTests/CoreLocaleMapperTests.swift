//
//  CoreLocaleMapperTests.swift
//  PVSupport
//
//  Created by Claude on 2026-03-25.
//

import Testing
@testable import PVSupport
import Foundation

@Suite("CoreLocaleMapper")
struct CoreLocaleMapperTests {

    private func locale(_ id: String) -> Locale { Locale(identifier: id) }

    @Test("English locale maps to 0")
    func englishMapsToZero() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("en")) == 0)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("en-US")) == 0)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("en-GB")) == 0)
    }

    @Test("Japanese maps to 1")
    func japaneseMapsToOne() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ja")) == 1)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ja-JP")) == 1)
    }

    @Test("French maps to 2")
    func frenchMapsToTwo() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("fr")) == 2)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("fr-FR")) == 2)
    }

    @Test("Spanish maps to 3")
    func spanishMapsToThree() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("es")) == 3)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("es-MX")) == 3)
    }

    @Test("German maps to 4")
    func germanMapsToFour() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("de")) == 4)
    }

    @Test("Portuguese (Brazil) maps to 7, Portugal maps to 8")
    func portugueseRegionSplit() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("pt")) == 7)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("pt-BR")) == 7)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("pt-PT")) == 8)
    }

    @Test("Russian maps to 9")
    func russianMapsToNine() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ru")) == 9)
    }

    @Test("Korean maps to 10")
    func koreanMapsToTen() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ko")) == 10)
    }

    @Test("Chinese Simplified maps to 12 for CN region")
    func chineseSimplifiedForChinaRegion() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-CN")) == 12)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-SG")) == 12)
    }

    @Test("Chinese Traditional maps to 11 for TW region")
    func chineseTraditionalForTaiwanRegion() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-TW")) == 11)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-HK")) == 11)
    }

    @Test("Arabic maps to 16")
    func arabicMapsToSixteen() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ar")) == 16)
    }

    @Test("Greek maps to 17")
    func greekMapsToSeventeen() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("el")) == 17)
    }

    @Test("Turkish maps to 18")
    func turkishMapsToEighteen() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("tr")) == 18)
    }

    @Test("Finnish maps to 23")
    func finnishMapsToTwentyThree() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("fi")) == 23)
    }

    @Test("Unknown locale falls back to English (0)")
    func unknownLocaleFallsBackToEnglish() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("xx")) == 0)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zz-ZZ")) == 0)
    }

    // MARK: - CTR (3DS) language IDs

    @Test("CTR: English maps to 1")
    func ctrEnglish() {
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("en")) == 1)
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("en-US")) == 1)
    }

    @Test("CTR: Japanese maps to 0")
    func ctrJapanese() {
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("ja")) == 0)
    }

    @Test("CTR: French maps to 2")
    func ctrFrench() {
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("fr")) == 2)
    }

    @Test("CTR: Korean maps to 7")
    func ctrKorean() {
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("ko")) == 7)
    }

    @Test("CTR: Chinese Simplified maps to 6 for CN region")
    func ctrChineseSimplified() {
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("zh-CN")) == 6)
    }

    @Test("CTR: Chinese Traditional maps to 11 for TW region")
    func ctrChineseTraditional() {
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("zh-TW")) == 11)
    }

    @Test("CTR: Unknown locale falls back to English (1)")
    func ctrUnknownFallsBackToEnglish() {
        #expect(CoreLocaleMapper.ctrLanguageID(for: locale("xx")) == 1)
    }

    // MARK: - PSP language IDs

    @Test("PSP: English maps to 1")
    func pspEnglish() {
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("en")) == 1)
    }

    @Test("PSP: Japanese maps to 0")
    func pspJapanese() {
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("ja")) == 0)
    }

    @Test("PSP: French maps to 2, Spanish to 3, German to 4, Italian to 5")
    func pspEuropeanLanguages() {
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("fr")) == 2)
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("es")) == 3)
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("de")) == 4)
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("it")) == 5)
    }

    @Test("PSP: Dutch maps to 6, Portuguese to 7, Russian to 8, Korean to 9")
    func pspOtherLanguages() {
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("nl")) == 6)
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("pt")) == 7)
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("ru")) == 8)
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("ko")) == 9)
    }

    @Test("PSP: Chinese Traditional=10, Simplified=11")
    func pspChinese() {
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("zh-TW")) == 10)
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("zh-CN")) == 11)
    }

    @Test("PSP: Unknown falls back to English (1)")
    func pspUnknownFallback() {
        #expect(CoreLocaleMapper.pspLanguageID(for: locale("xx")) == 1)
    }

    // MARK: - Wii language IDs

    @Test("Wii: English maps to 1, Japanese to 0")
    func wiiBasicLanguages() {
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("en")) == 1)
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("ja")) == 0)
    }

    @Test("Wii: German=2, French=3, Spanish=4, Italian=5, Dutch=6")
    func wiiEuropeanLanguages() {
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("de")) == 2)
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("fr")) == 3)
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("es")) == 4)
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("it")) == 5)
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("nl")) == 6)
    }

    @Test("Wii: Chinese Simplified=7, Traditional=8, Korean=9")
    func wiiAsianLanguages() {
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("zh-CN")) == 7)
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("zh-TW")) == 8)
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("ko")) == 9)
    }

    @Test("Wii: Unknown falls back to English (1)")
    func wiiUnknownFallback() {
        #expect(CoreLocaleMapper.wiiLanguageID(for: locale("xx")) == 1)
    }

    // MARK: - RetroArch → system-specific converters

    @Test("PSP fromRetroArch: maps all supported languages correctly")
    func pspFromRetroArch() {
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 0) == 1)   // EN→1
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 1) == 0)   // JA→0
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 2) == 2)   // FR→2
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 3) == 3)   // ES→3
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 4) == 4)   // DE→4
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 5) == 5)   // IT→5
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 6) == 6)   // NL→6
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 7) == 7)   // PT-BR→7
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 8) == 7)   // PT-PT→7
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 9) == 8)   // RU→8
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 10) == 9)  // KO→9
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 11) == 10) // ZH-TW→10
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 12) == 11) // ZH-CN→11
        #expect(CoreLocaleMapper.pspLanguageID(fromRetroArch: 99) == 1)  // Unknown→EN
    }

    @Test("Wii fromRetroArch: maps all supported languages correctly")
    func wiiFromRetroArch() {
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 0) == 1)   // EN→1
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 1) == 0)   // JA→0
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 2) == 3)   // FR→3
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 3) == 4)   // ES→4
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 4) == 2)   // DE→2
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 5) == 5)   // IT→5
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 6) == 6)   // NL→6
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 10) == 9)  // KO→9
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 11) == 8)  // ZH-TW→8
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 12) == 7)  // ZH-CN→7
        #expect(CoreLocaleMapper.wiiLanguageID(fromRetroArch: 99) == 1)  // Unknown→EN
    }

    @Test("CTR fromRetroArch: maps all supported languages correctly")
    func ctrFromRetroArch() {
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 0) == 1)   // EN→1
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 1) == 0)   // JA→0
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 2) == 2)   // FR→2
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 3) == 5)   // ES→5
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 4) == 3)   // DE→3
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 5) == 4)   // IT→4
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 6) == 8)   // NL→8
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 7) == 9)   // PT-BR→9
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 8) == 9)   // PT-PT→9
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 9) == 10)  // RU→10
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 10) == 7)  // KO→7
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 11) == 11) // ZH-TW→11
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 12) == 6)  // ZH-CN→6
        #expect(CoreLocaleMapper.ctrLanguageID(fromRetroArch: 99) == 1)  // Unknown→EN
    }

    // MARK: - NDS firmware language strings

    @Test("NDS: English maps to 'English'")
    func ndsEnglish() {
        #expect(CoreLocaleMapper.ndsLanguageString(for: locale("en")) == "English")
        #expect(CoreLocaleMapper.ndsLanguageString(for: locale("en-US")) == "English")
    }

    @Test("NDS: Japanese maps to 'Japanese'")
    func ndsJapanese() {
        #expect(CoreLocaleMapper.ndsLanguageString(for: locale("ja")) == "Japanese")
    }

    @Test("NDS: French maps to 'French'")
    func ndsFrench() {
        #expect(CoreLocaleMapper.ndsLanguageString(for: locale("fr")) == "French")
    }

    @Test("NDS: Spanish maps to 'Spanish'")
    func ndsSpanish() {
        #expect(CoreLocaleMapper.ndsLanguageString(for: locale("es")) == "Spanish")
    }

    @Test("NDS: Unknown locale falls back to 'English'")
    func ndsUnknownFallsBackToEnglish() {
        #expect(CoreLocaleMapper.ndsLanguageString(for: locale("xx")) == "English")
        #expect(CoreLocaleMapper.ndsLanguageString(for: locale("ko")) == "English")
    }
}
