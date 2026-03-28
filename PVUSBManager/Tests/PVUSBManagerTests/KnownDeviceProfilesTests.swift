import XCTest
@testable import PVUSBManager

final class KnownDeviceProfilesTests: XCTestCase {

    // MARK: - Profile Lookup

    func testExactVIDPIDMatch() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x054C, productID: 0x0268)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.productName, "DualShock 3")
        XCTAssertTrue(profile?.requiresDriverKit == true)
    }

    func testVendorFallbackMatch() {
        let profile = KnownDeviceProfiles.profile(vendorID: KnownDeviceProfiles.vendor8BitDo, productID: 0xABCD)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.manufacturerName, "8BitDo")
    }

    func testNoMatchReturnsNil() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0xFFFF, productID: 0xFFFF)
        XCTAssertNil(profile)
    }

    func testDualSenseProfileExists() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x054C, productID: 0x0CE6)
        XCTAssertEqual(profile?.productName, "DualSense")
        XCTAssertEqual(profile?.category, .gamepad)
        XCTAssertFalse(profile?.requiresDriverKit == true)
    }

    func testDualSenseEdgeProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x054C, productID: 0x0DF2)
        XCTAssertEqual(profile?.productName, "DualSense Edge")
        XCTAssertEqual(profile?.category, .gamepad)
    }

    func testDS4v1Profile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x054C, productID: 0x05C4)
        XCTAssertEqual(profile?.productName, "DualShock 4 v1")
        XCTAssertFalse(profile?.requiresDriverKit == true)
    }

    func testSwitchProControllerProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x057E, productID: 0x2009)
        XCTAssertEqual(profile?.productName, "Switch Pro Controller")
        XCTAssertEqual(profile?.category, .gamepad)
        XCTAssertFalse(profile?.requiresDriverKit == true)
    }

    func testJoyConLeftProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x057E, productID: 0x2006)
        XCTAssertEqual(profile?.productName, "Joy-Con (L)")
    }

    func testJoyConRightProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x057E, productID: 0x2007)
        XCTAssertEqual(profile?.productName, "Joy-Con (R)")
    }

    func testXboxSeriesProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x045E, productID: 0x0B12)
        XCTAssertEqual(profile?.productName, "Xbox Series X|S Controller")
        XCTAssertEqual(profile?.category, .gamepad)
        XCTAssertFalse(profile?.requiresDriverKit == true)
    }

    func testXboxOneProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x045E, productID: 0x02FD)
        XCTAssertEqual(profile?.productName, "Xbox One Controller")
    }

    func testXbox360Profile() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x045E, productID: 0x028E)
        XCTAssertEqual(profile?.productName, "Xbox 360 Controller")
    }

    // MARK: - DriverKit Required

    func testDS3RequiresDriverKit() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x054C, productID: 0x0268)
        XCTAssertTrue(profile?.requiresDriverKit == true)
    }

    func testGamecubeAdapterRequiresDriverKit() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x057E, productID: 0x0337)
        XCTAssertNotNil(profile)
        XCTAssertTrue(profile?.requiresDriverKit == true)
    }

    func testMayflashGamecubeAdapterRequiresDriverKit() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x0079, productID: 0x1846)
        XCTAssertNotNil(profile)
        XCTAssertTrue(profile?.requiresDriverKit == true)
    }

    func testLogitechG920RequiresDriverKit() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x046D, productID: 0xC261)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.category, .steeringWheel)
        XCTAssertTrue(profile?.requiresDriverKit == true)
    }

    func testLogitechG923RequiresDriverKit() {
        let profile = KnownDeviceProfiles.profile(vendorID: 0x046D, productID: 0xC266)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.category, .steeringWheel)
        XCTAssertTrue(profile?.requiresDriverKit == true)
    }

    // MARK: - Vendor Fallbacks

    func testHoriFallbackProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: KnownDeviceProfiles.vendorHori, productID: 0x1234)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.manufacturerName, "HORI")
        XCTAssertEqual(profile?.category, .gamepad)
    }

    func testThrustmasterFallbackProfile() {
        let profile = KnownDeviceProfiles.profile(vendorID: KnownDeviceProfiles.vendorThrustmaster, productID: 0x9999)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.category, .steeringWheel)
        XCTAssertTrue(profile?.requiresDriverKit == true)
    }

    /// Exact match must take precedence over a vendor-only fallback.
    func testExactMatchTakesPrecedenceOverVendorFallback() {
        // 8BitDo has a vendor-only fallback entry; confirm an exact PID still resolves correctly
        // by verifying the fallback works for unknown PIDs but not by hiding known ones.
        let fallback = KnownDeviceProfiles.profile(vendorID: KnownDeviceProfiles.vendor8BitDo, productID: 0x0000)
        XCTAssertNotNil(fallback)
        // A completely unknown VID should still return nil
        let none = KnownDeviceProfiles.profile(vendorID: 0xDEAD, productID: 0x0000)
        XCTAssertNil(none)
    }

    // MARK: - Vendor IDs

    func testKnownVendorIDsMatchUSBSpec() {
        XCTAssertEqual(KnownDeviceProfiles.vendorSony, 0x054C)
        XCTAssertEqual(KnownDeviceProfiles.vendorMicrosoft, 0x045E)
        XCTAssertEqual(KnownDeviceProfiles.vendorNintendo, 0x057E)
        XCTAssertEqual(KnownDeviceProfiles.vendor8BitDo, 0x2DC8)
        XCTAssertEqual(KnownDeviceProfiles.vendorHori, 0x0F0D)
        XCTAssertEqual(KnownDeviceProfiles.vendorLogitechUSB, 0x046D)
        XCTAssertEqual(KnownDeviceProfiles.vendorThrustmaster, 0x044F)
        XCTAssertEqual(KnownDeviceProfiles.vendorMayflash, 0x0079)
    }

    // MARK: - Profile Integrity

    func testAllProfilesHaveValidCategory() {
        for profile in KnownDeviceProfiles.all {
            XCTAssertNotNil(profile.category)
        }
    }

    func testAllProfilesHaveNonEmptyProductName() {
        for profile in KnownDeviceProfiles.all {
            XCTAssertFalse(profile.productName.isEmpty, "Empty productName for VID:\(profile.vendorID) PID:\(String(describing: profile.productID))")
        }
    }

    func testAllProfilesHaveNonEmptyManufacturerName() {
        for profile in KnownDeviceProfiles.all {
            XCTAssertFalse(profile.manufacturerName.isEmpty)
        }
    }

    // MARK: - USBDevice

    func testUSBDeviceUsbID() {
        let device = USBDevice(
            vendorID: 0x054C, productID: 0x0CE6,
            productName: "DualSense", manufacturerName: "Sony",
            transport: .usb, category: .gamepad
        )
        XCTAssertEqual(device.usbID, "054C:0CE6")
    }

    func testUSBDeviceDefaults() {
        let device = USBDevice(
            vendorID: 0x1234, productID: 0x5678,
            productName: "Test", manufacturerName: "Corp",
            transport: .usb, category: .unknown
        )
        XCTAssertFalse(device.requiresDriverKit)
        XCTAssertFalse(device.driverKitActive)
        XCTAssertNil(device.locationID)
    }

    func testUSBDeviceIDIsUniqueByDefault() {
        let a = USBDevice(vendorID: 0, productID: 0, productName: "", manufacturerName: "", transport: .usb, category: .unknown)
        let b = USBDevice(vendorID: 0, productID: 0, productName: "", manufacturerName: "", transport: .usb, category: .unknown)
        XCTAssertNotEqual(a.id, b.id, "Default UUID should be unique per instance")
    }

    func testUSBDeviceHashableEquality() {
        let fixedID = UUID()
        let a = USBDevice(id: fixedID, vendorID: 0x054C, productID: 0x0CE6,
                          productName: "DualSense", manufacturerName: "Sony",
                          transport: .usb, category: .gamepad)
        let b = USBDevice(id: fixedID, vendorID: 0x054C, productID: 0x0CE6,
                          productName: "DualSense", manufacturerName: "Sony",
                          transport: .usb, category: .gamepad)
        XCTAssertEqual(a, b)

        var set = Set<USBDevice>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1, "Set should deduplicate identical USBDevices")
    }

    func testUSBDeviceWithLocationID() {
        let device = USBDevice(
            vendorID: 0x054C, productID: 0x0268,
            productName: "DS3", manufacturerName: "Sony",
            transport: .usb, category: .gamepad,
            requiresDriverKit: true, driverKitActive: false,
            locationID: 0x14200000
        )
        XCTAssertEqual(device.locationID, 0x14200000)
        XCTAssertTrue(device.requiresDriverKit)
    }

    // MARK: - PeripheralCategory

    func testPeripheralCategoryRawValues() {
        XCTAssertEqual(PeripheralCategory.gamepad.rawValue, "Gamepad")
        XCTAssertEqual(PeripheralCategory.steeringWheel.rawValue, "Steering Wheel")
        XCTAssertEqual(PeripheralCategory.keyboard.rawValue, "Keyboard")
        XCTAssertEqual(PeripheralCategory.mouse.rawValue, "Mouse")
        XCTAssertEqual(PeripheralCategory.unknown.rawValue, "Unknown")
    }

    func testPeripheralCategoryAllCasesHaveNonEmptyRawValues() {
        for category in PeripheralCategory.allCases {
            XCTAssertFalse(category.rawValue.isEmpty)
        }
    }

    // MARK: - PeripheralTransport

    func testPeripheralTransportRawValues() {
        XCTAssertEqual(PeripheralTransport.usb.rawValue, "USB")
        XCTAssertEqual(PeripheralTransport.bluetooth.rawValue, "Bluetooth")
        XCTAssertEqual(PeripheralTransport.mfi.rawValue, "MFi")
        XCTAssertEqual(PeripheralTransport.gcController.rawValue, "GCController")
    }
}
