//
//  ImportTaskRowView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import PVLibrary
import PVThemes
import Perception

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
    
    var bgColor: Color {
        themeManager.currentPalette.settingsCellBackground?.swiftUIColor ?? themeManager.currentPalette.menuBackground.swiftUIColor
    }
    
    var body: some View {
        WithPerceptionTracking {
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
            .background(bgColor)
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
}
