//
//  GameExternalOutputView.swift
//  PVUI
//
//  The game picture on a second screen.
//

#if os(iOS)
import UIKit
import Metal
import QuartzCore
import PVLogging
import PVSettings
import PVShaders
import SkinKitCore
import SkinKitUI

/// A Metal-backed view on a second screen. `PVMetalViewController` draws every game frame
/// into it as well as into the device's own view, so the device's view hierarchy (skins,
/// viewport frames) is left exactly as it is with no external display.
final class GameExternalOutputView: UIView {

    override class var layerClass: AnyClass { CAMetalLayer.self }

    /// This screen's own filter. Fed by `PVEmulatorViewController.updateExternalDisplayFilter()`.
    let filter: ShaderPostProcessor

    var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    /// The TV around the picture: glass, frame, reflections and room. Runs after `filter`,
    /// which then draws only the tube (see `PVMetalViewController.presentOnExternalOutput`).
    let bezelProcessor: ShaderPostProcessor
    /// The TV shown or being loaded, and where its tube is.
    private(set) var bezelScene: TVBezelScene?
    /// Identifies the TV artwork shown or being loaded, so repeated updates do no work.
    private var bezelKey: String?
    private var bezelLoad: Task<Void, Never>?
    /// What `showBezel` was last asked for, to ask again when the display changes size.
    private var bezelRequest: (bezel: TVBezel, lightsRoom: Bool, flatGlass: Bool, didChange: () -> Void)?
    /// The picture as the tube shows it, between the two draw stages.
    private var tubeTexture: MTLTexture?

    /// A bezel that is one image, above the picture: it leaves its screen clear.
    private let bezelImageView = UIImageView()
    /// The image bezel shown, for its size and where its screen is.
    private var imageBezel: TVBezel.ImageArtwork?
    /// The image bezel's screen in this view's coordinates, while one is shown.
    private var bezelScreenFrame: CGRect?

    /// The skin's artwork, above the picture: a skin leaves its screen area clear.
    private let skinImageView = UIImageView()
    private var skinLayout: ExternalDisplaySkinLayout?
    /// Identifies the skin artwork shown or being loaded, so repeated updates do no work.
    private var skinKey: String?
    private var skinLoad: Task<Void, Never>?
    /// The skin's screen in this view's coordinates, while a skin is shown.
    private var skinScreenFrame: CGRect?

    init(device: MTLDevice) {
        filter = ShaderPostProcessor(device: device)
        bezelProcessor = ShaderPostProcessor(device: device)
        super.init(frame: .zero)
        backgroundColor = .black
        isUserInteractionEnabled = false
        addSubview(skinImageView)
        addSubview(bezelImageView)
        guard let metalLayer else { return }
        metalLayer.device = device
        // Matches the presenter's pipeline, which is built for the device view's format.
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        // Never let a starved drawable pool block the main thread (see PVMetalViewController.directRender).
        metalLayer.allowsNextDrawableTimeout = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let metalLayer else { return }
        let scale = window?.windowScene?.screen.scale ?? 1
        metalLayer.contentsScale = scale
        let size = CGSize(width: floor(bounds.width * scale), height: floor(bounds.height * scale))
        if size.width > 0, size.height > 0, metalLayer.drawableSize != size {
            metalLayer.drawableSize = size
            // The TV's artwork is drawn for one pixel size.
            if let request = bezelRequest {
                showBezel(request.bezel, lightsRoom: request.lightsRoom, flatGlass: request.flatGlass,
                          didChange: request.didChange)
            }
        }
        let frames = skinLayout?.frames(in: bounds.size)
        skinImageView.frame = frames?.image ?? .zero
        skinScreenFrame = frames?.screen
        layoutImageBezel()
    }

    /// Fits the image bezel whole into the view and works out where its screen lands.
    private func layoutImageBezel() {
        guard let art = imageBezel, art.size.width > 0, bounds.width > 0, bounds.height > 0 else {
            bezelImageView.frame = .zero
            bezelScreenFrame = nil
            return
        }
        let frame = RenderGeometry.aspectFit(aspect: art.size, in: bounds)
        let scale = frame.width / art.size.width
        bezelImageView.frame = frame
        bezelScreenFrame = CGRect(x: frame.minX + art.screen.minX * scale, y: frame.minY + art.screen.minY * scale,
                                  width: art.screen.width * scale, height: art.screen.height * scale)
    }

