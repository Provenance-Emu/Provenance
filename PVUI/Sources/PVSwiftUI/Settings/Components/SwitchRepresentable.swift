//
//  SwitchRepresentable.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

#if !os(tvOS)
import SwiftUI
import UIKit
import PVThemes

struct SwitchThemedToggleStyle: ToggleStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Switch(isOn: configuration.$isOn, tint: tint)
        }
    }
}

private struct Switch: View {
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        // Use UIKit switch for custom styling
        SwitchRepresentable(isOn: $isOn, tint: tint)
            .frame(width: 51, height: 31) // Standard UISwitch dimensions
    }
}


// UIViewRepresentable wrapper for UISwitch
private struct SwitchRepresentable: UIViewRepresentable {
    @Binding var isOn: Bool
    let tint: Color

    func makeUIView(context: Context) -> UISwitch {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = UIColor(tint)
        uiSwitch.thumbTintColor = ThemeManager.shared.currentPalette.switchThumb
        uiSwitch.addTarget(context.coordinator,
                          action: #selector(Coordinator.switchChanged(_:)),
                          for: .valueChanged)
        return uiSwitch
    }

    func updateUIView(_ uiView: UISwitch, context: Context) {
        uiView.isOn = isOn
        uiView.onTintColor = UIColor(tint)
        uiView.thumbTintColor = ThemeManager.shared.currentPalette.switchThumb
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isOn: $isOn)
    }

    class Coordinator: NSObject {
        private var isOn: Binding<Bool>

        init(isOn: Binding<Bool>) {
            self.isOn = isOn
        }

        @objc func switchChanged(_ sender: UISwitch) {
            isOn.wrappedValue = sender.isOn
        }
    }
}
#endif
