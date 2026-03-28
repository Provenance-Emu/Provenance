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
            .navigationTitle(String(localized: "peripherals.nav_title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showDriverStore = true
                    } label: {
                        Label(
                            String(localized: "store.driver_store_toolbar_label"),
                            systemImage: "cart.badge.plus"
                        )
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
                    Text("peripherals.driverkit.title")
                        .font(.headline)
                    Text(driverKitStatusKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if driverExtManager.canEnable {
                    Button(String(localized: "peripherals.driverkit.enable_button")) {
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
                Label(
                    String(localized: "peripherals.driverkit.status.failed \(msg)"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
        } header: {
            Text("peripherals.driverkit.section_header")
        } footer: {
            Text("peripherals.driverkit.description")
        }
    }

    // MARK: - Connected Devices Section

    @ViewBuilder
    private var connectedDevicesSection: some View {
        Section {
            if peripheralManager.connectedDevices.isEmpty {
                ContentUnavailableView(
                    String(localized: "peripherals.empty.title"),
                    systemImage: "cable.connector.slash",
                    description: Text("peripherals.empty.description")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(peripheralManager.connectedDevices) { device in
                    DeviceRowView(device: device)
                }
            }
        } header: {
            HStack {
                Text("peripherals.section.connected")
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
            NavigationLink(String(localized: "peripherals.supported_devices.view_all")) {
                SupportedDevicesListView()
            }
        } header: {
            Text("peripherals.section.compatibility")
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

    /// Returns the `LocalizedStringKey` for static status labels.
    /// Dynamic cases (`.failed`) are rendered inline via their own view branch above.
    private var driverKitStatusKey: LocalizedStringKey {
        switch driverExtManager.activationState {
        case .unknown:         return "peripherals.driverkit.status.unknown"
        case .notInstalled:    return "peripherals.driverkit.status.not_installed"
        case .activating:      return "peripherals.driverkit.status.activating"
        case .active:          return "peripherals.driverkit.status.active"
        case .deactivating:    return "peripherals.driverkit.status.deactivating"
        case .failed:          return "peripherals.driverkit.status.active" // fallback; error shown below
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
                    Label(String(localized: "peripherals.driverkit.driver_badge"), systemImage: "bolt.fill")
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
                Section(category.localizedName) {
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
                                Label(String(localized: "store.driver_badge"), systemImage: "bolt")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "peripherals.supported_devices.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PeripheralsTabView()
}
