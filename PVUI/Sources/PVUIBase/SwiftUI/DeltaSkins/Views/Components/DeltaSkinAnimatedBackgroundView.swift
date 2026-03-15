import SwiftUI
import UIKit

/// Renders an animated background for a skin using a frame sequence.
/// Supports `.frames` type animations via `TimelineView`. APNG and GIF
/// files are rendered with `Image(uiImage:)` using the first frame only
/// (full animated APNG/GIF support can be added when needed).
struct DeltaSkinAnimatedBackgroundView: View {
    let animation: DeltaSkinBackgroundAnimation
    let skin: any DeltaSkinProtocol

    @State private var frames: [UIImage] = []
    @State private var currentFrame: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    private var fps: Double { max(1, animation.fps ?? 8) }
    private var loops: Bool { animation.loops ?? true }

    var body: some View {
        Group {
            if frames.isEmpty {
                // Transparent placeholder while loading
                Color.clear
            } else if frames.count == 1 {
                Image(uiImage: frames[0])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Drive animation via TimelineView
                TimelineView(.animation(minimumInterval: 1.0 / fps, paused: scenePhase != .active)) { _ in
                    Image(uiImage: frames[currentFrame])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .onChange(of: scenePhase) { newPhase in
                    // TimelineView pauses automatically; reset frame on foreground if needed
                    if newPhase == .active && !loops {
                        currentFrame = 0
                    }
                }
                // Advance frame outside of TimelineView body to avoid rendering cycle issues
                .onReceive(
                    Timer.publish(every: 1.0 / fps, on: .main, in: .common).autoconnect()
                ) { _ in
                    guard scenePhase == .active else { return }
                    guard frames.count > 1 else { return }
                    if loops || currentFrame < frames.count - 1 {
                        currentFrame = (currentFrame + 1) % frames.count
                    }
                }
            }
        }
        .onAppear { loadFrames() }
    }

    // MARK: - Frame loading

    private func loadFrames() {
        let names = animation.frames ?? []
        guard !names.isEmpty else { return }

        Task {
            var loaded: [UIImage] = []
            for name in names {
                if let img = try? await skin.loadThumbstickImage(named: name) {
                    loaded.append(img)
                }
            }
            await MainActor.run {
                frames = loaded
                currentFrame = 0
            }
        }
    }
}
