//
//  ArtworkTypeTests.swift
//  PVLookup
//
//  Tests for ArtworkType OptionSet including raw values, allCases,
//  default sets, OptionSet operations, displayNames, and Codable conformance.
//

import Testing
import Foundation
import PVLookupTypes

struct ArtworkTypeTests {

    // MARK: - Raw Values

    @Test("Raw values are unique powers of 2")
    func rawValuesAreUniquePowersOf2() {
        let types: [ArtworkType] = [
            .boxFront, .boxBack, .manual, .screenshot,
            .titleScreen, .fanArt, .banner, .clearLogo, .other
        ]
        let rawValues = types.map(\.rawValue)
        let uniqueRawValues = Set(rawValues)
        #expect(rawValues.count == uniqueRawValues.count, "All raw values should be unique")

        for raw in rawValues {
            #expect(raw > 0 && (raw & (raw - 1)) == 0, "Raw value \(raw) should be a power of 2")
        }
    }

    // MARK: - allCases

    @Test("allCases contains exactly 9 types")
    func allCasesCount() {
        #expect(ArtworkType.allCases.count == 9)
    }

    @Test("allCases contains all expected types")
    func allCasesContainsExpected() {
        let allCases = ArtworkType.allCases
        #expect(allCases.contains(.boxFront))
        #expect(allCases.contains(.boxBack))
        #expect(allCases.contains(.manual))
        #expect(allCases.contains(.screenshot))
        #expect(allCases.contains(.titleScreen))
        #expect(allCases.contains(.fanArt))
        #expect(allCases.contains(.banner))
        #expect(allCases.contains(.clearLogo))
        #expect(allCases.contains(.other))
    }

    // MARK: - defaults

    @Test("defaults contains boxFront, titleScreen, boxBack")
    func defaultsContainsExpectedTypes() {
        let defaults = ArtworkType.defaults
        #expect(defaults.contains(.boxFront))
        #expect(defaults.contains(.titleScreen))
        #expect(defaults.contains(.boxBack))
    }

    @Test("defaults does not contain non-default types")
    func defaultsExcludesNonDefault() {
        let defaults = ArtworkType.defaults
        #expect(!defaults.contains(.manual))
        #expect(!defaults.contains(.screenshot))
        #expect(!defaults.contains(.fanArt))
        #expect(!defaults.contains(.banner))
        #expect(!defaults.contains(.clearLogo))
        #expect(!defaults.contains(.other))
    }

    // MARK: - retroDBSupported

    @Test("retroDBSupported contains boxFront, titleScreen, screenshot")
    func retroDBSupportedContainsExpected() {
        let supported = ArtworkType.retroDBSupported
        #expect(supported.contains(.boxFront))
        #expect(supported.contains(.titleScreen))
        #expect(supported.contains(.screenshot))
    }

    @Test("retroDBSupported excludes non-supported types")
    func retroDBSupportedExcludesNonSupported() {
        let supported = ArtworkType.retroDBSupported
        #expect(!supported.contains(.boxBack))
        #expect(!supported.contains(.manual))
        #expect(!supported.contains(.fanArt))
        #expect(!supported.contains(.banner))
        #expect(!supported.contains(.clearLogo))
        #expect(!supported.contains(.other))
    }

    // MARK: - OptionSet Operations

    @Test("OptionSet union contains both members")
    func optionSetUnion() {
        let combined: ArtworkType = [.boxFront, .screenshot]
        #expect(combined.contains(.boxFront))
        #expect(combined.contains(.screenshot))
        #expect(!combined.contains(.boxBack))
        #expect(!combined.contains(.titleScreen))
    }

    @Test("OptionSet intersection returns only common members")
    func optionSetIntersection() {
        let a: ArtworkType = [.boxFront, .screenshot, .titleScreen]
        let b: ArtworkType = [.boxFront, .boxBack]
        let intersection = a.intersection(b)
        #expect(intersection.contains(.boxFront))
        #expect(!intersection.contains(.screenshot))
        #expect(!intersection.contains(.titleScreen))
        #expect(!intersection.contains(.boxBack))
    }

    @Test("Empty OptionSet contains no types")
    func emptyOptionSet() {
        let empty = ArtworkType([])
        #expect(!empty.contains(.boxFront))
        #expect(!empty.contains(.screenshot))
        #expect(!empty.contains(.boxBack))
    }

    @Test("OptionSet subtracting removes specific member")
    func optionSetSubtracting() {
        let all: ArtworkType = [.boxFront, .screenshot, .titleScreen]
        let result = all.subtracting(.screenshot)
        #expect(result.contains(.boxFront))
        #expect(!result.contains(.screenshot))
        #expect(result.contains(.titleScreen))
    }

