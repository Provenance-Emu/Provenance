// MARK: - tvOS Controller Guide View
// Shown inside empty library states to guide first-time users toward
// pairing a hardware controller before they start gaming.

import SwiftUI

// MARK: - Main Section View

/// Full controller-guide section embedded in the tvOS empty library view.
@available(tvOS 16.0, iOS 17.0, *)
struct TVControllerGuideSection: View {
    @State private var selectedEntry: ControllerGuideEntry?
    @FocusState private var focusedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            sectionHeader
            siriRemoteWarning
            controllerList
            if let entry = selectedEntry {
                pairingDetail(entry: entry)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Section header

    private var sectionHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.retroBlue, Color.retroPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.retroBlue.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("CONTROLLER REQUIRED")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundStyle(.white)

                Text("A hardware controller is strongly recommended for gaming")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    // MARK: Siri Remote warning card

    private var siriRemoteWarning: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: SiriRemoteLimitations.sfSymbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.retroYellow.opacity(0.8))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(SiriRemoteLimitations.headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.retroYellow)

                Text(SiriRemoteLimitations.summary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Text(SiriRemoteLimitations.menuButtonCaveat)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.retroYellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.retroYellow.opacity(0.25), lineWidth: 1)
                )
        )
        .frame(maxWidth: 700, alignment: .leading)
    }

    // MARK: Controller list

    private var controllerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPORTED CONTROLLERS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                ],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(ControllerGuideEntry.recommended) { entry in
                    ControllerEntryCard(
                        entry: entry,
                        isSelected: selectedEntry?.id == entry.id,
                        isFocused: focusedID == entry.id
                    )
                    .focusable()
                    .focused($focusedID, equals: entry.id)
                    .onLongPressGesture(minimumDuration: 0) { _ in }
                    perform: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if selectedEntry?.id == entry.id {
                                selectedEntry = nil
                            } else {
                                selectedEntry = entry
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 700, alignment: .leading)
        }
    }

    // MARK: Pairing detail panel

    private func pairingDetail(entry: ControllerGuideEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "list.number")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.retroBlue)

                Text("Pairing: \(entry.name)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(entry.pairingSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.retroBlue)
                            .frame(width: 20, alignment: .trailing)

                        Text(step)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let notes = entry.notes {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(notes)
                        .font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.retroBlue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.retroBlue.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 700, alignment: .leading)
    }
}

// MARK: - Compact Controller Tip Banner

/// A minimal single-line tip shown inside generic empty-state views.
/// Tapping/selecting it is not required — it is informational only.
@available(tvOS 16.0, iOS 17.0, *)
struct TVControllerTipBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.retroBlue)

            Text("Pair a hardware controller for the best gaming experience")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.retroBlue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.retroBlue.opacity(0.25), lineWidth: 1)
                )
        )
        .frame(maxWidth: 560, alignment: .leading)
    }
}

// MARK: - Controller Entry Card

@available(tvOS 16.0, iOS 17.0, *)
private struct ControllerEntryCard: View {
    let entry: ControllerGuideEntry
    let isSelected: Bool
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: entry.sfSymbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFocused ? .white : .white.opacity(0.9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(entry.manufacturer)
                        .font(.system(size: 11))
                        .foregroundStyle(isFocused ? accentColor : .white.opacity(0.5))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 10))
                Text(entry.connectionType.rawValue)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.white.opacity(0.45))

            if isSelected {
                Text("See pairing steps below")
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .shadow(color: isFocused ? accentColor.opacity(0.4) : .clear, radius: 10)
    }

    private var accentColor: Color {
        isSelected ? Color.retroPink : Color.retroBlue
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(accentColor.opacity(isFocused ? 0.18 : (isSelected ? 0.12 : 0.07)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        accentColor.opacity(isFocused ? 0.7 : (isSelected ? 0.45 : 0.2)),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
    }
}
