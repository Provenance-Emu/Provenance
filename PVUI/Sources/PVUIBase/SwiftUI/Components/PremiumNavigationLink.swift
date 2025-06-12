import SwiftUI
import UIKit
#if canImport(FreemiumKit)
import FreemiumKit
#endif
import PVThemes

struct PremiumNavigationLink<Label: View, Destination: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let label: Label
    let destination: Destination
    
    init(destination: Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }
    
#if canImport(FreemiumKit)
    var body: some View {
        PaidFeatureView {
            NavigationLink(destination: destination) {
                label
            }
        } lockedView: {
            ZStack {
                NavigationLink(destination: EmptyView()) {
                    label
                }
                .disabled(true)
                .opacity(0.8)
            }
        }
    }
#else
    var body: some View {
        NavigationLink(destination: destination) {
            label
        }
    }
#endif
}
