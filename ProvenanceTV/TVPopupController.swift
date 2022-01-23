//  TVPopupController.swift
//  Wombat
//
//  show another view controller centered "as a popup"
//  when you dont want the jarring fullscreen mode that you get with tvOS
//
//  child viewController *must* have a preferedContentSize
//
//  Created by Todd Laney on 22/01/2022.
//

import UIKit

final class TVPopupController: UIViewController {
    
    private let _viewController:UIViewController
    private let _backgroundColor = UIColor.black.withAlphaComponent(0.8)
    
    init(rootViewController:UIViewController) {
        _viewController = rootViewController
        super.init(nibName:nil, bundle:nil)
        self.modalPresentationStyle = .blurOverFullScreen
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var modalPresentationStyle: UIModalPresentationStyle {
        didSet {
            if modalPresentationStyle == .fullScreen {
                modalPresentationStyle = .overFullScreen
            }
         }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _viewController.view.layer.cornerRadius = 32.0
        
        if (modalPresentationStyle == .overFullScreen) {
            view.backgroundColor = _backgroundColor
            _viewController.view.layer.borderColor = UIColor(red: 0.1, green: 0.5, blue: 0.95, alpha: 1.0).cgColor
            _viewController.view.layer.borderWidth = 4.0
        }

        view.addSubview(_viewController.view)
        addChild(_viewController)
        _viewController.didMove(toParent: self)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        assert(_viewController.preferredContentSize != .zero)
        _viewController.view.frame.size = _viewController.preferredContentSize
        _viewController.view.center = CGPoint(x:self.view.bounds.midX, y:self.view.bounds.midY)
     }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let size = _viewController.preferredContentSize

        let scale = min(1.0, min(self.view.bounds.size.width * 0.95 / size.width, self.view.bounds.size.height * 0.95 / size.height))

        _viewController.view.transform = CGAffineTransform(scaleX:0.001, y:0.001)
        UIView.animate(withDuration: 0.200) { [self] in
            _viewController.view.transform  = CGAffineTransform(scaleX:scale, y:scale);
        }
    }
}
