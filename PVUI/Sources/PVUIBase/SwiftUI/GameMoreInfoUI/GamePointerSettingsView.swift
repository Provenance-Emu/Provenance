import PVCoreBridge
import PVSystems
import SwiftUI

/// Edits the game's overrides while showing the values inherited from its system or global settings.
struct GamePointerSettingsView: View {
    let md5: String
    let system: SystemIdentifier

    @State private var settings = ControllerPointerSettings()

    private var store: ControllerPointerSettingsStore { .shared }
    private var scope: ControllerPointerScope { .game(md5: md5) }
    private var inherited: ControllerPointerSettingsStore.Resolved {
        store.resolved(system: system, gameMD5: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pointer Settings").font(.headline)
            menu("Pointer Mode", selection: override(\.mode)) {
                Text("Inherit").tag(nil as ControllerPointerMode?)
                Text("Automatic").tag(Optional(ControllerPointerMode.automatic))
                Text("Off").tag(Optional(ControllerPointerMode.off))
                if MouseGameRegistry.shared.systemHasAnyMouseSupport(system) {
                    Text("Mouse").tag(Optional(ControllerPointerMode.mouse))
                }
                if system.supportsLightGun {
                    Text("Light Gun").tag(Optional(ControllerPointerMode.lightGun))
                }
                if system == .Wii {
                    Text("Wii Pointer").tag(Optional(ControllerPointerMode.wiiPointer))
                }
            }

            number("Touchpad Speed", field: \.speed, fallback: inherited.curve.speed, range: PointerSpeedCurve.speedRange, step: 0.1)
            number("Touchpad Acceleration", field: \.acceleration, fallback: inherited.curve.acceleration, range: PointerSpeedCurve.accelerationRange, step: 0.05)

            choice("Gyro Aiming", field: \.gyro, fallback: inherited.gyroEnabled)
            number("Gyro Sensitivity", field: \.gyroSensitivity, fallback: inherited.gyroFilter.sensitivity, range: GyroPointerFilter.sensitivityRange, step: 0.1)
            number("Gyro Dead Zone", field: \.gyroDeadZone, fallback: inherited.gyroFilter.deadZone, range: GyroPointerFilter.deadZoneRange, step: 0.01)
            choice("Invert Gyro Left–Right", field: \.gyroInvertX, fallback: inherited.gyroFilter.invertX)
            choice("Invert Gyro Up–Down", field: \.gyroInvertY, fallback: inherited.gyroFilter.invertY)

            if system == .Wii {
                menu("Wii Remote Tilt", selection: override(\.wiiTilt)) {
                    Text("Inherit").tag(nil as WiiTiltMode?)
                    Text("Off").tag(Optional(WiiTiltMode.off))
                    Text("Upright").tag(Optional(WiiTiltMode.upright))
                    Text("Sideways").tag(Optional(WiiTiltMode.sideways))
                }
                choice("Wii Remote Shake", field: \.shake, fallback: inherited.shakeEnabled)
            }
        }
        .onAppear { settings = store.settings(for: scope) }
        .onReceive(NotificationCenter.default.publisher(for: ControllerPointerSettingsStore.didChangeNotification)) { _ in
            settings = store.settings(for: scope)
        }
    }

    private func override<Value>(_ field: WritableKeyPath<ControllerPointerSettings, Value?>) -> Binding<Value?> {
        Binding(get: { settings[keyPath: field] }, set: { value in
            store.update(scope) { $0[keyPath: field] = value }
            settings = store.settings(for: scope)
        })
    }

    /// A picker with its title beside it: outside a `Form` a menu picker shows only its value.
    private func menu<Value: Hashable, Options: View>(
        _ title: LocalizedStringKey, selection: Binding<Value>, @ViewBuilder options: () -> Options
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection, content: options)
                .labelsHidden()
        }
    }

    private func choice(_ title: LocalizedStringKey, field: WritableKeyPath<ControllerPointerSettings, Bool?>, fallback: Bool) -> some View {
        menu(title, selection: override(field)) {
            Text(fallback ? "Inherit (On)" : "Inherit (Off)").tag(nil as Bool?)
            Text("On").tag(Optional(true))
            Text("Off").tag(Optional(false))
        }
    }

    private func number(
        _ title: LocalizedStringKey, field: WritableKeyPath<ControllerPointerSettings, Double?>,
        fallback: Double, range: ClosedRange<Double>, step: Double
    ) -> some View {
        let value = override(field)
        return VStack(alignment: .leading) {
            Toggle(isOn: Binding(
                get: { value.wrappedValue != nil },
                set: { value.wrappedValue = $0 ? fallback : nil }
            )) {
                Text(title)
            }
            Text((value.wrappedValue ?? fallback).formatted(.number.precision(.fractionLength(2))))
                .monospacedDigit()
            if value.wrappedValue != nil {
                RetroWaveSlider(value: Binding(
                    get: { value.wrappedValue ?? fallback },
                    set: { value.wrappedValue = $0 }
                ), in: range, step: step)
                .accessibilityLabel(Text(title))
            }
        }
    }
}
