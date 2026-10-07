// DualScreenSourceMapping.swift
// PVUI
//
// Pure helpers for the Metal dual-screen renderer: which part of a DS core's
// framebuffer texture each skin screen samples, and the texture coordinates
// that sample it upright.

import CoreGraphics
import PVCoreBridge

/// Per-vertex texture coordinates for one dual-screen quad.
struct DualScreenTextureCoordinates: Equatable, Sendable {
    let u0: Float
    let u1: Float
    /// V sampled at the quad's top edge.
    let vTop: Float
    /// V sampled at the quad's bottom edge.
    let vBottom: Float
}

enum DualScreenSourceMapping {
    /// The framebuffer DeltaSkin DS `inputFrame`s are authored against: the two
    /// screens stacked top over bottom with no gap (256×384).
    static let skinFramebufferConvention = NDSScreenLayout.default

    /// Largest relative difference between the horizontal and vertical texture
    /// scale factors still accepted as "the texture is this layout".
    static let proportionTolerance: CGFloat = 0.02

    /// Resolves the region of the core's framebuffer, in native DS pixels, that a
    /// skin screen shows.
    ///
    /// A skin `inputFrame` is read as "this DS screen, cropped like so" in the stacked
    /// skin convention and re-based onto the core's actual layout, so a core using a
    /// gap or a side-by-side layout still feeds a top/bottom skin correctly. A frame
    /// that is missing, empty or spans both screens falls back to `defaultScreen`.
    ///
    /// - Parameters:
    ///   - skinInputFrame: the skin screen's `inputFrame`, if any.
    ///   - defaultScreen: the DS screen to show when the input frame does not name one.
    ///   - swapped: `true` to show the other DS screen (frontend screen swap).
    ///   - layout: the layout the core is emitting.
    /// - Returns: `nil` when the chosen screen is not present in the framebuffer.
    static func sourceRect(skinInputFrame: CGRect?,
                           defaultScreen: NDSScreen,
                           swapped: Bool,
                           layout: NDSScreenLayout) -> CGRect? {
        let screenBounds = CGRect(x: 0, y: 0,
                                  width: NDSScreenLayout.screenWidth,
                                  height: NDSScreenLayout.screenHeight)
        var screen = defaultScreen
        var crop = screenBounds

        if let inputFrame = skinInputFrame, !inputFrame.isEmpty,
           inputFrame.height <= NDSScreenLayout.screenHeight {
            let named: NDSScreen = inputFrame.midY < NDSScreenLayout.screenHeight ? .top : .bottom
            if let conventionFrame = skinFramebufferConvention.frame(of: named) {
                let local = inputFrame
                    .offsetBy(dx: -conventionFrame.minX, dy: -conventionFrame.minY)
                    .intersection(screenBounds)
                if !local.isNull, !local.isEmpty {
                    screen = named
                    crop = local
                }
            }
        }

        if swapped {
            screen = screen.other
        }
        guard let target = layout.frame(of: screen) else { return nil }
        return crop.offsetBy(dx: target.minX, dy: target.minY)
    }

    /// Normalises a native-pixel source rect for sampling the texture actually bound.
    ///
    /// The texture holds the core's whole framebuffer at some internal resolution
    /// scale (native DeSmuME reports a padded 2048×2048 `bufferSize`, but the texture
    /// is sized to its screen rect). The rect is scaled by `textureSize /
    /// framebufferSize` and divided by `textureSize`, which keeps it valid at any
    /// resolution scale.
    ///
    /// - Returns: `nil` when the texture's proportions disagree with the layout — the
    ///   core has not yet reported its real geometry, or its layout options changed —
    ///   so the caller can fall back to a plain blit instead of sampling garbage.
    static func normalizedSourceRect(_ rect: CGRect,
                                     framebufferSize: CGSize,
                                     textureSize: CGSize) -> CGRect? {
        guard framebufferSize.width > 0, framebufferSize.height > 0,
              textureSize.width > 0, textureSize.height > 0 else { return nil }
        let scaleX = textureSize.width / framebufferSize.width
        let scaleY = textureSize.height / framebufferSize.height
        guard abs(scaleX - scaleY) / max(scaleX, scaleY) <= proportionTolerance else { return nil }
        return CGRect(x: rect.minX * scaleX / textureSize.width,
                      y: rect.minY * scaleY / textureSize.height,
                      width: rect.width * scaleX / textureSize.width,
                      height: rect.height * scaleY / textureSize.height)
    }

    /// Texture coordinates that draw `normalizedRect` upright on a quad.
    ///
    /// Metal samples with v = 0 at the texture's first row. Software and Vulkan
    /// frames store the image top row first; OpenGL frames store it bottom row
    /// first, which mirrors every region vertically.
    static func textureCoordinates(for normalizedRect: CGRect,
                                   sourceIsBottomUp: Bool) -> DualScreenTextureCoordinates {
        let top = sourceIsBottomUp ? 1 - normalizedRect.minY : normalizedRect.minY
        let bottom = sourceIsBottomUp ? 1 - normalizedRect.maxY : normalizedRect.maxY
        return DualScreenTextureCoordinates(u0: Float(normalizedRect.minX),
                                            u1: Float(normalizedRect.maxX),
                                            vTop: Float(top),
                                            vBottom: Float(bottom))
    }
}
