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

    /// Localized display name sourced from `Localizable.xcstrings`.
    public var displayName: String {
        switch self {
        case .ds3Driver:        return String(localized: "store.product.ds3.name")
        case .gamecubeAdapter:  return String(localized: "store.product.gamecube.name")
        case .steeringWheelPack: return String(localized: "store.product.steering_wheel.name")
        case .legacyHIDPack:    return String(localized: "store.product.legacy_hid.name")
        case .memoryCardPack:   return String(localized: "store.product.memory_card.name")
        case .allAccessBundle:  return String(localized: "store.product.all_access.name")
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

    /// Localized short description sourced from `Localizable.xcstrings`.
    public var localizedDescription: String {
        switch self {
        case .ds3Driver:        return String(localized: "store.product.ds3.description")
        case .gamecubeAdapter:  return String(localized: "store.product.gamecube.description")
        case .steeringWheelPack: return String(localized: "store.product.steering_wheel.description")
        case .legacyHIDPack:    return String(localized: "store.product.legacy_hid.description")
        case .memoryCardPack:   return String(localized: "store.product.memory_card.description")
        case .allAccessBundle:  return String(localized: "store.product.all_access.description")
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
