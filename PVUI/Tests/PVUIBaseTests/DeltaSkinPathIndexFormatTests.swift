import XCTest

/// Validates the JSON shape used for `skin_path_index.json` (identifier → file path).
final class DeltaSkinPathIndexFormatTests: XCTestCase {

    func testRoundTripIdentifierToPathMap() throws {
        let original: [String: String] = [
            "com.example.skin": "/Documents/DeltaSkins/Example.deltaskin",
            "another.id": "/path/with spaces/Manic.skin/manicskin"
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
