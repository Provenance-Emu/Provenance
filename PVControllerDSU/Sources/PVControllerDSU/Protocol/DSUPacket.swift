/// DSU / CemuHook protocol packet types, encoding, and decoding.
///
/// Reference: https://v1993.github.io/cemuhook-protocol/
///
/// All multi-byte integers are little-endian unless noted otherwise.

import Foundation

// MARK: - Constants

/// DSU protocol constants.
public enum DSUConstants: Sendable {
    /// UDP port used by the DSU server.
    public static let defaultPort: UInt16 = 26760
    /// Protocol version carried in every packet header.
    public static let protocolVersion: UInt16 = 1001
    /// Magic bytes for server → client packets ("DSUS").
    public static let serverMagic: [UInt8] = [0x44, 0x53, 0x55, 0x53]
    /// Magic bytes for client → server packets ("DSUC").
    public static let clientMagic: [UInt8] = [0x44, 0x53, 0x55, 0x43]
    /// Bonjour/mDNS service type for the Provenance DSU server.
    public static let bonjourServiceType = "_provenance-dsu._udp."
}

// MARK: - Message Type

/// DSU message type identifiers.
public enum DSUMessageType: UInt32, Sendable, CaseIterable {
    case versionRequest  = 0x100001
    case listPorts       = 0x100002
    case padDataRequest  = 0x100003
}

// MARK: - Supporting types

/// Controller slot state.
public enum DSUSlotState: UInt8, Sendable {
    case notConnected = 0
    case reserved     = 1
    case connected    = 2
}

/// Device model class.
public enum DSUDeviceModel: UInt8, Sendable {
    case none    = 0
    case partial = 1
    case full    = 2
}

/// Physical connection type.
public enum DSUConnectionType: UInt8, Sendable {
    case none      = 0
    case usb       = 1
    case bluetooth = 2
}

/// Battery status byte.
public enum DSUBatteryStatus: UInt8, Sendable {
    case notApplicable = 0x00
    case dying         = 0x01
    case low           = 0x02
    case medium        = 0x03
    case high          = 0x04
    case full          = 0x05
    case charging      = 0xEE
    case charged       = 0xEF
}

/// A single touch contact point.
public struct DSUTouchContact: Sendable, Equatable {
    /// Whether this contact point is active.
    public var isActive: Bool
    /// Touch identifier (0-127).
    public var id: UInt8
    /// X coordinate (0-1920 typical range).
    public var x: UInt16
    /// Y coordinate (0-942 typical range).
    public var y: UInt16

    public init(isActive: Bool = false, id: UInt8 = 0, x: UInt16 = 0, y: UInt16 = 0) {
        self.isActive = isActive
        self.id = id
        self.x = x
        self.y = y
    }
}

// MARK: - DSU Header

/// The common 20-byte packet header.
///
/// Layout (all little-endian):
/// ```
/// Offset  Size  Field
///  0       4    Magic ("DSUS" or "DSUC")
///  4       2    Protocol version
///  6       2    Payload length (bytes after the header)
///  8       4    CRC32
/// 12       4    Client UID
/// 16       4    Message type
/// ```
public struct DSUHeader: Sendable, Equatable {
    public static let size = 20

    public var magic: [UInt8]          // 4 bytes
    public var protocolVersion: UInt16
    public var payloadLength: UInt16
    public var crc32: UInt32
    public var clientUID: UInt32
    public var messageType: UInt32

    public init(
        magic: [UInt8],
        protocolVersion: UInt16 = DSUConstants.protocolVersion,
        payloadLength: UInt16 = 0,
        crc32: UInt32 = 0,
        clientUID: UInt32 = 0,
        messageType: UInt32
    ) {
        self.magic = magic
        self.protocolVersion = protocolVersion
        self.payloadLength = payloadLength
        self.crc32 = crc32
        self.clientUID = clientUID
        self.messageType = messageType
    }
}

// MARK: - Controller data payload

