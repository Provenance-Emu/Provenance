//
//  PillPageControl.swift
//  PageControls
//
//  Created by Kyle Zaragoza on 8/8/16.
//  Copyright © 2016 Kyle Zaragoza. All rights reserved.
//

import UIKit

//@IBDesignable
open class PillPageControl: UIView {

    // MARK: - PageControl
	// TODO: Fixme when true, not refreshing on rotation
	var hideOnSinglePage : Bool = true

    @IBInspectable open var pageCount: Int = 0 {
        didSet {
            updateNumberOfPages(pageCount)
        }
    }
    @IBInspectable open var progress: CGFloat = 0 {
        didSet {
            layoutActivePageIndicator(progress)
        }
    }
    open var currentPage: Int {
        return Int(round(progress))
    }

    // MARK: - Appearance

    @IBInspectable open var pillSize: CGSize = CGSize(width: 20, height: 2.5) {
        didSet {

        }
    }
    @IBInspectable open var activeTint: UIColor = UIColor.white {
        didSet {
            activeLayer.backgroundColor = activeTint.cgColor
        }
    }
    @IBInspectable open var inactiveTint: UIColor = UIColor(white: 1, alpha: 0.3) {
        didSet {
            inactiveLayers.forEach { $0.backgroundColor = inactiveTint.cgColor }
        }
    }
    @IBInspectable open var indicatorPadding: CGFloat = 7 {
        didSet {
            layoutInactivePageIndicators(inactiveLayers)
        }
    }

    fileprivate var inactiveLayers = [CALayer]()
    fileprivate lazy var activeLayer: CALayer = { [unowned self] in
        let layer = CALayer()
        layer.frame = CGRect(origin: CGPoint.zero,
                             size: CGSize(width: self.pillSize.width, height: self.pillSize.height))
        layer.backgroundColor = self.activeTint.cgColor
        layer.cornerRadius = self.pillSize.height/2
        layer.actions = [
            "bounds": NSNull(),
            "frame": NSNull(),
            "position": NSNull()]
        return layer
    }()

    // MARK: - State Update

    fileprivate func updateNumberOfPages(_ count: Int) {
		isHidden = hideOnSinglePage && pageCount < 2

        // no need to update
        guard count != inactiveLayers.count else { return }
        // reset current layout
        inactiveLayers.forEach { $0.removeFromSuperlayer() }
        inactiveLayers = [CALayer]()
        // add layers for new page count
        inactiveLayers = stride(from: 0, to:count, by:1).map { _ in
            let layer = CALayer()
            layer.backgroundColor = self.inactiveTint.cgColor
            self.layer.addSublayer(layer)
            return layer
        }
        layoutInactivePageIndicators(inactiveLayers)
        // ensure active page indicator is on top
        self.layer.addSublayer(activeLayer)
        layoutActivePageIndicator(progress)
        self.invalidateIntrinsicContentSize()
    }

    // MARK: - Layout

    fileprivate func layoutActivePageIndicator(_ progress: CGFloat) {
        // ignore if progress is outside of page indicators' bounds
        guard progress >= 0 && progress <= CGFloat(pageCount - 1) else { return }
        let denormalizedProgress = progress * (pillSize.width + indicatorPadding)
        activeLayer.frame.origin.x = denormalizedProgress
    }

    fileprivate func layoutInactivePageIndicators(_ layers: [CALayer]) {
        var layerFrame = CGRect(origin: CGPoint.zero, size: pillSize)
        layers.forEach { layer in
            layer.cornerRadius = layerFrame.size.height / 2
            layer.frame = layerFrame
            layerFrame.origin.x += layerFrame.width + indicatorPadding
        }
    }

    override open var intrinsicContentSize: CGSize {
        return sizeThatFits(CGSize.zero)
    }

    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: CGFloat(inactiveLayers.count) * pillSize.width + CGFloat(inactiveLayers.count - 1) * indicatorPadding,
                      height: pillSize.height)
    }
}
