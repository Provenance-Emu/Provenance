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

    @Test("German maps to 3")
    func germanMapsToThree() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("de")) == 3)
    }

    @Test("Spanish maps to 4")
    func spanishMapsToFour() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("es")) == 4)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("es-MX")) == 4)
    }

    @Test("Portuguese maps to 6")
    func portugueseMapsToSix() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("pt")) == 6)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("pt-BR")) == 6)
    }

    @Test("Russian maps to 16")
    func russianMapsToSixteen() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ru")) == 16)
    }

    @Test("Korean maps to 12")
    func koreanMapsToTwelve() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ko")) == 12)
    }

    @Test("Chinese Simplified maps to 11 for CN region")
    func chineseSimplifiedForChinaRegion() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-CN")) == 11)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-SG")) == 11)
    }

    @Test("Chinese Traditional maps to 13 for TW region")
    func chineseTraditionalForTaiwanRegion() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-TW")) == 13)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zh-HK")) == 13)
    }

    @Test("Arabic maps to 14")
    func arabicMapsToFourteen() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("ar")) == 14)
    }

    @Test("Unknown locale falls back to English (0)")
    func unknownLocaleFallsBackToEnglish() {
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("xx")) == 0)
        #expect(CoreLocaleMapper.retroArchLanguageID(for: locale("zz-ZZ")) == 0)
    }
}
