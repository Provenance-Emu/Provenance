//  Spotify.swift
//  Spotify ( https://github.com/xmartlabs/XLActionController )
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

open class SpotifyCell: ActionCell {
    
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
        backgroundColor = .clear
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        selectedBackgroundView = backgroundView
        actionTitleLabel?.textColor = .white
        actionTitleLabel?.textAlignment = .left
        
    }
}

public struct SpotifyHeaderData {
    
    var title: String
    var subtitle: String
    var image: UIImage
    
    public init(title: String, subtitle: String, image: UIImage) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
    }
}

open class SpotifyHeaderView: UICollectionReusableView {
    
    open lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: CGRect.zero)
        imageView.image = UIImage(named: "sp-header-icon")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    open lazy var title: UILabel = {
        let title = UILabel(frame: CGRect.zero)
        title.font = UIFont(name: "HelveticaNeue-Bold", size: 18)
        title.text = "The Fast And ... The Furious Soundtrack Collection"
        title.textColor = UIColor.white
        title.translatesAutoresizingMaskIntoConstraints = false
        title.sizeToFit()
        return title
    }()
    
    open lazy var artist: UILabel = {
        let discArtist = UILabel(frame: CGRect.zero)
        discArtist.font = UIFont(name: "HelveticaNeue", size: 16)
        discArtist.text = "Various..."
        discArtist.textColor = UIColor.white.withAlphaComponent(0.8)
        discArtist.translatesAutoresizingMaskIntoConstraints = false
        discArtist.sizeToFit()
        return discArtist
    }()
    
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
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        addSubview(imageView)
        addSubview(title)
        addSubview(artist)
        let separator: UIView = {
            let separator = UIView(frame: CGRect.zero)
            separator.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            separator.translatesAutoresizingMaskIntoConstraints = false
            return separator
        }()
        addSubview(separator)
        
        let views = [ "ico": imageView, "title": title, "artist": artist, "separator": separator ]
        let metrics = [ "icow": 54, "icoh": 54 ]
        let options = NSLayoutFormatOptions()
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-15-[ico(icow)]-10-[title]-15-|", options: options, metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[separator]|", options: options, metrics: metrics, views: views))
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[ico(icoh)]", options: options, metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-18-[title][artist]", options: .alignAllLeft, metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[separator(1)]|", options: options, metrics: metrics, views: views))
    }
}

open class SpotifyActionController: ActionController<SpotifyCell, ActionData, SpotifyHeaderView, SpotifyHeaderData, UICollectionReusableView, Void> {
    
    fileprivate lazy var blurView: UIVisualEffectView = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        return blurView
    }()
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        backgroundView.addSubview(blurView)
        
        cancelView?.frame.origin.y = view.bounds.size.height // Starts hidden below screen
        cancelView?.layer.shadowColor = UIColor.black.cgColor
        cancelView?.layer.shadowOffset = CGSize( width: 0, height: -4)
        cancelView?.layer.shadowRadius = 2
        cancelView?.layer.shadowOpacity = 0.8
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        blurView.frame = backgroundView.bounds
    }
    
    public override init(nibName nibNameOrNil: String? = nil, bundle nibBundleOrNil: Bundle? = nil) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        settings.behavior.bounces = true
        settings.behavior.scrollEnabled = true
        settings.cancelView.showCancel = true
        settings.animation.scale = nil
        settings.animation.present.springVelocity = 0.0
        settings.cancelView.hideCollectionViewBehindCancelView = true
        
        cellSpec = .nibFile(nibName: "SpotifyCell", bundle: Bundle(for: SpotifyCell.self), height: { _ in 60 })
        headerSpec = .cellClass( height: { _ in 84 })
        
        onConfigureCellForAction = { [weak self] cell, action, indexPath in
            cell.setup(action.data?.title, detail: action.data?.subtitle, image: action.data?.image)
            cell.separatorView?.isHidden = indexPath.item == (self?.collectionView.numberOfItems(inSection: indexPath.section))! - 1
            cell.alpha = action.enabled ? 1.0 : 0.5
        }
        onConfigureHeader = { (header: SpotifyHeaderView, data: SpotifyHeaderData)  in
            header.title.text = data.title
            header.artist.text = data.subtitle
            header.imageView.image = data.image
        }
    }
  
    required public init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
    }
    
    open override func performCustomDismissingAnimation(_ presentedView: UIView, presentingView: UIView) {
        super.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
        cancelView?.frame.origin.y = view.bounds.size.height + 10
    }
    
    open override func onWillPresentView() {
        cancelView?.frame.origin.y = view.bounds.size.height
    }
}
