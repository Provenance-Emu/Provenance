import XCTest
@testable import PVUSBManager

final class KnownDeviceProfilesTests: XCTestCase {

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

    func testUSBDeviceUsbID() {
        let device = USBDevice(
            vendorID: 0x054C, productID: 0x0CE6,
            productName: "DualSense", manufacturerName: "Sony",
            transport: .usb, category: .gamepad
        )
        XCTAssertEqual(device.usbID, "054C:0CE6")
    }

    func testAllProfilesHaveValidCategory() {
        for profile in KnownDeviceProfiles.all {
            XCTAssertNotNil(profile.category)
        }
    }
}