/// Full controller state sent in a periodic PadData packet (message 0x100003).
public struct DSUControllerData: Sendable {
    // Slot info
    public var slotIndex: UInt8
    public var slotState: DSUSlotState
    public var deviceModel: DSUDeviceModel
    public var connectionType: DSUConnectionType
    /// 6-byte MAC address.
    public var macAddress: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    public var batteryStatus: DSUBatteryStatus
    public var isActive: Bool

    // Data stream
    public var packetNumber: UInt32

    // Digital buttons byte 1: [share, l3, r3, options, dpad_up, dpad_down, dpad_left, dpad_right]
    public var buttons1: UInt8
    // Digital buttons byte 2: [l1, r1, l2, r2, cross, circle, square, triangle]
    public var buttons2: UInt8
    /// PS/Home button (0 or 1).
    public var psButton: UInt8
    /// Touchpad click button (0 or 1).
    public var touchButton: UInt8

    // Analog sticks (0-255, center = 128)
    public var leftStickX: UInt8
    public var leftStickY: UInt8
    public var rightStickX: UInt8
    public var rightStickY: UInt8

    // Analog d-pad (0-255)
    public var dpadLeft: UInt8
    public var dpadDown: UInt8
    public var dpadRight: UInt8
    public var dpadUp: UInt8

    // Analog face/shoulder buttons (0-255)
    public var buttonR1: UInt8
    public var buttonL1: UInt8
    public var buttonR2: UInt8
    public var buttonL2: UInt8
    public var buttonTriangle: UInt8
    public var buttonCircle: UInt8
    public var buttonCross: UInt8
    public var buttonSquare: UInt8

    // Triggers (redundant but part of spec)
    public var triggerR2: UInt8
    public var triggerL2: UInt8

    // Touch contacts
    public var touch1: DSUTouchContact
    public var touch2: DSUTouchContact

    // Motion sensors (little-endian IEEE 754 float32)
    public var accelerometerX: Float
    public var accelerometerY: Float
    public var accelerometerZ: Float
    public var gyroPitch: Float
    public var gyroYaw: Float
    public var gyroRoll: Float

    public init(
        slotIndex: UInt8 = 0,
        slotState: DSUSlotState = .connected,
        deviceModel: DSUDeviceModel = .full,
        connectionType: DSUConnectionType = .bluetooth,
        macAddress: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0),
        batteryStatus: DSUBatteryStatus = .full,
        isActive: Bool = true,
        packetNumber: UInt32 = 0,
        buttons1: UInt8 = 0,
        buttons2: UInt8 = 0,
        psButton: UInt8 = 0,
        touchButton: UInt8 = 0,
        leftStickX: UInt8 = 128,
        leftStickY: UInt8 = 128,
        rightStickX: UInt8 = 128,
        rightStickY: UInt8 = 128,
        dpadLeft: UInt8 = 0,
        dpadDown: UInt8 = 0,
        dpadRight: UInt8 = 0,
        dpadUp: UInt8 = 0,
        buttonR1: UInt8 = 0,
        buttonL1: UInt8 = 0,
        buttonR2: UInt8 = 0,
        buttonL2: UInt8 = 0,
        buttonTriangle: UInt8 = 0,
        buttonCircle: UInt8 = 0,
        buttonCross: UInt8 = 0,
        buttonSquare: UInt8 = 0,
        triggerR2: UInt8 = 0,
        triggerL2: UInt8 = 0,
        touch1: DSUTouchContact = DSUTouchContact(),
        touch2: DSUTouchContact = DSUTouchContact(),
        accelerometerX: Float = 0,
        accelerometerY: Float = 0,
        accelerometerZ: Float = 0,
        gyroPitch: Float = 0,
        gyroYaw: Float = 0,
        gyroRoll: Float = 0
    ) {
        self.slotIndex = slotIndex
        self.slotState = slotState
        self.deviceModel = deviceModel
        self.connectionType = connectionType
        self.macAddress = macAddress
        self.batteryStatus = batteryStatus
        self.isActive = isActive
        self.packetNumber = packetNumber
        self.buttons1 = buttons1
        self.buttons2 = buttons2
        self.psButton = psButton
        self.touchButton = touchButton
        self.leftStickX = leftStickX
        self.leftStickY = leftStickY
        self.rightStickX = rightStickX
        self.rightStickY = rightStickY
        self.dpadLeft = dpadLeft
        self.dpadDown = dpadDown
        self.dpadRight = dpadRight
        self.dpadUp = dpadUp
        self.buttonR1 = buttonR1
        self.buttonL1 = buttonL1
        self.buttonR2 = buttonR2
        self.buttonL2 = buttonL2
        self.buttonTriangle = buttonTriangle
        self.buttonCircle = buttonCircle
        self.buttonCross = buttonCross
        self.buttonSquare = buttonSquare
        self.triggerR2 = triggerR2
        self.triggerL2 = triggerL2
        self.touch1 = touch1
        self.touch2 = touch2
        self.accelerometerX = accelerometerX
        self.accelerometerY = accelerometerY
        self.accelerometerZ = accelerometerZ
        self.gyroPitch = gyroPitch
        self.gyroYaw = gyroYaw
        self.gyroRoll = gyroRoll
    }
}

