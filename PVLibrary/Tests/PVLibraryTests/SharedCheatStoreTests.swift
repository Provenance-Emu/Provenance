import Testing
import Foundation
@testable import PVLibrary

// MARK: - SharedCheatEntry URL encoding tests

@Suite("SharedCheatEntry QR URL encoding")
struct SharedCheatEntryURLTests {

    let entry = SharedCheatEntry(
        id: UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000001")!,
        name: "Infinite Lives",
        code: "9999-5EC0",
        format: "Game Genie",
        systemName: "Super Nintendo",
        gameName: "Super Mario World"
    )

    @Test("qrURLString starts with provenance-cheat://v1")
    func urlScheme() {
        #expect(entry.qrURLString.hasPrefix("provenance-cheat://v1"))
    }

    @Test("qrURLString contains the cheat code")
    func urlContainsCode() {
        #expect(entry.qrURLString.contains("9999-5EC0"))
    }

    @Test("round-trip: from(qrURLString:) recovers all fields")
    func roundTrip() {
        guard let recovered = SharedCheatEntry.from(qrURLString: entry.qrURLString) else {
            Issue.record("from(qrURLString:) returned nil")
            return
        }
        #expect(recovered.code       == entry.code)
        #expect(recovered.format     == entry.format)
        #expect(recovered.systemName == entry.systemName)
        #expect(recovered.gameName   == entry.gameName)
        #expect(recovered.name       == entry.name)
    }

    @Test("from(qrURLString:) returns nil for garbage input")
    func roundTripGarbage() {
        #expect(SharedCheatEntry.from(qrURLString: "not-a-url") == nil)
        #expect(SharedCheatEntry.from(qrURLString: "https://example.com") == nil)
        #expect(SharedCheatEntry.from(qrURLString: "") == nil)
    }

    @Test("entries with special characters survive URL encoding")
    func specialCharacters() {
        let special = SharedCheatEntry(
            name: "Lives & Coins (x99)",
            code: "7E03E2:63+7E03AF:63",
            format: "Game Shark v1.1",
            systemName: "SNES / Super Famicom",
            gameName: "Yoshi's Island"
        )
        guard let recovered = SharedCheatEntry.from(qrURLString: special.qrURLString) else {
            Issue.record("Round-trip failed for special characters")
            return
        }
        #expect(recovered.code   == special.code)
        #expect(recovered.format == special.format)
        #expect(recovered.gameName == special.gameName)
    }
}

// MARK: - SharedCheatStore persistence tests

@Suite("SharedCheatStore persistence (temp-dir)")
struct SharedCheatStoreTests {

    // Use a temp-dir-backed store so tests don't touch real App Group containers.
    private func makeStore() -> SharedCheatStore {
        // Override with a random group ID that won't resolve to a real container.
        // The store will fall back to an in-memory no-op when the container is unavailable.
        SharedCheatStore(groupIdentifier: "group.test.nonexistent.\(UUID())")
    }

    @Test("loadAll returns empty array when no file exists")
    func emptyOnFirstLoad() async throws {
        let store = makeStore()
        let entries = try await store.loadAll()
        #expect(entries.isEmpty)
    }

    @Test("add then loadAll returns the entry")
    func addAndLoad() async throws {
        // Write directly to a temp file to avoid App Group requirement.
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cheats-\(UUID()).json")
        let store = SharedCheatStore(fileURL: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let entry = SharedCheatEntry(name: "Test", code: "ABCD-1234", format: "GS", systemName: "NES", gameName: "Tetris")
        try await store.add(entry)
        let loaded = try await store.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded[0].code == "ABCD-1234")
    }

    @Test("add deduplicates by id (replaces existing)")
    func addDeduplicates() async throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cheats-\(UUID()).json")
        let store = SharedCheatStore(fileURL: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let id = UUID()
        let original = SharedCheatEntry(id: id, name: "Old", code: "OLD-0000", format: "GS", systemName: "NES", gameName: "Mario")
        let updated  = SharedCheatEntry(id: id, name: "New", code: "NEW-1111", format: "GS", systemName: "NES", gameName: "Mario")

        try await store.add(original)
        try await store.add(updated)

        let loaded = try await store.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded[0].code == "NEW-1111")
    }

    @Test("remove deletes the correct entry")
    func removeEntry() async throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cheats-\(UUID()).json")
        let store = SharedCheatStore(fileURL: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let id1 = UUID()
        let id2 = UUID()
        try await store.add(SharedCheatEntry(id: id1, name: "A", code: "AA", format: "GS", systemName: "NES", gameName: "A"))
        try await store.add(SharedCheatEntry(id: id2, name: "B", code: "BB", format: "GS", systemName: "NES", gameName: "B"))
        try await store.remove(id: id1)

        let loaded = try await store.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == id2)
    }
}
