//  TVPopupController.swift
//  Wombat
//
//  show another view centered "as a popup"
//  when you dont want the jarring fullscreen mode that you get with tvOS
//
//  we *must* have a preferedContentSize (or a self sizing view)
//
//  Created by Todd Laney on 22/01/2022.
//

import UIKit

class TVPopupController: UIViewController {
    
    // these are the PV defaults assuming Dark mode, etc.
    private let _style = UIModalPresentationStyle.overFullScreen                        // .overFullScreen OR .blurOverFullScreen
    private let _backgroundColor = UIColor.black.withAlphaComponent(0.8)
    private let _backdropColor = UIColor(red:0.11, green:0.11, blue:0.12, alpha:1)      // secondarySystemGroupedBackground
    private let _contentInset = UIEdgeInsets(top:16, left:16, bottom:16, right:16)
    private let _cornerRadius = 32.0
    private let _borderWidth = 4.0

    private let _backdropView = UIView()
    private var _contentSize = CGSize.zero
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
        self.modalPresentationStyle = _style
        self.modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    convenience init(rootViewController:UIViewController) {
        self.init(nibName:nil, bundle:nil)
        view.addSubview(rootViewController.view)
        addChild(rootViewController)
        rootViewController.didMove(toParent:self)
        preferredContentSize = rootViewController.preferredContentSize
    }

    override var preferredContentSize: CGSize {
        get {
            guard let content = view.subviews.last else {return .zero}
            var size = _contentSize
            if size == .zero {
                size = content.sizeThatFits(.zero)
            }
            if size == .zero {
                size = content.systemLayoutSizeFitting(.zero)
            }
            
            // TODO: dont do this if we are in a popup (if/when we run this code on iPad....)
            size.width  += (_contentInset.left + _contentInset.right)
            size.height += (_contentInset.top + _contentInset.bottom)
            
            return size
        }
        set {
            _contentSize = newValue
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // get the content view, bail if none
        guard let content = view.subviews.last else {return}
        
        // first layout, add our decoration/backdrop view behind the content
        // TODO: dont do this if we are in a popup (if/when we run this code on iPad....)
        if _backdropView.superview == nil {

            view.addSubview(_backdropView)
            view.sendSubviewToBack(_backdropView)

            _backdropView.backgroundColor = _backdropColor

            _backdropView.layer.cornerRadius = _cornerRadius
            _backdropView.layer.borderColor = _backdropColor.cgColor
            _backdropView.layer.borderWidth = _borderWidth

            if (modalPresentationStyle == .overFullScreen) {
                view.backgroundColor = _backgroundColor
            }
        }
        
        let rect = CGRect(origin:.zero, size:preferredContentSize)
        let center = CGPoint(x:view.bounds.midX, y:view.bounds.midY)

        _backdropView.bounds = rect
        _backdropView.center = center

        content.bounds = CGRect(origin:.zero, size:rect.inset(by:_contentInset).size)
        content.center = center

        content.backgroundColor = .clear
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // get the content view, bail if none
        guard let content = view.subviews.last else {return}

        let size = preferredContentSize
        let scale = min(1.0, min(view.bounds.size.width * 0.95 / size.width, view.bounds.size.height * 0.95 / size.height))
        
        // TODO: dont do this if we are in a popup (if/when we run this code on iPad....)
        _backdropView.transform = CGAffineTransform(scaleX:0.001, y:0.001)
        content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
        UIView.animate(withDuration: 0.200) { [self] in
            content.transform  = CGAffineTransform(scaleX:scale, y:scale)
            _backdropView.transform = CGAffineTransform(scaleX:scale, y:scale)
        }
    }

    #if os(iOS)
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // get the content view, bail if none
        guard let content = view.subviews.last else {return}

        // TODO: dont do this if we are in a popup (if/when we run this code on iPad....)
        UIView.animate(withDuration: 0.200) { [self] in
            content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
            _backdropView.transform = CGAffineTransform(scaleX:0.001, y:0.001)
        }
    }
    #endif
}
