//
//  ImportStatusView.swift
//  PVUI
//
//  Created by David Proskin on 10/31/24.
//

import SwiftUI
import PVUIBase
import PVLibrary
import PVThemes
import Perception
import PVSystems

public protocol ImportStatusDelegate: AnyObject {
    func dismissAction()
    func addImportsAction()
    func forceImportsAction()
    func didSelectSystem(_ system: SystemIdentifier, for item: ImportQueueItem)
}

public struct ImportStatusView: View {
    @ObservedObject
    public var updatesController: PVGameLibraryUpdatesController
    public var gameImporter: any GameImporting
    public weak var delegate: ImportStatusDelegate?
    public var dismissAction: (() -> Void)? = nil

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }
    @Namespace private var namespace  // Add namespace for focus management
    
    // State to hold the import queue items
    @State private var queueItems: [ImportQueueItem] = []

    public init(updatesController: PVGameLibraryUpdatesController, gameImporter: any GameImporting, delegate: ImportStatusDelegate? = nil, dismissAction: (() -> Void)? = nil) {
        self.updatesController = updatesController
        self.gameImporter = gameImporter
        self.delegate = delegate
        self.dismissAction = dismissAction
    }

    private func deleteItems(at offsets: IndexSet) {
        Task {
            await gameImporter.removeImports(at: offsets)
            // Refresh the queue items after deletion
            await refreshQueueItems()
        }
    }
    
    // Function to refresh the queue items
    private func refreshQueueItems() async {
        queueItems = await gameImporter.importQueue
    }

    // Define the system selection handler
    private func handleSystemSelection(_ system: SystemIdentifier, for item: ImportQueueItem) {
        // Forward to the delegate
        delegate?.didSelectSystem(system, for: item)
    }

    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0
    
    public var body: some View {
        WithPerceptionTracking {
            NavigationView {
                ZStack {
                    // RetroWave background
                    RetroTheme.retroBackground
                    
                    // Grid overlay
                    RetroGrid()
                        .opacity(0.3)
                    
                    VStack {
                        // Retrowave header
                        Text("IMPORT QUEUE")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(RetroTheme.retroPink)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)
                        
                        // Main content
                        if queueItems.isEmpty {
                            VStack {
                                Spacer()
                                Text("NO ITEMS IN QUEUE")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(RetroTheme.retroBlue)
                                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                                    .padding()
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(queueItems) { item in
                                    ZStack {
                                        // Custom background to maintain retrowave styling
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.black.opacity(0.7))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1.5
                                                    )
                                                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                                            )
                                        
                                        // Pass callback to ImportTaskRowView
                                        ImportTaskRowView(
                                            item: item,
                                            onSystemSelected: handleSystemSelection
                                        )
                                        .id(item.id)
                                        .padding(.vertical, 4) // Add padding to ensure the content doesn't touch the edges
                                    }
                                    .listRowInsets(EdgeInsets()) // Remove default list row insets
                                    .listRowBackground(Color.clear) // Make the list row background transparent
#if os(tvOS)
                                    .focusable()
                                    .prefersDefaultFocus(in: namespace)
#endif
                                }
                                .onDelete(perform: deleteItems) // Add swipe-to-delete functionality
                                .listRowSeparator(.hidden) // Hide default separators
                            }
                            .listStyle(PlainListStyle()) // Use plain style to minimize default styling
                            .padding(.horizontal)
                            .background(Color.clear) // Make list background transparent
                            .scrollContentBackground(.hidden) // Hide the scroll content background on iOS 16+
                        }
                    }
                }
                #if os(tvOS)
                .focusSection()
                .focusScope(namespace)
                #endif
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading,
                                     content: {
                        // TODO: Removing from tvOS as a hack @JoeMatt
                        #if !os(tvOS)
                        if dismissAction != nil {
                            Button(action: {
                                dismissAction?()
                                delegate?.dismissAction()
                            }) {
                                Text("CLOSE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(RetroTheme.retroPurple)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(LinearGradient(
                                                gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroPink]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ), lineWidth: 1.5)
                                    )
                                    .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                            }
#if os(tvOS)
                            .focusable(true)
#endif
                        }
                        #endif
                    })
                    ToolbarItemGroup(placement: .topBarTrailing,
                                   content: {
                        #if !os(tvOS)
                        Button(action: {
                            delegate?.addImportsAction()
                        }) {
                            Text("ADD FILES")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(RetroTheme.retroPink)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ), lineWidth: 1.5)
                                )
                                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                        }
                        #endif

                        Button(action: {
                            delegate?.forceImportsAction()
                        }) {
                            Text("BEGIN")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(RetroTheme.retroBlue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ), lineWidth: 1.5)
                                )
                                .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                        }
                        #if os(tvOS)
                        .focusable(true)
                        #endif
                    })
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onAppear {
                // Load the queue items when the view appears
                Task {
                    await refreshQueueItems()
                }
                
                // Start retrowave animations
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    @ObservedObject var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    let mockImportStatusDriverData = MockImportStatusDriverData()

    ImportStatusView(
        updatesController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
        gameImporter: mockImportStatusDriverData.gameImporter,
        delegate: mockImportStatusDriverData) {
            print("Import Status View Closed")
        }
        .onAppear {
            themeManager.setCurrentPalette(CGAThemes.green.palette)
        }
}
#endif

#if os(tvOS)
private extension ButtonStyle where Self == TVCardButtonStyle {
    static var card: TVCardButtonStyle { TVCardButtonStyle() }
}

private struct TVCardButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.currentPalette.menuBackground.swiftUIColor)
                    .opacity(configuration.isPressed ? 0.7 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
#endif
