//
//  NetpacketPumpTests.swift
//  PVLibRetroTests
//
//  Netplay hands the core its netpacket callbacks (libretro env 78) on the
//  emulation thread, once per frame before retro_run: lifecycle events and
//  packets in arrival order, then `poll`. These tests drive a fake core's
//  callback table through that pump.
//
//  The fake core's state is global (C function pointers can't capture), so
//  the suite is serialized.
//

import Foundation
import Testing
@testable import PVCoreBridgeRetro

private enum FakeCore {
    nonisolated(unsafe) static var log: [String] = []
    nonisolated(unsafe) static var acceptsClients = true
    nonisolated(unsafe) static var sendsOnStart = false

    static func reset() {
        log = []
        acceptsClients = true
        sendsOnStart = false
    }

    static func callback() -> retro_netpacket_callback {
        var callback = retro_netpacket_callback()
        callback.start = { clientID, send, _ in
            FakeCore.log.append("start \(clientID)")
            if FakeCore.sendsOnStart {
                let bytes: [UInt8] = [0xAB]
                bytes.withUnsafeBytes { send?(0, $0.baseAddress, $0.count, 0) }
            }
        }
        callback.receive = { buf, len, clientID in
            let bytes = buf.map { [UInt8](UnsafeRawBufferPointer(start: $0, count: len)) } ?? []
            FakeCore.log.append("receive \(clientID) \(bytes)")
        }
        callback.stop = { FakeCore.log.append("stop") }
        callback.poll = { FakeCore.log.append("poll") }
        callback.connected = { clientID in
            FakeCore.log.append("connected \(clientID)")
            return FakeCore.acceptsClients
        }
        callback.disconnected = { clientID in FakeCore.log.append("disconnected \(clientID)") }
        return callback
    }
}

/// Collects values handed to the frontend's blocks.
private final class Box<Value>: @unchecked Sendable {
    var values: [Value] = []
}

@Suite(.serialized)
struct NetpacketPumpTests {

    private func makeFrontend() -> PVThinLibretroFrontend {
        FakeCore.reset()
        let frontend = PVThinLibretroFrontend()
        var callback = FakeCore.callback()
        frontend._testRegisterNetpacketCallback(&callback)
        return frontend
    }

    @Test func nothingReachesTheCoreUntilTheFrameRuns() {
        let frontend = makeFrontend()
        frontend.startNetpacketSession(withClientID: 0)
        frontend.netpacketPeerConnected(1)
        frontend.enqueueNetpacketData(Data([1, 2]), fromClient: 1)
        #expect(FakeCore.log.isEmpty)

        frontend._testRunNetpacketFrame()

        #expect(FakeCore.log == ["start 0", "connected 1", "receive 1 [1, 2]", "poll"])
    }

    @Test func pollRunsEveryFrameWhileTheSessionIsUp() {
        let frontend = makeFrontend()
        frontend.startNetpacketSession(withClientID: 2)
        frontend._testRunNetpacketFrame()
        frontend._testRunNetpacketFrame()

        #expect(FakeCore.log == ["start 2", "poll", "poll"])
    }

    @Test func packetsOutsideASessionAreDropped() {
        let frontend = makeFrontend()
        frontend.enqueueNetpacketData(Data([9]), fromClient: 1)
        frontend.netpacketPeerConnected(1)
        frontend._testRunNetpacketFrame()

        #expect(FakeCore.log.isEmpty)
    }

    @Test func stopEndsTheSession() {
        let frontend = makeFrontend()
        frontend.startNetpacketSession(withClientID: 0)
        frontend._testRunNetpacketFrame()
        frontend.stopNetpacketSession()
        frontend.enqueueNetpacketData(Data([5]), fromClient: 1)
        frontend._testRunNetpacketFrame()

        #expect(FakeCore.log == ["start 0", "poll", "stop"])
    }

    @Test func aClientTheCoreRefusesIsDropped() {
        let frontend = makeFrontend()
        FakeCore.acceptsClients = false
        let rejected = Box<UInt16>()
        frontend.netpacketRejectPeerBlock = { rejected.values.append($0) }
        frontend.startNetpacketSession(withClientID: 0)
        frontend.netpacketPeerConnected(3)

        frontend._testRunNetpacketFrame()

        #expect(rejected.values == [3])

        // Dropping the refused client reports it as gone; the core never
        // accepted it, so it shouldn't hear about it.
        frontend.netpacketPeerDisconnected(3)
        frontend._testRunNetpacketFrame()
        #expect(!FakeCore.log.contains("disconnected 3"))
    }

    @Test func theCoreCanSendFromStart() {
        let frontend = makeFrontend()
        FakeCore.sendsOnStart = true
        let sent = Box<[UInt8]>()
        frontend.netpacketSendBlock = { _, buf, len, _ in
            sent.values.append([UInt8](UnsafeRawBufferPointer(start: buf, count: len)))
        }
        frontend.startNetpacketSession(withClientID: 0)

        frontend._testRunNetpacketFrame()

        #expect(sent.values == [[0xAB]])
    }
}

struct NetplayBonjourNameTests {

    @Test func shortNamesAreUnchanged() {
        #expect(PVThinLibretroCore.bonjourInstanceName("Joe — Doom") == "Joe — Doom")
    }

    @Test func longNamesStopAt63BytesOnACharacterBoundary() {
        // 62 ASCII bytes, then a 3-byte em dash that would cross the limit.
        let name = String(repeating: "a", count: 62) + "—tail"
        let cut = PVThinLibretroCore.bonjourInstanceName(name)
        #expect(cut == String(repeating: "a", count: 62))
        #expect(cut.utf8.count <= 63)
    }
}
