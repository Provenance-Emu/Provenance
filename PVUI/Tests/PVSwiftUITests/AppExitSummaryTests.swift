//
//  AppExitSummaryTests.swift
//  PVSwiftUITests
//

import Testing
@testable import PVSwiftUI

@Suite("AppExitSummary")
struct AppExitSummaryTests {

    /// A clean run: only normal exits, nothing to report.
    private func cleanCounts() -> AppExitCounts {
        AppExitCounts(
            normal: 12,
            memoryResourceLimit: 0,
            badAccess: 0,
            abnormal: 0,
            illegalInstruction: 0,
            watchdog: 0
        )
    }

    @Test("Clean counters report no abnormal exits")
    func cleanCountersHaveNoAbnormalExits() {
        let counts = cleanCounts()
        #expect(counts.abnormalTotal == 0)
        #expect(counts.jetsamTotal == 0)
        #expect(counts.hasAbnormalExits == false)
        #expect(counts.nonZeroCounters.isEmpty)
        #expect(counts.summaryLine == "normal=12")
    }

    @Test("Jetsam total combines memory-limit and memory-pressure kills")
    func jetsamTotalCombinesBothMemoryCounters() {
        let counts = AppExitCounts(
            normal: 3,
            memoryResourceLimit: 4,
            memoryPressure: 2,
            badAccess: 0,
            abnormal: 0,
            illegalInstruction: 0,
            watchdog: 0
        )
        #expect(counts.jetsamTotal == 6)
        #expect(counts.abnormalTotal == 6)
        #expect(counts.hasAbnormalExits)
    }

    @Test("0xdead10cc counts as an abnormal exit but not as jetsam")
    func lockedFileExitIsAbnormalNotJetsam() {
        let counts = AppExitCounts(
            normal: 1,
            memoryResourceLimit: 0,
            badAccess: 0,
            abnormal: 0,
            illegalInstruction: 0,
            watchdog: 0,
            suspendedWithLockedFile: 5
        )
        #expect(counts.jetsamTotal == 0)
        #expect(counts.abnormalTotal == 5)
        #expect(counts.summaryLine == "normal=1 suspendedWithLockedFile=5")
    }

    @Test("Zero counters are omitted from the summary line")
    func summaryLineOmitsZeroCounters() {
        let counts = AppExitCounts(
            normal: 0,
            memoryResourceLimit: 7,
            badAccess: 0,
            abnormal: 0,
            illegalInstruction: 0,
            watchdog: 1
        )
        #expect(counts.summaryLine == "normal=0 memoryResourceLimit=7 watchdog=1")
    }

    @Test("Dominant class picks the largest bucket across both scopes")
    func dominantClassPicksLargestBucket() {
        let summary = AppExitSummary(
            foreground: AppExitCounts(
                normal: 5, memoryResourceLimit: 1,
                badAccess: 2, abnormal: 0, illegalInstruction: 0, watchdog: 0
            ),
            background: AppExitCounts(
                normal: 8, memoryResourceLimit: 9,
                badAccess: 0, abnormal: 0, illegalInstruction: 0, watchdog: 0
            )
        )
        /// 1 (foreground) + 9 (background) = 10 memory-limit kills beats 2 bad-access.
        #expect(summary.dominantClass == "memoryResourceLimit")
        #expect(summary.hasAbnormalExits)
    }

    @Test("Dominant class is 'none' when everything exited cleanly")
    func dominantClassIsNoneWhenClean() {
        let summary = AppExitSummary(foreground: cleanCounts(), background: cleanCounts())
        #expect(summary.dominantClass == "none")
        #expect(summary.hasAbnormalExits == false)
    }

    @Test("Sentry tags expose jetsam and locked-file counts for filtering")
    func sentryTagsExposeSuspectedTerminationClasses() {
        let summary = AppExitSummary(
            foreground: cleanCounts(),
            background: AppExitCounts(
                normal: 2,
                memoryResourceLimit: 3,
                memoryPressure: 1,
                badAccess: 0,
                abnormal: 0,
                illegalInstruction: 0,
                watchdog: 0,
                suspendedWithLockedFile: 2
            )
        )
        let tags = summary.sentryTags
        #expect(tags["exit.background.jetsam"] == "4")
        #expect(tags["exit.background.locked_file"] == "2")
        #expect(tags["exit.foreground.jetsam"] == "0")
        #expect(tags["exit.dominant_class"] == "memoryResourceLimit")
    }

    @Test("Dominant class breaks ties deterministically")
    func dominantClassIsDeterministicOnTies() {
        let counts = AppExitCounts(
            normal: 0,
            memoryResourceLimit: 2,
            badAccess: 2,
            abnormal: 0,
            illegalInstruction: 0,
            watchdog: 0
        )
        let summary = AppExitSummary(foreground: counts, background: cleanCounts())
        /// Equal counts — the lexicographically smaller name wins, every time.
        #expect(summary.dominantClass == "badAccess")
        #expect(summary.dominantClass == AppExitSummary(foreground: counts, background: cleanCounts()).dominantClass)
    }
}
