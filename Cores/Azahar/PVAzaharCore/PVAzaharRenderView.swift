import UIKit
import QuartzCore

/// Plain Metal-backed view; azahar presents into its layer through MoltenVK.
@objc public final class PVAzaharRenderView: UIView {
    public override static var layerClass: AnyClass { CAMetalLayer.self }
    @objc public var metalLayer: CAMetalLayer { unsafeDowncast(layer, to: CAMetalLayer.self) }   // layerClass guarantees the type

    /// Called from `layoutSubviews` whenever the drawable size (in pixels) changes:
    /// rotation, skin frame changes, Stage Manager resizes, tvOS output changes.
    @objc public var onDrawableSizeChange: ((CGSize) -> Void)?
    private var lastDrawableSize: CGSize = .zero

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = .black
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false   // MoltenVK blits/copies for screenshots
        #if !os(tvOS)
        isMultipleTouchEnabled = true
        #endif
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        metalLayer.contentsScale = scale
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        metalLayer.drawableSize = size
        if size != lastDrawableSize {
            lastDrawableSize = size
            onDrawableSizeChange?(size)
        }
    }

    #if !os(tvOS)
    /// Bottom-screen touch; the Bool is `ended`. Only the first finger down drives it.
    @objc public var onTouch: ((UITouch, Bool) -> Void)?
    private weak var trackedTouch: UITouch?

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackedTouch == nil, let touch = touches.first else { return }
        trackedTouch = touch
        onTouch?(touch, false)
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        onTouch?(touch, false)
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTrackedTouch(in: touches) }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTrackedTouch(in: touches) }

    private func endTrackedTouch(in touches: Set<UITouch>) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        trackedTouch = nil
        onTouch?(touch, true)
    }
    #endif
}
