#if canImport(UIKit)
import SwiftUI
import UIKit
import ImageIO

/// Renders an animated background for a skin using a frame sequence.
/// Supports `.frames`, `.apng`, and `.gif` animations via `TimelineView`.
/// APNG and GIF files are fully decoded — all frames and their per-frame display
/// durations are extracted using `CGImageSource` for accurate variable-rate playback.
struct DeltaSkinAnimatedBackgroundView: View {
    let animation: DeltaSkinBackgroundAnimation
    let skin: any DeltaSkinProtocol

    /// Decoded frames together with their individual display durations (seconds).
    @State private var frames: [(image: UIImage, duration: Double)] = []
    @State private var startDate: Date = Date()
    @Environment(\.scenePhase) private var scenePhase

    private var loops: Bool { animation.loops ?? true }

    /// Smallest per-frame duration; used as the TimelineView cadence.
    private var minimumInterval: Double {
        let fallback = 1.0 / Double(max(1, animation.fps ?? 8))
        return frames.map(\.duration).min() ?? fallback
    }

    // MARK: - Body

    var body: some View {
        Group {
            if frames.isEmpty {
                Color.clear
            } else if frames.count == 1 {
                Image(uiImage: frames[0].image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Drive animation via TimelineView; cadence = smallest frame duration
                TimelineView(.animation(minimumInterval: minimumInterval, paused: scenePhase != .active)) { context in
                    Image(uiImage: frame(at: context.date).image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active && !loops {
                        startDate = Date()
                    }
                }
            }
        }
        .task { await loadFrames() }
    }

    // MARK: - Frame selection

    /// Returns the frame that should be displayed at `date`, honouring per-frame durations.
    private func frame(at date: Date) -> (image: UIImage, duration: Double) {
        let elapsed = date.timeIntervalSince(startDate)
        let totalDuration = frames.map(\.duration).reduce(0, +)
        guard totalDuration > 0 else { return frames[0] }

        let t: Double = loops
            ? elapsed.truncatingRemainder(dividingBy: totalDuration)
            : min(elapsed, totalDuration)

        var accumulated = 0.0
        for f in frames {
            accumulated += f.duration
            if t < accumulated { return f }
        }
        return frames[frames.count - 1]
    }

    // MARK: - Frame loading

    private func loadFrames() async {
        var loaded: [(UIImage, Double)] = []
        let fallbackFPS = Double(max(1, animation.fps ?? 8))

        switch animation.type {
        case .frames:
            let names = animation.frames ?? []
            let frameDuration = 1.0 / fallbackFPS
            for name in names {
                if let img = try? await skin.loadThumbstickImage(named: name) {
                    loaded.append((img, frameDuration))
                }
            }

        case .apng, .gif:
            // Prefer raw bytes so CGImageSource can read embedded per-frame timing metadata.
            if let fileName = animation.file,
               let rawData = try? skin.loadAssetData(fileName) {
                loaded = extractFrames(from: rawData, fallbackFPS: fallbackFPS)
            }
            // Fall back to single-frame display if extraction failed.
            if loaded.isEmpty,
               let fileName = animation.file,
               let img = try? await skin.loadThumbstickImage(named: fileName) {
                loaded.append((img, 1.0 / fallbackFPS))
            }
        }

        await MainActor.run {
            frames = loaded
            startDate = Date()
        }
    }

    /// Decode all frames and their per-frame delays from raw APNG or GIF data.
    private func extractFrames(from data: Data, fallbackFPS: Double) -> [(UIImage, Double)] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return [] }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return [] }

        let scale = UIScreen.main.scale
        var result: [(UIImage, Double)] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            let duration = frameDuration(from: source, at: index, fallbackFPS: fallbackFPS)
            result.append((image, duration))
        }
        return result
    }

    /// Read the display duration for a single frame from the image-source properties.
    /// Returns `1/fallbackFPS` when no timing metadata is present.
    private func frameDuration(from source: CGImageSource, at index: Int, fallbackFPS: Double) -> Double {
        let fallback = 1.0 / fallbackFPS
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return fallback
        }
        // APNG
        if let d = (props[kCGImagePropertyPNGDictionary] as? [CFString: Any])?[kCGImagePropertyAPNGUnclampedDelayTime] as? Double, d > 0 { return d }
        if let d = (props[kCGImagePropertyPNGDictionary] as? [CFString: Any])?[kCGImagePropertyAPNGDelayTime] as? Double, d > 0 { return d }
        // GIF
        if let d = (props[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFUnclampedDelayTime] as? Double, d > 0 { return d }
        if let d = (props[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFDelayTime] as? Double, d > 0 { return d }
        return fallback
    }
}
#endif
