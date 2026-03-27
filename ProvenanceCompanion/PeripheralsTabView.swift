import SwiftUI

/// Placeholder view for the Peripherals tab.
/// The DriverKit extension embedded in this app will expose USB/HID devices
/// as virtual HID devices accessible to the main Provenance app via IOKit.
struct PeripheralsTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Peripherals Coming Soon",
                systemImage: "cable.connector",
                description: Text("Connect USB and Bluetooth controllers and adapters via the embedded DriverKit extension.")
            )
            .navigationTitle("Peripherals")
        }
    }
}

#Preview {
    PeripheralsTabView()
}
