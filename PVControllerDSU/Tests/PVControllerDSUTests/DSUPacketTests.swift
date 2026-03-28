import Testing
import Foundation
@testable import PVControllerDSU

/// Tests for DSUPacket encoding and decoding.
///
/// All tests are pure protocol logic — no Network.framework is used.
struct DSUPacketTests {

    // MARK: - Header size

    @Test("DSUHeader.size constant equals 20")
    func testHeaderSize() {
        #expect(DSUHeader.size == 20)
    }

    // MARK: - VersionRequest round-trip

    @Test("VersionRequest encodes to correct magic and message type, decodes back")
    func testVersionRequestRoundTrip() throws {
        let uid: UInt32 = 0xDEADBEEF
        let packet = DSUPacket.versionRequest(clientUID: uid)
        let data = packet.encode()

        // Magic must be "DSUC" for client → server
        let magic = Array(data[0..<4])
        #expect(magic == DSUConstants.clientMagic)

        // Protocol version at bytes 4-5 (LE)
        let version = UInt16(data[4]) | (UInt16(data[5]) << 8)
        #expect(version == DSUConstants.protocolVersion)

        // Message type at bytes 16-19 (LE)
        let msgType = UInt32(data[16])
            | (UInt32(data[17]) << 8)
            | (UInt32(data[18]) << 16)
            | (UInt32(data[19]) << 24)
        #expect(msgType == DSUMessageType.versionRequest.rawValue)

        // CRC must be valid
        #expect(DSUCRC32.verify(data))

        // Decode
        let decoded = try #require(DSUPacket.decode(data))
        guard case .versionRequest(let decodedUID) = decoded else {
            Issue.record("Expected .versionRequest")
            return
        }
        #expect(decodedUID == uid)
    }

    // MARK: - VersionResponse round-trip

    @Test("VersionResponse encodes with server magic, decodes back")
    func testVersionResponseRoundTrip() throws {
        let uid: UInt32 = 0x12345678
        let ver: UInt16 = DSUConstants.protocolVersion
        let packet = DSUPacket.versionResponse(clientUID: uid, version: ver)
        let data = packet.encode()

        let magic = Array(data[0..<4])
        #expect(magic == DSUConstants.serverMagic)
        #expect(DSUCRC32.verify(data))

        let decoded = try #require(DSUPacket.decode(data))
        guard case .versionResponse(let decodedUID, let decodedVersion) = decoded else {
            Issue.record("Expected .versionResponse")
            return
        }
        #expect(decodedUID == uid)
        #expect(decodedVersion == ver)
    }

    // MARK: - ListPortsResponse round-trip

    @Test("ListPortsResponse encodes slot info, decodes back")
    func testListPortsResponseRoundTrip() throws {
        let uid: UInt32 = 0x11223344
        let mac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF)
        let packet = DSUPacket.listPortsResponse(
            clientUID: uid,
            slotIndex: 1,
            slotState: .connected,
            deviceModel: .full,
            connectionType: .bluetooth,
            macAddress: mac,
            batteryStatus: .high
        )
        let data = packet.encode()

        #expect(Array(data[0..<4]) == DSUConstants.serverMagic)
        #expect(DSUCRC32.verify(data))

