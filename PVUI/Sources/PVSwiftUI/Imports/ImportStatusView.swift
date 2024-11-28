
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

func iconNameForFileType(_ type: FileType) -> String {
    
    switch type {
    case .bios:
        return "bios_filled"
    case .artwork:
        return "image_icon_256"
    case .game:
        return "file_icon_256"
    case .cdRom:
        return "cd_icon_256"
    case .unknown:
        return "questionMark"
    }
}

public struct ImportStatusView: View {
    @ObservedObject
    public var updatesController: PVGameLibraryUpdatesController
    public var gameImporter:any GameImporting
    public weak var delegate:ImportStatusDelegate!
    public var dismissAction: (() -> Void)? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public init(updatesController: PVGameLibraryUpdatesController, gameImporter: any GameImporting, delegate: ImportStatusDelegate, dismissAction: (() -> Void)? = nil) {
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
                            ImportTaskRowView(item: item).id(item.id)
                        }.onDelete(
                            perform: deleteItems
                        )
                    }
                }
                .navigationTitle("Import Queue")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading,
                                     content: {
                        if dismissAction != nil {
                            Button("Done") { delegate.dismissAction()
                            }
                            .tint(currentPalette.defaultTintColor?.swiftUIColor)
                        }
                    })
                    ToolbarItemGroup(placement: .topBarTrailing,
                                     content:  {
                        Button("Add Files") {
                            delegate?.addImportsAction()
                        }
                        .tint(currentPalette.defaultTintColor?.swiftUIColor)
                        Button("Begin") {
                            delegate?.forceImportsAction()
                        }
                        .tint(currentPalette.defaultTintColor?.swiftUIColor)
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
