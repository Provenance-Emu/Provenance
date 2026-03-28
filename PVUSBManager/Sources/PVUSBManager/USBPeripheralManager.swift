// USBPeripheralManager is only functional on Apple platforms.
// The guard ensures the package compiles on Linux for CI test runs of
// KnownDeviceProfiles / USBDevice without requiring unavailable frameworks.
#if canImport(GameController)

import Foundation
import GameController

#if !os(tvOS)
import ExternalAccessory
#endif

#if canImport(IOKit)
import IOKit
import IOKit.hid
#endif

/// Delegate for peripheral connect/disconnect events.
public protocol USBPeripheralManagerDelegate: AnyObject, Sendable {
    func peripheralManager(_ manager: USBPeripheralManager, didConnect device: USBDevice)
    func peripheralManager(_ manager: USBPeripheralManager, didDisconnect device: USBDevice)
}

/// Central manager for USB/HID peripheral discovery across all available transport layers.
///
/// On iPadOS without DriverKit, enumeration uses:
/// - `IOHIDManager` for raw HID devices (macOS / Catalyst)
/// - `GCController` for recognised gaming controllers
/// - `EAAccessoryManager` for MFi accessories (iOS / macOS only, not tvOS)
///
/// With a DriverKit extension active, the manager additionally surfaces devices that
/// the OS dext has claimed, identified via `USBDevice.driverKitActive == true`.
@MainActor
@Observable
public final class USBPeripheralManager: NSObject {

    // MARK: - Public State

    /// Currently connected peripherals.
    public private(set) var connectedDevices: [USBDevice] = []

    public weak var delegate: (any USBPeripheralManagerDelegate)?

    // MARK: - Private

    private var gcObservers: [Any] = []

    #if canImport(IOKit)
    private var hidManager: IOHIDManager?
    #endif

    // MARK: - Lifecycle

    public override init() {
        super.init()
    }

    deinit {
        stopScanning()
    }

    // MARK: - Public API

    /// Begin scanning for connected peripherals.
    public func startScanning() {
        registerGCControllerObservers()
        #if canImport(IOKit)
        startHIDManager()
        #endif
        #if !os(tvOS)
        registerEAObservers()
        #endif
        // Snapshot already-connected controllers.
        for controller in GCController.controllers() {
            addGCController(controller)
        }
    }

    /// Stop scanning and release all observers.
    public func stopScanning() {
        for ob in gcObservers { NotificationCenter.default.removeObserver(ob) }
        gcObservers = []
        #if canImport(IOKit)
        if let m = hidManager {
            IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }
        #endif
    }

    /// Marks a device as having an active DriverKit extension.
    public func markDriverKitActive(vendorID: Int, productID: Int) {
        guard let idx = connectedDevices.firstIndex(where: {
            $0.vendorID == vendorID && $0.productID == productID
        }) else { return }
        connectedDevices[idx].driverKitActive = true
    }

    // MARK: - GCController

    private func registerGCControllerObservers() {
        let nc = NotificationCenter.default
        gcObservers.append(nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.addGCController(controller)
        })
        gcObservers.append(nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.removeGCController(controller)
        })
    }

    private func addGCController(_ controller: GCController) {
        let (vid, pid) = gcControllerVIDPID(controller)
        let profile = KnownDeviceProfiles.profile(vendorID: vid, productID: pid)
        let device = USBDevice(
            vendorID: vid,
            productID: pid,
            productName: controller.vendorName ?? profile?.productName ?? "Controller",
            manufacturerName: profile?.manufacturerName ?? "Unknown",
            transport: .gcController,
            category: profile?.category ?? .gamepad,
            requiresDriverKit: false,
            driverKitActive: false
        )
        guard !connectedDevices.contains(device) else { return }
        connectedDevices.append(device)
        delegate?.peripheralManager(self, didConnect: device)
    }

    private func removeGCController(_ controller: GCController) {
        let (vid, pid) = gcControllerVIDPID(controller)
        guard let idx = connectedDevices.firstIndex(where: {
            $0.vendorID == vid && $0.productID == pid && $0.transport == .gcController
        }) else { return }
        let device = connectedDevices.remove(at: idx)
        delegate?.peripheralManager(self, didDisconnect: device)
    }

    private func gcControllerVIDPID(_ controller: GCController) -> (Int, Int) {
        // GCController doesn't expose VID/PID directly — best-effort match on vendor name.
        let name = controller.vendorName?.lowercased() ?? ""
        switch true {
        case name.contains("dualshock 4") || name.contains("dual shock 4"):
            return (KnownDeviceProfiles.vendorSony, 0x09CC)
        case name.contains("dualsense"):
            return (KnownDeviceProfiles.vendorSony, 0x0CE6)
        case name.contains("xbox") && name.contains("series"):
            return (KnownDeviceProfiles.vendorMicrosoft, 0x0B12)
        case name.contains("xbox"):
            return (KnownDeviceProfiles.vendorMicrosoft, 0x02FD)
        case name.contains("pro controller") || name.contains("nintendo"):
            return (KnownDeviceProfiles.vendorNintendo, 0x2009)
        case name.contains("8bitdo"):
            return (KnownDeviceProfiles.vendor8BitDo, 0x0000)
        default:
            return (0x0000, 0x0000)
        }
    }

    // MARK: - IOHIDManager (macOS / Catalyst)

    #if canImport(IOKit)
    private func startHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Match all HID devices
        IOHIDManagerSetDeviceMatching(manager, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, hidDeviceAdded, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(manager, hidDeviceRemoved, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager
    }
    #endif

    // MARK: - ExternalAccessory (iOS / macOS only — not available on tvOS)

    #if !os(tvOS)
    private func registerEAObservers() {
        let nc = NotificationCenter.default
        gcObservers.append(nc.addObserver(
            forName: .EAAccessoryDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let accessory = note.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
            self?.addEAAccessory(accessory)
        })
        gcObservers.append(nc.addObserver(
            forName: .EAAccessoryDidDisconnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let accessory = note.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
            self?.removeEAAccessory(accessory)
        })
        EAAccessoryManager.shared().registerForLocalNotifications()
        for accessory in EAAccessoryManager.shared().connectedAccessories {
            addEAAccessory(accessory)
        }
    }

    private func addEAAccessory(_ accessory: EAAccessory) {
        let device = USBDevice(
            vendorID: Int(accessory.connectionID),
            productID: 0,
            productName: accessory.name,
            manufacturerName: accessory.manufacturer,
            transport: .mfi,
            category: .gamepad
        )
        guard !connectedDevices.contains(device) else { return }
        connectedDevices.append(device)
        delegate?.peripheralManager(self, didConnect: device)
    }

    private func removeEAAccessory(_ accessory: EAAccessory) {
        guard let idx = connectedDevices.firstIndex(where: {
            $0.transport == .mfi && $0.vendorID == Int(accessory.connectionID)
        }) else { return }
        let device = connectedDevices.remove(at: idx)
        delegate?.peripheralManager(self, didDisconnect: device)
    }
    #endif
}

