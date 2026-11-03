import XCTest
@testable import PVSwiftUI

final class LibraryGameFilterTests: XCTestCase {
    private struct Game: Equatable {
        let id: Int
        let title: String
    }

    func testFilteringKeepsTheCurrentCollectionAndItsOrder() {
        let snes = [Game(id: 1, title: "Super Mario World"), Game(id: 2, title: "F-Zero"), Game(id: 3, title: "Mario Paint")]
        let favorites = [snes[2], Game(id: 4, title: "Mario Kart 64")]

        XCTAssertEqual(LibraryGameFilter.games(snes, matching: " mario ", title: \.title).map(\.id), [1, 3])
        XCTAssertEqual(LibraryGameFilter.games(favorites, matching: "mario", title: \.title).map(\.id), [3, 4])
        XCTAssertEqual(LibraryGameFilter.games(snes, matching: "kart", title: \.title), [])
        XCTAssertEqual(LibraryGameFilter.games(favorites, matching: " ", title: \.title), favorites)
    }

}
