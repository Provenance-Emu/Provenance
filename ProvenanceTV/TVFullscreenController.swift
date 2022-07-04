//  TVFullscreenController.swift
//  Wombat
//
//  show another view centered "as a popup" with a dimmed (or blured) background
//  when you dont want the jarring fullscreen mode that you get with tvOS
//
//  if the viewController does not have a preferedContentSize, use a default like a formSheet on iOS
//
//  Created by Todd Laney on 22/01/2022.
//

import UIKit

class TVFullscreenController: UIViewController {

    // these are the PV defaults assuming Dark mode, etc.
    private let _fullscreenColor = UIColor.black.withAlphaComponent(0.8)
    private let _backgroundColor = UIColor.black
    private let _inset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    private let _borderWidth = 4.0
    private let _cornerRadius = 16.0

    convenience init(rootViewController:UIViewController, style:UIModalPresentationStyle = .overFullScreen) {
        self.init(nibName:nil, bundle:nil)

        let back = UIView()
        back.backgroundColor = rootViewController.view.backgroundColor ?? _backgroundColor
        back.layer.borderWidth = _borderWidth
        back.layer.cornerRadius = _cornerRadius

        if let nav = rootViewController as? UINavigationController {
            nav.navigationBar.isTranslucent = false
            nav.navigationBar.backgroundColor =  UIColor.black.withAlphaComponent(0.8)
        }

        back.addSubview(rootViewController.view)
        view.addSubview(back)
        addChild(rootViewController)
        rootViewController.didMove(toParent:self)

        var size = rootViewController.preferredContentSize
        if size == .zero {
            size = CGSize(width:UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.height * 0.95)
        }
        size.width += (_inset.left + _inset.right)
        size.height += (_inset.top + _inset.bottom)
        preferredContentSize = size

        modalPresentationStyle = style // .overFullScreen OR .blurOverFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let content = view.subviews.first {
            content.layer.borderColor = content.tintColor.cgColor
            content.bounds = CGRect(origin:.zero, size:preferredContentSize)
            content.center = CGPoint(x:view.bounds.midX, y:view.bounds.midY)
            content.subviews.first?.frame = content.bounds.inset(by: _inset)
        }

        if (modalPresentationStyle == .overFullScreen) {
            view.backgroundColor = _fullscreenColor
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // get the content view, bail if none
        guard let content = view.subviews.first else {return}

        let size = preferredContentSize
        let scale = min(1.0, min(view.bounds.size.width * 0.95 / size.width, view.bounds.size.height * 0.95 / size.height))

        content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
        UIView.animate(withDuration: 0.150) {
            content.transform  = CGAffineTransform(scaleX:scale, y:scale)
        }
    }
}
