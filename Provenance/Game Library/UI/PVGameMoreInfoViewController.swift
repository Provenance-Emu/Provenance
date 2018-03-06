//
//  PVGameMoreInfoViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

#if os(iOS)
import SafariServices
#endif
    
class PVGameMoreInfoViewController: UIViewController, GameLaunchingViewController {

    @objc
    var game : PVGame? {
        didSet {
            if isViewLoaded {
                updateContent()
            }
        }
    }
    
    @objc
    var showsPlayButton : Bool = true {
        didSet {
            #if os(iOS)
            if showsPlayButton {
                navigationItem.rightBarButtonItems = [playBarButtonItem, onlineLookupBarButtonItem]
            } else {
                navigationItem.rightBarButtonItems = [onlineLookupBarButtonItem]
            }
            #endif
        }
    }
    
    @IBOutlet weak var artworkImageView: UIImageView!
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var systemLabel: UILabel!
    @IBOutlet weak var developerLabel: UILabel!
    @IBOutlet weak var publisherLabel: UILabel!
    @IBOutlet weak var publishDateLabel: UILabel!
    @IBOutlet weak var genresLabel: UILabel!
    @IBOutlet weak var regionLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    @IBOutlet var singleImageTapGesture: UITapGestureRecognizer!
    @IBOutlet var doubleImageTapGesture: UITapGestureRecognizer!
    
    @IBOutlet var playCountLabel : UILabel!
    @IBOutlet var timeSpentLabel : UILabel!
    
    #if os(iOS)
    @IBOutlet weak var onlineLookupBarButtonItem: UIBarButtonItem!
    #endif
    @IBOutlet weak var playBarButtonItem: UIBarButtonItem!
    
    var mustRefreshDataSource = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Prevent double tap from triggering single tap also
        #if os(iOS)
        singleImageTapGesture.require(toFail: doubleImageTapGesture)
        #endif
        
