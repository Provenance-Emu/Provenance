
//
//  ImportStatusView.swift
//  PVUI
//
//  Created by David Proskin on 10/31/24.
//

import SwiftUI
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
    public var gameImporter:GameImporter
    public weak var delegate:ImportStatusDelegate!
    public var dismissAction: (() -> Void)? = nil
    
    public init(updatesController: PVGameLibraryUpdatesController, gameImporter:GameImporter, delegate:ImportStatusDelegate, dismissAction: (() -> Void)? = nil) {
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
                            .foregroundColor(.gray)
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
                        Button("Done") { delegate.dismissAction()
                        }
                    })
                    ToolbarItemGroup(placement: .topBarTrailing,
                                     content:  {
                        Button("Add Files") {
                            delegate?.addImportsAction()
                        }
                        Button("Begin") {
                            delegate?.forceImportsAction()
                        }
                    })
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

//#Preview {
//    let gameImporter = AppState.shared.gameImporter ?? GameImporter.shared
//    let pvgamelibraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter)
//    let importDelegate = MockImportStatusDelegate()
//
//    ImportStatusView(
//        updatesController: pvgamelibraryUpdatesController,
//        gameImporter: gameImporter,
//        delegate: importDelegate)
//}
