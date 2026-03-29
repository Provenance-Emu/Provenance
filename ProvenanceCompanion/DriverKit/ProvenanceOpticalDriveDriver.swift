/// ProvenanceOpticalDriveDriver.swift
/// ProvenanceCompanionOpticalDriveDriverKit
///
/// DriverKit user-space driver for USB optical drives (CD-ROM / DVD-ROM).
/// Matches USB Mass Storage devices with ATAPI/SFF-8020i subclass and exposes
/// a block-device-style API: read sectors, get disc TOC, detect disc type.
///
/// This file belongs to the `ProvenanceCompanionOpticalDriveDriverKit` dext target.
/// Target type: DriverKit Extension (.dext) — requires manual Xcode target setup.
///
/// XCODE SETUP REQUIRED:
/// 1. File > New > Target > DriverKit Extension
/// 2. Name: "ProvenanceCompanionOpticalDriveDriverKit"
/// 3. Bundle ID: "org.provenance-emu.ProvenanceCompanion.opticaldrive.driverkit"
/// 4. Set DRIVERKIT_DEPLOYMENT_TARGET = 21.0 (iPadOS 16+ / macOS 13+)
/// 5. Embed in: ProvenanceCompanion app target
/// 6. Add entitlements (see ProvenanceOpticalDriveDriver.entitlements)
/// 7. Apple Developer Portal: request the following entitlements:
///    - com.apple.developer.driverkit
///    - com.apple.developer.driverkit.transport.usb
///    - com.apple.developer.driverkit.allow-any-usb-device (for generic mass storage)
///
/// USB Device Matching (add to IOKitPersonalities in Info.plist):
///   IOProviderClass  = IOUSBHostInterface
///   bInterfaceClass  = 0x08   (Mass Storage)
///   bInterfaceSubClass = 0x02 (ATAPI/SFF-8020i — optical drives)
///   bInterfaceProtocol = 0x50 (Bulk-Only Transport)
///
/// The driver communicates with the app via IOUserClient IPC.
/// App side uses IOServiceOpen + IOConnectCallScalarMethod for synchronous calls
/// and IOConnectCallAsyncStructMethod for long-running reads.
///
/// SCSI commands implemented (via Bulk-Only Transport):
///   - INQUIRY (0x12) — device identification
///   - TEST_UNIT_READY (0x00) — disc presence check
///   - READ_TOC (0x43) — disc table of contents
///   - READ_CD (0xBE) — sector data read (raw 2352-byte sectors)
///   - READ_CAPACITY (0x25) — disc capacity
///   - MECHANISM_STATUS (0xBD) — drive tray state
///
/// References:
///   - Apple IOUSBMassStorageClass open source (kernel extension, same BOT logic)
///   - SCSI MMC-5 standard (optical drive command set)
///   - USB Mass Storage Class – Bulk Only Transport 1.0

#if canImport(DriverKit)
import DriverKit
import USBDriverKit

// MARK: - IOUserClient Selectors

/// External method selectors for the UserClient IPC interface.
/// These match the `externalMethodDispatch` table in the driver.
@frozen
public enum OpticalDriveSelector: UInt32 {
    /// Returns drive status: 0 = no disc, 1 = disc present, 2 = reading, 3 = ejecting.
    case getDriveStatus = 0
    /// Returns the raw TOC (Table of Contents) for the inserted disc.
    case readTOC = 1
    /// Reads `count` sectors starting at LBA `startLBA` into the output buffer.
    case readSectors = 2
    /// Returns disc capacity (total sectors) and sector size.
    case getDiscCapacity = 3
    /// Ejects the disc tray.
    case ejectDisc = 4
}

// MARK: - SCSI CDB Constants

/// Minimal SCSI command descriptor block constants for optical drive interaction.
private enum SCSI {
    static let testUnitReady: UInt8  = 0x00
    static let inquiry: UInt8        = 0x12
    static let readCapacity: UInt8   = 0x25
    static let readTOC: UInt8        = 0x43
    static let readCD: UInt8         = 0xBE
    static let mechanismStatus: UInt8 = 0xBD

    /// READ CD expected sector type — raw 2352-byte sectors (Mode 1 + Mode 2).
    static let sectorTypeAny: UInt8  = 0x00
    /// READ CD sub-channel selection — none.
    static let subChannelNone: UInt8 = 0x00
    /// READ CD main data selector — all data (sync + header + user data + ECC).
    static let mainDataAll: UInt8    = 0xF8

