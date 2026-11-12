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
import PVShaders

/// A Metal-backed view on a second screen. `PVMetalViewController` draws every game frame
/// into it as well as into the device's own view, so the device's view hierarchy (skins,
/// viewport frames) is left exactly as it is with no external display.
final class GameExternalOutputView: UIView {

    override class var layerClass: AnyClass { CAMetalLayer.self }

    /// This screen's own filter. Fed by `PVEmulatorViewController.updateExternalDisplayFilter()`.
    let filter: ShaderPostProcessor

    var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    init(device: MTLDevice) {
        filter = ShaderPostProcessor(device: device)
        super.init(frame: .zero)
        backgroundColor = .black
        isUserInteractionEnabled = false
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
    }
}
#endif
