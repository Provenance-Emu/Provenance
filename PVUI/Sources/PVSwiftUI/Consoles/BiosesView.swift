//
//  BiosesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes

/// A view that displays BIOS files for a console system
struct BiosesView: View {
    @ObservedRealmObject var console: PVSystem
    @ObservedObject private var themeManager = ThemeManager.shared

    /// State to track if the BIOS section is expanded
    @State private var isExpanded: Bool = false
    @State private var dragOffset: CGFloat = 0

    /// Storage key for expanded state
    private var storageKey: String {
        "BiosesView.isExpanded.\(console.identifier)"
    }

    /// Constants for the view
    private enum Constants {
        static let tabHeight: CGFloat = 30
        static let borderWidth: CGFloat = 2
        static let dragThreshold: CGFloat = 50
    }

    /// Only show view if there are BIOSes
    @ViewBuilder
    var body: some View {
        if !console.bioses.isEmpty {
            VStack(spacing: 0) {
                // Tab indicator
                tabIndicator

                // Content container with fixed height animation
                ZStack(alignment: .top) {
                    if isExpanded {
                        biosContent
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).animation(.spring(response: 0.3, dampingFraction: 0.7))
                                )
                            )
                    }
                }
                .clipped() // Clip the content container
                .frame(height: isExpanded ? calculateContentHeight() : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
            }
            .background(
                // Retrowave-style background
                ZStack {
                    // Dark background
                    Color.black.opacity(0.8)
                    
                    // Grid overlay for retrowave effect
                    RetroTheme.RetroGridView()
                        .opacity(0.15)
                }
            )
            // Neon border with gradient
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                RetroTheme.retroPurple,
                                RetroTheme.retroBlue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: Constants.borderWidth
                    )
            )
            // Add subtle glow effect
            .shadow(color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.6), radius: 5)
            .clipShape(Rectangle()) // Clip the entire container
            .offset(y: dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
            #if !os(tvOS)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.height
                        if isExpanded {
                            dragOffset = min(0, translation)
                        } else {
                            dragOffset = max(0, translation)
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.height
                        if abs(translation) > Constants.dragThreshold {
                            withAnimation {
                                isExpanded.toggle()
                                UserDefaults.standard.set(isExpanded, forKey: storageKey)
                            }
                        }
                        dragOffset = 0
                    }
            )
            #endif
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                    UserDefaults.standard.set(isExpanded, forKey: storageKey)
                }
            }
            .onAppear {
                // Load saved expansion state
                isExpanded = UserDefaults.standard.bool(forKey: storageKey)
            }
        }
    }

    private var tabIndicator: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                // Retrowave-styled icon
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                RetroTheme.retroPurple,
                                RetroTheme.retroBlue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.7), radius: 2)
                
                // Retrowave-styled text
                Text("BIOSes (\(console.bioses.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                RetroTheme.retroPurple,
                                RetroTheme.retroBlue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .frame(height: Constants.tabHeight)
            .padding(.vertical, 6)
            Spacer()
        }
        // Add subtle pulse animation
        .modifier(PulseAnimation(isExpanded: isExpanded))
    }

    private var biosContent: some View {
        VStack(spacing: 0) {
            // Retrowave-styled divider
            RetroDividerView()
            
            ForEach(console.bioses, id: \.expectedFilename) { bios in
                BiosRowView(biosFilename: bios.expectedFilename)
                    // Add hover effect for each row
                    .modifier(HoverEffect())
                
                RetroDividerView()
            }
        }
        .padding(.vertical, 8)
    }

    /// Calculate the height needed for the content based on number of BIOS entries
    private func calculateContentHeight() -> CGFloat {
        /// Height for each BIOS row (estimated) plus dividers
        let rowHeight: CGFloat = 44
        let dividerHeight: CGFloat = 1
        let padding: CGFloat = 16 // 8 top + 8 bottom

        /// Calculate total height based on number of BIOS entries
        /// Each entry has a row and a divider, plus one extra divider at the top
        return CGFloat(console.bioses.count) * rowHeight +
               CGFloat(console.bioses.count + 1) * dividerHeight +
               padding
    }
}

/// Preview provider for BiosesView
#if DEBUG
struct BiosesView_Previews: PreviewProvider {
    static var previews: some View {
        BiosesView(console: PVSystem(identifier: "test", name: "Test System", shortName: "TEST", manufacturer: "Test"))
            .previewLayout(.sizeThatFits)
    }
}
#endif