// MARK: - DSUControllerData Equatable
// Swift cannot synthesise Equatable for types with tuple-typed stored properties,
// so we provide the conformance manually.
extension DSUControllerData: Equatable {
    public static func == (lhs: DSUControllerData, rhs: DSUControllerData) -> Bool {
        lhs.slotIndex == rhs.slotIndex
            && lhs.slotState == rhs.slotState
            && lhs.deviceModel == rhs.deviceModel
            && lhs.connectionType == rhs.connectionType
            && lhs.macAddress.0 == rhs.macAddress.0
            && lhs.macAddress.1 == rhs.macAddress.1
            && lhs.macAddress.2 == rhs.macAddress.2
            && lhs.macAddress.3 == rhs.macAddress.3
            && lhs.macAddress.4 == rhs.macAddress.4
            && lhs.macAddress.5 == rhs.macAddress.5
            && lhs.batteryStatus == rhs.batteryStatus
            && lhs.isActive == rhs.isActive
            && lhs.packetNumber == rhs.packetNumber
            && lhs.buttons1 == rhs.buttons1
            && lhs.buttons2 == rhs.buttons2
            && lhs.psButton == rhs.psButton
            && lhs.touchButton == rhs.touchButton
            && lhs.leftStickX == rhs.leftStickX
            && lhs.leftStickY == rhs.leftStickY
            && lhs.rightStickX == rhs.rightStickX
            && lhs.rightStickY == rhs.rightStickY
            && lhs.dpadLeft == rhs.dpadLeft
            && lhs.dpadDown == rhs.dpadDown
            && lhs.dpadRight == rhs.dpadRight
            && lhs.dpadUp == rhs.dpadUp
            && lhs.buttonR1 == rhs.buttonR1
            && lhs.buttonL1 == rhs.buttonL1
            && lhs.buttonR2 == rhs.buttonR2
            && lhs.buttonL2 == rhs.buttonL2
            && lhs.buttonTriangle == rhs.buttonTriangle
            && lhs.buttonCircle == rhs.buttonCircle
            && lhs.buttonCross == rhs.buttonCross
            && lhs.buttonSquare == rhs.buttonSquare
            && lhs.triggerR2 == rhs.triggerR2
            && lhs.triggerL2 == rhs.triggerL2
            && lhs.touch1 == rhs.touch1
            && lhs.touch2 == rhs.touch2
            && lhs.accelerometerX == rhs.accelerometerX
            && lhs.accelerometerY == rhs.accelerometerY
            && lhs.accelerometerZ == rhs.accelerometerZ
            && lhs.gyroPitch == rhs.gyroPitch
            && lhs.gyroYaw == rhs.gyroYaw
            && lhs.gyroRoll == rhs.gyroRoll
    }
}