// MARK: - IOHIDManager C Callbacks

#if canImport(IOKit)
private func hidDeviceAdded(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let ctx = context else { return }
    let manager = Unmanaged<USBPeripheralManager>.fromOpaque(ctx).takeUnretainedValue()

    func intProp(_ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
    }
    func strProp(_ key: String) -> String {
        (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? ""
    }

    let vid = intProp(kIOHIDVendorIDKey)
    let pid = intProp(kIOHIDProductIDKey)
    let productName = strProp(kIOHIDProductKey)
    let manufacturer = strProp(kIOHIDManufacturerKey)
    let locationID = UInt32(intProp(kIOHIDLocationIDKey))

    let profile = KnownDeviceProfiles.profile(vendorID: vid, productID: pid)
    let category = inferCategory(usagePage: intProp(kIOHIDPrimaryUsagePageKey),
                                 usage: intProp(kIOHIDPrimaryUsageKey),
                                 profile: profile)

    let usbDevice = USBDevice(
        vendorID: vid,
        productID: pid,
        productName: productName.isEmpty ? (profile?.productName ?? "HID Device") : productName,
        manufacturerName: manufacturer.isEmpty ? (profile?.manufacturerName ?? "Unknown") : manufacturer,
        transport: .usb,
        category: category,
        requiresDriverKit: profile?.requiresDriverKit ?? false,
        driverKitActive: false,
        locationID: locationID
    )

    Task { @MainActor in
        guard !manager.connectedDevices.contains(usbDevice) else { return }
        manager.connectedDevices.append(usbDevice)
        manager.delegate?.peripheralManager(manager, didConnect: usbDevice)
    }
}

private func hidDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let ctx = context else { return }
    let manager = Unmanaged<USBPeripheralManager>.fromOpaque(ctx).takeUnretainedValue()

    func intProp(_ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
    }
    let vid = intProp(kIOHIDVendorIDKey)
    let pid = intProp(kIOHIDProductIDKey)
    let loc = UInt32(intProp(kIOHIDLocationIDKey))

    Task { @MainActor in
        guard let idx = manager.connectedDevices.firstIndex(where: {
            $0.vendorID == vid && $0.productID == pid && $0.locationID == loc
        }) else { return }
        let removed = manager.connectedDevices.remove(at: idx)
        manager.delegate?.peripheralManager(manager, didDisconnect: removed)
    }
}

private func inferCategory(usagePage: Int, usage: Int, profile: DeviceProfile?) -> PeripheralCategory {
    if let profile { return profile.category }
    // HID Usage Page 0x01 = Generic Desktop
    switch (usagePage, usage) {
    case (0x01, 0x04): return .gamepad        // Joystick
    case (0x01, 0x05): return .gamepad        // Gamepad
    case (0x01, 0x08): return .steeringWheel  // Multi-axis Controller
    case (0x01, 0x02): return .mouse
    case (0x01, 0x06): return .keyboard
    default:           return .unknown
    }
}
#endif

#endif // canImport(GameController)
