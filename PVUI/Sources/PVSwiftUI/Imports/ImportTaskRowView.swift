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

func iconNameForStatus(_ status: ImportQueueItem.ImportStatus) -> String {
    switch status {

    case .queued:
        return "play"
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
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    // Replace delegate with callback
    var onSystemSelected: ((SystemIdentifier, ImportQueueItem) -> Void)?

    var bgColor: Color {
        themeManager.currentPalette.settingsCellBackground?.swiftUIColor ?? themeManager.currentPalette.menuBackground.swiftUIColor
    }

    var fgColor: Color {
        themeManager.currentPalette.settingsCellText?.swiftUIColor ?? themeManager.currentPalette.menuText.swiftUIColor
    }

    var secondaryFgColor: Color {
        themeManager.currentPalette.settingsCellTextDetail?.swiftUIColor ?? .secondary
    }

    var body: some View {
        WithPerceptionTracking {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.url.lastPathComponent)
                        .font(.headline)
                        .foregroundColor(fgColor)

                    if item.fileType == .bios {
                        Text("BIOS")
                            .font(.subheadline)
                            .foregroundColor(fgColor)
                    } else if let chosenSystem = item.userChosenSystem {
                        // Show the selected system when one is chosen
                        Text("\(chosenSystem.fullName)")
                            .font(.subheadline)
                            .foregroundColor(secondaryFgColor)
                    } else if !item.systems.isEmpty {
                        if item.systems.count == 1 {
                            Text("\(item.systems.first!.fullName) matched")
                                .font(.subheadline)
                                .foregroundColor(secondaryFgColor)
                        } else {
                            Text("\(item.systems.count) systems")
                                .font(.subheadline)
                                .foregroundColor(secondaryFgColor)
                        }
                    }

                    if let errorText = item.errorValue {
                        Text("Error Detail: \(errorText)")
                            .font(.subheadline)
                            .foregroundColor(secondaryFgColor)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    if item.status == .processing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 40, height: 40, alignment: .center)
                    } else {
                        Image(systemName: iconNameForStatus(item.status))
                            .foregroundColor(item.status.color)
                    }

                    if (item.childQueueItems.count > 0) {
                        Text("+\(item.childQueueItems.count) files")
                            .font(.subheadline)
                            .foregroundColor(fgColor)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(bgColor)
                    .shadow(radius: 2)
            )
            .onTapGesture {
                // Only show system selection if we haven't chosen a system yet
                if item.userChosenSystem == nil {
                    switch item.status {
                    case .conflict, .failure:
                        isNavigatingToSystemSelection = true
                    case .partial:
                        if item.url.pathExtension.lowercased() == "cue" || item.url.pathExtension.lowercased() == "m3u" {
                            isNavigatingToSystemSelection = true
                        }
                    default:
                        break
                    }
                }
            }
            .background(
                NavigationLink(
                    destination: SystemSelectionView(
                        item: item,
                        onSystemSelected: onSystemSelected
                    ),
                    isActive: $isNavigatingToSystemSelection
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}
#if DEBUG
import PVThemes
#Preview {
    List {
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.jpg"), fileType: .artwork))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.bin"), fileType: .bios))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.iso"), fileType: .cdRom))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.jag"), fileType: .game))
        ImportTaskRowView(item: .init(url: .init(fileURLWithPath: "Test.zip"), fileType: .unknown))
    }
    .onAppear {
        ThemeManager.shared.setCurrentPalette(CGAThemes.green.palette)
    }
}
#endif