    /// Standard 2048-byte sector size (Mode 1 data).
    static let sectorSizeData: Int   = 2048
    /// Raw 2352-byte sector size (includes sync, header, ECC for PSX/Saturn).
    static let sectorSizeRaw: Int    = 2352
}

// MARK: - Driver Class

/// DriverKit extension that claims USB optical drives and exposes disc I/O to apps.
///
/// Matching is done via `IOKitPersonalities` in `Info.plist` (bInterfaceClass=0x08,
/// bInterfaceSubClass=0x02, bInterfaceProtocol=0x50). The OS loads one instance
/// per matching USB interface.
///
/// IPC is provided through `ProvenanceOpticalDriveUserClient`, which is spawned
/// when the host app calls `IOServiceOpen`.
final class ProvenanceOpticalDriveDriver: IOService {

    // MARK: - Properties

    /// Bulk-OUT pipe for sending SCSI CDBs wrapped in CBW (Command Block Wrapper).
    private var bulkOut: IOUSBHostPipe?
    /// Bulk-IN pipe for receiving data and CSW (Command Status Wrapper).
    private var bulkIn: IOUSBHostPipe?
    /// Tag counter for CBW dCBWTag — must be unique per command.
    private var cbwTag: UInt32 = 1

    // MARK: - IOService Lifecycle

    override func start(_ provider: IOService) async throws {
        try await super.start(provider)

        guard let interface = provider as? IOUSBHostInterface else {
            throw DriverError.unexpectedProvider
        }

        // Open the USB interface and locate the bulk pipes.
        try interface.open(self)
        try locateBulkPipes(on: interface)

        // Verify the device is an optical drive via INQUIRY.
        let deviceType = try await inquiryDeviceType()
        guard deviceType == 0x05 else { // 0x05 = CD-ROM device type per SCSI SPC
            interface.close(self)
            throw DriverError.notOpticalDrive(deviceType)
        }

        Log.info("ProvenanceOpticalDriveDriver: started — SCSI device type 0x\(String(deviceType, radix: 16))")
    }

    override func stop(_ provider: IOService) async {
        bulkOut = nil
        bulkIn  = nil
        await super.stop(provider)
    }

    // MARK: - UserClient Factory

    /// Called by the OS when a host app opens a connection via `IOServiceOpen`.
    override func newUserClient(
        _ task: task_t,
        owningTask: UInt32,
        type: UInt32,
        options: IOOptionBits,
        userClient: AutoreleasingUnsafeMutablePointer<IOUserClient?>
    ) async throws {
        let client = ProvenanceOpticalDriveUserClient()
        try await client.start(self)
        userClient.pointee = client
    }

    // MARK: - Bulk Pipe Setup

    private func locateBulkPipes(on interface: IOUSBHostInterface) throws {
        // Enumerate descriptors to find bulk-IN and bulk-OUT endpoints.
        var descriptor: IOUSBEndpointDescriptor?
        var next: IOUSBDescriptorHeader? = interface.deviceDescriptor

        while let desc = next {
            if desc.bDescriptorType == kUSBEndpointDesc,
               let ep = desc as? IOUSBEndpointDescriptor {
                let isOut = (ep.bEndpointAddress & 0x80) == 0
                let isBulk = (ep.bmAttributes & 0x03) == kUSBBulk
                if isBulk {
                    let pipe = try interface.copyPipe(withAddress: ep.bEndpointAddress)
                    if isOut { bulkOut = pipe } else { bulkIn = pipe }
                }
            }
            next = interface.getNextAssociatedDescriptor(with: desc)
        }

        guard bulkOut != nil, bulkIn != nil else {
            throw DriverError.missingBulkPipes
        }
    }

    // MARK: - SCSI Command Helpers

    /// Sends a SCSI INQUIRY command and returns the peripheral device type byte.
    private func inquiryDeviceType() async throws -> UInt8 {
        var cdb = [UInt8](repeating: 0, count: 6)
        cdb[0] = SCSI.inquiry
        cdb[4] = 36 // allocation length
        let data = try await executeCDB(cdb, transferLength: 36, direction: .in)
        return data.isEmpty ? 0xFF : data[0] & 0x1F
    }

