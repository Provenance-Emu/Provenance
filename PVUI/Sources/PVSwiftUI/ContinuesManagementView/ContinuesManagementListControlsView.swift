//
//  ContinuesManagementListControlsView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import PVSwiftUI
import SwiftUI
import PVThemes
#if !os(tvOS)
import DateRangePicker
import OpenDateInterval
#endif

/// View model for the list controls
public class ContinuesManagementListControlsViewModel: ObservableObject {
    /// Controls whether auto-saves are enabled
    @Published var isAutoSavesEnabled: Bool = true
    /// Controls whether the view is in edit mode
    @Published var isEditing: Bool = false
    /// Controls the sort order of the list
    @Published var sortAscending: Bool = false
    /// Current visible month in the date picker
    @Published var currentMonth: Int = Calendar.current.component(.month, from: .now)
    /// Current visible year: Int = Calendar.current.component(.year, from: .now)
    @Published var currentYear: Int = Calendar.current.component(.year, from: .now)
    #if !os(tvOS)
    /// Date range for filtering
    @Published var dateRange: OpenDateInterval?
    #endif
    /// Minimum selectable date
    @Published var minimumDate: Date?
    /// Maximum selectable date
    @Published var maximumDate: Date?
    /// Controls whether to show only favorite items
    @Published var filterFavoritesOnly: Bool = false
    /// Optional delete action
    var onDeleteSelected: (() -> Void)?
    /// Actions for selection management
    var onSelectAll: (() -> Void)?
    var onClearAll: (() -> Void)?

    /// Shadow color for the controls view
    var shadowColor: Color {
        currentPalette.defaultTintColor?.swiftUIColor.opacity(0.1) ?? Color.accentColor.opacity(0.1)
    }

    var editButtonsBorderColor: Color? {
        currentPalette.defaultTintColor?.swiftUIColor
    }

    var autoSaveLabelColor: Color? {
        isAutoSavesEnabled ?
        currentPalette.switchON?.swiftUIColor :
        currentPalette.switchON?.swiftUIColor.opacity(0.75)
    }

    /// Computed property for edit button title
    var editButtonTitle: String {
        isEditing ? "Done" : "Edit"
    }

    var backgroundColor: Color {
        #if os(tvOS)
        currentPalette.settingsCellBackground?.swiftUIColor ?? Color.white
        #else
        currentPalette.settingsCellBackground?.swiftUIColor ?? Color(uiColor: .systemBackground)
        #endif
    }

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    /// Update date bounds based on save states
    func updateDateBounds(from saveStates: [SaveStateRowViewModel]) {
        minimumDate = saveStates.map({ $0.saveDate }).min()
        maximumDate = saveStates.map({ $0.saveDate }).max()

        #if !os(tvOS)
        /// Optionally set initial date range to full range
        dateRange = minimumDate.flatMap { min in
            maximumDate.map { max in
                OpenDateInterval(start: min, end: max)
            }
        }
        #endif
    }

    public init(
        onDeleteSelected: (() -> Void)? = nil,
        onSelectAll: (() -> Void)? = nil,
        onClearAll: (() -> Void)? = nil
    ) {
        self.onDeleteSelected = onDeleteSelected
        self.onSelectAll = onSelectAll
        self.onClearAll = onClearAll
    }

    /// Select all save states
    func selectAll() {
        onSelectAll?()
    }

    /// Clear all selections
    func clearAll() {
        onClearAll?()
    }
}

public struct ContinuesManagementListControlsView: View {
    /// View model containing the control states
    @ObservedObject var viewModel: ContinuesManagementListControlsViewModel
    /// State for showing date picker
    @State private var showingDatePicker = false

