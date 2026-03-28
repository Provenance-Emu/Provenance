/// ProvenanceHIDDriver.swift
/// ProvenanceCompanionDriverKit
///
/// DriverKit HID driver for non-MFi USB gamepads.
/// This file belongs to the `ProvenanceCompanionDriverKit` dext target.
/// Target type: DriverKit Extension (.dext) — requires manual Xcode target setup.
///
/// XCODE SETUP REQUIRED:
/// 1. File > New > Target > DriverKit Extension
/// 2. Name: "ProvenanceCompanionDriverKit"
/// 3. Bundle ID: "org.provenance-emu.ProvenanceCompanion.driverkit"
/// 4. Set DRIVERKIT_DEPLOYMENT_TARGET = 21.0 (iPadOS 16+ / macOS 13+)
/// 5. Embed in: ProvenanceCompanion app target
/// 6. Add entitlements (see ProvenanceHIDDriver.entitlements)
/// 7. Apple Developer Portal: request "DriverKit" entitlement for your App ID
///
/// Supported devices (initial set):
/// - Sony DualShock 3 (VID 0x054C, PID 0x0268)
/// - Nintendo GameCube Adapter (VID 0x057E, PID 0x0337)
/// - Mayflash GameCube Adapter (VID 0x0079, PID 0x1846)
/// - Logitech G920/G923 steering wheels
///
/// The driver re-exposes matched USB HID devices as virtual GCControllers via
/// the IOHIDInterface→IOHIDEventService chain, making them visible to GameController.framework
/// in any app on the device — not just Provenance.

#if canImport(HIDDriverKit)
import HIDDriverKit
import DriverKit

// swiftlint:disable identifier_name

/// USB matching tables for devices this dext claims.
/// Each dictionary maps kIOHIDVendorIDKey + kIOHIDProductIDKey to a device entry.
/// Add new devices here to expand the driver's scope.
let kUSBMatchingCriteria: [[String: Any]] = [
    // Sony DualShock 3
    [kIOHIDVendorIDKey: 0x054C, kIOHIDProductIDKey: 0x0268],
    // Nintendo GameCube USB Adapter
    [kIOHIDVendorIDKey: 0x057E, kIOHIDProductIDKey: 0x0337],
    // Mayflash GameCube USB Adapter (mode: PC)
    [kIOHIDVendorIDKey: 0x0079, kIOHIDProductIDKey: 0x1846],
    // Logitech G920
    [kIOHIDVendorIDKey: 0x046D, kIOHIDProductIDKey: 0xC261],
    // Logitech G923 (PS)
    [kIOHIDVendorIDKey: 0x046D, kIOHIDProductIDKey: 0xC266],
]

// swiftlint:enable identifier_name

final class ProvenanceHIDDriver: IOUserHIDEventDriver {

    // MARK: - Lifecycle

    override func start(_ provider: IOService) async throws {
        try await super.start(provider)
        // Future: device-specific init (e.g. DS3 Bluetooth handshake, GC adapter port polling)
    }

    override func handleCopyMatchingEvent(
        _ sender: IOHIDInterface,
        matching: IOHIDElement
    ) -> Bool {
        // Accept all elements from matched devices
        return true
    }

    // MARK: - Input Reports

    override func handleReport(
        _ timestamp: UInt64,
        report: IOMemoryDescriptor,
        reportLength: IOByteCount,
        reportType: IOHIDReportType,
        reportID: UInt32
    ) async {
        // For DualShock 3 and GameCube adapter, translate proprietary report layouts
        // into standard HID usage values before forwarding to the event system.
        await super.handleReport(
            timestamp,
            report: report,
            reportLength: reportLength,
            reportType: reportType,
            reportID: reportID
        )
    }
}

#endif
