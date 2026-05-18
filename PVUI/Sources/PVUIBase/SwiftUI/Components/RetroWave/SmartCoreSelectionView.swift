///
/// SmartCoreSelectionView.swift
/// Provenance
///
/// Rich, tile-based core selection sheet that surfaces capability metadata
/// and smart recommendations from ``CoreRecommendationEngine``.
/// Created by Claude on 2026-03-19.
///

import SwiftUI
import PVPrimitives
import PVCoreLoader

// MARK: - View Model

/// Input data for ``SmartCoreSelectionView``.
/// Construct one from ``CoreRecommendation`` objects produced by
/// ``CoreRecommendationEngine`` and pass it into the view.
public struct SmartCoreSelectionItem: Identifiable, Sendable {
    public let id: String            // core identifier
    public let coreName: String
    public let saveCount: Int
    public let rank: CoreRecommendation.Rank
    public let summary: String?
    public let highlightedCapabilities: [CoreCapability]
    public let recommendationTip: String?
    public let qualityRank: Int

    public init(
        id: String,
        coreName: String,
        saveCount: Int,
        rank: CoreRecommendation.Rank = .standard,
        summary: String? = nil,
        highlightedCapabilities: [CoreCapability] = [],
        recommendationTip: String? = nil,
        qualityRank: Int = 0
    ) {
        self.id = id
        self.coreName = coreName
        self.saveCount = saveCount
        self.rank = rank
        self.summary = summary
        self.highlightedCapabilities = highlightedCapabilities
        self.recommendationTip = recommendationTip
        self.qualityRank = qualityRank
    }

    /// Creates a ``SmartCoreSelectionItem`` from a ``CoreRecommendation``,
    /// using the given project name for display.
    public init(recommendation: CoreRecommendation, coreName: String) {
        self.id = recommendation.coreIdentifier
        self.coreName = coreName
        self.saveCount = recommendation.saveCount
        self.rank = recommendation.rank
        self.summary = recommendation.metadata?.summary
        self.highlightedCapabilities = recommendation.highlightedCapabilities
        self.recommendationTip = recommendation.recommendationTip
        self.qualityRank = recommendation.metadata?.qualityRank ?? 0
    }
}

// MARK: - SmartCoreSelectionView

/// A RetroWave-styled core selection sheet with capability chips,
/// recommendation badges and save state counts.
///
/// Replace the plain `RetroSelectionAlertView` with this view when the
/// ``CoreRecommendationEngine`` has metadata for at least one available core.
public struct SmartCoreSelectionView: View {

    // MARK: - Properties

    private let title: String
    private let message: String
    private let items: [SmartCoreSelectionItem]
    private let onSelect: (String) -> Void
    private let onCancel: () -> Void
    private let showSetDefault: Bool
    private let onSetDefault: ((String) -> Void)?

    @Binding private var isPresented: Bool
    @State private var glowOpacity: Double = 0.7

    #if os(tvOS) || os(iOS)
    @FocusState private var focusedItemId: String?
    #endif

    #if os(iOS)
    /// Gamepad input bridge so iOS controller users can navigate the
    /// retrowave core picker with d-pad / A / B.
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    /// Stable focus identifier for the Cancel button.
    private static let cancelFocusID = "__retro_core_picker_cancel__"

    // MARK: - Init

