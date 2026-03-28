import XCTest
@testable import ProvenanceCompanion

final class ProvenanceCompanionTests: XCTestCase {

    // MARK: - URL Scheme

    func testProvenanceURLSchemeIsValid() {
        let url = URL(string: "provenance://")
        XCTAssertNotNil(url, "provenance:// must produce a valid URL")
    }

    func testProvenanceURLSchemeComponents() {
        let url = URL(string: "provenance://")
        XCTAssertEqual(url?.scheme, "provenance")
        XCTAssertEqual(url?.host, "")
    }

    func testProvenanceURLWithPath() {
        let url = URL(string: "provenance://open")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "provenance")
    }

    func testCompanionURLSchemeIsValid() {
        let url = URL(string: "provenance-companion://")
        XCTAssertNotNil(url, "provenance-companion:// must produce a valid URL")
    }

    func testCompanionURLSchemeComponents() {
        let url = URL(string: "provenance-companion://")
        XCTAssertEqual(url?.scheme, "provenance-companion")
    }

    func testCompanionURLWithPath() {
        let url = URL(string: "provenance-companion://peripherals")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "provenance-companion")
        XCTAssertEqual(url?.host, "peripherals")
    }

    func testInvalidURLSchemeReturnsNil() {
        let url = URL(string: "")
        XCTAssertNil(url, "Empty string must not produce a valid URL")
    }

    // MARK: - Bundle Identifier Convention

    func testBundleIdentifierFollowsOrgNamespace() {
        let expectedPrefix = "org.provenance-emu"
        let companionBundleID = "org.provenance-emu.ProvenanceCompanion"
        let testsBundleID = "org.provenance-emu.ProvenanceCompanionTests"
        XCTAssertTrue(companionBundleID.hasPrefix(expectedPrefix))
        XCTAssertTrue(testsBundleID.hasPrefix(expectedPrefix))
    }

    func testCompanionBundleIDIsSubdomainOfMainApp() {
        let mainAppPrefix = "org.provenance-emu"
        let companionID = "org.provenance-emu.ProvenanceCompanion"
        XCTAssertTrue(companionID.hasPrefix(mainAppPrefix + "."))
    }

    // MARK: - View Instantiation (smoke tests)

    func testContentViewInitializes() {
        let view = ContentView()
        _ = view.body
    }

    func testLibraryTabViewInitializes() {
        let view = LibraryTabView()
        _ = view.body
    }

    func testPeripheralsTabViewInitializes() {
        let view = PeripheralsTabView()
        _ = view.body
    }

    func testSettingsTabViewInitializes() {
        let view = SettingsTabView()
        _ = view.body
    }

    // MARK: - Deep Link URL Formation

    func testDeepLinkURLCanBeUsedAsOpenURLTarget() {
        // Verify the URL string used in SettingsTabView is constructable
        let rawURL = "provenance://"
        let url = URL(string: rawURL)
        XCTAssertNotNil(url, "The provenance:// URL used in SettingsTabView must be constructable")
        XCTAssertEqual(url?.scheme, "provenance")
    }

    func testCompanionDeepLinkURLCanBeConstructed() {
        let rawURL = "provenance-companion://"
        let url = URL(string: rawURL)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, rawURL)
    }
}
