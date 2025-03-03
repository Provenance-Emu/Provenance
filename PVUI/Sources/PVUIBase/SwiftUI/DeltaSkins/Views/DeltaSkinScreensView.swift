import SwiftUI
import PVLogging

/// View that renders a DeltaSkin with its screens and buttons
public struct DeltaSkinScreensView: View {
    let skin: DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let containerSize: CGSize

    /// Whether to show debug overlays
    @Environment(\.debugSkinMappings) private var showDebug: Bool

    /// State for the loaded skin image
    @State private var skinImage: UIImage?
    @State private var loadingError: Error?

    @State private var screenGroups: [DeltaSkinScreenGroup]?

    public init(skin: DeltaSkinProtocol, traits: DeltaSkinTraits, containerSize: CGSize) {
        self.skin = skin
        self.traits = traits
        self.containerSize = containerSize
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base skin image
                if let skinImage {
                    Image(uiImage: skinImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                } else if let loadingError = loadingError {
                    Text("Failed to load skin: \(loadingError.localizedDescription)")
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                }

                // Screen groups overlay
                if let groups = screenGroups {
                    ForEach(groups, id: \.id) { group in
                        screenGroup(group, in: geometry)
                    }
                }
            }
        }
        .task {
            // Load skin image
            do {
                skinImage = try await skin.image(for: traits)
            } catch {
                loadingError = error
            }

            // Load screen groups
            screenGroups = skin.screenGroups(for: traits)
        }
    }

    @ViewBuilder
    private func screenGroup(_ group: DeltaSkinScreenGroup, in geometry: GeometryProxy) -> some View {
        ZStack {
            // Translucent background if needed
            if group.translucent ?? false {
                Rectangle()
                    .fill(.black.opacity(0.5))
            }

            // Screens in this group
            ForEach(group.screens, id: \.id) { screen in
                screenView(screen, in: geometry)
            }
        }
    }

    @ViewBuilder
    private func screenView(_ screen: DeltaSkinScreen, in geometry: GeometryProxy) -> some View {
        guard let outputFrame = screen.outputFrame else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ZStack {
                // Screen frame
                Rectangle()
                    .stroke(showDebug ? .blue : .clear, lineWidth: 2)
                    .frame(
                        width: outputFrame.width * geometry.size.width,
                        height: outputFrame.height * geometry.size.height
                    )

                // Debug info
                if showDebug {
                    VStack(alignment: .leading) {
                        Text(screen.id)
                            .font(.caption)
                        if let inputFrame = screen.inputFrame {
                            Text("In: \(formatRect(inputFrame))")
                                .font(.caption2)
                        }
                        Text("Out: \(formatRect(outputFrame))")
                            .font(.caption2)
                        Text("Place: \(screen.placement.rawValue)")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(4)
                    .background(.white.opacity(0.8))
                    .cornerRadius(4)
                }
            }
            .position(
                x: outputFrame.midX * geometry.size.width,
                y: outputFrame.midY * geometry.size.height
            )
        )
    }

    private func formatRect(_ rect: CGRect) -> String {
        String(format: "(%.1f, %.1f, %.1f, %.1f)",
               rect.origin.x, rect.origin.y,
               rect.size.width, rect.size.height)
    }
}
