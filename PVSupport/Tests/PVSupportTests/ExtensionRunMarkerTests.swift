//
//  ExtensionRunMarkerTests.swift
//  PVSupportTests
//

import Foundation
import Testing
@testable import PVSupport

@Suite("ExtensionRunMarker")
struct ExtensionRunMarkerTests {

    private func record(
        footprintMB: UInt64,
        availableMB: UInt64,
        phase: String = "indexing",
        durationSeconds: TimeInterval = 2
    ) -> ExtensionRunRecord {
        let now = Date()
        return ExtensionRunRecord(
            extensionName: "Spotlight",
            phase: phase,
            startedAt: now.addingTimeInterval(-durationSeconds),
            updatedAt: now,
            footprintBytes: footprintMB * 1024 * 1024,
            availableMemoryBytes: availableMB * 1024 * 1024,
            appBuildVersion: "1234"
        )
    }

    @Test("No memory headroom left classifies as jetsam")
    func noHeadroomIsJetsam() {
        #expect(record(footprintMB: 30, availableMB: 1).likelyCause == "jetsam")
    }

    @Test("High footprint classifies as jetsam even with a stale headroom reading")
    func highFootprintIsJetsam() {
        #expect(record(footprintMB: 55, availableMB: 100).likelyCause == "jetsam")
    }

    @Test("Low footprint with plenty of headroom is not blamed on memory")
    func lowFootprintWithHeadroomIsUnknown() {
        #expect(record(footprintMB: 12, availableMB: 200).likelyCause == "unknown")
    }

    /// `os_proc_available_memory()` documents a `0` return both for a process
    /// over its limit *and* for a process that simply is not an app, so `0`
    /// must never be read as "no headroom".
    @Test("Unknown headroom (0) is not treated as no headroom")
    func zeroAvailableMemoryIsNotJetsam() {
        #expect(record(footprintMB: 8, availableMB: 0).likelyCause == "unknown")
    }

    @Test("Duration is derived from the start and last-checkpoint timestamps")
    func durationIsDerivedFromTimestamps() {
        #expect(abs(record(footprintMB: 10, availableMB: 50, durationSeconds: 7).duration - 7) < 0.001)
    }

    @Test("Record survives a JSON round trip")
    func recordRoundTripsThroughJSON() throws {
        let original = record(footprintMB: 42, availableMB: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExtensionRunRecord.self, from: data)
        #expect(decoded == original)
    }

    @Test("Reporting tags carry name, phase and cause")
    func reportingTagsCarryTriageFields() {
        let tags = record(footprintMB: 55, availableMB: 1, phase: "reindex-all").reportingTags
        #expect(tags["extension.name"] == "Spotlight")
        #expect(tags["extension.phase"] == "reindex-all")
        #expect(tags["extension.likely_cause"] == "jetsam")
    }

    @Test("Summary line reports an unknown headroom reading as unknown")
    func summaryLineLabelsUnknownHeadroom() {
        let line = record(footprintMB: 10, availableMB: 0).summaryLine
        #expect(line.contains("available=unknown"))
        #expect(line.contains("Spotlight"))
    }

    @Test("Marker filenames are filesystem safe")
    func markerFilenamesAreSanitised() {
        /// Nil only when the App Group container is unavailable (as in CI);
        /// when present the name must never contain path-hostile characters.
        if let name = ExtensionRunMarker.markerURL(for: "ROM File Provider")?.lastPathComponent {
            #expect(name == "ROM_File_Provider.json")
        }
        if let name = ExtensionRunMarker.markerURL(for: "../escape")?.lastPathComponent {
            #expect(!name.contains("/"))
            #expect(!name.contains(".."))
        }
    }

    @Test("Consuming records without an App Group container is a no-op, not a crash")
    func consumingWithoutContainerIsSafe() {
        /// Unit tests have no App Group entitlement, so the container is nil.
        /// The reader must degrade quietly rather than trap.
        #expect(ExtensionRunMarker.consumePendingRecords().isEmpty)
    }

    @Test("Physical footprint reports a plausible non-zero value")
    func physicalFootprintIsPlausible() {
        let footprint = ExtensionRunMarker.physicalFootprintBytes()
        #expect(footprint > 0)
        /// Sanity bound — a test process is nowhere near 5GB.
        #expect(footprint < 5_000_000_000)
    }
}
