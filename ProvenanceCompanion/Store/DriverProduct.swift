import Foundation
import StoreKit

/// Purchasable driver packs available in the companion app.
///
/// Product identifiers must be registered in App Store Connect.
/// Each pack unlocks a DriverKit-backed device category.
///
/// Design note — "Reusable drivers":
/// A DriverKit extension is tied to the app that contains it, but once activated
/// by the user it becomes a system-level driver that ANY app can benefit from,
/// because the OS presents the device to all apps via GCController / IOHIDDevice.
/// Provenance's value proposition: we ship the extension, handle the IAP,
/// and other emulators/games get the device for free once activated.
public enum DriverProductID: String, CaseIterable, Sendable {
    /// DS3 / DirectInput USB HID driver pack.
    case ds3Driver              = "org.provenance-emu.companion.iap.driver.ds3"
    /// Nintendo GameCube USB Adapter driver pack.
    case gamecubeAdapter        = "org.provenance-emu.companion.iap.driver.gamecube"
    /// Steering wheel driver pack (G920, G923, T300RS, etc.).
    case steeringWheelPack      = "org.provenance-emu.companion.iap.driver.wheel"
    /// Legacy HID pack (generic DirectInput devices, old Fight Sticks).
    case legacyHIDPack          = "org.provenance-emu.companion.iap.driver.legacy-hid"
    /// Memory card / cartridge reader pack.
    case memoryCardPack         = "org.provenance-emu.companion.iap.driver.memcard"
    /// All-access bundle (all driver packs + future packs).
    case allAccessBundle        = "org.provenance-emu.companion.iap.bundle.all"

    public var displayName: String {
        switch self {
        case .ds3Driver:        return "DualShock 3 Driver"
        case .gamecubeAdapter:  return "GameCube Adapter Driver"
        case .steeringWheelPack: return "Steering Wheel Pack"
        case .legacyHIDPack:    return "Legacy HID Pack"
        case .memoryCardPack:   return "Memory Card Reader Pack"
        case .allAccessBundle:  return "All Drivers Bundle"
        }
    }

    public var systemImageName: String {
        switch self {
        case .ds3Driver:        return "gamecontroller"
        case .gamecubeAdapter:  return "gamecenter"
        case .steeringWheelPack: return "steeringwheel"
        case .legacyHIDPack:    return "cable.connector"
        case .memoryCardPack:   return "memorychip"
        case .allAccessBundle:  return "star.circle.fill"
        }
    }

    public var description: String {
        switch self {
        case .ds3Driver:
            return "Enables DualShock 3 controllers over USB on iPadOS. " +
                   "Works system-wide — other games and emulators benefit too."
        case .gamecubeAdapter:
            return "Official Nintendo and Mayflash GameCube USB adapters. " +
                   "Supports all 4 ports."
        case .steeringWheelPack:
            return "Logitech G920/G923, Thrustmaster T300RS, and compatible " +
                   "USB force-feedback wheels."
        case .legacyHIDPack:
            return "Generic DirectInput USB HID devices: arcade sticks, " +
                   "older flight sticks, and budget gamepads."
        case .memoryCardPack:
            return "Import and export saves via USB memory card readers. " +
                   "Supports GameShark/Max Drive adapters."
        case .allAccessBundle:
            return "All current driver packs plus any future drivers we ship. " +
                   "Best value."
        }
    }
}

/// A loaded StoreKit product with purchase state.
public struct DriverStoreProduct: Identifiable, Sendable {
    public let id: DriverProductID
    public let product: Product
    public var isPurchased: Bool

    public var displayPrice: String { product.displayPrice }
}
