//  Twitter.swift
//  Twitter ( https://github.com/xmartlabs/XLActionController )
//
//  Copyright (c) 2015 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
#if XLACTIONCONTROLLER_EXAMPLE
import XLActionController
#endif

open class TwitterCell: ActionCell {

    public override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        initialize()
    }

    func initialize() {
        backgroundColor = .white
        actionImageView?.clipsToBounds = true
        actionImageView?.layer.cornerRadius = 5.0
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(white: 0.0, alpha: 0.15)
        selectedBackgroundView = backgroundView
    }
}

open class TwitterActionControllerHeader: UICollectionReusableView {
    
    lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.backgroundColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 17)
        return label
    }()
    
    lazy var bottomLine: UIView = {
        let bottomLine = UIView()
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.backgroundColor = .lightGray
        return bottomLine
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        addSubview(label)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[label]|", options: NSLayoutFormatOptions(), metrics: nil, views: ["label": label]))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[label]|", options: NSLayoutFormatOptions(), metrics: nil, views: ["label": label]))
        addSubview(bottomLine)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[line(1)]|", options: NSLayoutFormatOptions(), metrics: nil, views: ["line": bottomLine]))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[line]|", options: NSLayoutFormatOptions(), metrics: nil, views: ["line": bottomLine]))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


open class TwitterActionController: ActionController<TwitterCell, ActionData, TwitterActionControllerHeader, String, UICollectionReusableView, Void> {

    static let bottomPadding: CGFloat = 20.0

    lazy var hideBottomSpaceView: UIView = {
        let width = collectionView.bounds.width - safeAreaInsets.left - safeAreaInsets.right
        let height = contentHeight + TwitterActionController.bottomPadding + safeAreaInsets.bottom
        let hideBottomSpaceView = UIView(frame: CGRect.init(x: 0, y: 0, width: width, height: height))
        hideBottomSpaceView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        hideBottomSpaceView.backgroundColor = .white
        return hideBottomSpaceView
    }()

    public override init(nibName nibNameOrNil: String? = nil, bundle nibBundleOrNil: Bundle? = nil) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        settings.animation.present.duration = 0.6
        settings.animation.dismiss.duration = 0.6
        cellSpec = CellSpec.nibFile(nibName: "TwitterCell", bundle: Bundle(for: TwitterCell.self), height: { _ in 56 })
        headerSpec = .cellClass(height: { _ -> CGFloat in return 45 })

        onConfigureHeader = { header, title in
            header.label.text = title
        }
        onConfigureCellForAction = { [weak self] cell, action, indexPath in
            cell.setup(action.data?.title, detail: action.data?.subtitle, image: action.data?.image)
            cell.separatorView?.isHidden = indexPath.item == (self?.collectionView.numberOfItems(inSection: indexPath.section))! - 1
            cell.alpha = action.enabled ? 1.0 : 0.5
        }
    }
  
    required public init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.clipsToBounds = false
        collectionView.addSubview(hideBottomSpaceView)
        collectionView.sendSubview(toBack: hideBottomSpaceView)
    }

    @available(iOS 11, *)
    override open func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        hideBottomSpaceView.frame.size.height = contentHeight + TwitterActionController.bottomPadding + safeAreaInsets.bottom
        hideBottomSpaceView.frame.size.width = collectionView.bounds.width - safeAreaInsets.left - safeAreaInsets.right
    }

    override open func dismissView(_ presentedView: UIView, presentingView: UIView, animationDuration: Double, completion: ((_ completed: Bool) -> Void)?) {
        onWillDismissView()
        let animationSettings = settings.animation.dismiss
        let upTime = 0.1
        UIView.animate(withDuration: upTime, delay: 0, options: .curveEaseIn, animations: { [weak self] in
            self?.collectionView.frame.origin.y -= 10
        }, completion: { [weak self] (completed) -> Void in
            UIView.animate(withDuration: animationDuration - upTime,
                delay: 0,
                usingSpringWithDamping: animationSettings.damping,
                initialSpringVelocity: animationSettings.springVelocity,
                options: UIViewAnimationOptions.curveEaseIn,
                animations: { [weak self] in
                    presentingView.transform = CGAffineTransform.identity
                    self?.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
                },
                completion: { [weak self] finished in
                    self?.onDidDismissView()
                    completion?(finished)
                })
        })
    }
}

