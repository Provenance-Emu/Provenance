//
//  SaveStateRowView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import SwiftUI
import PVThemes
import PVSwiftUI
import SwipeCellSUI

/// View model for individual save state rows
public class SaveStateRowViewModel: ObservableObject, Identifiable {
    public let id: UUID = UUID()
    let gameTitle: String
    let saveDate: Date
    let thumbnailImage: Image
    @Published var description: String?
    @Published var isEditing: Bool = false
    @Published var isSelected: Bool = false
    @Published var isFavorite: Bool = false
    /// New property for pin state
    @Published var isPinned: Bool = false

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public init(gameTitle: String, saveDate: Date, thumbnailImage: Image, description: String? = nil) {
        self.gameTitle = gameTitle
        self.saveDate = saveDate
        self.thumbnailImage = thumbnailImage
        self.description = description
    }
}

public struct SaveStateRowView: View {
    @ObservedObject var viewModel: SaveStateRowViewModel
    @State private var showingEditDialog = false
    @State private var editText: String = ""
    @Binding var currentUserInteractionCellID: String?

    /// Computed property for display title
    private var displayTitle: String {
        viewModel.description?.isEmpty == false ? viewModel.description! : viewModel.gameTitle
    }

    public var body: some View {
        HStack(spacing: 0) {
            /// Selection button when in edit mode
            if viewModel.isEditing {
                Toggle("", isOn: $viewModel.isSelected)
                    .toggleStyle(.button)
                    .buttonStyle(SelectionButtonStyle())
                    .padding(.horizontal)
            }

            /// Main row content
            HStack(spacing: 20) {
                /// Thumbnail image
                viewModel.thumbnailImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(20)

                /// Labels
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        editText = viewModel.description ?? ""
                        showingEditDialog = true
                    } label: {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }

                    Text(viewModel.saveDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                /// Favorite heart icon
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.isFavorite.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .resizable()
                        .frame(width: 24, height: 22)
                        .foregroundColor(viewModel.isFavorite ? .red : .secondary)
                        .symbolEffect(.bounce, value: viewModel.isFavorite)
                }
                .padding(.trailing)
            }
        }
        .frame(height: 100)
        .swipeCell(
            id: viewModel.id.uuidString,
            cellWidth: UIScreen.main.bounds.width,
            leadingSideGroup: leadingSwipeActions(),
            trailingSideGroup: trailingSwipeActions(),
            currentUserInteractionCellID: $currentUserInteractionCellID
        )
        .alert("Edit Description", isPresented: $showingEditDialog) {
            TextField("Description", text: $editText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                viewModel.description = editText.isEmpty ? nil : editText
            }
        } message: {
            Text("Enter a custom description for this save state")
        }
    }

    /// Leading (left) swipe actions
    private func leadingSwipeActions() -> [SwipeCellActionItem] {
        [
            SwipeCellActionItem(
                buttonView: {
                    pinView(swipeOut: false)
                },
                swipeOutButtonView: {
                    pinView(swipeOut: true)
                },
                buttonWidth: 80,
                backgroundColor: .yellow,
                swipeOutAction: true,
                swipeOutHapticFeedbackType: .success
            ) {
                viewModel.isPinned.toggle()
            }
        ]
    }

    /// Trailing (right) swipe actions
    private func trailingSwipeActions() -> [SwipeCellActionItem] {
        [
            SwipeCellActionItem(
                buttonView: {
                    shareView()
                },
                buttonWidth: 80,
                backgroundColor: .blue
            ) {
                // Share action
                print("Share tapped")
            },
            SwipeCellActionItem(
                buttonView: {
                    deleteView(swipeOut: false)
                },
                swipeOutButtonView: {
                    deleteView(swipeOut: true)
                },
                buttonWidth: 80,
                backgroundColor: .red,
                swipeOutAction: true,
                swipeOutHapticFeedbackType: .warning,
                swipeOutIsDestructive: true
            ) {
                // Delete action
                print("Delete tapped")
            }
        ]
    }

    /// Pin button view
    private func pinView(swipeOut: Bool) -> AnyView {
        Group {
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: viewModel.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: swipeOut ? 28 : 24))
                    .foregroundColor(.white)
                Text(viewModel.isPinned ? "Unpin" : "Pin")
                    .font(.system(size: swipeOut ? 16 : 14))
                    .foregroundColor(.white)
            }
            .frame(maxHeight: 80)
            .padding(.horizontal, swipeOut ? 20 : 5)
            if !swipeOut {
                Spacer()
            }
        }
        .animation(.default, value: viewModel.isPinned)
        .eraseToAnyView()
    }

    /// Share button view
    private func shareView() -> AnyView {
        VStack(spacing: 2) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 24))
                .foregroundColor(.white)
            Text("Share")
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
        .frame(maxHeight: 80)
        .eraseToAnyView()
    }

    /// Delete button view
    private func deleteView(swipeOut: Bool) -> AnyView {
        VStack(spacing: 2) {
            Image(systemName: "trash")
                .font(.system(size: swipeOut ? 28 : 24))
                .foregroundColor(.white)
            Text("Delete")
                .font(.system(size: swipeOut ? 16 : 14))
                .foregroundColor(.white)
        }
        .frame(maxHeight: 80)
        .animation(.default, value: swipeOut)
        .eraseToAnyView()
    }
}

