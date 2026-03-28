import SwiftUI
import PVUSBManager

struct PeripheralsTabView: View {

    @State private var peripheralManager = USBPeripheralManager()
    @State private var driverExtManager = DriverExtensionManager()
    @State private var showDriverStore = false

    var body: some View {
        NavigationStack {
            List {
                driverKitSection
                connectedDevicesSection
                supportedDevicesSection
            }
            .navigationTitle("Peripherals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showDriverStore = true
                    } label: {
                        Label("Driver Store", systemImage: "cart.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showDriverStore) {
                DriverStoreView()
            }
            .task {
                peripheralManager.startScanning()
            }
        }
    }

    // MARK: - DriverKit Status Section

    @ViewBuilder
    private var driverKitSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: driverKitStatusIcon)
                    .font(.title2)
                    .foregroundStyle(driverKitStatusColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("USB DriverKit Extension")
                        .font(.headline)
                    Text(driverKitStatusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if driverExtManager.canEnable {
                    Button("Enable") {
                        driverExtManager.activateExtension()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if case .active = driverExtManager.activationState {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)

            if case .failed(let msg) = driverExtManager.activationState {
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Driver Status")
        } footer: {
            Text("The DriverKit extension enables USB gamepads and peripherals not natively supported by iPadOS, including DualShock 3 and GameCube adapters. Once active, all apps on your device benefit.")
        }
    }

    // MARK: - Connected Devices Section

    @ViewBuilder
    private var connectedDevicesSection: some View {
        Section {
            if peripheralManager.connectedDevices.isEmpty {
                ContentUnavailableView(
                    "No Devices Connected",
                    systemImage: "cable.connector.slash",
                    description: Text("Connect a USB or Bluetooth controller to get started.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(peripheralManager.connectedDevices) { device in
                    DeviceRowView(device: device)
                }
            }
        } header: {
            HStack {
                Text("Connected")
                Spacer()
                if !peripheralManager.connectedDevices.isEmpty {
                    Text("\(peripheralManager.connectedDevices.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Supported Devices Section

    @ViewBuilder
    private var supportedDevicesSection: some View {
        Section {
            NavigationLink("View All Supported Devices") {
                SupportedDevicesListView()
            }
        } header: {
            Text("Compatibility")
        }
    }

    // MARK: - DriverKit Status Helpers

    private var driverKitStatusIcon: String {
        switch driverExtManager.activationState {
        case .unknown:         return "questionmark.circle"
        case .notInstalled:    return "cable.connector"
        case .activating:      return "arrow.clockwise.circle"
        case .active:          return "checkmark.seal.fill"
        case .deactivating:    return "arrow.counterclockwise.circle"
        case .failed:          return "exclamationmark.triangle.fill"
        }
    }

    private var driverKitStatusColor: Color {
        switch driverExtManager.activationState {
        case .active:          return .green
        case .failed:          return .red
        case .activating,
             .deactivating:    return .orange
        default:               return .secondary
        }
    }

    private var driverKitStatusLabel: String {
        switch driverExtManager.activationState {
        case .unknown:         return "Checking status..."
        case .notInstalled:    return "Not active — tap Enable to load"
        case .activating:      return "Activating — user approval may be required"
        case .active:          return "Active — USB HID devices are fully supported"
        case .deactivating:    return "Deactivating..."
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

// MARK: - Device Row

private struct DeviceRowView: View {
    let device: USBDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.productName)
                    .font(.body)
                HStack(spacing: 8) {
                    Text(device.manufacturerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if device.transport != .gcController {
                        Text(device.usbID)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospaced()
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                transportBadge
                if device.driverKitActive {
                    Label("Driver", systemImage: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var categoryIcon: String {
        switch device.category {
        case .gamepad:          return "gamecontroller.fill"
        case .lightGun:         return "scope"
        case .steeringWheel:    return "steeringwheel"
        case .flightStick:      return "airplane"
        case .mouse:            return "computermouse.fill"
        case .keyboard:         return "keyboard.fill"
        case .memoryCard:       return "memorychip"
        case .cartridgeReader:  return "internaldrive.fill"
        case .massStorage:      return "externaldrive.fill"
        case .serialAdapter:    return "cable.connector.horizontal"
        case .unknown:          return "questionmark.square"
        }
    }

    private var categoryColor: Color {
        switch device.category {
        case .gamepad:          return .blue
        case .steeringWheel:    return .orange
        case .lightGun:         return .red
        case .memoryCard,
             .cartridgeReader,
             .massStorage:      return .green
        default:                return .secondary
        }
    }

    @ViewBuilder
    private var transportBadge: some View {
        let (label, color): (String, Color) = {
            switch device.transport {
            case .usb:          return ("USB", .blue)
            case .bluetooth:    return ("BT", .indigo)
            case .mfi:          return ("MFi", .green)
            case .gcController: return ("HID", .purple)
            }
        }()
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Supported Devices List

private struct SupportedDevicesListView: View {
    private let grouped: [(PeripheralCategory, [DeviceProfile])] = {
        var dict: [PeripheralCategory: [DeviceProfile]] = [:]
        for profile in KnownDeviceProfiles.all {
            dict[profile.category, default: []].append(profile)
        }
        return PeripheralCategory.allCases.compactMap { cat in
            guard let profiles = dict[cat], !profiles.isEmpty else { return nil }
            return (cat, profiles)
        }
    }()

    var body: some View {
        List {
            ForEach(grouped, id: \.0) { category, profiles in
                Section(category.rawValue) {
                    ForEach(profiles, id: \.productName) { profile in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.productName)
                                Text(profile.manufacturerName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if profile.requiresDriverKit {
                                Label("Driver", systemImage: "bolt")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Supported Devices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PeripheralsTabView()
}
