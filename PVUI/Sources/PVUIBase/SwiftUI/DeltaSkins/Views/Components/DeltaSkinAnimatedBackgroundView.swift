#if canImport(UIKit)
import SwiftUI
import UIKit
import ImageIO

/// Renders an animated background for a skin using a frame sequence.
/// Supports `.frames`, `.apng`, and `.gif` animations via `TimelineView`.
/// APNG and GIF files are fully decoded — all frames are extracted using `CGImageSource`.
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
        .task { await loadFrames() }
    }

    // MARK: - Frame loading

    private func loadFrames() async {
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
            // Extract all frames from the animated image using CGImageSource
            if let fileName = animation.file,
               let rawData = try? skin.loadAssetData(fileName) {
                loaded = extractFrames(from: rawData)
            }
            // Fall back to single-frame display if extraction failed
            if loaded.isEmpty,
               let fileName = animation.file,
               let img = try? await skin.loadThumbstickImage(named: fileName) {
                loaded.append(img)
            }
        }

        await MainActor.run {
            frames = loaded
            startDate = Date()
        }
    }

    /// Decode all frames from raw APNG or GIF data using CGImageSource.
    /// Falls back to a single frame when the source contains only one image.
    private func extractFrames(from data: Data) -> [UIImage] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return []
        }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return [] }

        let scale = UIScreen.main.scale
        var result: [UIImage] = []
        result.reserveCapacity(count)

        for index in 0 ..< count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }
            result.append(UIImage(cgImage: cgImage, scale: scale, orientation: .up))
        }
        return result
    }
}
#endif
