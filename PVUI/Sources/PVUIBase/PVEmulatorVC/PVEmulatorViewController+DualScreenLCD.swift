// PVEmulatorViewController+DualScreenLCD.swift
// PVUI
//
// LCD look for 3DS skins. Azahar draws both screens into a layer of its own, so
// no filter can touch its pixels; this lays `LCDScreenFilter`'s pixel grid over
// each screen instead (grid only: no ghosting or colour change). DS skins get
// the full filter in PVMetalViewController+DualScreenLCD.

import UIKit
import Defaults
import PVSettings
import PVShaders
import PVSystems

extension PVEmulatorViewController {

    /// The 3DS screens in emulated pixels.
    static let threeDSTopScreenSize = CGSize(width: 400, height: 240)
    static let threeDSBottomScreenSize = CGSize(width: 320, height: 240)

    /// Lays the grid over the 3DS screens at `top` and `bottom` (in `container`'s space),
    /// or removes it when the skin brings its own filter or this is not a 3DS.
    /// The overlays follow the setting on their own.
    func updateDualScreenLCDOverlay(top: CGRect, bottom: CGRect, in container: UIView) {
        guard SystemIdentifier(rawValue: core.systemIdentifier ?? "") == ._3DS,
              isProgrammaticOverlayActive || !currentSkinProvidesScreenFilter else {
            removeDualScreenLCDOverlay()
            return
        }
        let screens = [(top, Self.threeDSTopScreenSize), (bottom, Self.threeDSBottomScreenSize)]
        while dualScreenLCDOverlays.count < screens.count { dualScreenLCDOverlays.append(LCDGridOverlayView()) }
        for (overlay, (frame, nativeSize)) in zip(dualScreenLCDOverlays, screens) {
            if overlay.superview !== container { container.addSubview(overlay) }
            overlay.frame = frame
            overlay.nativeSize = nativeSize
            container.bringSubviewToFront(overlay)
        }
    }

    func removeDualScreenLCDOverlay() {
        dualScreenLCDOverlays.forEach { $0.removeFromSuperview() }
        dualScreenLCDOverlays = []
    }
}

/// `LCDScreenFilter`'s pixel grid as a view over a screen drawn by someone else. Black
/// gaps at the grid strength darken exactly as the filter's multiply does. Shown only
/// while `Defaults[.dualScreenLCDLook]` is on; never takes touches (the 3DS bottom
/// screen is a touchscreen).
final class LCDGridOverlayView: UIView {
    /// Emulated pixels across and down the screen underneath.
    var nativeSize: CGSize = .zero {
        didSet { if oldValue != nativeSize { setNeedsDisplay() } }
    }

    private var settingObservation: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
        isHidden = !Defaults[.dualScreenLCDLook]
        // Above a render view the core adds to the same container later.
        layer.zPosition = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        settingObservation?.cancel()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        settingObservation?.cancel()
        settingObservation = nil
        guard window != nil else { return }
        settingObservation = Task { @MainActor [weak self] in
            for await enabled in Defaults.updates(.dualScreenLCDLook) {
                self?.isHidden = !enabled
            }
        }
    }

    override func draw(_ rect: CGRect) {
        let gaps = LCDScreenFilter.gapRects(in: bounds.size, nativeSize: nativeSize,
                                            scale: traitCollection.displayScale)
        guard !gaps.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(UIColor.black.withAlphaComponent(LCDScreenFilter.Defaults.gridStrength).cgColor)
        // One fill for all gaps, so crossings are not darkened twice.
        context.fill(gaps)
    }
}