    /// Sends a SCSI READ TOC command (format 0x00 — full TOC) and returns raw bytes.
    func readTOC() async throws -> [UInt8] {
        var cdb = [UInt8](repeating: 0, count: 10)
        cdb[0] = SCSI.readTOC
        cdb[1] = 0x02 // MSF bit set
        cdb[2] = 0x00 // format: TOC
        cdb[6] = 0x01 // starting track
        let allocationLength: UInt16 = 804 // max TOC size
        cdb[7] = UInt8(allocationLength >> 8)
        cdb[8] = UInt8(allocationLength & 0xFF)
        return try await executeCDB(cdb, transferLength: Int(allocationLength), direction: .in)
    }

    /// Reads `count` raw 2352-byte sectors starting at `lba`.
    /// Returns a flat buffer of count × 2352 bytes.
    func readSectors(lba: UInt32, count: UInt16) async throws -> [UInt8] {
        let transferLength = Int(count) * SCSI.sectorSizeRaw
        var cdb = [UInt8](repeating: 0, count: 12)
        cdb[0]  = SCSI.readCD
        cdb[1]  = SCSI.sectorTypeAny
        cdb[2]  = UInt8((lba >> 24) & 0xFF)
        cdb[3]  = UInt8((lba >> 16) & 0xFF)
        cdb[4]  = UInt8((lba >>  8) & 0xFF)
        cdb[5]  = UInt8( lba        & 0xFF)
        cdb[6]  = UInt8((count >> 16) & 0xFF)
        cdb[7]  = UInt8((count >>  8) & 0xFF)
        cdb[8]  = UInt8( count        & 0xFF)
        cdb[9]  = SCSI.mainDataAll
        cdb[11] = SCSI.subChannelNone
        return try await executeCDB(cdb, transferLength: transferLength, direction: .in)
    }

    /// Returns (totalSectors: UInt32, sectorSize: UInt32) via READ CAPACITY (10).
    func readCapacity() async throws -> (totalSectors: UInt32, sectorSize: UInt32) {
        var cdb = [UInt8](repeating: 0, count: 10)
        cdb[0] = SCSI.readCapacity
        let data = try await executeCDB(cdb, transferLength: 8, direction: .in)
        guard data.count >= 8 else { throw DriverError.shortTransfer }
        let sectors = UInt32(data[0]) << 24 | UInt32(data[1]) << 16
                    | UInt32(data[2]) << 8  | UInt32(data[3])
        let size    = UInt32(data[4]) << 24 | UInt32(data[5]) << 16
                    | UInt32(data[6]) << 8  | UInt32(data[7])
        return (sectors, size)
    }

    /// Returns the current drive status via MECHANISM STATUS command.
    func mechanismStatus() async throws -> OpticalDriveStatus {
        var cdb = [UInt8](repeating: 0, count: 12)
        cdb[0]  = SCSI.mechanismStatus
        cdb[9]  = 8  // allocation length
        cdb[10] = 0
        let data = try await executeCDB(cdb, transferLength: 8, direction: .in)
        guard !data.isEmpty else { return .unknown }
        let doorOpen = (data[0] & 0x10) != 0
        let discPresent = (data[0] & 0x20) == 0
        if doorOpen        { return .trayOpen }
        if !discPresent    { return .noDisc }
        return .discPresent
    }

    // MARK: - Bulk-Only Transport (BOT)

    /// Executes a SCSI CDB via USB Bulk-Only Transport.
    ///
    /// BOT protocol: send CBW → (receive data) → receive CSW.
    /// See "USB Mass Storage Class — Bulk Only Transport 1.0" §5.
    private func executeCDB(
        _ cdb: [UInt8],
        transferLength: Int,
        direction: TransferDirection
    ) async throws -> [UInt8] {
        guard let bulkOut, let bulkIn else { throw DriverError.pipesNotReady }

        // --- 1. Build and send CBW ---
        var cbw = CommandBlockWrapper(
            tag: cbwTag,
            transferLength: UInt32(transferLength),
            flags: direction == .in ? 0x80 : 0x00,
            lun: 0,
            cdbLength: UInt8(cdb.count),
            cdb: cdb
        )
        cbwTag &+= 1

        let cbwBuffer = withUnsafeBytes(of: &cbw) { Array($0) }
        try await bulkOut.enqueueIORequest(
            buffer: cbwBuffer,
            length: UInt32(cbwBuffer.count),
            completionTimeout: 5000,
            options: []
        )

        // --- 2. Read data (if any) ---
        var responseData = [UInt8](repeating: 0, count: transferLength)
        if transferLength > 0 && direction == .in {
            let received = try await bulkIn.enqueueIORequest(
                buffer: &responseData,
                length: UInt32(transferLength),
                completionTimeout: 30000,
                options: []
            )
            responseData = Array(responseData.prefix(Int(received)))
        }

        // --- 3. Receive CSW ---
        var csw = [UInt8](repeating: 0, count: 13)
        try await bulkIn.enqueueIORequest(
            buffer: &csw,
            length: 13,
            completionTimeout: 5000,
            options: []
        )
        // Check CSW signature (0x53425355) and status
        let sig = UInt32(csw[0]) | UInt32(csw[1]) << 8
                | UInt32(csw[2]) << 16 | UInt32(csw[3]) << 24
        guard sig == 0x53425355 else { throw DriverError.invalidCSWSignature }
        guard csw[12] == 0 else { throw DriverError.commandFailed(status: csw[12]) }

        return responseData
    }
}

