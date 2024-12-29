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

public protocol ImportStatusDelegate : AnyObject {
    func dismissAction()
    func addImportsAction()
    func forceImportsAction()
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

    public init(updatesController: PVGameLibraryUpdatesController, gameImporter: any GameImporting, delegate: ImportStatusDelegate? = nil, dismissAction: (() -> Void)? = nil) {
        self.updatesController = updatesController
        self.gameImporter = gameImporter
        self.delegate = delegate
        self.dismissAction = dismissAction
    }

    private func deleteItems(at offsets: IndexSet) {
        gameImporter.removeImports(at: offsets)
    }

    public var body: some View {
        WithPerceptionTracking {
            NavigationView {
                List {
                    if gameImporter.importQueue.isEmpty {
                        Text("No items in the import queue")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(gameImporter.importQueue) { item in
                            Button(action: {
                                print("Tapped item: \(item.id)")
                            }) {
                                ImportTaskRowView(item: item)
                                    .id(item.id)
                            }
                            #if os(tvOS)
                            .buttonStyle(.bordered)
                            .focusable()
                            .prefersDefaultFocus(in: namespace)
                            #endif
                        }.onDelete(
                            perform: deleteItems
                        )
                    }
                }
                #if os(tvOS)
                .focusSection()
                .focusScope(namespace)
                #endif
                .navigationTitle("Import Queue")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading,
                                     content: {
                        // TODO: Removing from tvOS as a hack @JoeMatt
                        #if !os(tvOS)
                        if dismissAction != nil {
                            Button("Done") {
                                dismissAction?()
                                delegate?.dismissAction()
                            }
                            .tint(currentPalette.defaultTintColor?.swiftUIColor)
#if os(tvOS)
                            .focusable(true)
#endif
                        }
                        #endif
                    })
                    ToolbarItemGroup(placement: .topBarTrailing,
                                   content: {
                        #if !os(tvOS)
                        Button("Add Files") {
                            delegate?.addImportsAction()
                        }
                        .tint(currentPalette.defaultTintColor?.swiftUIColor)
                        #endif

                        Button("Begin") {
                            delegate?.forceImportsAction()
                        }
                        .tint(currentPalette.defaultTintColor?.swiftUIColor)
                        #if os(tvOS)
                        .focusable(true)
                        #endif
                    })
                }
                .background(currentPalette.gameLibraryBackground.swiftUIColor)
            }
            .background(currentPalette.gameLibraryBackground.swiftUIColor)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
