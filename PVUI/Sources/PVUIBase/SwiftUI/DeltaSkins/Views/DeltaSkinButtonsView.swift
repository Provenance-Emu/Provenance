import SwiftUI
import PVPrimitives

/// View that displays interactive buttons for a Delta skin
public struct DeltaSkinButtonsView: View {
    let skin: DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let onButtonPress: (String) -> Void

    @State private var pressedButtons: Set<String> = []
    @State private var skinImage: UIImage?
    @State private var isLoading = true
    @State private var error: Error?

    public init(
        skin: DeltaSkinProtocol,
        traits: DeltaSkinTraits,
        onButtonPress: @escaping (String) -> Void
    ) {
        self.skin = skin
        self.traits = traits
        self.onButtonPress = onButtonPress
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background skin image
                if let skinImage = skinImage {
                    Image(uiImage: skinImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Interactive buttons
                if let buttons = skin.buttons(for: traits),
                   let mappingSize = skin.mappingSize(for: traits) {
                    ForEach(buttons, id: \.id) { button in
                        buttonOverlay(for: button, mappingSize: mappingSize, containerSize: geometry.size)
                    }
                }

                // Loading indicator
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }

                // Error view
                if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)

                        Text("Error loading skin")
                            .font(.headline)

                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(12)
                }
            }
            .onAppear {
                loadSkinImage()
            }
        }
    }

    private func buttonOverlay(for button: DeltaSkinButton, mappingSize: CGSize, containerSize: CGSize) -> some View {
        let scale = min(
            containerSize.width / mappingSize.width,
            containerSize.height / mappingSize.height
        )

        let scaledFrame = CGRect(
            x: button.frame.minX * containerSize.width,
            y: button.frame.minY * containerSize.height,
            width: button.frame.width * containerSize.width,
            height: button.frame.height * containerSize.height
        )

        let isPressed = pressedButtons.contains(button.id)

        return Rectangle()
            .fill(Color.clear)
            .frame(
                width: scaledFrame.width,
                height: scaledFrame.height
            )
            .position(
                x: scaledFrame.midX,
                y: scaledFrame.midY
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(isPressed ? 0.5 : 0), lineWidth: 2)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            pressedButtons.insert(button.id)
                            handleButtonPress(button)
                        }
                    }
                    .onEnded { _ in
                        pressedButtons.remove(button.id)
                    }
            )
    }

    private func handleButtonPress(_ button: DeltaSkinButton) {
        switch button.input {
        case .single(let input):
            onButtonPress(input)
        case .directional(let mapping):
            // For directional inputs, we'd need to determine direction
            // For now, just use the first mapping
            if let firstInput = mapping.values.first {
                onButtonPress(firstInput)
            }
        }
    }

    private func loadSkinImage() {
        Task {
            do {
                let image = try await skin.image(for: traits)

                await MainActor.run {
                    self.skinImage = image
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