    /// Draws `skin` around the picture using `layout`, or with `nil` shows the picture alone.
    ///
    /// - Parameter didChange: called once what is on screen has changed (the artwork loads off
    ///   the main thread), so a paused game can be redrawn.
    func showSkin(_ skin: (any DeltaSkinRenderable)?, layout: ExternalDisplaySkinLayout?, didChange: @escaping () -> Void) {
        guard let skin, let layout else {
            guard skinKey != nil else { return }
            skinLoad?.cancel()
            skinKey = nil
            applySkin(image: nil, layout: nil)
            didChange()
            return
        }
        let key = "\(skin.identifier)|\(skin.selectedThemeId ?? "")|\(layout.traits.description)"
        guard key != skinKey else { return }
        skinKey = key
        skinLoad?.cancel()
        skinLoad = Task { @MainActor [weak self] in
            let image: UIImage?
            do {
                image = try await skin.image(for: layout.traits)
            } catch {
                WLOG("External display: could not draw skin '\(skin.name)' (\(layout.traits.description)): \(error)")
                image = nil
            }
            guard let self, self.skinKey == key else { return }
            self.applySkin(image: image, layout: image == nil ? nil : layout)
            didChange()
        }
    }

    // MARK: - TV

    /// Surrounds the picture with `bezel`, or with `nil` shows the picture alone.
    ///
    /// The cabinet and room are drawn off the main thread for this display's pixel size, then
    /// handed to the bezel preset as its background. Until that is ready, and if anything
    /// fails, the display keeps showing the picture alone.
    ///
    /// - Parameters:
    ///   - lightsRoom: the picture lights the room (the costlier preset).
    ///   - flatGlass: keep the glass flat, because the filter inside bends the picture itself.
    ///   - didChange: called once what is on screen has changed, so a paused game can be redrawn.
    func showBezel(_ bezel: TVBezel?, lightsRoom: Bool, flatGlass: Bool, didChange: @escaping () -> Void) {
        guard let bezel else {
            bezelRequest = nil
            guard bezelKey != nil else { return }
            bezelLoad?.cancel()
            bezelKey = nil
            clearShaderBezel()
            clearImageBezel()
            didChange()
            return
        }
        bezelRequest = (bezel, lightsRoom, flatGlass, didChange)
        let drawableSize = metalLayer?.drawableSize ?? .zero
        if let art = bezel.image {
            showImageBezel(bezel, art: art, drawableSize: drawableSize, didChange: didChange)
            return
        }
        let sceneRect = RenderGeometry.sceneRect(aspect: TVBezelShader.sceneAspect, drawableSize: drawableSize)
        // No size yet: `layoutSubviews` asks again once the drawable has one.
        guard sceneRect.width > 0, sceneRect.height > 0 else { return }
        let lit = lightsRoom && bezel.lightsRoom
        let key = "\(bezel.id)|\(Int(sceneRect.width))|\(lit)|\(flatGlass)"
        guard key != bezelKey else { return }
        bezelKey = key
        bezelLoad?.cancel()
        bezelLoad = Task { @MainActor [weak self] in
            let scene = await Task.detached(priority: .userInitiated) {
                TVBezelScene.make(bezel: bezel, lightsRoom: lit, flatGlass: flatGlass,
                                  scenePixelWidth: sceneRect.width, key: key)
            }.value
            guard let self, self.bezelKey == key else { return }
            self.clearImageBezel()
            self.bezelScene = scene
            self.tubeTexture = nil
            self.bezelProcessor.update(scene?.shader, smoothing: true, textures: scene?.textures)
            if scene == nil {
                WLOG("External display: TV '\(bezel.name)' could not be drawn; showing the picture alone")
            } else {
                ILOG("External display: TV '\(bezel.name)'\(lit ? ", lighting the room" : "")")
            }
            didChange()
        }
    }