        // Add a shadow to artwork
        let layer = artworkImageView.layer
        artworkImageView.clipsToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 1)
        layer.shadowRadius = 4.0
        layer.shadowOpacity = 0.7
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateContent()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    private func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    func updateContent() {
        self.title = game?.title
        
        #if os(iOS)
        if showsPlayButton {
            navigationItem.rightBarButtonItems = [playBarButtonItem, onlineLookupBarButtonItem]
        } else {
            navigationItem.rightBarButtonItems = [onlineLookupBarButtonItem]
        }
        #endif
        
        nameLabel.text = game?.title ?? ""
        systemLabel.text = game?.systemShortName ?? ""
        developerLabel.text = game?.developer  ?? ""
        publisherLabel.text = game?.publisher  ?? ""
        publishDateLabel.text = game?.year  ?? ""
        genresLabel.text = game?.genres?.components(separatedBy: ",").joined(separator: ", ")  ?? ""
        
        if let regionText = game?.regionName {
            let flags = ["Europe" : "🇪🇺", "USA" : "🇺🇸", "Japan" : "🇯🇵", "World" : "🌎", "Korea" : "🇰🇷", "Spain" : "🇪🇸", "Taiwan" : "🇹🇼", "China" : "🇨🇳", "Australia" : "🇦🇺", "Netherlands" : "🇳🇱", "Italy" : "🇮🇹", "Germany" : "🇩🇪", "France" : "🇫🇷", "Brazil" : "🇧🇷", "Asia" : "🌏"]
            regionLabel.text = flags.reduce(regionText, { (result, dict) -> String in
                let (text, flag) = dict
                return result.replacingOccurrences(of: text, with: flag)
            })
        } else {
            regionLabel.text = ""
        }
        
        var descriptionText = game?.gameDescription  ?? ""
        #if DEBUG
            descriptionText = [game?.debugDescription ?? "", descriptionText].joined(separator: "\n")
        #endif
        descriptionTextView.text = descriptionText
        
        let playsText : String
        if let playCount = game?.playCount {
            playsText = "\(playCount)"
        } else {
            playsText = "Never"
        }
        playCountLabel.text = playsText
        
        let timeSpentText : String
        if let timeSpent = game?.timeSpentInGame {
            let calendar = Calendar(identifier: .gregorian)
            let calendarUnitFlags: Set<Calendar.Component> = Set([.year, .month, .day, .hour, .minute, .second])
            let components = calendar.dateComponents(calendarUnitFlags, from: Date(), to: Date(timeIntervalSinceNow: TimeInterval(timeSpent)))
            
            var textBuilder = ""
            if let days = components.day, days > 0 {
                textBuilder += "\(days) Days, "
            }
            
            if let hours = components.hour, hours > 0 {
                textBuilder += "\(hours) Hours, "
            }
            
            if let minutes = components.minute, minutes > 0 {
                textBuilder += "\(minutes) Minutes, "
            }

            if let seconds = components.second, seconds > 0 {
                textBuilder += "\(seconds) Seconds"
            }

            if !textBuilder.isEmpty {
                timeSpentText = textBuilder
            } else {
                timeSpentText = "None"
            }
            
        } else {
            timeSpentText = "None"
        }
        timeSpentLabel.text = timeSpentText
        
        updateImageView()
        
        #if os(iOS)
        if let referenceURL = game?.referenceURL, !referenceURL.isEmpty {
            onlineLookupBarButtonItem.isEnabled = true
        } else {
            onlineLookupBarButtonItem.isEnabled = false
        }
        #endif
    }

    var showingFrontArt = true

    var canShowBackArt : Bool {
        if let backArt = game?.boxBackArtworkURL, !backArt.isEmpty {
            return true
        } else {
            return false
        }
    }
    
    #if os(iOS)
    @IBAction func moreInfoButtonClicked(_ sender: UIBarButtonItem) {
        if #available(iOS 9.0, *) {
            if let urlString = game?.referenceURL, let url = URL(string:urlString) {
                if #available(iOS 11.0, *) {
                    let config = SFSafariViewController.Configuration()
                    config.barCollapsingEnabled = true
                    config.entersReaderIfAvailable = true
                    
                    let webVC = SFSafariViewController(url: url, configuration: config)
                    present(webVC, animated: true, completion: nil)
                } else {
                    let webVC = SFSafariViewController(url: url, entersReaderIfAvailable: true)
                    present(webVC, animated: true, completion: nil)
                }
            }
        } else {
            let alert = UIAlertController(title: "Not supported", message: "Feature requires iOS 9 or above", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    #endif
    
    @IBAction func imageViewTapped(_ sender: UITapGestureRecognizer) {
        if canShowBackArt {
            showingFrontArt = !showingFrontArt
            updateImageView()
        }
    }
    
    @IBAction func imageViewDoubleTapped(_ sender: UITapGestureRecognizer) {
        let mediaZoom = MediaZoom(with: artworkImageView, animationTime: 0.5, useBlur: true)
        view.addSubview(mediaZoom)
        mediaZoom.show {
            mediaZoom.removeFromSuperview()
        }
    }
    
    @IBAction func playButtonTapped(_ sender: UIBarButtonItem) {
        if let game = game {
            load(game)
        }
    }
    
    private func updateImageView() {
        if showingFrontArt {
            if let imageKey = (game?.customArtworkURL.isEmpty ?? true) ? game?.originalArtworkURL : game?.customArtworkURL {
                PVMediaCache.shareInstance().image(forKey: imageKey, completion: { (image) in
                    if let image = image {
                        self.flipImageView(withImage: image)
                    }
                })
            }
        } else {
            if let imageKey = game?.boxBackArtworkURL, !imageKey.isEmpty {
                PVMediaCache.shareInstance().image(forKey: imageKey, completion: { (image) in
                    if let image = image {
                        self.flipImageView(withImage: image)
                    } else {
                        // Need to download
                        guard let url = URL(string: imageKey) else {
                            ELOG("Couldn't create URL with \(imageKey)")
                            return
                        }
                        
                        // Download the art now
                        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                            if let data = data {
                                
                                // Save to cache for later
                                _ = try? PVMediaCache.writeData(toDisk: data, withKey: imageKey)
                                
                                DispatchQueue.main.async {
                                    if let newImage = UIImage(data: data) {
                                        self.flipImageView(withImage: newImage)
                                    }
                                }
                            }
                        }).resume()
                    }
                })
            }
        }
    }
    
    private func flipImageView(withImage image : UIImage) {
        let direction : UIViewAnimationOptions = showingFrontArt ? .transitionFlipFromLeft : .transitionFlipFromRight
        UIView.transition(with: artworkImageView, duration: 0.4, options: direction, animations: {
            self.artworkImageView.image = image
        }, completion: nil)
    }
}

// TEMP

//
//  MediaZoom.swift
//  MediaZoom (https://github.com/xmartlabs/XLMediaZoom)
//
//  Copyright (c) 2017 Xmartlabs ( http://xmartlabs.com )
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
//

import UIKit

public class MediaZoom: UIView, UIScrollViewDelegate {
    
