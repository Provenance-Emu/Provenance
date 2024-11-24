//
//  ContinuesManagementListControlsView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/23/24.
//

import PVSwiftUI
import SwiftUI
import PVThemes
import DateRangePicker
import OpenDateInterval

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
    /// Date range for filtering
    @Published var dateRange: OpenDateInterval?
    /// Minimum selectable date
    @Published var minimumDate: Date?
    /// Maximum selectable date
    @Published var maximumDate: Date?
    /// Controls whether to show only favorite items
    @Published var filterFavoritesOnly: Bool = false
    /// Optional delete action
    var onDeleteSelected: (() -> Void)?

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
        currentPalette.settingsCellBackground?.swiftUIColor ?? Color(uiColor: .systemBackground)
    }

    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    /// Update date bounds based on save states
    func updateDateBounds(from saveStates: [SaveStateRowViewModel]) {
        minimumDate = saveStates.map({ $0.saveDate }).min()
        maximumDate = saveStates.map({ $0.saveDate }).max()

        /// Optionally set initial date range to full range
        dateRange = minimumDate.flatMap { min in
            maximumDate.map { max in
                OpenDateInterval(start: min, end: max)
            }
        }
    }

    public init(onDeleteSelected: (() -> Void)? = nil) {
        self.onDeleteSelected = onDeleteSelected
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
                                viewModel.filterFavoritesOnly ?
                                viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor :
                                .secondary.opacity(0.5)
                            )
                    }

                    /// Auto-saves toggle button
                    Button {
                        viewModel.isAutoSavesEnabled.toggle()
                    } label: {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(
                                viewModel.isAutoSavesEnabled ?
                                viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor :
                                .secondary.opacity(0.5)
                            )
                    }

                    /// Date range picker button
                    Button {
                        showingDatePicker.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(
                                viewModel.dateRange != nil ?
                                viewModel.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor :
                                .secondary.opacity(0.5)
                            )
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
                            /// Will be implemented later
                        }
                        .padding(.horizontal, 12)

                        Divider()
                            .frame(width: 1, height: 24)
                            .padding(.vertical, 4)
                            .background(viewModel.editButtonsBorderColor ?? .white)

                        Button("Clear All") {
                            /// Will be implemented later
                        }
                        .padding(.horizontal, 12)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.editButtonsBorderColor ?? .white, lineWidth: 1)
                    }
                }

                Spacer()

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
            }
            .frame(height: viewModel.isEditing ? nil : 4.0)  /// Maintain original height when not editing
        }
        .padding()
//        .background(viewModel.backgroundColor)
//        .shadow(
//            color: viewModel.shadowColor,
//            radius: 8,
//            x: 0,
//            y: 4
//        )
        .mask {
            /// This mask will clip the shadow on the top
            VStack(spacing: 0) {
                /// Solid rectangle for the top portion
                Rectangle()
                    .frame(height: 200.0)

                /// Gradient fade for the bottom shadow
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
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
        }
    }
}

/// Helper view for date range selection
private struct DateRangePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dateRange: ClosedRange<Date>

    var body: some View {
        VStack {
            DatePicker("Start Date", selection: .init(
                get: { dateRange.lowerBound },
                set: { dateRange = $0...dateRange.upperBound }
            ), displayedComponents: .date)

            DatePicker("End Date", selection: .init(
                get: { dateRange.upperBound },
                set: { dateRange = dateRange.lowerBound...$0 }
            ), displayedComponents: .date)
        }
        .padding()
        .navigationTitle("Select Date Range")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("List Controls", traits: .sizeThatFitsLayout) {
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