// MARK: - DSU Packet

/// A typed representation of a DSU protocol packet.
public enum DSUPacket: Sendable {

    // MARK: Client → Server

    /// Version information request (0x100001).
    case versionRequest(clientUID: UInt32)

    /// Request slot states for up to 4 controllers (0x100002).
    case listPortsRequest(clientUID: UInt32, ports: [UInt8])

    /// Subscribe to a pad's data stream (0x100003).
    /// `flags`: 0 = all slots, 1 = by slot index, 2 = by MAC address.
    case padDataRequest(clientUID: UInt32, flags: UInt8, slotIndex: UInt8, macAddress: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8))

    // MARK: Server → Client

    /// Version information response (0x100001).
    case versionResponse(clientUID: UInt32, version: UInt16)

    /// Slot state info response (0x100002).
    case listPortsResponse(clientUID: UInt32, slotIndex: UInt8, slotState: DSUSlotState, deviceModel: DSUDeviceModel, connectionType: DSUConnectionType, macAddress: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8), batteryStatus: DSUBatteryStatus)

    /// Controller data packet (0x100003).
    case controllerData(clientUID: UInt32, data: DSUControllerData)
}

// MARK: - Serialization

extension DSUPacket {

    /// Serialise this packet to a `Data` buffer with the CRC32 stamped.
    public func encode() -> Data {
        var buffer = Data()
        switch self {

        case .versionRequest(let uid):
            appendHeader(to: &buffer, magic: DSUConstants.clientMagic, uid: uid, type: DSUMessageType.versionRequest.rawValue, payloadLength: 0)

        case .listPortsRequest(let uid, let ports):
            // Payload: portCount (4 bytes LE) + up to 4 slot indices
            let count = min(ports.count, 4)
            var payload = Data()
            appendUInt32LE(UInt32(count), to: &payload)
            for i in 0..<count {
                payload.append(ports[i])
            }
            appendHeader(to: &buffer, magic: DSUConstants.clientMagic, uid: uid, type: DSUMessageType.listPorts.rawValue, payloadLength: UInt16(payload.count))
            buffer.append(payload)

        case .padDataRequest(let uid, let flags, let slotIndex, let mac):
            var payload = Data()
            payload.append(flags)
            payload.append(slotIndex)
            payload.append(mac.0)
            payload.append(mac.1)
            payload.append(mac.2)
            payload.append(mac.3)
            payload.append(mac.4)
            payload.append(mac.5)
            appendHeader(to: &buffer, magic: DSUConstants.clientMagic, uid: uid, type: DSUMessageType.padDataRequest.rawValue, payloadLength: UInt16(payload.count))
            buffer.append(payload)

        case .versionResponse(let uid, let version):
            var payload = Data()
            appendUInt16LE(version, to: &payload)
            appendHeader(to: &buffer, magic: DSUConstants.serverMagic, uid: uid, type: DSUMessageType.versionRequest.rawValue, payloadLength: UInt16(payload.count))
            buffer.append(payload)

        case .listPortsResponse(let uid, let slotIndex, let slotState, let deviceModel, let connectionType, let mac, let battery):
            var payload = Data()
            payload.append(slotIndex)
            payload.append(slotState.rawValue)
            payload.append(deviceModel.rawValue)
            payload.append(connectionType.rawValue)
            payload.append(mac.0)
            payload.append(mac.1)
            payload.append(mac.2)
            payload.append(mac.3)
            payload.append(mac.4)
            payload.append(mac.5)
            payload.append(battery.rawValue)
            // Terminator byte (0)
            payload.append(0)
            appendHeader(to: &buffer, magic: DSUConstants.serverMagic, uid: uid, type: DSUMessageType.listPorts.rawValue, payloadLength: UInt16(payload.count))
            buffer.append(payload)

        case .controllerData(let uid, let data):
            var payload = Data()
            encodeControllerData(data, into: &payload)
            appendHeader(to: &buffer, magic: DSUConstants.serverMagic, uid: uid, type: DSUMessageType.padDataRequest.rawValue, payloadLength: UInt16(payload.count))
            buffer.append(payload)
        }

        DSUCRC32.stamp(into: &buffer)
        return buffer
    }