    public init(
        title: String,
        message: String,
        items: [SmartCoreSelectionItem],
        isPresented: Binding<Bool>,
        showSetDefault: Bool = true,
        onSelect: @escaping (String) -> Void,
        onSetDefault: ((String) -> Void)? = nil,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.items = items
        self._isPresented = isPresented
        self.showSetDefault = showSetDefault
        self.onSelect = onSelect
        self.onSetDefault = onSetDefault
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
                #if !os(tvOS)
                .onTapGesture { dismiss() }
                #endif

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                Divider()
                    .background(Color.retroBlue.opacity(0.4))

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            coreSelectionRow(for: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .frame(maxHeight: 500)

                Divider()
                    .background(Color.retroBlue.opacity(0.4))

                cancelButton
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.retroBlue, Color.retroPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.retroBlue.opacity(0.3 * glowOpacity), radius: 20, x: 0, y: 0)
            )
            .padding(.horizontal, 20)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
                #if os(tvOS) || os(iOS)
                focusedItemId = items.first?.id
                #endif
                #if os(iOS)
                // Block sidebar / root / home gamepad subscribers from
                // "leaking" A and d-pad input through to the views behind
                // the picker.
                GamepadManager.shared.isModalAlertPresented = true
                #endif
            }
            .onDisappear {
                #if os(iOS)
                GamepadManager.shared.isModalAlertPresented = false
                #endif
            }
            .tvOSDisableFocusEffect()
        }
        .tvOSDisableFocusEffect()
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard isPresented, gamepadManager.isControllerConnected else { return }
            switch event {
            case .verticalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveSelection(value: value)
            case .buttonPress(let isPressed):
                guard isPressed else { return }
                activateFocusedItem()
            case .buttonB(let isPressed):
                guard isPressed else { return }
                dismiss()
            default:
                break
            }
        }
        #endif
    }

    // MARK: - Subviews

    /// Binds list-row focus to ``CoreSelectionCard`` so tvOS border/scale track ``focusedItemId`` (environment alone is unreliable when `.focused` wraps the card).
    @ViewBuilder
    private func coreSelectionRow(for item: SmartCoreSelectionItem) -> some View {
        #if os(tvOS) || os(iOS)
        let isFocused = focusedItemId == item.id
        coreSelectionCard(for: item, isItemFocused: isFocused)
            .focused($focusedItemId, equals: item.id)
            .tvOSDisableFocusEffect()
            #if os(iOS)
            .overlay(controllerFocusRing(visible: isFocused, cornerRadius: 12))
            #endif
        #else
        coreSelectionCard(for: item, isItemFocused: false)
        #endif
    }

    /// Shared row content for ``coreSelectionRow(for:)``.
    private func coreSelectionCard(for item: SmartCoreSelectionItem, isItemFocused: Bool) -> CoreSelectionCard {
        CoreSelectionCard(
            item: item,
            showSetDefault: showSetDefault && onSetDefault != nil,
            isItemFocused: isItemFocused,
            onSelect: { onSelect(item.id) },
            onSetDefault: {
                onSetDefault?(item.id)
                onSelect(item.id)
            }
        )
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: Color.retroBlue.opacity(0.8), radius: 6, x: 0, y: 0)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var cancelButton: some View {
        Button(action: { dismiss() }) {
            Text("Cancel")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.retroPink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.retroPink.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        #if os(tvOS) || os(iOS)
        .focused($focusedItemId, equals: Self.cancelFocusID)
        #endif
        #if os(iOS)
        .overlay(controllerFocusRing(visible: focusedItemId == Self.cancelFocusID, cornerRadius: 10))
        #endif
    }

    // MARK: - Helpers

    private func dismiss() {
        isPresented = false
        onCancel()
    }

    // MARK: - iOS Controller Navigation

    #if os(iOS)
    /// Moves vertical d-pad focus through the core list and Cancel button.
    private func moveSelection(value: Float) {
        let ids = items.map(\.id) + [Self.cancelFocusID]
        guard !ids.isEmpty else { return }
        guard let current = focusedItemId, let idx = ids.firstIndex(of: current) else {
            focusedItemId = ids.first
            return
        }
        let isDown = value < 0
        let next = isDown ? idx + 1 : idx - 1
        guard next >= 0, next < ids.count else { return }
        focusedItemId = ids[next]
    }

    /// Activates the focused row or Cancel button on A press.
    private func activateFocusedItem() {
        guard let current = focusedItemId else {
            if let first = items.first { onSelect(first.id) }
            return
        }
        if current == Self.cancelFocusID {
            dismiss()
            return
        }
        if items.contains(where: { $0.id == current }) {
            onSelect(current)
        }
    }

    /// Retrowave gradient ring shown around the focused tile when a
    /// controller is driving navigation.
    @ViewBuilder
    private func controllerFocusRing(visible: Bool, cornerRadius: CGFloat) -> some View {
        if visible && gamepadManager.isControllerConnected {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [.retroPink, .retroBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .shadow(color: .retroPink.opacity(0.7), radius: 6, x: 0, y: 0)
                .allowsHitTesting(false)
        }
    }
    #endif
}

// MARK: - CoreSelectionCard

/// A single card displayed in the ``SmartCoreSelectionView`` list.
private struct CoreSelectionCard: View {
    let item: SmartCoreSelectionItem
    let showSetDefault: Bool
    /// Matches parent ``FocusState`` when the row is focused (required for tvOS custom border/scale; see ``SmartCoreSelectionView/coreSelectionRow(for:)``).
    let isItemFocused: Bool
    let onSelect: () -> Void
    let onSetDefault: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                topRow
                if let summary = item.summary, !summary.isEmpty {
                    summaryRow(summary)
                }
                if !item.highlightedCapabilities.isEmpty {
                    capabilityChips
                }
                if let tip = item.recommendationTip {
                    tipRow(tip)
                }
                bottomRow
            }
            .padding(14)
            .background(cardBackground)
            #if os(tvOS)
            .scaleEffect(isItemFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isItemFocused)
            #endif
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .contextMenu {
            if showSetDefault {
                Button {
                    onSetDefault()
                } label: {
                    Label("Set as Default for This System", systemImage: "star.fill")
                }
            }
        }
    }

    // MARK: Card sub-views

    private var topRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.coreName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                saveCountLabel
            }
            Spacer()
            rankBadge
        }
    }

    private var saveCountLabel: some View {
        Group {
            if item.saveCount > 0 {
                Label(
                    item.saveCount == 1 ? "1 save" : "\(item.saveCount) saves",
                    systemImage: "square.and.arrow.down"
                )
                .font(.system(size: 12))
                .foregroundColor(Color.retroGreen.opacity(0.9))
            } else {
                Text("No saves")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    @ViewBuilder
    private var rankBadge: some View {
        switch item.rank {
        case .recommended:
            Label("Recommended", systemImage: "star.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.retroYellow)
                .clipShape(Capsule())
        case .fallback:
            Text("Fallback")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        case .standard:
            EmptyView()
        }
    }

    private func summaryRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.7))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var capabilityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(item.highlightedCapabilities, id: \.self) { cap in
                    CapabilityChip(capability: cap)
                }
            }
        }
    }

    private func tipRow(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundColor(Color.retroYellow)
            Text(tip)
                .font(.system(size: 12))
                .foregroundColor(Color.retroYellow.opacity(0.9))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.retroYellow.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            // tvOS: a hint that long-press / hold sets this as the default. The
            // gesture itself is wired via `.contextMenu` on the card; without
            // this label users had no way to discover that the affordance
            // exists. iOS uses the standard contextMenu glyph from the system
            // so the same hint isn't needed there.
            if showSetDefault {
                #if os(tvOS)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("Hold to set default")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color.retroYellow.opacity(0.85))
                #endif
            }
            Spacer()
            Image(systemName: "play.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.retroBlue.opacity(0.8))
            Text("Launch")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.retroBlue.opacity(0.8))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(cardFillColor)
            .overlay(cardBorderStroke)
    }

    /// Rank-tinted 1pt stroke when unfocused; on tvOS, a thicker retro gradient when focused.
    @ViewBuilder
    private var cardBorderStroke: some View {
        #if os(tvOS)
        if isItemFocused {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.retroBlue, Color.retroPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        } else {
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: 1)
        }
        #else
        RoundedRectangle(cornerRadius: 12)
            .stroke(cardBorderColor, lineWidth: 1)
        #endif
    }

    private var cardFillColor: Color {
        switch item.rank {
        case .recommended: return Color.retroBlue.opacity(0.12)
        case .standard:    return Color.white.opacity(0.05)
        case .fallback:    return Color.white.opacity(0.03)
        }
    }

    private var cardBorderColor: Color {
        switch item.rank {
        case .recommended: return Color.retroBlue.opacity(0.5)
        case .standard:    return Color.white.opacity(0.1)
        case .fallback:    return Color.white.opacity(0.06)
        }
    }
}

