//  TVFullscreenController.swift
//  Wombat
//
//  show another view centered "as a popup" with a dimmed (or blured) background
//  when you dont want the jarring fullscreen mode that you get with tvOS
//
//  we *must* have a preferedContentSize
//
//  Created by Todd Laney on 22/01/2022.
//

import UIKit

class TVFullscreenController: UIViewController {
    
    // these are the PV defaults assuming Dark mode, etc.
    private let _backgroundColor = UIColor.black.withAlphaComponent(0.8)

    convenience init(rootViewController:UIViewController, style:UIModalPresentationStyle = .overFullScreen) {
        self.init(nibName:nil, bundle:nil)
        view.addSubview(rootViewController.view)
        addChild(rootViewController)
        rootViewController.didMove(toParent:self)
        preferredContentSize = rootViewController.preferredContentSize
        assert(preferredContentSize != .zero)
        modalPresentationStyle = style // .overFullScreen OR .blurOverFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if let content = view.subviews.first {
            content.bounds = CGRect(origin:.zero, size:preferredContentSize)
            content.center = CGPoint(x:view.bounds.midX, y:view.bounds.midY)
        }
        
        if (modalPresentationStyle == .overFullScreen) {
            view.backgroundColor = _backgroundColor
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // get the content view, bail if none
        guard let content = view.subviews.first else {return}

        let size = preferredContentSize
        let scale = min(1.0, min(view.bounds.size.width * 0.95 / size.width, view.bounds.size.height * 0.95 / size.height))
        
        content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
        UIView.animate(withDuration: 0.200) {
            content.transform  = CGAffineTransform(scaleX:scale, y:scale)
        }
    }
}
