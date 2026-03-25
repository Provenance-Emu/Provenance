import SwiftUI

// MARK: - Edit-mode overlay

/// An overlay rendered on top of `DeltaSkinView` when edit mode is active.
///
/// Each button gets a semi-transparent drag handle the user can drag to reposition.
/// Offsets are saved to `DeltaSkinButtonOffsets` on drag end.
///
/// tvOS: the drag handles are rendered for visual affordance, but `DragGesture` is
/// not available on tvOS, so actual repositioning is iOS-only.
struct DeltaSkinEditModeOverlay: View {

    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let mappingSize: CGSize
    let containerSize: CGSize
    let buttonOffsets: DeltaSkinButtonOffsets
    let onOffsetChanged: (String, CGPoint) -> Void

    /// Currently dragging button id → accumulated drag translation in screen points.
    @State private var dragTranslations: [String: CGSize] = [:]

    var body: some View {
        ZStack {
            // Dim background so it's clear the layout is being edited
            Color.black.opacity(0.35)
                .allowsHitTesting(false)

            if let buttons = skin.buttons(for: traits) {
                ForEach(buttons, id: \.id) { button in
                    editHandle(for: button)
                }
            }
        }
    }

    // MARK: - Per-button handle

    @ViewBuilder
    private func editHandle(for button: DeltaSkinButton) -> some View {
        let savedOffset = buttonOffsets.offset(for: button.id, skinIdentifier: skin.identifier)
        let dragOffset = dragTranslations[button.id] ?? .zero

        // Compute the screen-space frame of the button (with saved offset applied)
        let screenFrame = screenFrame(for: button, savedOffset: savedOffset)

        // Convert the live drag translation to normalized space so we can preview
        let liveNormalizedOffset = normalizedOffset(fromScreenDelta: CGSize(
            width: dragOffset.width,
            height: dragOffset.height
        ))
        let totalOffset = CGPoint(
            x: savedOffset.x + liveNormalizedOffset.x,
            y: savedOffset.y + liveNormalizedOffset.y
        )
        let liveFrame = screenFrame(for: button, savedOffset: totalOffset)

        Group {
            // Highlight rectangle
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                )
                .frame(width: liveFrame.width, height: liveFrame.height)
                .position(x: liveFrame.midX, y: liveFrame.midY)
                .allowsHitTesting(false)

            // Drag handle (center icon + label)
            dragHandleView(for: button, savedOffset: savedOffset, liveFrame: liveFrame)
        }
    }

    @ViewBuilder
    private func dragHandleView(for button: DeltaSkinButton, savedOffset: CGPoint, liveFrame: CGRect) -> some View {
        #if os(tvOS)
        // tvOS: no drag gesture, just show indicator
        Image(systemName: "move.3d")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(4)
            .background(Color.black.opacity(0.6))
            .clipShape(Circle())
            .position(x: liveFrame.midX, y: liveFrame.midY)
            .allowsHitTesting(false)
        #else
        Image(systemName: "move.3d")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(4)
            .background(Color.black.opacity(0.6))
            .clipShape(Circle())
            .position(x: liveFrame.midX, y: liveFrame.midY)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        dragTranslations[button.id] = value.translation
                    }
                    .onEnded { value in
                        // Convert screen delta to normalized offset
                        let delta = normalizedOffset(fromScreenDelta: value.translation)
                        let newOffset = CGPoint(
                            x: savedOffset.x + delta.x,
                            y: savedOffset.y + delta.y
                        )
                        onOffsetChanged(button.id, newOffset)
                        dragTranslations.removeValue(forKey: button.id)
                    }
            )
        #endif
    }

    // MARK: - Coordinate helpers

    /// Compute the screen-space frame for a button given its base frame and a normalized offset.
    private func screenFrame(for button: DeltaSkinButton, savedOffset: CGPoint) -> CGRect {
        let adjustedFrame = CGRect(
            x: button.frame.minX + savedOffset.x,
            y: button.frame.minY + savedOffset.y,
            width: button.frame.width,
            height: button.frame.height
        )
        // Scale from mappingSize space to containerSize space
        let scaleX = containerSize.width / mappingSize.width
        let scaleY = containerSize.height / mappingSize.height
        return CGRect(
            x: adjustedFrame.minX * scaleX,
            y: adjustedFrame.minY * scaleY,
            width: adjustedFrame.width * scaleX,
            height: adjustedFrame.height * scaleY
        )
    }

    /// Convert a screen-space drag delta (points) to a normalized mappingSize delta.
    private func normalizedOffset(fromScreenDelta delta: CGSize) -> CGPoint {
        guard containerSize.width > 0, containerSize.height > 0 else { return .zero }
        return CGPoint(
            x: (delta.width / containerSize.width) * mappingSize.width,
            y: (delta.height / containerSize.height) * mappingSize.height
        )
    }
}

// MARK: - "Edit Layout" / "Done" floating button

/// A pill-shaped button shown during edit mode and a separate "Reset" link.
struct DeltaSkinEditModeToolbar: View {
    @Binding var isEditMode: Bool
    let skinIdentifier: String
    let buttonOffsets: DeltaSkinButtonOffsets
    let hasCustomOffsets: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Edit / Done toggle
            Button(action: { isEditMode.toggle() }) {
                Label(
                    isEditMode ? "Done" : "Edit Layout",
                    systemImage: isEditMode ? "checkmark.circle.fill" : "arrow.up.and.down.and.arrow.left.and.right"
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isEditMode ? Color.green.opacity(0.85) : Color.black.opacity(0.6))
                .clipShape(Capsule())
            }

            // Reset button — only shown in edit mode when there are custom offsets
            if isEditMode && hasCustomOffsets {
                Button(action: {
                    Task { @MainActor in
                        buttonOffsets.resetOffsets(for: skinIdentifier)
                    }
                }) {
                    Label("Reset to Default", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.65))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
