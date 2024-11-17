
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

struct ImportStatusView: View {
    @ObservedObject var updatesController: PVGameLibraryUpdatesController
    var gameImporter:GameImporter
    weak var delegate:ImportStatusDelegate!
    
    private func deleteItems(at offsets: IndexSet) {
        gameImporter.removeImports(at: offsets)
    }
    
    var body: some View {
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
//    
//}
