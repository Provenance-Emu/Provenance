//
//  SaveStateRowView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import SwiftUI
import PVThemes
import PVSwiftUI
#if !os(tvOS)
import SwipeCellSUI
#endif

/// View model for individual save state rows
public class SaveStateRowViewModel: ObservableObject, Identifiable, Equatable {
    public let id: String
    public let gameID: String
    public let gameTitle: String
    public let saveDate: Date
    public let thumbnailImage: Image

    /// Size of the save state in bytes
    @Published public var size: UInt64 = 0

    /// Thumbnail image that can be updated
    @Published public var thumbnail: Image

    @Published var isEditing: Bool = false
    @Published var isSelected: Bool = false

    @Published public var description: String?
    @Published public var isAutoSave: Bool
    @Published public var isPinned: Bool
    @Published public var isFavorite: Bool

    /// Callback for delete action
    var onDelete: (() -> Void)?
    /// Callback for load action
    var onLoad: (() -> Void)?

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public static func == (lhs: SaveStateRowViewModel, rhs: SaveStateRowViewModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.gameID == rhs.gameID &&
        lhs.gameTitle == rhs.gameTitle &&
        lhs.saveDate == rhs.saveDate &&
        lhs.description == rhs.description &&
        lhs.isAutoSave == rhs.isAutoSave &&
        lhs.isPinned == rhs.isPinned &&
        lhs.isFavorite == rhs.isFavorite &&
        lhs.isEditing == rhs.isEditing &&
        lhs.isSelected == rhs.isSelected &&
        lhs.size == rhs.size
    }

    public init(
        id: String = UUID().uuidString,
        gameID: String,
        gameTitle: String,
        saveDate: Date,
        thumbnailImage: Image,
        description: String? = nil,
        isAutoSave: Bool = false,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        size: UInt64 = 0,
        onDelete: (() -> Void)? = nil,
        onLoad: (() -> Void)? = nil
    ) {
        self.id = id
        self.gameID = gameID
        self.gameTitle = gameTitle
        self.saveDate = saveDate
        self.thumbnailImage = thumbnailImage
        self.thumbnail = thumbnailImage
        self.description = description
        self.isAutoSave = isAutoSave
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.size = size
        self.onDelete = onDelete
        self.onLoad = onLoad
    }
}

/// Custom toggle style for selection
private struct SelectionToggleStyle: ToggleStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(configuration.isOn ? .accentColor : .accentColor)
                .animation(.easeInOut, value: configuration.isOn)
        }
    }
}

/// Extension to add eraseToAnyView functionality
extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

// MARK: - Previews

#if DEBUG

@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("Save State Row") {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    VStack(spacing: 20) {
        /// Normal mode
        SaveStateRowView(viewModel: SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Boss Fight - World 3"
        ), currentUserInteractionCellID: $currentUserInteractionCellID)

        /// Normal mode without description
        SaveStateRowView(viewModel: SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller")
        ), currentUserInteractionCellID: $currentUserInteractionCellID)

        /// Edit mode
        let editViewModel = SaveStateRowViewModel(
            gameID: "1",
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
@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("Dark Mode") {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    SaveStateRowView(viewModel: SaveStateRowViewModel(
        gameID: "1",
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
@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("Save State Row States") {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    /// Create sample save states with different states and dates
    let sampleSaveStates = [
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date().addingTimeInterval(-5 * 24 * 3600), // 5 days ago
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Final Boss Battle"
        ),
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date().addingTimeInterval(-4 * 24 * 3600), // 4 days ago
            thumbnailImage: Image(systemName: "gamecontroller")
        ),
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date().addingTimeInterval(-3 * 24 * 3600), // 3 days ago
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Secret Area Found"
        ),
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date().addingTimeInterval(-2 * 24 * 3600), // 2 days ago
            thumbnailImage: Image(systemName: "gamecontroller")
        ),
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date().addingTimeInterval(-24 * 3600), // Yesterday
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Power-Up Location"
        ),
        SaveStateRowViewModel(
            gameID: "1",
            gameTitle: "Bomber Man",
            saveDate: Date(), // Today
            thumbnailImage: Image(systemName: "gamecontroller")
        )
    ]

    /// Set different states for the save states
    sampleSaveStates[0].isFavorite = true  // First save is favorited
    sampleSaveStates[0].isPinned = true    // and pinned

    sampleSaveStates[1].isAutoSave = true    // Autosave

    sampleSaveStates[2].isFavorite = true  // Third save is favorited

    sampleSaveStates[4].isPinned = true    // Fifth save is pinned
    sampleSaveStates[4].isAutoSave = true    // and Autosave

    return ScrollView {
        VStack(spacing: 0) {
            ForEach(sampleSaveStates) { saveState in
                SaveStateRowView(
                    viewModel: saveState,
                    currentUserInteractionCellID: $currentUserInteractionCellID
                )
                Divider()
            }
        }
    }
    .padding()
}

