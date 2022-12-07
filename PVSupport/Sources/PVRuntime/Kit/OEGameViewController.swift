//
//  File.swift
//  PVRuntime
//
//  Created by Stuart Carnie on 5/12/2022.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import QuartzCore

#if os(tvOS)
public typealias OEGameViewControllerRootClass = GCEventViewController
#else
public typealias OEGameViewControllerRootClass = UIViewController
#endif

@objc public final class OEGameViewController: OEGameViewControllerRootClass {
    let gameView: OEGameView = .init()
    let gameCore: OEGameCore
    
    required init(gameCore: OEGameCore) {
        self.gameCore = gameCore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        super.loadView()
        view = gameView
        gameView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        gameView.isUserInteractionEnabled = false
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let parentSafeAreaInsets: UIEdgeInsets
        if #available(iOS 11.0, tvOS 11.0, macOS 11.0, macCatalyst 11.0, *) {
            parentSafeAreaInsets = parent?.view.safeAreaInsets ?? .zero
        } else {
            parentSafeAreaInsets = .zero
        }
        
        if !gameCore.screenRect.size.isEmpty {
            let aspectSize = CGSize(width: CGFloat(gameCore.aspectSize.width), height: CGFloat(gameCore.aspectSize.height))
            let ratio: CGFloat
            if aspectSize.width > aspectSize.height {
                ratio = aspectSize.width  / aspectSize.height
            } else {
                ratio = aspectSize.height / aspectSize.width
            }
            
            let parentSize = parent?.view.bounds.size ?? view.window?.bounds.size ?? .init(width: 320, height: 200)

            var height: CGFloat
            var width: CGFloat

            if parentSize.width > parentSize.height {
                // TODO: Add this
                // if PVSettingsModel.shared.integerScaleEnabled {
                if true {
                    height = (parentSize.height / aspectSize.height).rounded(.down) * aspectSize.height
                } else {
                    height = parentSize.height
                }
                width = (height * ratio).rounded(.toNearestOrAwayFromZero)
                if width > parentSize.width {
                    width = parentSize.width
                    height = (width / ratio).rounded(.toNearestOrAwayFromZero)
                }
            } else {
                // TODO: Add this
                // if PVSettingsModel.shared.integerScaleEnabled {
                if true {
                    width = (parentSize.width / aspectSize.width).rounded(.down) * aspectSize.width
                } else {
                    width = parentSize.height
                }
                height = (width * ratio).rounded(.toNearestOrAwayFromZero)
                if height > parentSize.height {
                    height = parentSize.height
                    width = (height / ratio).rounded(.toNearestOrAwayFromZero)
                }
            }
            
            var origin = CGPoint(x: ((parentSize.width - width) / 2.0).rounded(.toNearestOrAwayFromZero),
                                 y: 0.0)
            if traitCollection.userInterfaceIdiom == .phone, parentSize.height > parentSize.width {
                origin.y = parentSafeAreaInsets.top + 40.0 // directly below menu button at top of screen
            } else {
                origin.y = ((parentSize.height - height) / 2.0).rounded(.toNearestOrAwayFromZero) // centered
            }
            
            view.frame = .init(origin: origin, size: .init(width: width, height: height))
        }
    }
}

protocol LayoutDelegate: AnyObject {
    func layoutForViewDidChange(_ view: UIView)
}

@objc class OEGameView: UIView {
    override class var layerClass: AnyClass { GameHelperMetalLayer.self }
    
    weak var delegate: LayoutDelegate?
    
    var metalLayer: GameHelperMetalLayer { layer as! GameHelperMetalLayer }
    
    var device: MTLDevice? {
        didSet {
            metalLayer.device = device
            metalLayer.isOpaque = true
            metalLayer.framebufferOnly = true
        }
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        delegate?.layoutForViewDidChange(self)
    }
}
