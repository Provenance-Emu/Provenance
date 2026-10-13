//
//  ShaderThumbnailView.swift
//  PVUI
//
//  Small preview of a filter. Shows a rendered preview when a loader is
//  installed in the environment (`shaderPreviewLoader`), else a placeholder.
//

import SwiftUI
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

/// Supplies rendered filter previews to the UI.
public enum ShaderPreviewService {
    /// `nil` until a preview renderer is available: thumbnails show placeholders.
    public static var loader: ShaderPreviewLoader? { nil }
}
