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
        super.init(frame: .zero)
        backgroundColor = .black
        isUserInteractionEnabled = false
        addSubview(skinImageView)
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
        }
        let frames = skinLayout?.frames(in: bounds.size)
        skinImageView.frame = frames?.image ?? .zero
        skinScreenFrame = frames?.screen
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

    private func applySkin(image: UIImage?, layout: ExternalDisplaySkinLayout?) {
        skinImageView.image = image
        skinLayout = layout
        setNeedsLayout()
        layoutIfNeeded()
    }

    /// The picture's rect in drawable pixels: inside the skin's screen while a skin is shown,
    /// else aspect-fit in the whole view.
    func pictureRect(aspect: CGSize, drawableSize: CGSize) -> CGRect {
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
