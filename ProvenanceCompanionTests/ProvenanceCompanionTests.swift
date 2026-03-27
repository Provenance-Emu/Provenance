import XCTest
@testable import ProvenanceCompanion

final class ProvenanceCompanionTests: XCTestCase {

    // MARK: - URL Scheme

    func testProvenanceURLSchemeIsValid() {
        let url = URL(string: "provenance://")
        XCTAssertNotNil(url, "provenance:// must produce a valid URL")
    }

    func testCompanionURLSchemeIsValid() {
        let url = URL(string: "provenance-companion://")
        XCTAssertNotNil(url, "provenance-companion:// must produce a valid URL")
    }

    // MARK: - View Instantiation

    func testContentViewInitializes() {
        let view = ContentView()
        XCTAssertNotNil(view)
    }

    func testLibraryTabViewInitializes() {
        let view = LibraryTabView()
        XCTAssertNotNil(view)
    }

    func testPeripheralsTabViewInitializes() {
        let view = PeripheralsTabView()
        XCTAssertNotNil(view)
    }

    func testSettingsTabViewInitializes() {
        let view = SettingsTabView()
        XCTAssertNotNil(view)
    }
}
