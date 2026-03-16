//
//  AutoSaveFilmstripView.swift
//  PVUI
//
//  A filmstrip timeline presenting the autosave history for a game.
//  Triggered by long-pressing a stacked autosave card in the Recent Saves section.
//

#if canImport(SwiftUI)
import SwiftUI
import PVThemes

// MARK: - AutoSaveFilmstripView

/// Presents the autosave history for a game as a horizontal filmstrip timeline.
///
/// Each save appears as a thumbnail "frame". Vertical time-gap dividers between frames
/// show how much time passed between consecutive saves. Large gaps (for example, > 2 h)
/// make potential session boundaries and long breaks visually prominent.
///
/// The view is designed to be presented as a `.sheet` from `HomeContinueItemView`.
@available(iOS 15, tvOS 15, *)
struct AutoSaveFilmstripView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Display name of the game these saves belong to.
    let gameTitle: String?
    /// All saves to display, **newest first**. Must contain at least one item.
    let allSaves: [ContinueItemModel]
    /// Called when the user taps a thumbnail or the primary "Load" button.
    let onSelect: (ContinueItemModel) -> Void

    @State private var selectedID: String?

    // MARK: Constants

    private enum Layout {
        static let thumbnailWidth: CGFloat = 140
        static let thumbnailHeight: CGFloat = 105
        static let thumbnailCornerRadius: CGFloat = 8
        static let gapIndicatorWidth: CGFloat = 56
        static let headerHeight: CGFloat = 52
        static let filmstripVerticalPadding: CGFloat = 20
        static let frameHorizontalPadding: CGFloat = 20
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
                .background(accentGradient)

            filmstripArea
                .frame(maxHeight: .infinity)

            Divider()
                .background(accentGradient)

            actionBar
        }
        .background(panelBackground.ignoresSafeArea())
        .onAppear {
            selectedID = allSaves.first?.id
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Autosave History")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentGradient)
                if let title = gameTitle {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.6)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: Layout.headerHeight)
    }

    // MARK: - Filmstrip

    private var filmstripArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(allSaves.enumerated()), id: \.element.id) { index, save in
                        // Time-gap indicator before each save except the first.
                        if index > 0 {
                            timeGapIndicator(
                                between: allSaves[index - 1].date,
                                and: save.date
                            )
                        }
                        filmstripFrame(save: save, index: index)
                            .id(save.id)
                    }
                }
                .padding(.horizontal, Layout.frameHorizontalPadding)
                .padding(.vertical, Layout.filmstripVerticalPadding)
            }
            .onAppear {
                if let firstID = allSaves.first?.id {
                    proxy.scrollTo(firstID, anchor: .leading)
                }
            }
        }
    }

    /// A single thumbnail frame within the filmstrip.
    @ViewBuilder
    private func filmstripFrame(save: ContinueItemModel, index: Int) -> some View {
        let isSelected = selectedID == save.id

        Button {
            selectedID = save.id
        } label: {
            VStack(spacing: 6) {
                // Thumbnail image
                thumbnailImage(for: save)
                    .frame(width: Layout.thumbnailWidth, height: Layout.thumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius)
                            .strokeBorder(
                                isSelected
                                    ? AnyShapeStyle(accentGradient)
                                    : AnyShapeStyle(Color.clear),
                                lineWidth: isSelected ? 2.5 : 0
                            )
                    )
                    .shadow(
                        color: isSelected
                            ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.7)
                            : Color.clear,
                        radius: 6
                    )
                    .scaleEffect(isSelected ? 1.04 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                // Relative time label
                Text(save.date, style: .relative)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(
                            isSelected ? 1.0 : 0.55
                        )
                    )
                    .lineLimit(1)
                    .frame(width: Layout.thumbnailWidth)

                // "Newest" / numbered label
                Text(index == 0 ? "Latest" : "#\(index + 1)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        index == 0
                            ? AnyShapeStyle(accentGradient)
                            : AnyShapeStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.4))
                    )
            }
        }
        .buttonStyle(.plain)
    }

    /// Cached async thumbnail inside the filmstrip frame.
    @ViewBuilder
    private func thumbnailImage(for save: ContinueItemModel) -> some View {
        CachedAsyncImageView(
            url: save.imageURL,
            fallbackImage: UIImage.missingArtworkImage(gameTitle: save.gameTitle ?? "", ratio: 1),
            height: Layout.thumbnailHeight,
            zoomFactor: 1.0
        )
    }

    // MARK: - Time Gap Indicator

    /// Vertical divider between two saves annotated with the time elapsed between them.
    /// A gap exceeding `RealmContinuesDataDriver.sessionBoundaryInterval` (2 h) is shown
    /// as a prominent session-break indicator.
    private func timeGapIndicator(between newer: Date, and older: Date) -> some View {
        let gap = newer.timeIntervalSince(older)
        let isLargeGap = gap > RealmContinuesDataDriver.sessionBoundaryInterval

        return VStack(spacing: 4) {
            if isLargeGap {
                // Dashed separator for long breaks
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(RetroTheme.retroPurple.opacity(0.4))
                        .frame(width: 1, height: 12)
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 10))
                        .foregroundStyle(RetroTheme.retroPurple.opacity(0.7))
                    Rectangle()
                        .fill(RetroTheme.retroPurple.opacity(0.4))
                        .frame(width: 1, height: 12)
                }
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.3) ?? RetroTheme.retroPink.opacity(0.3),
                                RetroTheme.retroBlue.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1, height: 30)
            }

            Text(formatGap(gap))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(
                    isLargeGap
                        ? AnyShapeStyle(RetroTheme.retroPurple.opacity(0.8))
                        : AnyShapeStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.45))
                )
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: Layout.gapIndicatorWidth)
    }

    /// Human-readable gap string, e.g. "5 min", "1 h 20 m", "2 d".
    private func formatGap(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let days = hours / 24

        if days >= 1 {
            return "\(days)d \(hours % 24)h"
        } else if hours >= 1 {
            return "\(hours)h \(minutes % 60)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 16) {
            // Cancel / go back
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.25),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            // Load selected save
            Button {
                if let id = selectedID,
                   let save = allSaves.first(where: { $0.id == id }) {
                    onSelect(save)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Load Save")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentGradient)
                        .shadow(
                            color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.5),
                            radius: 6
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedID == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                RetroTheme.retroPurple,
                RetroTheme.retroBlue
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @ViewBuilder
    private var panelBackground: some View {
        ZStack {
            #if os(tvOS)
            Color(themeManager.currentPalette.dark
                ? UIColor.black.withAlphaComponent(0.95)
                : UIColor.gray.withAlphaComponent(0.97)
            )
            #else
            Color(themeManager.currentPalette.dark
                ? UIColor.black.withAlphaComponent(0.95)
                : UIColor.systemBackground.withAlphaComponent(0.97)
            )
            #endif
            RetroTheme.RetroGridView()
                .opacity(themeManager.currentPalette.dark ? 0.08 : 0.04)
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 15, tvOS 15, *)
struct AutoSaveFilmstripView_Previews: PreviewProvider {
    static var previews: some View {
        AutoSaveFilmstripView(
            gameTitle: "Super Mario World",
            allSaves: [
                ContinueItemModel(
                    id: "1", gameTitle: "Super Mario World",
                    imageURL: nil, date: Date(), systemIdentifier: "com.provenance.snes",
                    isAutosave: true, resolver: { nil }
                ),
                ContinueItemModel(
                    id: "2", gameTitle: "Super Mario World",
                    imageURL: nil, date: Date(timeIntervalSinceNow: -300), systemIdentifier: "com.provenance.snes",
                    isAutosave: true, resolver: { nil }
                ),
                ContinueItemModel(
                    id: "3", gameTitle: "Super Mario World",
                    imageURL: nil, date: Date(timeIntervalSinceNow: -900), systemIdentifier: "com.provenance.snes",
                    isAutosave: true, resolver: { nil }
                )
            ],
            onSelect: { _ in }
        )
    }
}
#endif
#endif