    // MARK: - Decode

    /// Decode a `DSUPacket` from raw bytes.
    ///
    /// - Parameter data: The raw packet buffer.
    /// - Returns: The decoded packet, or `nil` if the buffer is malformed or the CRC is invalid.
    public static func decode(_ data: Data) -> DSUPacket? {
        guard data.count >= DSUHeader.size else { return nil }
        guard DSUCRC32.verify(data) else { return nil }

        let magic = Array(data[0..<4])
        let isServer = magic == DSUConstants.serverMagic
        let isClient = magic == DSUConstants.clientMagic
        guard isServer || isClient else { return nil }

        let msgType: UInt32 = readUInt32LE(data, offset: 16)
        let clientUID: UInt32 = readUInt32LE(data, offset: 12)
        let payload = data.dropFirst(DSUHeader.size)

        switch msgType {
        case DSUMessageType.versionRequest.rawValue:
            if isClient {
                return .versionRequest(clientUID: clientUID)
            } else {
                guard payload.count >= 2 else { return nil }
                let version: UInt16 = readUInt16LE(Data(payload), offset: 0)
                return .versionResponse(clientUID: clientUID, version: version)
            }

        case DSUMessageType.listPorts.rawValue:
            if isClient {
                guard payload.count >= 4 else { return nil }
                let count = Int(readUInt32LE(Data(payload), offset: 0))
                let available = min(count, payload.count - 4)
                let ports = (0..<available).map { payload[payload.startIndex + 4 + $0] }
                return .listPortsRequest(clientUID: clientUID, ports: ports)
            } else {
                guard payload.count >= 12 else { return nil }
                let p = Data(payload)
                let slotIdx = p[0]
                let slotState = DSUSlotState(rawValue: p[1]) ?? .notConnected
                let devModel = DSUDeviceModel(rawValue: p[2]) ?? .none
                let connType = DSUConnectionType(rawValue: p[3]) ?? .none
                let mac = (p[4], p[5], p[6], p[7], p[8], p[9])
                let battery = DSUBatteryStatus(rawValue: p[10]) ?? .notApplicable
                return .listPortsResponse(clientUID: clientUID, slotIndex: slotIdx, slotState: slotState, deviceModel: devModel, connectionType: connType, macAddress: mac, batteryStatus: battery)
            }

        case DSUMessageType.padDataRequest.rawValue:
            if isClient {
                guard payload.count >= 8 else { return nil }
                let p = Data(payload)
                let flags = p[0]
                let slotIdx = p[1]
                let mac = (p[2], p[3], p[4], p[5], p[6], p[7])
                return .padDataRequest(clientUID: clientUID, flags: flags, slotIndex: slotIdx, macAddress: mac)
            } else {
                guard let ctrlData = decodeControllerData(Data(payload)) else { return nil }
                return .controllerData(clientUID: clientUID, data: ctrlData)
            }

        default:
            return nil
        }
    }
}

// MARK: - Private helpers

private func appendHeader(to buffer: inout Data, magic: [UInt8], uid: UInt32, type msgType: UInt32, payloadLength: UInt16) {
    buffer.append(contentsOf: magic)
    appendUInt16LE(DSUConstants.protocolVersion, to: &buffer)
    appendUInt16LE(payloadLength, to: &buffer)
    appendUInt32LE(0, to: &buffer) // CRC placeholder
    appendUInt32LE(uid, to: &buffer)
    appendUInt32LE(msgType, to: &buffer)
}

private func appendUInt16LE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
}

private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8)  & 0xFF))
    data.append(UInt8((value >> 16) & 0xFF))
    data.append(UInt8((value >> 24) & 0xFF))
}

