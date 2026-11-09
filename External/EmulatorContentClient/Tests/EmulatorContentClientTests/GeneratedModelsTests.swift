import EmulatorContentClient
import Foundation
import XCTest

final class GeneratedModelsTests: XCTestCase {
    func testDefaultConfigurationKeepsItsWireName() throws {
        let configuration = PlayerConfiguration(enabled: true, default: true)
        let data = try JSONEncoder().encode(configuration)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Bool])
        XCTAssertEqual(fields, ["enabled": true, "default": true])
        let decoded = try JSONDecoder().decode(PlayerConfiguration.self, from: data)
        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(decoded.`default`, true)
    }
}