        let decoded = try #require(DSUPacket.decode(data))
        guard case .listPortsResponse(
            let dUID, let dSlot, let dState, let dModel, let dConn, let dMac, let dBattery
        ) = decoded else {
            Issue.record("Expected .listPortsResponse")
            return
        }
        #expect(dUID == uid)
        #expect(dSlot == 1)
        #expect(dState == .connected)
        #expect(dModel == .full)
        #expect(dConn == .bluetooth)
        #expect(dMac == mac)
        #expect(dBattery == .high)
    }

    // MARK: - ListPortsRequest round-trip

    @Test("ListPortsRequest encodes port list, decodes back")
    func testListPortsRequestRoundTrip() throws {
        let uid: UInt32 = 0xAABBCCDD
        let ports: [UInt8] = [0, 1, 2, 3]
        let packet = DSUPacket.listPortsRequest(clientUID: uid, ports: ports)
        let data = packet.encode()

        #expect(Array(data[0..<4]) == DSUConstants.clientMagic)
        #expect(DSUCRC32.verify(data))

        let decoded = try #require(DSUPacket.decode(data))
        guard case .listPortsRequest(let decodedUID, let decodedPorts) = decoded else {
            Issue.record("Expected .listPortsRequest")
            return
        }
        #expect(decodedUID == uid)
        #expect(decodedPorts == ports)
    }

    @Test("ListPortsRequest truncates to 4 ports maximum")
    func testListPortsRequestTruncation() throws {
        let uid: UInt32 = 0x01020304
        // Supply 6 ports — should be silently truncated to 4
        let ports: [UInt8] = [0, 1, 2, 3, 4, 5]
        let packet = DSUPacket.listPortsRequest(clientUID: uid, ports: ports)
        let data = packet.encode()

        let decoded = try #require(DSUPacket.decode(data))
        guard case .listPortsRequest(_, let decodedPorts) = decoded else {
            Issue.record("Expected .listPortsRequest")
            return
        }
        #expect(decodedPorts.count <= 4)
    }

    // MARK: - PadDataRequest round-trip

    @Test("PadDataRequest encodes flags, slot, and MAC; decodes back")
    func testPadDataRequestRoundTrip() throws {
        let uid: UInt32 = 0xFEFEFEFE
        let flags: UInt8 = 1
        let slotIndex: UInt8 = 2
        let mac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x11, 0x22, 0x33, 0x44, 0x55, 0x66)

        let packet = DSUPacket.padDataRequest(clientUID: uid, flags: flags, slotIndex: slotIndex, macAddress: mac)
        let data = packet.encode()

        #expect(Array(data[0..<4]) == DSUConstants.clientMagic)
        #expect(DSUCRC32.verify(data))

        let decoded = try #require(DSUPacket.decode(data))
        guard case .padDataRequest(let dUID, let dFlags, let dSlot, let dMac) = decoded else {
            Issue.record("Expected .padDataRequest")
            return
        }
        #expect(dUID == uid)
        #expect(dFlags == flags)
        #expect(dSlot == slotIndex)
        #expect(dMac == mac)
    }

    // MARK: - ControllerData round-trip

    @Test("ControllerData encodes all fields, decodes back with matching values")
    func testControllerDataRoundTrip() throws {
        let uid: UInt32 = 0xCAFEBABE
        let mac: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF)

        let touch1 = DSUTouchContact(isActive: true, id: 1, x: 640, y: 400)
        let touch2 = DSUTouchContact(isActive: false, id: 0, x: 0, y: 0)

        let ctrlData = DSUControllerData(
            slotIndex: 0,
            slotState: .connected,
            deviceModel: .full,
            connectionType: .bluetooth,
            macAddress: mac,
            batteryStatus: .high,
            isActive: true,
            packetNumber: 42,
            buttons1: 0b00001010,
            buttons2: 0b11000000,
            psButton: 1,
            touchButton: 0,
            leftStickX: 100,
            leftStickY: 150,
            rightStickX: 200,
            rightStickY: 75,
            dpadLeft: 255,
            dpadDown: 0,
            dpadRight: 0,
            dpadUp: 128,
            buttonR1: 200,
            buttonL1: 180,
            buttonR2: 100,
            buttonL2: 90,
            buttonTriangle: 255,
            buttonCircle: 0,
            buttonCross: 128,
            buttonSquare: 64,
            triggerR2: 100,
            triggerL2: 90,
            touch1: touch1,
            touch2: touch2,
            accelerometerX: 0.1,
            accelerometerY: -9.8,
            accelerometerZ: 0.0,
            gyroPitch: 1.5,
            gyroYaw: -0.5,
            gyroRoll: 2.0
        )

        let packet = DSUPacket.controllerData(clientUID: uid, data: ctrlData)
        let data = packet.encode()

        // Server magic for controller data responses
        #expect(Array(data[0..<4]) == DSUConstants.serverMagic)
        #expect(DSUCRC32.verify(data))

        let decoded = try #require(DSUPacket.decode(data))
        guard case .controllerData(let dUID, let dData) = decoded else {
            Issue.record("Expected .controllerData")
            return
        }

        #expect(dUID == uid)
        #expect(dData.slotIndex == ctrlData.slotIndex)
        #expect(dData.slotState == ctrlData.slotState)
        #expect(dData.deviceModel == ctrlData.deviceModel)
        #expect(dData.connectionType == ctrlData.connectionType)
        #expect(dData.macAddress == ctrlData.macAddress)
        #expect(dData.batteryStatus == ctrlData.batteryStatus)
        #expect(dData.isActive == ctrlData.isActive)
        #expect(dData.packetNumber == ctrlData.packetNumber)
        #expect(dData.buttons1 == ctrlData.buttons1)
        #expect(dData.buttons2 == ctrlData.buttons2)
        #expect(dData.psButton == ctrlData.psButton)
        #expect(dData.touchButton == ctrlData.touchButton)
        #expect(dData.leftStickX == ctrlData.leftStickX)
        #expect(dData.leftStickY == ctrlData.leftStickY)
        #expect(dData.rightStickX == ctrlData.rightStickX)
        #expect(dData.rightStickY == ctrlData.rightStickY)
        #expect(dData.dpadLeft == ctrlData.dpadLeft)
        #expect(dData.dpadDown == ctrlData.dpadDown)
        #expect(dData.dpadRight == ctrlData.dpadRight)
        #expect(dData.dpadUp == ctrlData.dpadUp)
        #expect(dData.buttonR1 == ctrlData.buttonR1)
        #expect(dData.buttonL1 == ctrlData.buttonL1)
        #expect(dData.buttonR2 == ctrlData.buttonR2)
        #expect(dData.buttonL2 == ctrlData.buttonL2)
        #expect(dData.buttonTriangle == ctrlData.buttonTriangle)
        #expect(dData.buttonCircle == ctrlData.buttonCircle)
        #expect(dData.buttonCross == ctrlData.buttonCross)
        #expect(dData.buttonSquare == ctrlData.buttonSquare)
        #expect(dData.triggerR2 == ctrlData.triggerR2)
        #expect(dData.triggerL2 == ctrlData.triggerL2)

        // Touch contacts
        #expect(dData.touch1.isActive == touch1.isActive)
        #expect(dData.touch1.id == touch1.id)
        #expect(dData.touch1.x == touch1.x)
        #expect(dData.touch1.y == touch1.y)
        #expect(dData.touch2.isActive == touch2.isActive)

        // Float comparison with tolerance for IEEE 754 round-trip
        #expect(abs(dData.accelerometerX - ctrlData.accelerometerX) < 1e-6)
        #expect(abs(dData.accelerometerY - ctrlData.accelerometerY) < 1e-6)
        #expect(abs(dData.accelerometerZ - ctrlData.accelerometerZ) < 1e-6)
        #expect(abs(dData.gyroPitch - ctrlData.gyroPitch) < 1e-6)
        #expect(abs(dData.gyroYaw - ctrlData.gyroYaw) < 1e-6)
        #expect(abs(dData.gyroRoll - ctrlData.gyroRoll) < 1e-6)
    }

    // MARK: - Payload length field

    @Test("Encoded VersionRequest data_length == 4 (messageType only, no extra payload)")
    func testVersionRequestPayloadLength() {
        let data = DSUPacket.versionRequest(clientUID: 0).encode()
        // data_length at bytes 6-7 = total_size - 16.
        // For a versionRequest with no extra payload: 20 - 16 = 4 (messageType field only).
        let dataLength = UInt16(data[6]) | (UInt16(data[7]) << 8)
        #expect(dataLength == 4)
        // Total size should be exactly the 20-byte header
        #expect(data.count == DSUHeader.size)
    }

    @Test("Encoded VersionResponse data_length == total - 16")
    func testVersionResponsePayloadLength() {
        let data = DSUPacket.versionResponse(clientUID: 0, version: DSUConstants.protocolVersion).encode()
        let dataLength = UInt16(data[6]) | (UInt16(data[7]) << 8)
        // data_length = total - 16
        #expect(Int(dataLength) == data.count - 16)
    }

    @Test("Encoded ControllerData data_length == total - 16")
    func testControllerDataPayloadLength() {
        let ctrlData = DSUControllerData()
        let data = DSUPacket.controllerData(clientUID: 0, data: ctrlData).encode()
        let dataLength = UInt16(data[6]) | (UInt16(data[7]) << 8)
        // data_length = total - 16
        #expect(Int(dataLength) == data.count - 16)
        // Sanity check: extra payload (after the 20-byte header) must be at least 74 bytes
        #expect(data.count - DSUHeader.size >= 74)
    }

    // MARK: - Decode failures

    @Test("Decode returns nil for too-short buffer")
    func testDecodeTooShort() {
        let data = Data([0x44, 0x53, 0x55, 0x43])
        #expect(DSUPacket.decode(data) == nil)
    }

    @Test("Decode returns nil for bad magic")
    func testDecodeBadMagic() {
        var data = DSUPacket.versionRequest(clientUID: 42).encode()
        // Corrupt the magic
        data[0] = 0xFF
        #expect(DSUPacket.decode(data) == nil)
    }

    @Test("Decode returns nil for bad CRC")
    func testDecodeBadCRC() {
        var data = DSUPacket.versionRequest(clientUID: 42).encode()
        // Corrupt a byte outside the CRC field to break the checksum
        data[19] ^= 0xFF
        #expect(DSUPacket.decode(data) == nil)
    }

    @Test("Decode returns nil for unknown message type")
    func testDecodeUnknownMessageType() throws {
        // Build a valid versionRequest then patch in an unknown msgType
        var data = DSUPacket.versionRequest(clientUID: 0).encode()
        // Overwrite message type (bytes 16-19) with an unrecognised value
        data[16] = 0xFF
        data[17] = 0xFF
        data[18] = 0xFF
        data[19] = 0xFF
        // Re-stamp CRC so the decode doesn't fail on CRC before hitting the switch
        DSUCRC32.stamp(into: &data)
        #expect(DSUPacket.decode(data) == nil)
    }

    @Test("ListPortsRequest with empty ports list round-trips to empty array")
    func testListPortsRequestEmptyPorts() throws {
        let uid: UInt32 = 0xDEAD0000
        let packet = DSUPacket.listPortsRequest(clientUID: uid, ports: [])
        let data = packet.encode()
        #expect(DSUCRC32.verify(data))

        let decoded = try #require(DSUPacket.decode(data))
        guard case .listPortsRequest(let decodedUID, let decodedPorts) = decoded else {
            Issue.record("Expected .listPortsRequest")
            return
        }
        #expect(decodedUID == uid)
        #expect(decodedPorts.isEmpty)
    }

    // MARK: - MAC address equality helper

    @Test("MAC address tuples compare correctly via custom equality")
    func testMACEquality() {
        let mac1: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (1, 2, 3, 4, 5, 6)
        let mac2: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (1, 2, 3, 4, 5, 6)
        let mac3: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (1, 2, 3, 4, 5, 7)
        #expect(mac1 == mac2)
        #expect(mac1 != mac3)
    }

    // MARK: - Truncated payload

    @Test("Decode returns nil for controllerData packet with truncated payload")
    func testControllerDataTruncatedPayload() {
        // Encode a valid controllerData packet then strip bytes from the end.
        let valid = DSUPacket.controllerData(clientUID: 0, data: DSUControllerData()).encode()
        // Keep only the header (20 bytes) — payload is completely missing.
        let truncated = valid.prefix(DSUHeader.size)
        #expect(DSUPacket.decode(Data(truncated)) == nil)
    }

    @Test("Decode returns nil for listPortsResponse with truncated payload")
    func testListPortsResponseTruncatedPayload() {
        let valid = DSUPacket.listPortsResponse(
            clientUID: 0, slotIndex: 0, slotState: .connected,
            deviceModel: .full, connectionType: .bluetooth,
            macAddress: (0, 0, 0, 0, 0, 0), batteryStatus: .full
        ).encode()
        // Strip all but the header — the 12-byte slot-info payload is gone.
        let truncated = valid.prefix(DSUHeader.size)
        #expect(DSUPacket.decode(Data(truncated)) == nil)
    }

    // MARK: - Decode from Data slice

    @Test("Decode works correctly when given a Data slice with non-zero startIndex")
    func testDecodeFromDataSlice() throws {
        // Prepend 8 junk bytes so that the real packet lives at a non-zero offset.
        let packet = DSUPacket.versionRequest(clientUID: 0xABCD1234)
        let raw = packet.encode()
        let prefixed = Data(repeating: 0xFF, count: 8) + raw
        let slice = prefixed[8...]   // Data slice: startIndex == 8

        let decoded = try #require(DSUPacket.decode(slice))
        guard case .versionRequest(let uid) = decoded else {
            Issue.record("Expected .versionRequest")
            return
        }
        #expect(uid == 0xABCD1234)
    }
}

// MARK: - Tuple equality helpers (Swift tuples are not Equatable by default in all contexts)

private func == (
    lhs: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
    rhs: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
) -> Bool {
    lhs.0 == rhs.0 && lhs.1 == rhs.1 && lhs.2 == rhs.2
        && lhs.3 == rhs.3 && lhs.4 == rhs.4 && lhs.5 == rhs.5
}

private func != (
    lhs: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
    rhs: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
) -> Bool {
    !(lhs == rhs)
}