    @Test("OptionSet formUnion adds new member")
    func optionSetFormUnion() {
        var type: ArtworkType = [.boxFront]
        type.formUnion(.screenshot)
        #expect(type.contains(.boxFront))
        #expect(type.contains(.screenshot))
    }

    @Test("OptionSet isSubset correctly identifies subsets")
    func optionSetIsSubset() {
        let subset: ArtworkType = [.boxFront, .screenshot]
        let superset: ArtworkType = [.boxFront, .screenshot, .titleScreen]
        #expect(subset.isSubset(of: superset))
        #expect(!superset.isSubset(of: subset))
    }

    @Test("Single type is subset of allCases set")
    func singleTypeIsSubsetOfAll() {
        // Build a set from allCases
        var allSet = ArtworkType([])
        for t in ArtworkType.allCases {
            allSet.formUnion(t)
        }
        #expect(ArtworkType.boxFront.isSubset(of: allSet))
        #expect(ArtworkType.screenshot.isSubset(of: allSet))
        #expect(ArtworkType.other.isSubset(of: allSet))
    }

    // MARK: - displayName

    @Test("displayName returns correct string for each type")
    func displayNamesAreCorrect() {
        #expect(ArtworkType.boxFront.displayName == "Box Front")
        #expect(ArtworkType.boxBack.displayName == "Box Back")
        #expect(ArtworkType.screenshot.displayName == "Screenshot")
        #expect(ArtworkType.titleScreen.displayName == "Title Screen")
        #expect(ArtworkType.clearLogo.displayName == "Clear Logo")
        #expect(ArtworkType.banner.displayName == "Banner")
        #expect(ArtworkType.fanArt.displayName == "Fan Art")
        #expect(ArtworkType.manual.displayName == "Manual")
        #expect(ArtworkType.other.displayName == "Other")
    }

    // MARK: - Codable

    @Test("Single type survives Codable round-trip")
    func codableSingleType() throws {
        let type = ArtworkType.boxFront
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(type)
        let decoded = try decoder.decode(ArtworkType.self, from: data)
        #expect(decoded == type)
    }

    @Test("Composite type survives Codable round-trip")
    func codableCompositeType() throws {
        let type: ArtworkType = [.boxFront, .screenshot, .titleScreen]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(type)
        let decoded = try decoder.decode(ArtworkType.self, from: data)
        #expect(decoded == type)
        #expect(decoded.contains(.boxFront))
        #expect(decoded.contains(.screenshot))
        #expect(decoded.contains(.titleScreen))
        #expect(!decoded.contains(.boxBack))
    }

    @Test("Empty type survives Codable round-trip")
    func codableEmptyType() throws {
        let type = ArtworkType([])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(type)
        let decoded = try decoder.decode(ArtworkType.self, from: data)
        #expect(decoded == type)
        #expect(!decoded.contains(.boxFront))
    }

    // MARK: - Hashable

    @Test("Same types produce equal hash values")
    func hashableEqualTypes() {
        let a = ArtworkType.boxFront
        let b = ArtworkType.boxFront
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different types produce different hash values")
    func hashableDifferentTypes() {
        let a = ArtworkType.boxFront
        let b = ArtworkType.boxBack
        #expect(a.hashValue != b.hashValue)
    }

    @Test("Types are usable as Dictionary keys")
    func usableAsDictionaryKeys() {
        var dict: [ArtworkType: String] = [:]
        dict[.boxFront] = "front"
        dict[.boxBack] = "back"
        dict[.screenshot] = "screen"
        #expect(dict[.boxFront] == "front")
        #expect(dict[.boxBack] == "back")
        #expect(dict[.screenshot] == "screen")
        #expect(dict[.titleScreen] == nil)
    }

    @Test("Types are usable in Set")
    func usableInSet() {
        var set: Set<ArtworkType> = []
        set.insert(.boxFront)
        set.insert(.boxFront) // duplicate
        set.insert(.screenshot)
        #expect(set.count == 2)
        #expect(set.contains(.boxFront))
        #expect(set.contains(.screenshot))
        #expect(!set.contains(.boxBack))
    }

    // MARK: - Equality

    @Test("Same type values are equal")
    func equalityEqual() {
        #expect(ArtworkType.boxFront == ArtworkType.boxFront)
        #expect(ArtworkType.screenshot == ArtworkType.screenshot)
    }

    @Test("Different type values are not equal")
    func equalityNotEqual() {
        #expect(ArtworkType.boxFront != ArtworkType.boxBack)
        #expect(ArtworkType.screenshot != ArtworkType.titleScreen)
    }
}