    public lazy var imageView: UIImageView = {
        let image = UIImageView(frame: self.mediaFrame())
        image.clipsToBounds = true
        image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        image.contentMode = .scaleAspectFill
        return image
    }()
    
    public var maxAlpha: CGFloat = 1
    public var hideHandler: (() -> ())?
    public var useBlurEffect = false
    public var animationTime: Double
    public var originalImageView: UIImageView
    public var backgroundView: UIView
    public lazy var contentView: UIScrollView = {
        let contentView = UIScrollView(frame: MediaZoom.currentFrame())
        contentView.contentSize = self.mediaFrame().size
        contentView.backgroundColor = .clear
        contentView.maximumZoomScale = 1.5
        return contentView
    }()
    
    public init(with image: UIImageView, animationTime: Double, useBlur: Bool = false) {
        let frame = MediaZoom.currentFrame()
        self.animationTime = animationTime
        useBlurEffect = useBlur
        originalImageView = image
        backgroundView = MediaZoom.backgroundView(with: frame, useBlur: useBlur)
        super.init(frame: frame)
        
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange(notification:)),
            name: .UIDeviceOrientationDidChange,
            object: nil
        )
        #endif
        imageView.image = image.image
        addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(handleSingleTap(sender:))
            )
        )
        contentView.addSubview(imageView)
        contentView.delegate = self
        addSubview(backgroundView)
        addSubview(contentView)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show(onHide callback: (() -> ())? = nil) {
        let frame = MediaZoom.currentFrame()
        self.frame = frame
        backgroundView.frame = frame
        imageView.frame = mediaFrame()
        hideHandler = callback
        UIView.animate(
            withDuration: animationTime,
            animations: { [weak self] in
                guard let `self` = self else { return }
                self.imageView.frame = self.imageFrame()
                self.backgroundView.alpha = self.maxAlpha
            },
            completion: { [weak self] finished in
                if finished {
                    self?.showAnimationDidFinish()
                }
            }
        )
    }
    
    private static func backgroundView(with frame: CGRect, useBlur: Bool) -> UIView {
        if useBlur {
            let blurView = UIVisualEffectView(frame: frame)
            blurView.effect = UIBlurEffect(style: .dark)
            blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            blurView.alpha = 0
            return blurView
        } else {
            let bgView = UIView(frame: frame)
            bgView.backgroundColor = .black
            bgView.alpha = 0
            return bgView
        }
    }
    
    private static func currentFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds
        return CGRect(
            x: CGFloat(0),
            y: CGFloat(0),
            width: screenSize.width,
            height: screenSize.height
        )
    }
    
    private func imageFrame() -> CGRect {
        let size = bounds
        guard let imageSize = imageView.image?.size else { return CGRect.zero }
        let ratio = min(size.height / imageSize.height, size.width / imageSize.width)
        let imageWidth = imageSize.width * ratio
        let imageHeight = imageSize.height * ratio
        let imageX = (frame.size.width - imageWidth) * 0.5
        let imageY = (frame.size.height - imageHeight) * 0.5
        return CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)
    }
    
    private func mediaFrame() -> CGRect {
        return originalImageView.frame
    }
    
    #if os(iOS)
    @objc func deviceOrientationDidChange(notification: NSNotification) {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeLeft, .landscapeRight, .portrait:
            let newFrame = MediaZoom.currentFrame()
            frame = newFrame
            backgroundView.frame = newFrame
            imageView.frame = imageFrame()
        default:
            break
        }
    }
    #endif
    
    @objc public func handleSingleTap(sender: UITapGestureRecognizer) {
        willHandleSingleTap()
        UIView.animate(
            withDuration: animationTime,
            animations: { [weak self] in
                guard let `self` = self else { return }
                self.contentView.zoomScale = 1
                self.imageView.frame = self.mediaFrame()
                self.backgroundView.alpha = 0
            },
            completion: { [weak self] finished in
                if finished {
                    self?.removeFromSuperview()
                    self?.contentView.zoomScale = 1
                    self?.hideHandler?()
                }
            }
        )
    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        let yOffset = (scrollView.frame.height - imageView.frame.height) / 2.0
        let xOffset = (scrollView.frame.width - imageView.frame.width) / 2.0
        let x = xOffset > 0 ? xOffset : scrollView.frame.origin.x
        let y = yOffset > 0 ? yOffset : scrollView.frame.origin.y
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.imageView.frame.origin = CGPoint(x: x, y: y)
        }
        return imageView
    }
    
    open func willHandleSingleTap() {
        
    }
    
    open func showAnimationDidFinish() {
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
