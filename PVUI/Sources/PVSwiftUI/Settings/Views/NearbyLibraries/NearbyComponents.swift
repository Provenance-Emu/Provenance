//
//  NearbyComponents.swift
//  PVSwiftUI
//
//  Rows, sections and the controller cursor shared by the Nearby Libraries
//  screens. Each row is a button (or a value-based navigation link), so it
//  works with touch, the tvOS focus engine and an iOS controller cursor.
//

#if os(iOS) || os(tvOS)
import PVThemes
import PVUIBase
import SwiftUI

// MARK: - Cursor in the environment

private struct NearbyCursorIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The item the controller cursor is on (iOS). A row draws its highlight when it is its own.
    var nearbyCursorID: String? {
        get { self[NearbyCursorIDKey.self] }
        set { self[NearbyCursorIDKey.self] = newValue }
    }
}

enum NearbyMetrics {
    #if os(tvOS)
    static let horizontalPadding: CGFloat = 80
    static let verticalPadding: CGFloat = 40
    static let sectionSpacing: CGFloat = 44
    static let rowSpacing: CGFloat = 14
    static let rowPadding = EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30)
    static let chipPadding = EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
    static let cornerRadius: CGFloat = 16
    static let artworkSize: CGFloat = 80
    static let iconWidth: CGFloat = 48
    static let highlightScale: CGFloat = 1.02
    static let maxContentWidth: CGFloat = 1400
    #else
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let rowSpacing: CGFloat = 8
    static let rowPadding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    static let chipPadding = EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
    static let cornerRadius: CGFloat = 12
    static let artworkSize: CGFloat = 44
    static let iconWidth: CGFloat = 32
    static let highlightScale: CGFloat = 1
    static let maxContentWidth: CGFloat = 900
    #endif
    static let highlightBorderWidth: CGFloat = 3
    static let restingBorderWidth: CGFloat = 1
    static let restingFillOpacity = 0.05
    static let highlightFillOpacity = 0.14
    static let restingBorderOpacity = 0.08
    static let secondaryTextOpacity = 0.7
    static let disabledOpacity = 0.45
    static let selectedBorderOpacity = 0.6
    static let selectedFillOpacity = 0.18
    static let pressedOpacity = 0.7
    static let glowOpacity = 0.35
    static let glowRadius: CGFloat = 10

    static let highlightGradient = LinearGradient(
        colors: [.retroPink, .retroBlue], startPoint: .leading, endPoint: .trailing
    )

    static func borderWidth(highlighted: Bool) -> CGFloat {
        highlighted ? highlightBorderWidth : restingBorderWidth
    }
}

// MARK: - Screen and section

/// One Nearby screen: a themed background (the TV layout presents it full screen over the
/// library), its sections in a scroll view that follows the controller cursor.
struct NearbyScreen<Content: View>: View {
    let title: String
    let cursorID: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: NearbyMetrics.sectionSpacing) {
                    content()
                }
                .padding(.horizontal, NearbyMetrics.horizontalPadding)
                .padding(.vertical, NearbyMetrics.verticalPadding)
                .frame(maxWidth: NearbyMetrics.maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: cursorID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: TVMediaCursorMetrics.scrollDuration)) {
                    proxy.scrollTo(newValue)
                }
            }
        }
        .background(TVMediaBackground().ignoresSafeArea())
        .environment(\.nearbyCursorID, cursorID)
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// A titled group of rows with an optional note under it.
struct NearbySection<Content: View>: View {
    var header: String?
    var footer: String?
    @ViewBuilder let content: () -> Content
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: NearbyMetrics.rowSpacing) {
            if let header {
                Text(header.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.retroPink.opacity(0.9))
            }
            content()
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(themeManager.nearbySecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A line of text in a section that is not a control (status, empty states).
struct NearbyNote: View {
    let text: String
    var systemImage: String?
    var tint: Color?
    var showsProgress = false
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView()
            } else if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tint ?? themeManager.nearbySecondaryText)
        .padding(NearbyMetrics.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ThemeManager {
    var nearbyPrimaryText: Color { Color(currentPalette.gameLibraryText) }
    var nearbySecondaryText: Color { Color(currentPalette.gameLibraryText).opacity(NearbyMetrics.secondaryTextOpacity) }
}

// MARK: - Button chrome

/// A full-width row. Lit while the tvOS focus engine or the iOS controller cursor is on it.
struct NearbyRowButtonStyle: ButtonStyle {
    let cursorID: String

    func makeBody(configuration: Configuration) -> some View {
        NearbyChrome(cursorID: cursorID, isPressed: configuration.isPressed, shape: .row) {
            configuration.label
                .padding(NearbyMetrics.rowPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A small capsule button that sits in a row of choices (access levels, server libraries,
/// Cancel and Add). `isSelected` marks the current choice.
struct NearbyChipButtonStyle: ButtonStyle {
    let cursorID: String
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        NearbyChrome(cursorID: cursorID, isPressed: configuration.isPressed, shape: .chip, isSelected: isSelected) {
            configuration.label
                .font(.callout.weight(.semibold))
                .foregroundStyle(labelColor(role: configuration.role))
                .padding(NearbyMetrics.chipPadding)
        }
    }
}

extension NearbyChipButtonStyle {
    private func labelColor(role: ButtonRole?) -> Color {
        if role == .destructive { return .red }
        return isSelected ? .retroBlue : ThemeManager.shared.nearbyPrimaryText
    }
}

private struct NearbyChrome<Label: View>: View {
    enum ChromeShape { case row, chip }

    let cursorID: String
    let isPressed: Bool
    let shape: ChromeShape
    var isSelected = false
    @ViewBuilder let label: () -> Label

    @Environment(\.nearbyCursorID) private var activeCursorID
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    @ObservedObject private var themeManager = ThemeManager.shared

    private var isHighlighted: Bool { isFocused || activeCursorID == cursorID }

    private var outline: AnyShape {
        switch shape {
        case .row: AnyShape(RoundedRectangle(cornerRadius: NearbyMetrics.cornerRadius, style: .continuous))
        case .chip: AnyShape(Capsule())
        }
    }

    var body: some View {
        label()
            .foregroundStyle(themeManager.nearbyPrimaryText)
            .background(outline.fill(fill))
            // AnyShape is not insettable: a centred stroke, half of it inside the shape.
            .overlay(outline.stroke(border, lineWidth: NearbyMetrics.borderWidth(highlighted: isHighlighted)))
            .contentShape(outline)
            .scaleEffect(isHighlighted ? NearbyMetrics.highlightScale : 1)
            .opacity(isEnabled ? (isPressed ? NearbyMetrics.pressedOpacity : 1) : NearbyMetrics.disabledOpacity)
            .shadow(color: glow, radius: NearbyMetrics.glowRadius)
            .animation(.easeOut(duration: TVMediaCursorMetrics.scrollDuration), value: isHighlighted)
            .tvOSDisableFocusEffect()
            .id(cursorID)
    }

    private var glow: Color {
        isHighlighted ? Color.retroPink.opacity(NearbyMetrics.glowOpacity) : .clear
    }

    private var fill: Color {
        if isSelected { return Color.retroBlue.opacity(NearbyMetrics.selectedFillOpacity) }
        let opacity = isHighlighted ? NearbyMetrics.highlightFillOpacity : NearbyMetrics.restingFillOpacity
        return Color.white.opacity(opacity)
    }

    private var border: AnyShapeStyle {
        if isHighlighted {
            return AnyShapeStyle(NearbyMetrics.highlightGradient)
        }
        if isSelected {
            return AnyShapeStyle(Color.retroBlue.opacity(NearbyMetrics.selectedBorderOpacity))
        }
        return AnyShapeStyle(Color.white.opacity(NearbyMetrics.restingBorderOpacity))
    }
}

// MARK: - Rows

/// Icon, title and an optional second line, the common row content.
struct NearbyRowLabel<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var subtitleColor: Color?
    var systemImage: String?
    @ViewBuilder var trailing: () -> Trailing
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 16) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: NearbyMetrics.iconWidth)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(subtitleColor ?? themeManager.nearbySecondaryText)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
    }
}

extension NearbyRowLabel where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage) { EmptyView() }
    }
}

