//
//  PVLogChannelTests.swift
//  PVLoggingTests
//

import Foundation
@testable import PVLogging
import Testing

@Suite("PVLogChannel")
struct PVLogChannelTests {
    private func makeChannel(maxEntries: Int = 500) -> PVLogChannel {
        PVLogChannel("test-\(UUID().uuidString)", maxEntries: maxEntries, forwardToPublisher: false)
    }

    @Test func eventsAndMessagesAreCounted() {
        let channel = makeChannel()

        channel.event(.upload, item: "a.sav", status: .ok)
        channel.event(.upload, item: "b.sav", status: .failed)
        channel.error("disk full")
        channel.info("retrying")

        let summary = channel.summary()
        #expect(summary.totalEvents == 4)
        #expect(summary.errorCount == 2)
        #expect(summary.counters["UP.OK"] == 1)
        #expect(summary.counters["UP.FAIL"] == 1)
        #expect(channel.recentEvents().map(\.item) == ["a.sav", "b.sav"])
    }

    @Test func theRingBufferKeepsTheNewestEvents() {
        let channel = makeChannel(maxEntries: 3)

        for index in 0..<10 {
            channel.event(.download, item: "rom-\(index)", status: .ok)
        }

        #expect(channel.recentEvents().map(\.item) == ["rom-7", "rom-8", "rom-9"])
        #expect(channel.summary().totalEvents == 10)
    }

    @Test func clearEmptiesTheBuffersAndCounters() {
        let channel = makeChannel()
        channel.event(.upload, item: "a.sav", status: .failed)

        channel.clear()

        let summary = channel.summary()
        #expect(summary.totalEvents == 0)
        #expect(summary.errorCount == 0)
        #expect(summary.counters.isEmpty)
        #expect(summary.lastEventTime == nil)
        #expect(channel.recentEvents().isEmpty)
    }

    /// Sync workers log from many threads while a debug screen reads the summary.
    @Test func loggingFromManyThreadsLosesNothing() {
        let channel = makeChannel(maxEntries: 100)
        let iterations = 2_000

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            switch iteration % 4 {
            case 0: channel.event(.upload, item: "item-\(iteration)", status: .ok)
            case 1: channel.event(.upload, item: "item-\(iteration)", status: .failed)
            case 2: channel.error("message \(iteration)")
            default: _ = channel.summary()
            }
        }

        let summary = channel.summary()
        #expect(summary.totalEvents == iterations / 4 * 3)
        #expect(summary.errorCount == iterations / 4 * 2)
        #expect(summary.counters["UP.OK"] == iterations / 4)
        #expect(summary.counters["UP.FAIL"] == iterations / 4)
        #expect(channel.recentEvents(limit: 1_000).count == 100)
    }

    @Test func theRegistryFindsARegisteredChannel() {
        let channel = makeChannel()
        PVLogChannelRegistry.shared.register(channel)
        defer { PVLogChannelRegistry.shared.unregister(channel) }

        #expect(PVLogChannelRegistry.shared.channel(named: channel.name) === channel)
        #expect(PVLogChannelRegistry.shared.channelNames.contains(channel.name))
        #expect(PVLogChannelRegistry.shared.allSummaries().contains { $0.channelName == channel.name })
    }
}