private func appendFloat32LE(_ value: Float, to data: inout Data) {
    let bits = value.bitPattern
    data.append(UInt8(bits & 0xFF))
    data.append(UInt8((bits >> 8)  & 0xFF))
    data.append(UInt8((bits >> 16) & 0xFF))
    data.append(UInt8((bits >> 24) & 0xFF))
}

private func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
    guard data.count >= offset + 2 else { return 0 }
    let base = data.startIndex + offset
    return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
}

private func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
    guard data.count >= offset + 4 else { return 0 }
    let base = data.startIndex + offset
    return UInt32(data[base])
        | (UInt32(data[base + 1]) << 8)
        | (UInt32(data[base + 2]) << 16)
        | (UInt32(data[base + 3]) << 24)
}

private func readFloat32LE(_ data: Data, offset: Int) -> Float {
    let bits = readUInt32LE(data, offset: offset)
    return Float(bitPattern: bits)
}

private func encodeTouchContact(_ contact: DSUTouchContact, into data: inout Data) {
    data.append(contact.isActive ? 1 : 0)
    data.append(contact.id)
    appendUInt16LE(contact.x, to: &data)
    appendUInt16LE(contact.y, to: &data)
}

private func decodeTouchContact(_ data: Data, offset: Int) -> DSUTouchContact? {
    guard data.count >= offset + 6 else { return nil }
    let base = data.startIndex + offset
    let isActive = data[base] != 0
    let id = data[base + 1]
    let x: UInt16 = UInt16(data[base + 2]) | (UInt16(data[base + 3]) << 8)
    let y: UInt16 = UInt16(data[base + 4]) | (UInt16(data[base + 5]) << 8)
    return DSUTouchContact(isActive: isActive, id: id, x: x, y: y)
}

private func encodeControllerData(_ d: DSUControllerData, into data: inout Data) {
    // Slot info (11 bytes)
    data.append(d.slotIndex)
    data.append(d.slotState.rawValue)
    data.append(d.deviceModel.rawValue)
    data.append(d.connectionType.rawValue)
    data.append(d.macAddress.0)
    data.append(d.macAddress.1)
    data.append(d.macAddress.2)
    data.append(d.macAddress.3)
    data.append(d.macAddress.4)
    data.append(d.macAddress.5)
    data.append(d.batteryStatus.rawValue)
    // Active flag (1 byte)
    data.append(d.isActive ? 1 : 0)
    // Packet number (4 bytes LE)
    appendUInt32LE(d.packetNumber, to: &data)
    // Button bytes
    data.append(d.buttons1)
    data.append(d.buttons2)
    data.append(d.psButton)
    data.append(d.touchButton)
    // Analog sticks
    data.append(d.leftStickX)
    data.append(d.leftStickY)
    data.append(d.rightStickX)
    data.append(d.rightStickY)
    // Analog dpad
    data.append(d.dpadLeft)
    data.append(d.dpadDown)
    data.append(d.dpadRight)
    data.append(d.dpadUp)
    // Analog face/shoulder
    data.append(d.buttonR1)
    data.append(d.buttonL1)
    data.append(d.buttonR2)
    data.append(d.buttonL2)
    data.append(d.buttonTriangle)
    data.append(d.buttonCircle)
    data.append(d.buttonCross)
    data.append(d.buttonSquare)
    // Triggers (redundant copy)
    data.append(d.triggerR2)
    data.append(d.triggerL2)
    // Touch contacts
    encodeTouchContact(d.touch1, into: &data)
    encodeTouchContact(d.touch2, into: &data)
    // Motion
    appendFloat32LE(d.accelerometerX, to: &data)
    appendFloat32LE(d.accelerometerY, to: &data)
    appendFloat32LE(d.accelerometerZ, to: &data)
    appendFloat32LE(d.gyroPitch, to: &data)
    appendFloat32LE(d.gyroYaw, to: &data)
    appendFloat32LE(d.gyroRoll, to: &data)
}

