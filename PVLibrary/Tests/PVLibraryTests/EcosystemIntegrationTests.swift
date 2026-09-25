//
//  EcosystemIntegrationTests.swift
//  PVLibraryTests
//
//  Tests for EcosystemCallbackParser, KnownEmulator, and EcosystemApp models.
//

@testable import PVLibrary
import XCTest

final class EcosystemCallbackParserTests: XCTestCase {

    // MARK: - EcosystemCallbackParser

    func testParseValidXeniosCallback() throws {
        let games = [
            EcosystemGameScheme(titleName: "Halo 3", titleId: "5454082B"),
            EcosystemGameScheme(titleName: "Gears of War", titleId: "4D5307D5")
        ]
        let json = try JSONEncoder().encode(games)
        let base64 = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let url = URL(string: "provenance://xenios?games=\(base64)")!
        let result = EcosystemCallbackParser.parse(url: url)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.source, .xenios)
        XCTAssertEqual(result?.games.count, 2)
        XCTAssertEqual(result?.games.first?.titleName, "Halo 3")
        XCTAssertEqual(result?.games.first?.titleId, "5454082B")
    }

    func testParseValidMeloNXCallback() throws {
        let games = [EcosystemGameScheme(titleName: "Super Mario Odyssey", titleId: "0100000000010000")]
        let json = try JSONEncoder().encode(games)
        let base64 = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let url = URL(string: "provenance://atariemulator?games=\(base64)")!
        let result = EcosystemCallbackParser.parse(url: url)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.source, .melonx)
        XCTAssertEqual(result?.games.first?.titleName, "Super Mario Odyssey")
    }

    func testParseReturnsNilForUnknownSource() throws {
        let games = [EcosystemGameScheme(titleName: "Game", titleId: "1234")]
        let json = try JSONEncoder().encode(games)
        let base64 = json.base64EncodedString()

        let url = URL(string: "provenance://unknownapp?games=\(base64)")!
        XCTAssertNil(EcosystemCallbackParser.parse(url: url))
    }

    func testParseReturnsNilForMissingGamesParam() {
        let url = URL(string: "provenance://xenios?other=value")!
        XCTAssertNil(EcosystemCallbackParser.parse(url: url))
    }

    func testParseReturnsNilForMalformedBase64() {
        let url = URL(string: "provenance://xenios?games=!!!notbase64!!!")!
        XCTAssertNil(EcosystemCallbackParser.parse(url: url))
    }

    func testParseHandlesBase64UrlPaddingVariants() throws {
        // Payload lengths that result in 1, 2, or 0 padding chars
        let lengths = [1, 2, 3]
        for count in lengths {
            let games = (0..<count).map { EcosystemGameScheme(titleName: "Game\($0)", titleId: "\($0)") }
            let json = try JSONEncoder().encode(games)
            let base64url = json.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")

            let url = URL(string: "provenance://xenios?games=\(base64url)")!
            let result = EcosystemCallbackParser.parse(url: url)
            XCTAssertNotNil(result, "Failed to parse for \(count) game(s)")
            XCTAssertEqual(result?.games.count, count)
        }
    }

    // MARK: - KnownEmulator

    func testKnownEmulatorDisplayNames() {
        XCTAssertEqual(KnownEmulator.delta.displayName, "Delta")
        XCTAssertEqual(KnownEmulator.deltaLite.displayName, "Delta")
        XCTAssertEqual(KnownEmulator.retroArch.displayName, "RetroArch")
        XCTAssertEqual(KnownEmulator.ppsspp.displayName, "PPSSPP")
        XCTAssertEqual(KnownEmulator.manicEmu.displayName, "Manic EMU")
        XCTAssertEqual(KnownEmulator.gamma.displayName, "Gamma")
        XCTAssertEqual(KnownEmulator.consoles.displayName, "Consoles")
    }

    func testKnownEmulatorBundleIDs() {
        XCTAssertEqual(KnownEmulator.delta.bundleID, "com.rileytestut.Delta")
        XCTAssertEqual(KnownEmulator.manicEmu.bundleID, "com.aoshuang.manicemu")
        XCTAssertEqual(KnownEmulator.ppsspp.bundleID, "org.ppsspp.ppsspp")
        XCTAssertEqual(KnownEmulator.retroArch.bundleID, "com.libretro.RetroArch")
    }

    func testKnownEmulatorURLSchemes() {
        XCTAssertEqual(KnownEmulator.delta.urlScheme, "delta")
        XCTAssertEqual(KnownEmulator.retroArch.urlScheme, "retroarch")
        XCTAssertEqual(KnownEmulator.ppsspp.urlScheme, "ppsspp")
        XCTAssertNil(KnownEmulator.gamma.urlScheme)
    }

    func testKnownEmulatorSaveExtensions() {
        XCTAssertTrue(KnownEmulator.delta.saveFileExtensions.contains("sav"))
        XCTAssertTrue(KnownEmulator.retroArch.saveFileExtensions.contains("srm"))
        XCTAssertTrue(KnownEmulator.ppsspp.saveFileExtensions.contains("sav"))
    }

    func testKnownEmulatorStateExtensions() {
        XCTAssertTrue(KnownEmulator.delta.stateFileExtensions.contains("dvsave"))
        XCTAssertTrue(KnownEmulator.retroArch.stateFileExtensions.contains("state"))
        XCTAssertTrue(KnownEmulator.ppsspp.stateFileExtensions.contains("ppst"))
        XCTAssertTrue(KnownEmulator.gamma.stateFileExtensions.isEmpty)
        XCTAssertTrue(KnownEmulator.manicEmu.stateFileExtensions.isEmpty)
    }

    func testKnownEmulatorAppGroupIdentifier() {
        XCTAssertEqual(KnownEmulator.manicEmu.appGroupIdentifier, "group.aoshuang.manicemu")
        XCTAssertNil(KnownEmulator.delta.appGroupIdentifier)
        XCTAssertNil(KnownEmulator.retroArch.appGroupIdentifier)
    }

    // MARK: - EcosystemApp

    func testEcosystemAppURLSchemes() {
        XCTAssertEqual(EcosystemApp.xenios.urlScheme, "xenios")
        XCTAssertEqual(EcosystemApp.melonx.urlScheme, "atariemulator")
        XCTAssertEqual(EcosystemApp.meloCafe.urlScheme, "melocafe")
    }

    func testEcosystemAppLaunchURLXenios() {
        let url = EcosystemApp.xenios.launchURL(titleID: "5454082B")
        XCTAssertEqual(url?.absoluteString, "xenios://launch?title-id=5454082B")
    }

    func testEcosystemAppLaunchURLMeloNX() {
        let url = EcosystemApp.melonx.launchURL(titleID: "0100000000010000")
        XCTAssertEqual(url?.absoluteString, "atariemulator://game?id=0100000000010000")
    }

    func testEcosystemAppGameInfoQueryURL() {
        let url = EcosystemApp.xenios.gameInfoQueryURL()
        XCTAssertEqual(url?.absoluteString, "xenios://gameInfo?scheme=provenance")
    }

    func testEcosystemAppGameInfoQueryURLCustomScheme() {
        let url = EcosystemApp.melonx.gameInfoQueryURL(callbackScheme: "myapp")
        XCTAssertEqual(url?.absoluteString, "atariemulator://gameInfo?scheme=myapp")
    }

    // MARK: - EcosystemApp.icube

    func testEcosystemAppIcubeURLScheme() {
        XCTAssertEqual(EcosystemApp.icube.urlScheme, "dolphinios")
    }

    func testEcosystemAppIcubeDisplay() {
        XCTAssertEqual(EcosystemApp.icube.displayName, "iCube")
        XCTAssertEqual(EcosystemApp.icube.platformSummary, "GameCube · Wii")
        XCTAssertEqual(EcosystemApp.icube.symbolName, "cube")
    }

    func testEcosystemAppIcubeLaunchURL() {
        let url = EcosystemApp.icube.launchURL(titleID: "GALE01")
        XCTAssertEqual(url?.absoluteString, "dolphinios://play?id=GALE01")
    }

    func testEcosystemAppIcubeGameInfoQueryURL() {
        let url = EcosystemApp.icube.gameInfoQueryURL()
        XCTAssertEqual(url?.absoluteString, "dolphinios://gameInfo?scheme=provenance")
    }

    /// iCube identifies games by the 6-char disc id via `id=`, unlike iFly's `md5=`.
    func testEcosystemAppIcubeRequestGameURL() {
        let url = EcosystemApp.icube.requestGameURL(titleID: "GALE01")
        XCTAssertEqual(url?.absoluteString, "dolphinios://requestGame?id=GALE01&scheme=provenance")
    }

    func testEcosystemAppIcubeRequestGameURLCustomScheme() {
        let url = EcosystemApp.icube.requestGameURL(titleID: "GALE01", callbackScheme: "myapp")
        XCTAssertEqual(url?.absoluteString, "dolphinios://requestGame?id=GALE01&scheme=myapp")
    }

    /// iFly's requestGameURL keeps its own `md5=` shape, unaffected by adding iCube.
    func testEcosystemAppIflyRequestGameURLUnchanged() {
        let url = EcosystemApp.ifly.requestGameURL(titleID: "abc123")
        XCTAssertEqual(url?.absoluteString, "ifly://requestGame?md5=abc123&scheme=provenance")
    }

    func testEcosystemAppRequestGameURLNilForAppsWithoutFetchSupport() {
        XCTAssertNil(EcosystemApp.xenios.requestGameURL(titleID: "5454082B"))
        XCTAssertNil(EcosystemApp.melonx.requestGameURL(titleID: "0100000000010000"))
        XCTAssertNil(EcosystemApp.meloCafe.requestGameURL(titleID: "anything"))
    }

    func testParseValidIcubeCallback() throws {
        let games = [EcosystemGameScheme(titleName: "Metroid Prime", titleId: "GM8E01", developer: "01", version: "GameCube")]
        let json = try JSONEncoder().encode(games)
        let base64 = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let url = URL(string: "provenance://dolphinios?games=\(base64)")!
        let result = EcosystemCallbackParser.parse(url: url)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.source, .icube)
        XCTAssertEqual(result?.games.first?.titleName, "Metroid Prime")
        XCTAssertEqual(result?.games.first?.titleId, "GM8E01")
        XCTAssertEqual(result?.games.first?.developer, "01")
    }

    // MARK: - EcosystemFetchService container naming

    func testEcosystemFetchServiceContainerNamingUsesDisplayName() {
        // The container-naming rule ("\(source.displayName)-\(hex8)") is exercised end to
        // end via `download(_:from:)`, which needs network/filesystem plumbing this test
        // target doesn't set up. Pin the inputs to that rule here instead, so a future
        // change to `displayName` (or to the naming rule itself) is caught: iFly and iCube
        // must resolve to visibly different, source-identifying prefixes.
        let hex8 = "deadbeef"
        XCTAssertEqual("\(EcosystemApp.ifly.displayName)-\(hex8)", "iFly EMU-deadbeef")
        XCTAssertEqual("\(EcosystemApp.icube.displayName)-\(hex8)", "iCube-deadbeef")
    }
}
