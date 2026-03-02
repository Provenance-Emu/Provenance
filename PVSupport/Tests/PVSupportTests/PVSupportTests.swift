//
//  PVSupportTests.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Testing
@testable import PVSupport
import Foundation

// MARK: - Sequence+Intersects Tests

@Suite("Sequence.intersects")
struct SequenceIntersectsTests {

    @Test("Empty arrays do not intersect")
    func emptyArraysDoNotIntersect() {
        let a: [Int] = []
        let b: [Int] = []
        #expect(!a.intersects(with: b))
    }

    @Test("Empty self does not intersect with non-empty sequence")
    func emptyNotIntersectsNonEmpty() {
        let a: [Int] = []
        let b = [1, 2, 3]
        #expect(!a.intersects(with: b))
    }

    @Test("Non-empty self does not intersect with empty sequence")
    func nonEmptyNotIntersectsEmpty() {
        let a = [1, 2, 3]
        let b: [Int] = []
        #expect(!a.intersects(with: b))
    }

    @Test("Identical arrays intersect")
    func identicalArraysIntersect() {
        let a = [1, 2, 3]
        let b = [1, 2, 3]
        #expect(a.intersects(with: b))
    }

    @Test("Disjoint arrays do not intersect")
    func disjointArraysDoNotIntersect() {
        let a = [1, 2, 3]
        let b = [4, 5, 6]
        #expect(!a.intersects(with: b))
    }

    @Test("Partially overlapping arrays intersect")
    func partiallyOverlappingArraysIntersect() {
        let a = [1, 2, 3]
        let b = [3, 4, 5]
        #expect(a.intersects(with: b))
    }

    @Test("Single matching element causes intersection")
    func singleMatchingElement() {
        let a = [42]
        let b = [42]
        #expect(a.intersects(with: b))
    }

    @Test("Single non-matching element causes no intersection")
    func singleNonMatchingElement() {
        let a = [1]
        let b = [2]
        #expect(!a.intersects(with: b))
    }

    @Test("Works with String sequences")
    func stringSequences() {
        let a = ["apple", "banana", "cherry"]
        let b = ["cherry", "date"]
        #expect(a.intersects(with: b))
    }

    @Test("Works with String sequences — no overlap")
    func stringSequencesNoOverlap() {
        let a = ["apple", "banana"]
        let b = ["cherry", "date"]
        #expect(!a.intersects(with: b))
    }

    @Test("Works with Sets as argument")
    func setArgument() {
        let a = [1, 2, 3]
        let b: Set<Int> = [3, 4, 5]
        #expect(a.intersects(with: b))
    }

    @Test("Handles duplicates in self correctly")
    func duplicatesInSelf() {
        let a = [1, 1, 2, 2]
        let b = [2, 3]
        #expect(a.intersects(with: b))
    }

    @Test("Handles duplicates in argument correctly")
    func duplicatesInArgument() {
        let a = [1, 2, 3]
        let b = [3, 3, 3]
        #expect(a.intersects(with: b))
    }
}

// MARK: - Async Sequence Operations Tests

@Suite("Sequence asyncMap")
struct AsyncMapTests {

    @Test("asyncMap transforms all elements")
    func asyncMapTransformsAll() async throws {
        let input = [1, 2, 3, 4, 5]
        let result = try await input.asyncMap { $0 * 2 }
        #expect(result == [2, 4, 6, 8, 10])
    }

    @Test("asyncMap on empty sequence returns empty")
    func asyncMapEmptySequence() async throws {
        let input: [Int] = []
        let result = try await input.asyncMap { $0 * 2 }
        #expect(result.isEmpty)
    }

    @Test("asyncMap preserves order")
    func asyncMapPreservesOrder() async throws {
        let input = [3, 1, 4, 1, 5, 9, 2, 6]
        let result = try await input.asyncMap { $0 }
        #expect(result == input)
    }

    @Test("asyncMap can transform to different type")
    func asyncMapTypedTransform() async throws {
        let input = [1, 2, 3]
        let result = try await input.asyncMap { "\($0)" }
        #expect(result == ["1", "2", "3"])
    }

    @Test("asyncMap with single element")
    func asyncMapSingleElement() async throws {
        let input = [42]
        let result = try await input.asyncMap { $0 + 1 }
        #expect(result == [43])
    }
}

@Suite("Sequence asyncCompactMap")
struct AsyncCompactMapTests {

    @Test("asyncCompactMap filters out nils")
    func asyncCompactMapFiltersNils() async throws {
        let input = [1, 2, 3, 4, 5]
        let result = try await input.asyncCompactMap { n -> Int? in
            n % 2 == 0 ? n : nil
        }
        #expect(result == [2, 4])
    }

