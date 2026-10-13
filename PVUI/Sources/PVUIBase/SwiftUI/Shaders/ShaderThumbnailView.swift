//
//  ShaderThumbnailView.swift
//  PVUI
//
//  Small preview of a filter. Shows a rendered preview when a loader is
//  installed in the environment (`shaderPreviewLoader`), else a placeholder.
//

import SwiftUI
import Metal
import PVShaders

/// Renders (or fetches from cache) a preview image of `entry` at a pixel size.
public typealias ShaderPreviewLoader = @Sendable (ShaderCatalogEntry, CGSize) async -> CGImage?

private struct ShaderPreviewLoaderKey: EnvironmentKey {
    static let defaultValue: ShaderPreviewLoader? = nil
}

public extension EnvironmentValues {
    /// Supplies filter previews to thumbnails and the parameter editor.
    var shaderPreviewLoader: ShaderPreviewLoader? {
        get { self[ShaderPreviewLoaderKey.self] }
        set { self[ShaderPreviewLoaderKey.self] = newValue }
    }
}

struct ShaderThumbnailView: View {
    let entry: ShaderCatalogEntry
    let size: CGSize
    /// Changes when the preview must be re-rendered (for example after a parameter edit).
    var revision: Int = 0

    @Environment(\.shaderPreviewLoader) private var loader
    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    private static let cornerRadius: CGFloat = 6

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .task(id: TaskKey(id: entry.id, revision: revision)) {
            guard let loader else { return }
            let pixels = CGSize(width: size.width * displayScale, height: size.height * displayScale)
            let rendered = await loader(entry, pixels)
            if !Task.isCancelled { image = rendered }
        }
    }

    private struct TaskKey: Equatable {
        let id: ShaderID
        let revision: Int
    }

    private var placeholder: some View {
        // Stable per filter (hashValue is seeded per launch).
        let hue = Double(entry.id.rawValue.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }) / 360
        return LinearGradient(colors: [Color(hue: hue, saturation: 0.5, brightness: 0.45),
                                       Color(hue: hue, saturation: 0.6, brightness: 0.2)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: symbol).foregroundColor(.white.opacity(0.8)))
    }

    private var symbol: String {
        let looks = entry.looks
        if looks.contains(.crt) { return "tv" }
        if looks.contains(.lcd) || looks.contains(.handheld) { return "gamecontroller" }
        if looks.contains(.vhs) { return "videoprojector" }
        if looks.contains(.pixelArt) { return "square.grid.3x3" }
        if looks.contains(.bezel) { return "rectangle.inset.filled" }
        return "camera.filters"
    }
}

public extension View {
    /// Installs the shared filter-preview loader for thumbnails and editors below this view.
    func shaderPreviews() -> some View {
        environment(\.shaderPreviewLoader, ShaderPreviewService.loader)
    }
}

/// Supplies rendered filter previews to the UI: the paused game's frame when one is
/// available, else a placeholder (sample scene or test pattern).
public enum ShaderPreviewService {
    /// `UserDefaults` key: preview over the test pattern instead of the sample scene.
    public static let usesTestPatternKey = "shaderPreviewUsesTestPattern"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var gameFrame: ShaderPreviewSource?
    nonisolated(unsafe) private static var frameIdentity = 0

    private static let cache: ShaderPreviewCache? = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = try? ShaderPreviewRenderer(device: device) else { return nil }
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ShaderPreviews", isDirectory: true)
        return ShaderPreviewCache(renderer: renderer, diskDirectory: directory)
    }()

    /// Publishes the paused game's frame (`nil` when the game ends).
    public static func setGameFrame(_ texture: MTLTexture?) {
        lock.lock()
        defer { lock.unlock() }
        frameIdentity += 1
        gameFrame = texture.map { .frame(texture: $0, identity: frameIdentity) }
    }

    /// What previews are drawn over right now.
    public static var currentSource: ShaderPreviewSource {
        lock.lock()
        defer { lock.unlock() }
        if let gameFrame { return gameFrame }
        return UserDefaults.standard.bool(forKey: usesTestPatternKey) ? .testPattern : .sampleScene
    }

    public static var loader: ShaderPreviewLoader? {
        guard let cache else { return nil }
        return { entry, size in
            let values = await MainActor.run {
                let store = ShaderLibraryStore.shared
                return Dictionary(entry.parameters.map { ($0.name, store.value(of: $0, in: entry.id)) },
                                  uniquingKeysWith: { first, _ in first })
            }
            return await cache.preview(for: entry, source: currentSource, size: size,
                                       parameterValue: { values[$0.name] ?? $0.initial })
        }
    }
}