// MARK: - CapabilityChip

/// Small pill badge shown beneath a core card for each highlighted capability.
private struct CapabilityChip: View {
    let capability: CoreCapability

    var body: some View {
        Label(capability.displayName, systemImage: capability.sfSymbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(chipColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chipColor.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(chipColor.opacity(0.35), lineWidth: 0.5)
            )
    }

    private var chipColor: Color {
        capability.isRequirement ? Color.orange : Color.retroCyan
    }
}

// MARK: - Hosting wrapper (UIKit integration)

/// Wraps ``SmartCoreSelectionView`` in a `View` suitable for
/// embedding in a `UIHostingController`.
public struct SmartCoreSelectionHostingView: View {
    let title: String
    let message: String
    let items: [SmartCoreSelectionItem]
    let showSetDefault: Bool
    let onSelect: (String) -> Void
    let onSetDefault: ((String) -> Void)?
    let onCancel: () -> Void

    @State private var isPresented = true

    public init(
        title: String,
        message: String,
        items: [SmartCoreSelectionItem],
        showSetDefault: Bool = true,
        onSelect: @escaping (String) -> Void,
        onSetDefault: ((String) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.items = items
        self.showSetDefault = showSetDefault
        self.onSelect = onSelect
        self.onSetDefault = onSetDefault
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            if isPresented {
                SmartCoreSelectionView(
                    title: title,
                    message: message,
                    items: items,
                    isPresented: $isPresented,
                    showSetDefault: showSetDefault,
                    onSelect: { id in
                        isPresented = false
                        onSelect(id)
                    },
                    onSetDefault: onSetDefault.map { handler in
                        { id in
                            isPresented = false
                            handler(id)
                        }
                    },
                    onCancel: {
                        isPresented = false
                        onCancel()
                    }
                )
            }
        }
    }
}
