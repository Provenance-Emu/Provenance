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
                    HStack {
                        label
                        Spacer()
                        // Lock icon + PLUS badge
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("PLUS")
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.retroPink.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                    }
                }
                .disabled(true)
                .opacity(0.7)
            }
        }
        .freemiumKitColorReset()
    }
#else
    var body: some View {
        NavigationLink(destination: destination) {
            label
        }
    }
#endif
}