    /// Lays an image bezel over the picture. The image is decoded off the main thread, no
    /// larger than the display needs; until it is ready what was showing stays.
    private func showImageBezel(_ bezel: TVBezel, art: TVBezel.ImageArtwork, drawableSize: CGSize, didChange: @escaping () -> Void) {
        let maxPixel = max(drawableSize.width, drawableSize.height)
        // No size yet: `layoutSubviews` asks again once the drawable has one.
        guard maxPixel > 0 else { return }
        let key = "\(bezel.id)|image|\(Int(maxPixel))|\(art.screen)"
        guard key != bezelKey else { return }
        bezelKey = key
        bezelLoad?.cancel()
        bezelLoad = Task { @MainActor [weak self] in
            let image = await Task.detached(priority: .userInitiated) {
                TVBezelImage.displayImage(art.fileURL, maxPixel: maxPixel).map { UIImage(cgImage: $0) }
            }.value
            guard let self, self.bezelKey == key else { return }
            self.clearShaderBezel()
            self.imageBezel = image == nil ? nil : art
            self.bezelImageView.image = image
            self.setNeedsLayout()
            self.layoutIfNeeded()
            if image == nil {
                WLOG("External display: bezel '\(bezel.name)' could not be read; showing the picture alone")
            } else {
                ILOG("External display: bezel '\(bezel.name)', screen \(art.screen) of \(art.size)")
            }
            didChange()
        }
    }

    private func clearShaderBezel() {
        bezelScene = nil
        tubeTexture = nil
        bezelProcessor.update(nil, smoothing: true)
    }

    private func clearImageBezel() {
        guard imageBezel != nil || bezelImageView.image != nil else { return }
        imageBezel = nil
        bezelImageView.image = nil
        layoutImageBezel()
    }

    /// The texture stage one draws the tube's picture into, for a scene `sceneSize` pixels
    /// large. `nil` when no TV is shown or the texture cannot be made.
    func tubeTarget(sceneSize: CGSize) -> MTLTexture? {
        guard let scene = bezelScene, let device = metalLayer?.device else { return nil }
        let size = RenderGeometry.pixelSize(of: scene.tubeRect.size, canvas: TVBezelArtwork.canvas, sceneSize: sceneSize)
        if let tubeTexture, tubeTexture.width == size.width, tubeTexture.height == size.height {
            return tubeTexture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: size.width,
                                                                  height: size.height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        tubeTexture = device.makeTexture(descriptor: descriptor)
        return tubeTexture
    }

    private func applySkin(image: UIImage?, layout: ExternalDisplaySkinLayout?) {
        skinImageView.image = image
        skinLayout = layout
        setNeedsLayout()
        layoutIfNeeded()
    }

    /// The picture's rect in drawable pixels: inside an image bezel's or a skin's screen while
    /// one is shown, else aspect-fit in the whole view.
    func pictureRect(aspect: CGSize, drawableSize: CGSize) -> CGRect {
        if let screen = bezelScreenFrame, bounds.width > 0, bounds.height > 0 {
            let fit = BezelPictureFit.rect(aspect: aspect, in: screen)
            let scaleX = drawableSize.width / bounds.width
            let scaleY = drawableSize.height / bounds.height
            return CGRect(x: fit.minX * scaleX, y: fit.minY * scaleY,
                          width: fit.width * scaleX, height: fit.height * scaleY).integral
        }
        guard let screen = skinScreenFrame, bounds.width > 0, bounds.height > 0 else {
            return RenderGeometry.contentRect(aspect: aspect, viewSize: bounds.size, drawableSize: drawableSize)
        }
        let fit = skinLayout?.maintainsAspectRatio == false ? screen : RenderGeometry.aspectFit(aspect: aspect, in: screen)
        let scaleX = drawableSize.width / bounds.width
        let scaleY = drawableSize.height / bounds.height
        return CGRect(x: fit.minX * scaleX, y: fit.minY * scaleY,
                      width: fit.width * scaleX, height: fit.height * scaleY).integral
    }
}
#endif