/// Minimum expected payload size for a controller data packet.
/// 11 (slot info) + 1 (active) + 4 (packetNum) + 4 (buttons) + 4 (sticks)
/// + 4 (dpad) + 8 (face/shoulder) + 2 (triggers) + 12 (touches) + 24 (motion) = 74
private let minControllerPayloadSize = 74

private func decodeControllerData(_ data: Data) -> DSUControllerData? {
    guard data.count >= minControllerPayloadSize else { return nil }

    var offset = 0

    func readByte() -> UInt8 {
        defer { offset += 1 }
        return data[data.startIndex + offset]
    }

    func readUInt32() -> UInt32 {
        defer { offset += 4 }
        return readUInt32LE(data, offset: offset)
    }

    func readFloat() -> Float {
        defer { offset += 4 }
        return readFloat32LE(data, offset: offset)
    }

    let slotIndex = readByte()
    let slotState = DSUSlotState(rawValue: readByte()) ?? .notConnected
    let deviceModel = DSUDeviceModel(rawValue: readByte()) ?? .none
    let connectionType = DSUConnectionType(rawValue: readByte()) ?? .none
    let mac = (readByte(), readByte(), readByte(), readByte(), readByte(), readByte())
    let battery = DSUBatteryStatus(rawValue: readByte()) ?? .notApplicable
    let isActive = readByte() != 0
    let packetNumber = readUInt32()

    let buttons1 = readByte()
    let buttons2 = readByte()
    let psButton = readByte()
    let touchButton = readByte()

    let leftStickX = readByte()
    let leftStickY = readByte()
    let rightStickX = readByte()
    let rightStickY = readByte()

    let dpadLeft = readByte()
    let dpadDown = readByte()
    let dpadRight = readByte()
    let dpadUp = readByte()

    let buttonR1 = readByte()
    let buttonL1 = readByte()
    let buttonR2 = readByte()
    let buttonL2 = readByte()
    let buttonTriangle = readByte()
    let buttonCircle = readByte()
    let buttonCross = readByte()
    let buttonSquare = readByte()

    let triggerR2 = readByte()
    let triggerL2 = readByte()

    guard let touch1 = decodeTouchContact(data, offset: offset) else { return nil }
    offset += 6
    guard let touch2 = decodeTouchContact(data, offset: offset) else { return nil }
    offset += 6

    let accelX = readFloat()
    let accelY = readFloat()
    let accelZ = readFloat()
    let gyroPitch = readFloat()
    let gyroYaw = readFloat()
    let gyroRoll = readFloat()

    return DSUControllerData(
        slotIndex: slotIndex,
        slotState: slotState,
        deviceModel: deviceModel,
        connectionType: connectionType,
        macAddress: mac,
        batteryStatus: battery,
        isActive: isActive,
        packetNumber: packetNumber,
        buttons1: buttons1,
        buttons2: buttons2,
        psButton: psButton,
        touchButton: touchButton,
        leftStickX: leftStickX,
        leftStickY: leftStickY,
        rightStickX: rightStickX,
        rightStickY: rightStickY,
        dpadLeft: dpadLeft,
        dpadDown: dpadDown,
        dpadRight: dpadRight,
        dpadUp: dpadUp,
        buttonR1: buttonR1,
        buttonL1: buttonL1,
        buttonR2: buttonR2,
        buttonL2: buttonL2,
        buttonTriangle: buttonTriangle,
        buttonCircle: buttonCircle,
        buttonCross: buttonCross,
        buttonSquare: buttonSquare,
        triggerR2: triggerR2,
        triggerL2: triggerL2,
        touch1: touch1,
        touch2: touch2,
        accelerometerX: accelX,
        accelerometerY: accelY,
        accelerometerZ: accelZ,
        gyroPitch: gyroPitch,
        gyroYaw: gyroYaw,
        gyroRoll: gyroRoll
    )
}
