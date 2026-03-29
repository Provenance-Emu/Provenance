/// OpticalDriveStatusView.swift
/// ProvenanceCompanion
///
/// SwiftUI section view showing the optical drive DriverKit extension status
/// and disc information. Intended to be embedded in PeripheralsTabView.
///
/// Not compiled on tvOS (optical drives require USB host mode, unavailable on tvOS).

#if !os(tvOS)
import SwiftUI

/// Section card showing optical drive driver status and disc presence.
struct OpticalDriveStatusView: View {

    @Bindable var manager: OpticalDriveManager

    var body: some View {
        Section {
            statusRow
            if case .failed(let msg) = manager.activationState {
                Label(
                    "\(String(localized: "optical_drive.status.failed")): \(msg)",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
        } header: {
            Text("optical_drive.section_header")
        } footer: {
            Text("optical_drive.section_footer")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("optical_drive.title")
                    .font(.headline)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        if manager.canEnable {
            Button(String(localized: "optical_drive.enable_button")) {
                manager.activateExtension()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else if case .active = manager.activationState {
            discStatusBadge
        }
    }

    @ViewBuilder
    private var discStatusBadge: some View {
        switch manager.driveStatus {
        case .discPresent:
            Label(String(localized: "optical_drive.disc.present"), systemImage: "opticaldisc.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .noDisc:
            Label(String(localized: "optical_drive.disc.none"), systemImage: "opticaldisc")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .reading:
            Label(String(localized: "optical_drive.disc.reading"), systemImage: "arrow.clockwise.circle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .trayOpen:
            Label(String(localized: "optical_drive.disc.tray_open"), systemImage: "tray.2")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .driverNotActive, .unknown:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    // MARK: - Helpers

    private var statusIcon: String {
        switch manager.activationState {
        case .unknown:         return "questionmark.circle"
        case .notInstalled:    return "opticaldisc"
        case .activating:      return "arrow.clockwise.circle"
        case .active:
            return manager.hasDisc ? "opticaldisc.fill" : "opticaldisc"
        case .deactivating:    return "arrow.counterclockwise.circle"
        case .failed:          return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch manager.activationState {
        case .active:
            return manager.hasDisc ? .green : .blue
        case .failed:          return .red
        case .activating,
             .deactivating:    return .orange
        default:               return .secondary
        }
    }

    private var statusLabel: LocalizedStringKey {
        switch manager.activationState {
        case .unknown:         return "optical_drive.status.unknown"
        case .notInstalled:    return "optical_drive.status.not_installed"
        case .activating:      return "optical_drive.status.activating"
        case .active:          return driveStatusLabel
        case .deactivating:    return "optical_drive.status.deactivating"
        case .failed:          return "optical_drive.status.failed_short"
        }
    }

    private var driveStatusLabel: LocalizedStringKey {
        switch manager.driveStatus {
        case .discPresent:     return "optical_drive.disc.present"
        case .noDisc:          return "optical_drive.disc.none"
        case .reading:         return "optical_drive.disc.reading"
        case .trayOpen:        return "optical_drive.disc.tray_open"
        default:               return "optical_drive.status.active"
        }
    }
}

#Preview {
    List {
        OpticalDriveStatusView(manager: OpticalDriveManager())
    }
}
#endif // !os(tvOS)
