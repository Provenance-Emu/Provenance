import SwiftUI
import UIKit

/// Renders an animated background for a skin using a frame sequence.
/// Supports `.frames` type animations via `TimelineView`.
/// `.apng` and `.gif` files are loaded and displayed as a static image (first frame only;
/// full animated APNG/GIF support can be added when needed).
struct DeltaSkinAnimatedBackgroundView: View {
    let animation: DeltaSkinBackgroundAnimation
    let skin: any DeltaSkinProtocol

    @State private var frames: [UIImage] = []
    @State private var startDate: Date = Date()
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
                // Drive animation via TimelineView date — no separate Timer needed
                TimelineView(.animation(minimumInterval: 1.0 / fps, paused: scenePhase != .active)) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let rawIndex = Int(elapsed * fps)
                    let frameIndex = loops
                        ? rawIndex % frames.count
                        : min(rawIndex, frames.count - 1)
                    Image(uiImage: frames[max(0, frameIndex)])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .onChange(of: scenePhase) { newPhase in
                    // Reset start date on foreground for non-looping animations
                    if newPhase == .active && !loops {
                        startDate = Date()
                    }
                }
            }
        }
        .onAppear { loadFrames() }
    }

    // MARK: - Frame loading

    private func loadFrames() {
        Task {
            var loaded: [UIImage] = []

            switch animation.type {
            case .frames:
                let names = animation.frames ?? []
                for name in names {
                    if let img = try? await skin.loadThumbstickImage(named: name) {
                        loaded.append(img)
                    }
                }

            case .apng, .gif:
                // Load single file; display first frame (full animation support TBD)
                if let fileName = animation.file,
                   let img = try? await skin.loadThumbstickImage(named: fileName) {
                    loaded.append(img)
                }
            }

            await MainActor.run {
                frames = loaded
                startDate = Date()
            }
        }
    }
}
