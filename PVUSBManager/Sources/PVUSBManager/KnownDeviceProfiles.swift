import Foundation

/// Known USB/HID device entries used for VID:PID matching.
public struct DeviceProfile: Sendable {
    public let vendorID: Int
    /// nil matches any product from this vendor.
    public let productID: Int?
    public let manufacturerName: String
    public let productName: String
    public let category: PeripheralCategory
    /// True when the OS cannot use this device without a DriverKit extension.
    public let requiresDriverKit: Bool

    public init(
        vendorID: Int,
        productID: Int? = nil,
        manufacturerName: String,
        productName: String,
        category: PeripheralCategory,
        requiresDriverKit: Bool = false
    ) {
        self.vendorID = vendorID
        self.productID = productID
        self.manufacturerName = manufacturerName
        self.productName = productName
        self.category = category
        self.requiresDriverKit = requiresDriverKit
    }
}

/// Database of known gaming peripherals keyed by VID:PID.
public enum KnownDeviceProfiles {

    // MARK: - Vendor IDs

    public static let vendorSony: Int       = 0x054C
    public static let vendorMicrosoft: Int  = 0x045E
    public static let vendorNintendo: Int   = 0x057E
    public static let vendor8BitDo: Int     = 0x2DC8
    public static let vendorHori: Int       = 0x0F0D
    public static let vendorLogitechUSB: Int = 0x046D
    public static let vendorThrustmaster: Int = 0x044F
    public static let vendorMayflash: Int   = 0x0079

    // Optical drive vendors
    public static let vendorASUS: Int       = 0x0B05
    public static let vendorLG: Int         = 0x043E
    public static let vendorSamsung: Int    = 0x04E8
    public static let vendorPioneer: Int    = 0x08E4
    public static let vendorVerbatim: Int   = 0x08EC
    public static let vendorApple: Int      = 0x05AC // Apple SuperDrive
    public static let vendorOWC: Int        = 0x2B09

    // MARK: - Profiles