    public var body: some View {
        VStack(spacing: 12) {
            /// Top row with Edit/Done and Delete buttons
            HStack {
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.isEditing.toggle()
                    }) {
                        Text(viewModel.editButtonTitle)
                    }

                    if viewModel.isEditing {
                        Button(action: {
                            viewModel.onDeleteSelected?()
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()

                /// Filter buttons (always visible)
                HStack(spacing: 16) {
                    /// Favorites filter button
                    Button {
                        viewModel.filterFavoritesOnly.toggle()
                    } label: {
                        Image(systemName: viewModel.filterFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundStyle(
                                viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor
                            )
                    }

                    /// Auto-saves toggle button
                    Button {
                        viewModel.isAutoSavesEnabled.toggle()
                    } label: {
                        Image(systemName: viewModel.isAutoSavesEnabled ? "clock.badge.fill" : "clock.badge.checkmark")
                            .foregroundStyle(
                                viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor
                            )
                    }

                    /// Date range picker button
                    Button {
                        showingDatePicker.toggle()
                    } label: {
                        #if !os(tvOS)
                        Image(systemName: viewModel.dateRange != nil ? "calendar.badge.checkmark" : "calendar")
                            .foregroundStyle(
                                viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor
                            )
                        #endif
                    }

                    Divider()
                        .frame(height: 16)
                        .padding(.horizontal, -4)

                    Button {
                        viewModel.sortAscending.toggle()
                    } label: {
                        Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                    }
                }
            }

            /// Bottom row with selection and filter controls
            HStack {
                /// Edit mode buttons
                if viewModel.isEditing {
                    HStack(alignment: .center, spacing: 0) {
                        Button("Select All") {
                            viewModel.selectAll()
                        }
                        .padding(.horizontal, 12)

                        Divider()
                            .frame(width: 1, height: 24)
                            .padding(.vertical, 4)
                            .background(viewModel.editButtonsBorderColor ?? .white)

                        Button("Clear All") {
                            viewModel.clearAll()
                        }
                        .padding(.horizontal, 12)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.editButtonsBorderColor ?? .white, lineWidth: 1)
                    }
                }

                Spacer()

#if !os(tvOS)
                /// Date range display
                if let dateRange = viewModel.dateRange {
                    HStack(spacing: 8) {
                        /// Clear button
                        Button {
                            withAnimation {
                                viewModel.dateRange = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }

                        /// Date range text
                        Text("\(dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(dateRange.end?.formatted(date: .abbreviated, time: .omitted) ?? "Present")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
#endif
            }
            .frame(height: viewModel.isEditing ? nil : 4.0)  /// Maintain original height when not editing
        }
        .padding()
//        .background(viewModel.backgroundColor)
        .shadow(
            color: viewModel.shadowColor,
            radius: 8,
            x: 0,
            y: 4
        )
        .mask {
            /// This mask will clip the shadow on the top
            VStack(spacing: 0) {
                /// Solid rectangle for the top portion
                Rectangle()
                    .frame(height: 200.0)

                /// Gradient fade for the bottom shadow
                LinearGradient(
                    colors: [viewModel.shadowColor, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            #if !os(tvOS)
            NavigationView {
                DateRangePicker(
                    month: $viewModel.currentMonth,
                    year: $viewModel.currentYear,
                    selection: $viewModel.dateRange,
                    minimumDate: viewModel.minimumDate,
                    maximumDate: viewModel.maximumDate
                )
                .navigationTitle("Select Date Range")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingDatePicker = false
                        }
                    }
                }
            }
            #endif
        }
    }
}

#if DEBUG
// MARK: - Previews
@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("List Controls") {
    VStack(spacing: 20) {
        /// Normal mode
        let normalViewModel = ContinuesManagementListControlsViewModel()
        ContinuesManagementListControlsView(viewModel: normalViewModel)

        /// Auto-saves enabled
        let autoSaveViewModel = ContinuesManagementListControlsViewModel()
        ContinuesManagementListControlsView(viewModel: autoSaveViewModel)
            .onAppear {
                autoSaveViewModel.isAutoSavesEnabled = true
                autoSaveViewModel.isEditing = true
            }

        /// Descending sort order
        let sortViewModel = ContinuesManagementListControlsViewModel()
        ContinuesManagementListControlsView(viewModel: sortViewModel)
            .onAppear {
                sortViewModel.sortAscending = false
            }
    }
    .padding()
}

@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("Edit Mode", traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        /// Edit mode
        let editViewModel = ContinuesManagementListControlsViewModel()
        ContinuesManagementListControlsView(viewModel: editViewModel)
            .onAppear {
                editViewModel.isEditing = true
            }

        /// Auto-saves enabled
        let autoSaveViewModel = ContinuesManagementListControlsViewModel()
        ContinuesManagementListControlsView(viewModel: autoSaveViewModel)
            .onAppear {
                autoSaveViewModel.isAutoSavesEnabled = true
                autoSaveViewModel.isEditing = true
            }
    }
    .padding()
}

@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("Dark Mode") {
    VStack(spacing: 20) {
        let viewModel = ContinuesManagementListControlsViewModel()
        ContinuesManagementListControlsView(viewModel: viewModel)
            .onAppear {
                viewModel.isEditing = true
                viewModel.isAutoSavesEnabled = true
            }
    }
    .padding()
    .preferredColorScheme(.dark)
}

@available (iOS 17.0, macOS 10.15, tvOS 17.0, watchOS 6.0, *)
#Preview("Themes", traits: .sizeThatFitsLayout) {
    Group {
        /// Light theme
        ContinuesManagementListControlsView(viewModel: ContinuesManagementListControlsViewModel())

        /// Dark theme
        ContinuesManagementListControlsView(viewModel: ContinuesManagementListControlsViewModel())
            .preferredColorScheme(.dark)
    }
    .padding()
}
#endif