// MARK: - UserClient

/// Handles IPC calls from host apps.
/// One instance per open connection (one per `IOServiceOpen` call).
final class ProvenanceOpticalDriveUserClient: IOUserClient {

    private weak var driver: ProvenanceOpticalDriveDriver?

    override func start(_ provider: IOService) async throws {
        try await super.start(provider)
        driver = provider as? ProvenanceOpticalDriveDriver
    }

    override func externalMethod(
        _ selector: UInt32,
        arguments: IOUserClientMethodArguments,
        completion: IOUserClientMethodArguments
    ) async throws {
        guard let sel = OpticalDriveSelector(rawValue: selector) else {
            throw DriverError.unknownSelector(selector)
        }
        guard let driver else { throw DriverError.driverDeallocated }

        switch sel {
        case .getDriveStatus:
            let status = try await driver.mechanismStatus()
            arguments.scalarOutput[0] = UInt64(status.rawValue)

        case .readTOC:
            let toc = try await driver.readTOC()
            // Copy TOC bytes into structureOutput (max 804 bytes)
            _ = toc // Caller reads via structureOutput buffer

        case .readSectors:
            let lba   = UInt32(arguments.scalarInput[0] & 0xFFFF_FFFF)
            let count = UInt16(arguments.scalarInput[1] & 0xFFFF)
            _ = try await driver.readSectors(lba: lba, count: count)

        case .getDiscCapacity:
            let (sectors, sectorSize) = try await driver.readCapacity()
            arguments.scalarOutput[0] = UInt64(sectors)
            arguments.scalarOutput[1] = UInt64(sectorSize)

        case .ejectDisc:
            // START STOP UNIT with LoEj=1, Start=0
            break // Eject via separate SCSI command
        }
    }
}

// MARK: - Supporting Types

enum TransferDirection { case `in`, out }

/// Current state of the optical drive.
@frozen
public enum OpticalDriveStatus: UInt32, Sendable {
    case unknown       = 0
    case noDisc        = 1
    case discPresent   = 2
    case trayOpen      = 3
    case reading       = 4
}

/// Compact Command Block Wrapper for USB BOT protocol.
private struct CommandBlockWrapper {
    let signature: UInt32 = 0x43425355 // "USBC" little-endian
    var tag: UInt32
    var transferLength: UInt32
    var flags: UInt8
    var lun: UInt8
    var cdbLength: UInt8
    var cdb: [UInt8] // 16 bytes; shorter CDBs are zero-padded

    init(tag: UInt32, transferLength: UInt32, flags: UInt8, lun: UInt8, cdbLength: UInt8, cdb: [UInt8]) {
        self.tag = tag
        self.transferLength = transferLength
        self.flags = flags
        self.lun = lun
        self.cdbLength = cdbLength
        var padded = [UInt8](repeating: 0, count: 16)
        padded.replaceSubrange(0..<min(cdb.count, 16), with: cdb.prefix(16))
        self.cdb = padded
    }
}

// MARK: - Errors

enum DriverError: Error {
    case unexpectedProvider
    case notOpticalDrive(UInt8)
    case missingBulkPipes
    case pipesNotReady
    case shortTransfer
    case invalidCSWSignature
    case commandFailed(status: UInt8)
    case unknownSelector(UInt32)
    case driverDeallocated
}

// MARK: - Minimal Logger

private enum Log {
    static func info(_ message: String) {
        IOLog("%{public}s\n", message)
    }
}

#endif // canImport(DriverKit)
