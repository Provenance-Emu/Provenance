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
        static let cornerRadius: CGFloat = 16
        static let borderWidth: CGFloat = 4
        static let dragThreshold: CGFloat = 50
    }

    /// Only show view if there are BIOSes
    @ViewBuilder
    var body: some View {
        if !console.bioses.isEmpty {
            VStack(spacing: 0) {
                // Tab indicator
                tabIndicator

                // Content
                if isExpanded {
                    biosContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.black.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor,
                           lineWidth: Constants.borderWidth)
            )
            .cornerRadius(Constants.cornerRadius)
            .offset(y: dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
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
                            isExpanded.toggle()
                            UserDefaults.standard.set(isExpanded, forKey: storageKey)
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
        }
    }

    private var tabIndicator: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor)
                Text("BIOSes (\(console.bioses.count))")
                    .font(.caption)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
            .frame(height: Constants.tabHeight)
            .padding(.vertical, 4)
            Spacer()
        }
    }

    private var biosContent: some View {
        VStack(spacing: 0) {
            GamesDividerView()
            ForEach(console.bioses, id: \.expectedFilename) { bios in
                BiosRowView(biosFilename: bios.expectedFilename)
                GamesDividerView()
            }
        }
        .padding(.vertical, 8)
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