/// A row that opens another Nearby screen.
struct NearbyLinkRow: View {
    let route: NearbyRoute
    let cursorID: String
    let title: String
    var subtitle: String?
    var systemImage: String?
    var badge: String?

    var body: some View {
        NavigationLink(value: route) {
            NearbyRowLabel(title: title, subtitle: subtitle, systemImage: systemImage) {
                if let badge {
                    Text(badge)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.retroBlue.opacity(0.25)))
                }
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .opacity(0.6)
            }
        }
        .buttonStyle(NearbyRowButtonStyle(cursorID: cursorID))
    }
}

/// A switch drawn as a row: pressing anywhere on it flips it.
struct NearbySwitchRow: View {
    let title: String
    var subtitle: String?
    let cursorID: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            NearbyRowLabel(title: title, subtitle: subtitle) {
                NearbySwitchIndicator(isOn: isOn)
            }
        }
        .buttonStyle(NearbyRowButtonStyle(cursorID: cursorID))
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
    }
}

private struct NearbySwitchIndicator: View {
    let isOn: Bool

    #if os(tvOS)
    private let size = CGSize(width: 76, height: 40)
    #else
    private let size = CGSize(width: 50, height: 30)
    #endif

    var body: some View {
        Capsule()
            .fill(isOn ? Color.green : Color.white.opacity(0.2))
            .frame(width: size.width, height: size.height)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .padding(3)
            }
            .animation(.easeOut(duration: TVMediaCursorMetrics.scrollDuration), value: isOn)
    }
}

/// A text field drawn as a row. On iOS it is plain text in the row's chrome, so the
/// controller cursor can light it; tvOS keeps its own field, which the focus engine lights.
struct NearbyTextFieldRow: View {
    let placeholder: String
    @Binding var text: String
    let cursorID: String
    var isSecure = false
    var editing: FocusState<String?>.Binding

    var body: some View {
        #if os(tvOS)
        field
        #else
        field
            .textFieldStyle(.plain)
            .padding(NearbyMetrics.rowPadding)
            .background(
                RoundedRectangle(cornerRadius: NearbyMetrics.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(NearbyMetrics.restingFillOpacity))
            )
            .overlay(NearbyTextFieldHighlight(cursorID: cursorID))
            .id(cursorID)
        #endif
    }

    @ViewBuilder
    private var field: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .autocorrectionDisabled()
        .focused(editing, equals: cursorID)
    }
}

#if os(iOS)
private struct NearbyTextFieldHighlight: View {
    let cursorID: String
    @Environment(\.nearbyCursorID) private var activeCursorID

    var body: some View {
        let isHighlighted = activeCursorID == cursorID
        RoundedRectangle(cornerRadius: NearbyMetrics.cornerRadius, style: .continuous)
            .strokeBorder(
                isHighlighted
                    ? AnyShapeStyle(NearbyMetrics.highlightGradient)
                    : AnyShapeStyle(Color.white.opacity(NearbyMetrics.restingBorderOpacity)),
                lineWidth: NearbyMetrics.borderWidth(highlighted: isHighlighted)
            )
    }
}
#endif

#endif