    public static let all: [DeviceProfile] = [
        // Sony DualShock 3 — requires DriverKit on iPadOS (not GCController-compatible)
        DeviceProfile(vendorID: vendorSony, productID: 0x0268,
                      manufacturerName: "Sony", productName: "DualShock 3",
                      category: .gamepad, requiresDriverKit: true),

        // Sony DualShock 4 variants
        DeviceProfile(vendorID: vendorSony, productID: 0x05C4,
                      manufacturerName: "Sony", productName: "DualShock 4 v1",
                      category: .gamepad),
        DeviceProfile(vendorID: vendorSony, productID: 0x09CC,
                      manufacturerName: "Sony", productName: "DualShock 4 v2",
                      category: .gamepad),

        // Sony DualSense
        DeviceProfile(vendorID: vendorSony, productID: 0x0CE6,
                      manufacturerName: "Sony", productName: "DualSense",
                      category: .gamepad),
        DeviceProfile(vendorID: vendorSony, productID: 0x0DF2,
                      manufacturerName: "Sony", productName: "DualSense Edge",
                      category: .gamepad),

        // Microsoft Xbox controllers
        DeviceProfile(vendorID: vendorMicrosoft, productID: 0x028E,
                      manufacturerName: "Microsoft", productName: "Xbox 360 Controller",
                      category: .gamepad),
        DeviceProfile(vendorID: vendorMicrosoft, productID: 0x02FD,
                      manufacturerName: "Microsoft", productName: "Xbox One Controller",
                      category: .gamepad),
        DeviceProfile(vendorID: vendorMicrosoft, productID: 0x0B12,
                      manufacturerName: "Microsoft", productName: "Xbox Series X|S Controller",
                      category: .gamepad),

        // Nintendo
        DeviceProfile(vendorID: vendorNintendo, productID: 0x2009,
                      manufacturerName: "Nintendo", productName: "Switch Pro Controller",
                      category: .gamepad),
        DeviceProfile(vendorID: vendorNintendo, productID: 0x2006,
                      manufacturerName: "Nintendo", productName: "Joy-Con (L)",
                      category: .gamepad),
        DeviceProfile(vendorID: vendorNintendo, productID: 0x2007,
                      manufacturerName: "Nintendo", productName: "Joy-Con (R)",
                      category: .gamepad),
        DeviceProfile(vendorID: vendorNintendo, productID: 0x0337,
                      manufacturerName: "Nintendo", productName: "GameCube Adapter",
                      category: .gamepad, requiresDriverKit: true),

        // 8BitDo
        DeviceProfile(vendorID: vendor8BitDo, productID: nil,
                      manufacturerName: "8BitDo", productName: "8BitDo Controller",
                      category: .gamepad),

        // Hori
        DeviceProfile(vendorID: vendorHori, productID: nil,
                      manufacturerName: "HORI", productName: "HORI Controller",
                      category: .gamepad),

        // Logitech driving wheels
        DeviceProfile(vendorID: vendorLogitechUSB, productID: 0xC261,
                      manufacturerName: "Logitech", productName: "G920 Driving Force",
                      category: .steeringWheel, requiresDriverKit: true),
        DeviceProfile(vendorID: vendorLogitechUSB, productID: 0xC266,
                      manufacturerName: "Logitech", productName: "G923 PS Edition",
                      category: .steeringWheel, requiresDriverKit: true),

        // Thrustmaster
        DeviceProfile(vendorID: vendorThrustmaster, productID: nil,
                      manufacturerName: "Thrustmaster", productName: "Thrustmaster Wheel",
                      category: .steeringWheel, requiresDriverKit: true),

        // Mayflash GameCube adapter
        DeviceProfile(vendorID: vendorMayflash, productID: 0x1846,
                      manufacturerName: "Mayflash", productName: "GameCube Adapter",
                      category: .gamepad, requiresDriverKit: true),

        // MARK: - USB Optical Drives
        // These devices use ATAPI/BOT (bInterfaceClass=0x08, bInterfaceSubClass=0x02)
        // and require the ProvenanceCompanionOpticalDriveDriverKit dext.

        DeviceProfile(vendorID: vendorApple, productID: 0x1500,
                      manufacturerName: "Apple", productName: "USB SuperDrive",
                      category: .opticalDrive, requiresDriverKit: true),

        DeviceProfile(vendorID: vendorASUS, productID: nil,
                      manufacturerName: "ASUS", productName: "ASUS USB DVD Drive",
                      category: .opticalDrive, requiresDriverKit: true),

        DeviceProfile(vendorID: vendorLG, productID: nil,
                      manufacturerName: "LG", productName: "LG USB DVD Drive",
                      category: .opticalDrive, requiresDriverKit: true),

        DeviceProfile(vendorID: vendorSamsung, productID: nil,
                      manufacturerName: "Samsung", productName: "Samsung USB DVD Drive",
                      category: .opticalDrive, requiresDriverKit: true),

        DeviceProfile(vendorID: vendorPioneer, productID: nil,
                      manufacturerName: "Pioneer", productName: "Pioneer USB DVD Drive",
                      category: .opticalDrive, requiresDriverKit: true),

        DeviceProfile(vendorID: vendorVerbatim, productID: nil,
                      manufacturerName: "Verbatim", productName: "Verbatim USB DVD Drive",
                      category: .opticalDrive, requiresDriverKit: true),

        DeviceProfile(vendorID: vendorOWC, productID: nil,
                      manufacturerName: "OWC", productName: "OWC USB DVD Drive",
                      category: .opticalDrive, requiresDriverKit: true),
    ]

    /// Returns the best matching profile for the given VID:PID.
    public static func profile(vendorID: Int, productID: Int) -> DeviceProfile? {
        // Exact match first
        if let exact = all.first(where: { $0.vendorID == vendorID && $0.productID == productID }) {
            return exact
        }
        // Vendor-only fallback
        return all.first(where: { $0.vendorID == vendorID && $0.productID == nil })
    }
}
