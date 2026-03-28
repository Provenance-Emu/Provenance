import Foundation

/// Category of a connected USB/HID peripheral.
public enum PeripheralCategory: String, Sendable, CaseIterable {
    case gamepad        = "Gamepad"
    case lightGun       = "Light Gun"
    case steeringWheel  = "Steering Wheel"
    case flightStick    = "Flight Stick"
    case mouse          = "Mouse"
    case keyboard       = "Keyboard"
    case memoryCard     = "Memory Card Reader"
    case cartridgeReader = "Cartridge Reader"
    case massStorage    = "Mass Storage"
    case serialAdapter  = "Serial Adapter"
    case unknown        = "Unknown"
}

/// Connection transport for a peripheral.
public enum PeripheralTransport: String, Sendable {
    case usb        = "USB"
    case bluetooth  = "Bluetooth"
    case mfi        = "MFi"
    case gcController = "GCController"
}

/// Represents a discovered USB/HID peripheral.
public struct USBDevice: Identifiable, Sendable, Hashable {
    /// Unique identifier for this session.
    public let id: UUID
    /// USB Vendor ID (e.g. 0x054C for Sony).
    public let vendorID: Int
    /// USB Product ID.
    public let productID: Int
    /// Human-readable product name from the device descriptor.
    public let productName: String
    /// Manufacturer string from the device descriptor.
    public let manufacturerName: String
    /// Transport layer.
    public let transport: PeripheralTransport
    /// Inferred category based on HID usage page / VID:PID matching.
    public let category: PeripheralCategory
    /// Whether the device requires a DriverKit extension to function fully.
    public let requiresDriverKit: Bool
    /// Whether a DriverKit driver is currently active for this device.
    public var driverKitActive: Bool
    /// Device location ID for IOKit (nil for non-IOKit sources).
    public let locationID: UInt32?

    public init(
        id: UUID = UUID(),
        vendorID: Int,
        productID: Int,
        productName: String,
        manufacturerName: String,
        transport: PeripheralTransport,
        category: PeripheralCategory,
        requiresDriverKit: Bool = false,
        driverKitActive: Bool = false,
        locationID: UInt32? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.productID = productID
        self.productName = productName
        self.manufacturerName = manufacturerName
        self.transport = transport
        self.category = category
        self.requiresDriverKit = requiresDriverKit
        self.driverKitActive = driverKitActive
        self.locationID = locationID
    }

    /// Formatted "VID:PID" string for display.
    public var usbID: String { String(format: "%04X:%04X", vendorID, productID) }
}