    @Test("asyncCompactMap on empty sequence returns empty")
    func asyncCompactMapEmpty() async throws {
        let input: [Int] = []
        let result = try await input.asyncCompactMap { n -> Int? in n }
        #expect(result.isEmpty)
    }

    @Test("asyncCompactMap when all return nil gives empty array")
    func asyncCompactMapAllNils() async throws {
        let input = [1, 2, 3]
        let result = try await input.asyncCompactMap { _ -> Int? in nil }
        #expect(result.isEmpty)
    }

    @Test("asyncCompactMap when none are nil keeps all")
    func asyncCompactMapNoneNil() async throws {
        let input = [1, 2, 3]
        let result = try await input.asyncCompactMap { n -> Int? in n }
        #expect(result == [1, 2, 3])
    }

    @Test("asyncCompactMap can change type")
    func asyncCompactMapTypeChange() async throws {
        let input = ["1", "abc", "3", "xyz"]
        let result = try await input.asyncCompactMap { Int($0) }
        #expect(result == [1, 3])
    }
}

@Suite("Sequence asyncFilter")
struct AsyncFilterTests {

    @Test("asyncFilter keeps matching elements")
    func asyncFilterKeepsMatching() async throws {
        let input = [1, 2, 3, 4, 5, 6]
        let result = try await input.asyncFilter { $0 % 2 == 0 }
        #expect(result == [2, 4, 6])
    }

    @Test("asyncFilter on empty sequence returns empty")
    func asyncFilterEmpty() async throws {
        let input: [Int] = []
        let result = try await input.asyncFilter { $0 > 0 }
        #expect(result.isEmpty)
    }

    @Test("asyncFilter when none match returns empty")
    func asyncFilterNoneMatch() async throws {
        let input = [1, 3, 5, 7]
        let result = try await input.asyncFilter { $0 % 2 == 0 }
        #expect(result.isEmpty)
    }

    @Test("asyncFilter when all match returns all")
    func asyncFilterAllMatch() async throws {
        let input = [2, 4, 6, 8]
        let result = try await input.asyncFilter { $0 % 2 == 0 }
        #expect(result == input)
    }

    @Test("asyncFilter preserves order")
    func asyncFilterPreservesOrder() async throws {
        let input = [5, 1, 4, 2, 3]
        let result = try await input.asyncFilter { $0 > 2 }
        #expect(result == [5, 4, 3])
    }
}

@Suite("Sequence asyncForEach")
struct AsyncForEachTests {

    @Test("asyncForEach executes for each element")
    func asyncForEachExecutesForEach() async throws {
        let input = [1, 2, 3, 4, 5]
        var visited: [Int] = []
        try await input.asyncForEach { element in
            visited.append(element)
        }
        #expect(visited == [1, 2, 3, 4, 5])
    }

    @Test("asyncForEach on empty sequence is a no-op")
    func asyncForEachEmpty() async throws {
        let input: [Int] = []
        var count = 0
        try await input.asyncForEach { _ in count += 1 }
        #expect(count == 0)
    }

    @Test("asyncForEach executes in order")
    func asyncForEachExecutesInOrder() async throws {
        let input = ["a", "b", "c"]
        var result = ""
        try await input.asyncForEach { element in
            result += element
        }
        #expect(result == "abc")
    }
}

@Suite("Sequence concurrentMap")
struct ConcurrentMapTests {

    @Test("concurrentMap transforms all elements")
    func concurrentMapTransformsAll() async throws {
        let input = [1, 2, 3, 4, 5]
        let result = try await input.concurrentMap { $0 * 10 }
        let sorted = result.sorted()
        #expect(sorted == [10, 20, 30, 40, 50])
    }

    @Test("concurrentMap on empty sequence returns empty")
    func concurrentMapEmpty() async throws {
        let input: [Int] = []
        let result = try await input.concurrentMap { $0 * 2 }
        #expect(result.isEmpty)
    }

    @Test("concurrentMap with single element")
    func concurrentMapSingleElement() async throws {
        let input = [7]
        let result = try await input.concurrentMap { $0 * 3 }
        #expect(result == [21])
    }
}

@Suite("Sequence concurrentForEach")
struct ConcurrentForEachTests {

    @Test("concurrentForEach executes for all elements")
    func concurrentForEachExecutesAll() async {
        let input = [1, 2, 3, 4, 5]
        let counter = Counter()
        await input.concurrentForEach { _ in
            await counter.increment()
        }
        let finalCount = await counter.value
        #expect(finalCount == input.count)
    }

    @Test("concurrentForEach on empty sequence is a no-op")
    func concurrentForEachEmpty() async {
        let input: [Int] = []
        let counter = Counter()
        await input.concurrentForEach { _ in
            await counter.increment()
        }
        let finalCount = await counter.value
        #expect(finalCount == 0)
    }
}

/// Thread-safe counter for concurrent tests
actor Counter {
    var value = 0
    func increment() { value += 1 }
}
