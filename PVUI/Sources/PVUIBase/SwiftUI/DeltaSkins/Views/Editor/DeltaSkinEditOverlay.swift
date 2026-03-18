import SwiftUI

// MARK: - Edit Overlay

/// Interactive overlay for repositioning skin buttons.
///
/// Rendered on top of the skin preview when edit mode is active. Each
/// button is shown as a draggable rectangle. Tapping selects it and reveals
/// a coordinate-editing panel at the bottom of the screen.
///
/// - Note: Drag/resize gestures are iOS/macOS only (unavailable on tvOS).
struct DeltaSkinEditOverlay: View {
    @ObservedObject var viewModel: DeltaSkinEditorViewModel
    let size: CGSize
    var safeAreaInsets: EdgeInsets = EdgeInsets()

    // Per-button drag tracking (screen-space accumulated offset)
    @State private var dragOffsets: [Int: CGSize] = [:]

    var body: some View {
        if let mappingSize = viewModel.skin.mappingSize(for: viewModel.traits) {
            let availableWidth = size.width - safeAreaInsets.leading - safeAreaInsets.trailing
            let availableHeight = size.height - safeAreaInsets.top - safeAreaInsets.bottom
            let scale = min(
                availableWidth / mappingSize.width,
                availableHeight / mappingSize.height
            )
            let scaledWidth = mappingSize.width * scale
            let scaledHeight = mappingSize.height * scale
            let xOffset = safeAreaInsets.leading + (availableWidth - scaledWidth) / 2
            // Mirror DeltaSkinView layout: iPhone portrait is bottom-aligned; all others are centred
            let yOffset: CGFloat
            if viewModel.traits.device == .iphone && viewModel.traits.orientation == .portrait {
                yOffset = size.height - scaledHeight - safeAreaInsets.bottom
            } else {
                yOffset = safeAreaInsets.top + (availableHeight - scaledHeight) / 2
            }
            let origin = CGPoint(x: xOffset, y: yOffset)

            ZStack(alignment: .bottom) {
                // Button handles
                ForEach(viewModel.buttons.indices, id: \.self) { index in
                    buttonHandle(
                        index: index,
                        mappingSize: mappingSize,
                        scale: scale,
                        origin: origin
                    )
                }

                // Selected button detail panel
                if let selectedIndex = viewModel.selectedButtonIndex,
                   selectedIndex < viewModel.buttons.count {
                    selectedButtonPanel(index: selectedIndex)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.selectedButtonIndex)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Button handle

    @ViewBuilder
    private func buttonHandle(
        index: Int,
        mappingSize: CGSize,
        scale: CGFloat,
        origin: CGPoint
    ) -> some View {
        let frame = viewModel.frameForButton(at: index)
        let isSelected = viewModel.selectedButtonIndex == index
        let isModified = viewModel.isModified(at: index)

        // Convert mapping-space frame to screen-space, including live drag offset
        let liveOffset = dragOffsets[index] ?? .zero
        let screenX = frame.minX * scale + origin.x + liveOffset.width
        let screenY = frame.minY * scale + origin.y + liveOffset.height
        let screenW = frame.width * scale
        let screenH = frame.height * scale

        let borderColor: Color = isSelected ? .yellow : (isModified ? .orange : .green)

        ZStack {
            // Hit-area ghost (slightly larger, dimmer)
            Rectangle()
                .stroke(borderColor.opacity(0.25), lineWidth: 1)
                .background(borderColor.opacity(0.05))
                .frame(width: screenW + 40, height: screenH + 40)

            // Button frame
            Rectangle()
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1.5)
                .background(borderColor.opacity(isSelected ? 0.2 : 0.08))
                .frame(width: screenW, height: screenH)
                .overlay {
                    // Label
                    VStack(spacing: 2) {
                        Text(buttonLabel(index: index))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        if isModified {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 8))
                        }
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2)
                }

            // Move cursor icon at center
            if isSelected {
                Image(systemName: "move.3d")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.8), radius: 2)
            }
        }
        .position(x: screenX + screenW / 2, y: screenY + screenH / 2)
        .contentShape(Rectangle())
        #if !os(tvOS)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    dragOffsets[index] = value.translation
                    if viewModel.selectedButtonIndex != index {
                        viewModel.selectButton(at: index)
                    }
                }
                .onEnded { value in
                    viewModel.moveButton(
                        at: index,
                        screenDelta: value.translation,
                        scale: scale
                    )
                    dragOffsets.removeValue(forKey: index)
                }
        )
        #endif
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if viewModel.selectedButtonIndex == index {
                    viewModel.clearSelection()
                } else {
                    viewModel.selectButton(at: index)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buttonLabel(index: index))
        .accessibilityValue({
            let f = viewModel.frameForButton(at: index)
            return String(format: "X: %.0f Y: %.0f W: %.0f H: %.0f", f.minX, f.minY, f.width, f.height)
        }())
        .accessibilityHint(isSelected ? "Double-tap to deselect" : "Double-tap to select")
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: dragOffsets[index])
    }

    // MARK: - Selected button panel

    @ViewBuilder
    private func selectedButtonPanel(index: Int) -> some View {
        let frame = viewModel.frameForButton(at: index)
        let isModified = viewModel.isModified(at: index)

        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label(buttonLabel(index: index), systemImage: "square.dashed")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if isModified {
                    Button {
                        withAnimation {
                            viewModel.resetButton(at: index)
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation {
                        viewModel.clearSelection()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Coordinate fields
            HStack(spacing: 12) {
                coordinateField(label: "X", value: frame.minX) { newVal in
                    viewModel.setFrame(CGRect(x: newVal, y: frame.minY, width: frame.width, height: frame.height), for: index)
                }
                coordinateField(label: "Y", value: frame.minY) { newVal in
                    viewModel.setFrame(CGRect(x: frame.minX, y: newVal, width: frame.width, height: frame.height), for: index)
                }
                coordinateField(label: "W", value: frame.width) { newVal in
                    viewModel.setFrame(CGRect(x: frame.minX, y: frame.minY, width: max(1, newVal), height: frame.height), for: index)
                }
                coordinateField(label: "H", value: frame.height) { newVal in
                    viewModel.setFrame(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: max(1, newVal)), for: index)
                }
            }

            if isModified {
                Text("Modified from original")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Coordinate stepper field

    @ViewBuilder
    private func coordinateField(
        label: String,
        value: CGFloat,
        onChange: @escaping (CGFloat) -> Void
    ) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                Button {
                    // Snap to nearest integer baseline before stepping to avoid
                    // fractional drift when drag produces sub-pixel mapping values.
                    onChange(round(value) - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)

                Text(String(format: "%.0f", value))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(minWidth: 34)
                    .multilineTextAlignment(.center)

                Button {
                    onChange(round(value) + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func buttonLabel(index: Int) -> String {
        let button = viewModel.buttons[safe: index]
        switch button?.input {
        case .single(let name):
            return name.uppercased()
        case .directional:
            return "DPAD"
        case nil:
            return "BTN\(index)"
        }
    }
}

// MARK: - Bounds indicator bar

/// Compact summary bar showing how many buttons have been repositioned.
struct DeltaSkinEditorStatusBar: View {
    @ObservedObject var viewModel: DeltaSkinEditorViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.and.ruler")
                .font(.caption)

            if viewModel.hasChanges {
                Text("\(viewModel.modifiedFrames.count) button\(viewModel.modifiedFrames.count == 1 ? "" : "s") repositioned")
                    .font(.caption)
            } else {
                #if os(tvOS)
                Text("Select a button to inspect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #else
                Text("Drag buttons to reposition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }

            Spacer()

            if viewModel.hasChanges {
                Button("Reset All") {
                    withAnimation {
                        viewModel.resetAll()
                    }
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview

#Preview {
    DeltaSkinEditOverlay(
        viewModel: DeltaSkinEditorViewModel(
            skin: MockDeltaSkin(),
            traits: DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .portrait)
        ),
        size: CGSize(width: 390, height: 844)
    )
    .background(Color.black)
}
