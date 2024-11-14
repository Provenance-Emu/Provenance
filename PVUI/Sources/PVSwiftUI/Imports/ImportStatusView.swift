
//
//  ImportStatusView.swift
//  PVUI
//
//  Created by David Proskin on 10/31/24.
//

import SwiftUI
import PVLibrary
import PVThemes

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

func iconNameForStatus(_ status: ImportStatus) -> String {
    switch status {

    case .queued:
        return "line.3.horizontal.circle"
    case .processing:
        return "progress.indicator"
    case .success:
        return "checkmark.circle.fill"
    case .failure:
        return "xmark.diamond.fill"
    case .conflict:
        return "exclamationmark.triangle.fill"
    case .partial:
        return "display.trianglebadge.exclamationmark"
    }
}

// Individual Import Task Row View
struct ImportTaskRowView: View {
    let item: ImportQueueItem
    @State private var isNavigatingToSystemSelection = false
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack {
            //TODO: add icon for fileType
            VStack(alignment: .leading) {
                Text(item.url.lastPathComponent)
                    .font(.headline)
                if item.fileType == .bios {
                    Text("BIOS")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                } else if !item.systems.isEmpty {
                    Text("\(item.systems.count) systems")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                }

            }

            Spacer()

            VStack(alignment: .trailing) {
                if item.status == .processing {
                    ProgressView().progressViewStyle(.circular).frame(width: 40, height: 40, alignment: .center)
                } else {
                    Image(systemName: iconNameForStatus(item.status))
                        .foregroundColor(item.status.color)
                }

                if (item.childQueueItems.count > 0) {
                    Text("+\(item.childQueueItems.count) files")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                }
            }

        }
        .padding()
        .background(Color.white)
        .onTapGesture {
                    if item.status == .conflict {
                        isNavigatingToSystemSelection = true
                    }
                }
                .background(
                    NavigationLink(destination: SystemSelectionView(item: item), isActive: $isNavigatingToSystemSelection) {
                        EmptyView()
                    }
                    .hidden()
                )
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

#Preview {

}
