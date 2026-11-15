//
//  EntityStoreConcurrencyTests.swift
//  PVAppIntentsTests
//

import XCTest
@testable import PVAppIntents

#if canImport(AppIntents)

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class EntityStoreConcurrencyTests: XCTestCase {
    private static let gameCount = 50
    private static let iterations = 2_000

    override func tearDown() {
        GameEntityStore.shared.update(all: [], recents: [])
        super.tearDown()
    }

    private func games(generation: Int) -> [GameEntity] {
        (0..<Self.gameCount).map { index in
            GameEntity(id: "md5-\(index)", title: "Generation \(generation)", systemName: "NES",
                       systemIdentifier: "com.provenance.nes", isFavorite: false)
        }
    }

    /// The library is replaced while intents query it. Every read must see one whole
    /// generation: all the games, and recents that belong to that same set.
    func testReadsDuringReplacementSeeAWholeGeneration() {
        let generations = (0..<4).map { games(generation: $0) }
        GameEntityStore.shared.update(all: generations[0], recents: Array(generations[0].prefix(5)))

        DispatchQueue.concurrentPerform(iterations: Self.iterations) { iteration in
            if iteration.isMultiple(of: 4) {
                let all = generations[(iteration / 4) % generations.count]
                GameEntityStore.shared.update(all: all, recents: Array(all.prefix(5)))
            } else {
                let all = GameEntityStore.shared.allEntities()
                XCTAssertEqual(all.count, Self.gameCount)
                XCTAssertEqual(Set(all.map(\.title)).count, 1)
                XCTAssertEqual(GameEntityStore.shared.recentEntities(limit: 3).count, 3)
                XCTAssertNotNil(GameEntityStore.shared.entity(for: "md5-0"))
            }
        }
    }
}

#endif