@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("Dark Mode") {
    @Previewable
    @State var currentUserInteractionCellID: String? = nil

    return SaveStateRowView(
        viewModel: SaveStateRowViewModel(
            gameID: "1",
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
#endif

public struct SaveStateRowView: View {
    @ObservedObject var viewModel: SaveStateRowViewModel
    @State private var showingEditDialog = false
    @State private var showingLoadAlert = false
    @State private var tempDescription: String? = nil
    @Binding var currentUserInteractionCellID: String?
    var onEdit: ((SaveStateEditField, SaveStateRowViewModel, String?) -> Void)?

    /// Computed property for display title
    private var displayTitle: String {
        viewModel.description?.isEmpty == false ? viewModel.description! : viewModel.gameTitle
    }

    public var body: some View {
        HStack(spacing: 0) {
            /// Selection button when in edit mode
            if viewModel.isEditing {
                Toggle("", isOn: $viewModel.isSelected)
                    .toggleStyle(SelectionToggleStyle())
                    .padding(.horizontal)
            }

            /// Main row content
            HStack(spacing: 20) {
                /// Thumbnail image
                viewModel.thumbnailImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .padding(.leading, 9)
                    .onTapGesture {
                        showingLoadAlert = true
                    }

                /// Labels
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        showingEditDialog = true
                    } label: {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 4) {
                        Text(viewModel.saveDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.grey.middleGrey)

                        /// Auto-save indicator
                        if viewModel.isAutoSave {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.subheadline)
                                .foregroundColor(.grey.middleGrey)
                        }
                    }
                }

                Spacer()

                /// Right-side icons
                HStack(spacing: 16.0) {
                    /// Pin indicator
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.isPinned.toggle()
                        }
                    } label: {
                        if #available(iOS 17.0, tvOS 17.0, *) {
                            Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                                .rotationEffect(viewModel.isPinned ? .degrees(0.0) : .degrees(45))
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    viewModel.isPinned ?
                                    viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor :
                                            .accentColor
                                )
                                .opacity(viewModel.isPinned ? 1 : 0.7)
                                .symbolEffect(.bounce, value: viewModel.isPinned)
                        } else {
                            Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                                .rotationEffect(viewModel.isPinned ? .degrees(0.0) : .degrees(45))
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    viewModel.isPinned ?
                                    viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor :
                                            .accentColor
                                )
                                .opacity(viewModel.isPinned ? 1 : 0.7)
                        }
                    }

                    /// Favorite heart icon
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.isFavorite.toggle()
                        }
                    } label: {
                        if #available(iOS 17.0, tvOS 17.0, *) {
                            Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                .resizable()
                                .frame(width: 24, height: 22)
                                .foregroundColor(viewModel.isFavorite ? .red : .accentColor)
                                .symbolEffect(.bounce, value: viewModel.isFavorite)
                        } else {
                            // Fallback on earlier versions
                            Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                .resizable()
                                .frame(width: 24, height: 22)
                                .foregroundColor(viewModel.isFavorite ? .red : .accentColor)
                        }
                    }
                }
                .padding(.trailing)
            }
        }
        .frame(height: 100)
#if !os(tvOS)
        .swipeCell(
            id: viewModel.id,
            cellWidth: UIScreen.main.bounds.width,
            leadingSideGroup: leadingSwipeActions(),
            trailingSideGroup: trailingSwipeActions(),
            currentUserInteractionCellID: $currentUserInteractionCellID
        )
#endif
        .uiKitAlert("Load Save State",
                    message: "",
                    isPresented: $showingLoadAlert,
                    buttons: {
            UIAlertAction(title: "Yes", style: .default, handler: {
                _ in
                viewModel.onLoad?()
                showingLoadAlert = false
            })
            UIAlertAction(title: "No", style: .destructive, handler: {
                _ in
                showingLoadAlert = false
            })
        })
        .uiKitAlert(
            "Edit Description",
            message: "Enter a custom description for this save state",
            isPresented: $showingEditDialog,
            textValue: Binding(
                get: { self.tempDescription ?? viewModel.description ?? "" },
                set: { newValue in
                    if newValue == nil || newValue!.isEmpty {
                        self.tempDescription = nil
                    } else {
                        self.tempDescription = newValue
                    }
                }
            ),
            preferredContentSize: CGSize(width: 300, height: 200),
            textField: { textField in
                textField.placeholder = "Description"
                textField.clearButtonMode = .whileEditing
                textField.autocapitalizationType = .sentences
            }
        ) {
            UIAlertAction(title: "Save", style: .default) { _ in
                // Only update the viewModel when Save is clicked
                viewModel.description = tempDescription
                // Reset the temp value
                tempDescription = nil
                showingEditDialog = false
            }
            UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                // Discard the temp value
                tempDescription = nil
                showingEditDialog = false
            }
        }
        .onChange(of: showingEditDialog) { isShowing in
            if isShowing {
                // Initialize the temp value when the dialog is shown
                tempDescription = viewModel.description
            }
        }
    }

    /// Leading (left) swipe actions
    #if !os(tvOS)
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
//            SwipeCellActionItem(
//                buttonView: {
//                    shareView()
//                },
//                buttonWidth: 80,
//                backgroundColor: .blue
//            ) {
//                // Share action
//                print("Share tapped")
//            },
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
                viewModel.onDelete?()
            }
        ]
    }
    #endif

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