/// Custom button style for selection toggle
private struct SelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: configuration.isPressed ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundColor(configuration.isPressed ? .accentColor : .secondary)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

/// Extension to add eraseToAnyView functionality
extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

// MARK: - Previews

#Preview("Save State Row", traits: .sizeThatFitsLayout) {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    VStack(spacing: 20) {
        /// Normal mode
        SaveStateRowView(viewModel: SaveStateRowViewModel(
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Boss Fight - World 3"
        ), currentUserInteractionCellID: $currentUserInteractionCellID)

        /// Normal mode without description
        SaveStateRowView(viewModel: SaveStateRowViewModel(
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller")
        ), currentUserInteractionCellID: $currentUserInteractionCellID)

        /// Edit mode
        let editViewModel = SaveStateRowViewModel(
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller")
        )
        SaveStateRowView(viewModel: editViewModel, currentUserInteractionCellID: $currentUserInteractionCellID)
            .onAppear {
                editViewModel.isEditing = true
                editViewModel.isSelected = true
            }
    }
    .padding()
}

/// Dark mode preview
#Preview("Dark Mode", traits: .sizeThatFitsLayout) {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    SaveStateRowView(viewModel: SaveStateRowViewModel(
        gameTitle: "Bomber Man",
        saveDate: Date(),
        thumbnailImage: Image(systemName: "gamecontroller"),
        description: "Boss Fight - World 3"
    ),
                     currentUserInteractionCellID: $currentUserInteractionCellID)
    .padding()
    .preferredColorScheme(.dark)
}

/// Updated preview
#Preview("Save State Row States") {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    return VStack(spacing: 20) {
        /// Normal mode
        SaveStateRowView(
            viewModel: SaveStateRowViewModel(
                gameTitle: "Bomber Man",
                saveDate: Date(),
                thumbnailImage: Image(systemName: "gamecontroller"),
                description: "Boss Fight - World 3"
            ),
            currentUserInteractionCellID: $currentUserInteractionCellID
        )

        /// With favorite
        let favoriteViewModel = SaveStateRowViewModel(
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller")
        )
        SaveStateRowView(
            viewModel: favoriteViewModel,
            currentUserInteractionCellID: $currentUserInteractionCellID
        )
            .onAppear {
                favoriteViewModel.isFavorite = true
            }

        /// Edit mode with favorite
        let editViewModel = SaveStateRowViewModel(
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller")
        )
        SaveStateRowView(
            viewModel: editViewModel,
            currentUserInteractionCellID: $currentUserInteractionCellID
        )
            .onAppear {
                editViewModel.isEditing = true
                editViewModel.isSelected = true
                editViewModel.isFavorite = true
            }
    }
    .padding()
}

#Preview("Dark Mode") {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    return SaveStateRowView(
        viewModel: SaveStateRowViewModel(
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Boss Fight - World 3"
        ),
        currentUserInteractionCellID: $currentUserInteractionCellID
    )
    .padding()
    .preferredColorScheme(.dark)
}
