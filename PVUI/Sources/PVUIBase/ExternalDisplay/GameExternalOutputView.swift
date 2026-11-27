//
//  GameExternalOutputView.swift
//  PVUI
//
//  The game picture on a second screen.
//

#if os(iOS) || os(tvOS)
import UIKit
import Defaults
import Metal
import QuartzCore
import PVLogging
import PVSettings
import PVShaders
import SkinKitBezels
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
    private(set) var bezelProcessor: ShaderPostProcessor
    /// The next TV's shader, compiling while `bezelProcessor` keeps drawing the one on screen.
    private var pendingBezelProcessor: ShaderPostProcessor
    /// The TV that takes over once `pendingBezelProcessor` can draw (see `promotePendingBezelIfReady`).
    private var pendingBezelScene: TVBezelScene?
    /// The TV shown or being loaded, and where its tube is.
    private(set) var bezelScene: TVBezelScene?
    /// Identifies the TV artwork shown or being loaded, so repeated updates do no work.
    private var bezelKey: String?
    /// The canvas and framing asked for when a TV was last shown: the scene being loaded.
    private var requestedCanvas = TVBezelArtwork.canvas
    private var sceneFraming = SceneFraming.whole
    private var bezelLoad: Task<Void, Never>?
    /// The TV's artwork is being drawn or read off the main thread.
    private var bezelLoadInFlight = false
    /// A TV has been asked for and is on its way but cannot be drawn yet: its artwork is
    /// loading or its shader is compiling. `false` once it draws, and when it failed.
    var isBezelPending: Bool {
        bezelLoadInFlight || (bezelScene != nil && !bezelProcessor.isReady && !bezelProcessor.hasFailed)
    }
    /// The GPU could not draw a TV on this screen: none is shown for the rest of the game.
    private var bezelDroppedForSession = false
    /// A TV or an image bezel is on screen.
    var hasBezel: Bool { bezelScene != nil || hasImageBezel }
    /// A TV is being loaded or is waiting for its shader, whether or not another still shows.
    var isBezelLoading: Bool { bezelLoadInFlight || pendingBezelScene != nil }
    /// What `showBezel` was last asked for, to ask again when the display changes size.
    private var bezelRequest: (bezel: TVBezel, lightsRoom: Bool, flatGlass: Bool, didChange: () -> Void)?
    /// The shape of the game picture the TV is drawn for: a built-in TV has a 16:9 tube for
    /// a wide picture.
    private(set) var pictureShape: TVBezelPictureShape = .standard
    /// The picture as the tube shows it, between the two draw stages.
    private var tubeTexture: MTLTexture?

    /// A bezel that is one image, above the picture: it leaves its screen clear.
    private let bezelImageView = UIImageView()
    /// The image bezel shown, for its size and where its screen is.
    private var imageBezel: TVBezel.ImageArtwork?
    /// The image bezel's screen in this view's coordinates, while one is shown.
    private var bezelScreenFrame: CGRect?
    var hasImageBezel: Bool { bezelScreenFrame != nil }

    /// The skin's artwork, above the picture: a skin leaves its screen area clear.
    private let skinImageView = UIImageView()
    private var skinLayout: ExternalDisplaySkinLayout?
    /// Identifies the skin artwork shown or being loaded, so repeated updates do no work.
    private var skinKey: String?
    private var skinLoad: Task<Void, Never>?
    /// The skin's screen in this view's coordinates, while a skin is shown.
    private var skinScreenFrame: CGRect?

    init(device: MTLDevice, onShaderReady: @escaping @MainActor @Sendable () -> Void) {
        filter = ShaderPostProcessor(device: device, onReady: onShaderReady)
        bezelProcessor = ShaderPostProcessor(device: device, onReady: onShaderReady)
        pendingBezelProcessor = ShaderPostProcessor(device: device, onReady: onShaderReady)
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
    func showBezel(_ bezel: TVBezel?, lightsRoom: Bool, flatGlass: Bool, pictureAspect: CGSize? = nil,
                   didChange: @escaping () -> Void) {
        if let pictureAspect { pictureShape = TVBezelPictureShape(aspect: pictureAspect) }
        guard let bezel, !bezelDroppedForSession else {
            bezelRequest = nil
            guard bezelKey != nil else { return }
            bezelLoad?.cancel()
            bezelLoadInFlight = false
            bezelKey = nil
            clearShaderBezel()
            clearImageBezel()
            didChange()
            return
        }
        bezelRequest = (bezel, lightsRoom, flatGlass, didChange)
        let drawableSize = metalLayer?.drawableSize ?? .zero
        let seat = Defaults[.externalDisplayBezelSeat]
        // A built-in TV is laid out for this display's shape; one that draws its own scene keeps 16:9.
        let isBuiltIn = bezel.presetID == nil && bezel.image == nil
        requestedCanvas = isBuiltIn ? TVBezelCanvas.size(display: drawableSize, seat: seat) : TVBezelArtwork.canvas
        sceneFraming = SceneFraming(coversDisplay: true, zoom: isBuiltIn ? 1 : seat.standaloneZoom, kept: isBuiltIn ? TVBezelSeat.keptPart : TVBezelSeat.standaloneKeptPart)
        let canvas = requestedCanvas
        if let art = bezel.image {
            showImageBezel(bezel, art: art, drawableSize: drawableSize, didChange: didChange)
            return
        }
        let shape = pictureShape
        // The bezel presets place a centred tube only, so a portrait room, whose TV is at the
        // top, is laid over the picture as a plain image: no glass or reflections there.
        if isBuiltIn, bezel.drawsPortrait, let portrait = TVBezelCanvas.portraitSize(display: drawableSize, seat: seat) {
            showPortraitBezel(bezel, canvas: portrait, shape: shape, drawableSize: drawableSize, didChange: didChange)
            return
        }
        let sceneRect = sceneRect(canvas: canvas, drawableSize: drawableSize)
        // No size yet: `layoutSubviews` asks again once the drawable has one.
        guard sceneRect.width > 0, sceneRect.height > 0 else { return }
        let lit = lightsRoom && bezel.lightsRoom
        let key = TVBezelScene.key(bezel: bezel, lightsRoom: lit, flatGlass: flatGlass, scenePixelWidth: sceneRect.width,
                                   canvas: canvas, shape: shape)
        guard key != bezelKey else { return }
        bezelKey = key
        bezelLoad?.cancel()
        if let cached = TVBezelSceneCache.shared.scene(for: key) {
            bezelLoadInFlight = false
            adopt(cached, name: bezel.name, lit: lit)
            didChange()
            return
        }
        bezelLoadInFlight = true
        bezelLoad = Task { @MainActor [weak self] in
            let scene = await Task.detached(priority: .userInitiated) {
                TVBezelScene.make(bezel: bezel, lightsRoom: lit, flatGlass: flatGlass,
                                  scenePixelWidth: sceneRect.width, key: key, canvas: canvas, shape: shape)
            }.value
            guard let self, self.bezelKey == key else { return }
            self.bezelLoadInFlight = false
            if let scene { TVBezelSceneCache.shared.store(scene, for: key) }
            self.adopt(scene, name: bezel.name, lit: lit)
            didChange()
        }
    }

    /// Puts a loaded TV on screen. With another TV showing, that one keeps drawing until the
    /// new one's shader has compiled, so there is no bare picture between the two.
    private func adopt(_ scene: TVBezelScene?, name: String, lit: Bool) {
        clearImageBezel()
        guard let scene, let shader = scene.resolvedShader() else {
            clearShaderBezel()
            WLOG("External display: TV '\(name)' could not be drawn; showing the picture alone")
            return
        }
        if bezelScene != nil, bezelProcessor.isReady {
            pendingBezelScene = scene
            pendingBezelProcessor.update(shader, smoothing: true, textures: scene.textures)
        } else {
            pendingBezelScene = nil
            pendingBezelProcessor.update(nil, smoothing: true)
            bezelScene = scene
            tubeTexture = nil
            bezelProcessor.update(shader, smoothing: true, textures: scene.textures)
        }
        ILOG("External display: TV '\(name)'\(lit ? ", lighting the room" : "")")
    }

    /// Swaps in the TV that finished loading once its shader can draw, and gives up on one
    /// whose shader failed. Call before drawing a frame.
    func promotePendingBezelIfReady() {
        guard let pending = pendingBezelScene else { return }
        if pendingBezelProcessor.isReady {
            swap(&bezelProcessor, &pendingBezelProcessor)
            bezelScene = pending
            tubeTexture = nil
        } else if pendingBezelProcessor.hasFailed {
            WLOG("External display: the next TV's shader failed; keeping the one on screen")
        } else {
            return
        }
        pendingBezelScene = nil
        pendingBezelProcessor.update(nil, smoothing: true)
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
        bezelLoadInFlight = true
        bezelLoad = Task { @MainActor [weak self] in
            let image = await Task.detached(priority: .userInitiated) {
                TVBezelImage.displayImage(art.fileURL, maxPixel: maxPixel).map { UIImage(cgImage: $0) }
            }.value
            guard let self, self.bezelKey == key else { return }
            self.bezelLoadInFlight = false
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

    /// Takes the TV off this screen and keeps it off until the view is rebuilt for another
    /// game: the GPU could not draw it, and trying again risks a hang.
    func dropBezelForSession() {
        bezelDroppedForSession = true
        bezelRequest = nil
        bezelLoad?.cancel()
        bezelLoadInFlight = false
        bezelKey = nil
        clearShaderBezel()
        clearImageBezel()
    }

    private func clearShaderBezel() {
        bezelScene = nil
        pendingBezelScene = nil
        tubeTexture = nil
        bezelProcessor.update(nil, smoothing: true)
        pendingBezelProcessor.update(nil, smoothing: true)
    }

    private func clearImageBezel() {
        guard imageBezel != nil || bezelImageView.image != nil else { return }
        imageBezel = nil
        bezelImageView.image = nil
        layoutImageBezel()
    }

    /// Where the shown TV's scene goes in a drawable of `drawableSize`: all of it when the
    /// scene was laid out for this shape, else covering it with the tube kept on screen (the
    /// rect is then larger than the drawable). While another scene loads, this is still the
    /// shown scene's own canvas, so its tube stays where its artwork has it.
    func sceneRect(drawableSize: CGSize) -> CGRect {
        sceneRect(canvas: bezelScene?.canvas ?? requestedCanvas, drawableSize: drawableSize)
    }

    private func sceneRect(canvas: CGSize, drawableSize: CGSize) -> CGRect {
        RenderGeometry.sceneRect(aspect: canvas, drawableSize: drawableSize, framing: sceneFraming)
    }

    /// The texture stage one draws the tube's picture into, for a scene `sceneSize` pixels
    /// large. `nil` when no TV is shown or the texture cannot be made.
    func tubeTarget(sceneSize: CGSize) -> MTLTexture? {
        guard let scene = bezelScene, let device = metalLayer?.device else { return nil }
        let size = RenderGeometry.pixelSize(of: scene.tubeRect.size, canvas: scene.canvas, sceneSize: sceneSize)
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

    /// Where the picture sits inside the TV shown, in this view's coordinates (points): in an
    /// image bezel's screen, or in a shader TV's tube. `nil` with no TV, or before layout.
    func bezelPictureFrame(aspect: CGSize) -> CGRect? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        if let screen = bezelScreenFrame { return BezelPictureFit.rect(aspect: aspect, in: screen) }
        guard let scene = bezelScene else { return nil }
        let sceneRect = sceneRect(drawableSize: bounds.size)
        let scale = sceneRect.width / scene.canvas.width
        let tube = CGRect(x: sceneRect.minX + scene.tubeRect.minX * scale, y: sceneRect.minY + scene.tubeRect.minY * scale,
                          width: scene.tubeRect.width * scale, height: scene.tubeRect.height * scale)
        return RenderGeometry.aspectFit(aspect: aspect, in: tube)
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

// MARK: - Portrait rooms and the picture's shape

extension GameExternalOutputView {

    /// Lays a built-in TV's portrait room over the picture: its artwork as one image with the
    /// tube left see-through, shown the way an image bezel is. Drawn off the main thread.
    private func showPortraitBezel(_ bezel: TVBezel, canvas: CGSize, shape: TVBezelPictureShape, drawableSize: CGSize,
                                   didChange: @escaping () -> Void) {
        let maxPixel = max(drawableSize.width, drawableSize.height)
        // No size yet: `layoutSubviews` asks again once the drawable has one.
        guard maxPixel > 0 else { return }
        // The set hangs from the top of the screen: it goes below a notch or Dynamic Island.
        let topInset = bounds.width > 0 ? safeAreaTopInWindow * canvas.width / bounds.width : 0
        let key = "\(bezel.id)|portrait|\(Int(maxPixel))|\(Int(canvas.width))x\(Int(canvas.height))|\(shape.rawValue)|\(Int(topInset))"
        guard key != bezelKey else { return }
        bezelKey = key
        bezelLoad?.cancel()
        bezelLoadInFlight = true
        bezelLoad = Task { @MainActor [weak self] in
            let drawn = await Task.detached(priority: .userInitiated) { () -> (image: UIImage, tube: CGRect)? in
                guard let tube = TVBezelPlainArtwork.tubeRect(of: bezel, canvas: canvas, shape: shape, topInset: topInset),
                      let image = TVBezelPlainArtwork.image(for: bezel, maxPixel: maxPixel, canvas: canvas, shape: shape,
                                                            topInset: topInset, cutsOutTube: true) else { return nil }
                return (UIImage(cgImage: image), tube)
            }.value
            guard let self, self.bezelKey == key else { return }
            self.bezelLoadInFlight = false
            self.clearShaderBezel()
            // The canvas has the display's proportions, so the artwork fits it whole and the tube is its screen.
            self.imageBezel = drawn.map { TVBezel.ImageArtwork(fileURL: URL(fileURLWithPath: bezel.artwork), size: canvas, screen: $0.tube) }
            self.bezelImageView.image = drawn?.image
            self.setNeedsLayout()
            self.layoutIfNeeded()
            if drawn == nil {
                WLOG("External display: TV '\(bezel.name)' could not be drawn for portrait; showing the picture alone")
            } else {
                ILOG("External display: TV '\(bezel.name)' in portrait, \(shape.rawValue) picture")
            }
            didChange()
        }
    }

    /// How much of this view's top the window's safe area covers, in points. The view's own
    /// inset is not used: the GPU view it sits in is laid out by frame, not by safe area.
    private var safeAreaTopInWindow: CGFloat {
        guard let window else { return 0 }
        return max(0, window.safeAreaInsets.top - convert(bounds.origin, to: window).y)
    }

    /// Tells the view the picture's shape while a TV shows. A core may report its shape only
    /// once the game is running; the TV is then drawn again for it.
    func pictureAspectDidChange(_ aspect: CGSize) {
        guard TVBezelPictureShape(aspect: aspect) != pictureShape, let request = bezelRequest else { return }
        showBezel(request.bezel, lightsRoom: request.lightsRoom, flatGlass: request.flatGlass, pictureAspect: aspect,
                  didChange: request.didChange)
    }
}
