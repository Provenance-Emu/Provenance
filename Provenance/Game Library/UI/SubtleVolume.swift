//
//  SubtleVolume.swift
//  SubtleVolume
//
//  Created by Andrea Mazzini on 05/03/16.
//  Modified by Sev Gerk on 04/29/2018.
//  Copyright © 2016 Fancy Pixel. All rights reserved.
//

import AVFoundation
import MediaPlayer
import UIKit

/**
 The style of the volume indicator

 - Plain: A plain bar
 - RoundedLine: A plain bar with rounded corners
 - Dashes: A bar divided in dashes
 - Dots: A bar composed by a line of dots
 */
@objc public enum SubtleVolumeStyle: Int {
    case plain
    case roundedLine
    case dashes
    case dots
}

/**
 The entry and exit animation of the volume indicator

 - None: The indicator is always visible
 - SlideDown: The indicator fades in/out and slides from/to the top into position
 - FadeIn: The indicator fades in and out
 */
@objc public enum SubtleVolumeAnimation: Int {
    case none
    case slideDown
    case fadeIn
}

/**
 Errors being thrown by `SubtleError`.

 - unableToChangeVolumeLevel: `SubtleVolume` was unable to change audio level
 */
public enum SubtleVolumeError: Error {
    case unableToChangeVolumeLevel
}

/**
 Delegate protocol fo `SubtleVolume`.
 Notifies the delegate when a change is about to happen (before the entry animation)
 and when a change occurred (and the exit animation is complete)
 */
@objc public protocol SubtleVolumeDelegate {
    /**
     The volume is about to change. This is fired before performing any entry animation

     - parameter subtleVolume: The current instance of `SubtleVolume`
     - parameter value: The value of the volume (between 0 an 1.0)
     */
    @objc func subtleVolume(_ subtleVolume: SubtleVolume, willChange value: Double)

    /**
     The volume did change. This is fired after the exit animation is done

     - parameter subtleVolume: The current instance of `SubtleVolume`
     - parameter value: The value of the volume (between 0 an 1.0)
     */
    @objc func subtleVolume(_ subtleVolume: SubtleVolume, didChange value: Double)
}

/**
 Replace the system volume popup with a more subtle way to display the volume
 when the user changes it with the volume rocker.
 */
@objc open class SubtleVolume: UIView {
    /**
     The style of the volume indicator
     */
    open var style = SubtleVolumeStyle.plain

    /**
     The entry and exit animation of the indicator. The animation is triggered by the volume
     If the animation is set to `.None`, the volume indicator is always visible
     */
    open var animation = SubtleVolumeAnimation.none {
        didSet {
            updateVolume(volumeLevel, animated: false)
        }
    }

    open var barBackgroundColor = UIColor.clear {
        didSet {
            backgroundColor = barBackgroundColor
        }
    }

    open var barTintColor = UIColor.white {
        didSet {
            overlay.backgroundColor = barTintColor
        }
    }

    open weak var delegate: SubtleVolumeDelegate?

    fileprivate let volume = MPVolumeView(frame: CGRect.zero)
    fileprivate let overlay = UIView()
    public fileprivate(set) var volumeLevel = Double(0)
    public static let DefaultVolumeStep: Double = 0.05

    private var audioSessionOutputVolumeObserver: Any?

    @objc public convenience init(style: SubtleVolumeStyle, frame: CGRect) {
        self.init(frame: frame)
        self.style = style
    }

    @objc public convenience init(style: SubtleVolumeStyle) {
        self.init(style: style, frame: CGRect.zero)
    }

    @objc public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    @objc public required override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init() {
        fatalError("Please use the convenience initializers instead")
    }

    /// Increase the volume by a given step
    ///
    /// - Parameter delta: the volume increase. The volume goes from 0 to 1, delta must be a Double in that range
    /// - Throws: `SubtleVolumeError.unableToChangeVolumeLevel`
    @objc public func increseVolume(by step: Double = DefaultVolumeStep, animated: Bool = false) throws {
        try setVolumeLevel(volumeLevel + step, animated: animated)
    }

    /// Increase the volume by a given step
    ///
    /// - Parameter delta: the volume increase. The volume goes from 0 to 1, delta must be a Double in that range
    /// - Throws: `SubtleVolumeError.unableToChangeVolumeLevel`
    @objc public func decreaseVolume(by step: Double = DefaultVolumeStep, animated: Bool = false) throws {
        try setVolumeLevel(volumeLevel - step, animated: animated)
    }

    /**
     Programatically set the volume level.

     - parameter volumeLevel: The new level of volume (between 0 an 1.0)
     - parameter animated: Indicating whether the change should be animated
     */
    @objc public func setVolumeLevel(_ volumeLevel: Double, animated: Bool = false) throws {
        #if !os(tvOS)
        guard let slider = volume.subviews.compactMap({ $0 as? UISlider }).first else {
            throw SubtleVolumeError.unableToChangeVolumeLevel
        }

        let updateVolume = {
            // Trick iOS into thinking that slider value has changed
            slider.value = max(0, min(1, Float(volumeLevel)))
        }

        // If user opted out of animation, toggle observation for the duration of the change
        if !animated {
            audioSessionOutputVolumeObserver = nil

            updateVolume()

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { [weak self] in
                guard let `self` = self else { return }
                self.audioSessionOutputVolumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume) { [weak self] audioSession, _ in
                    guard let `self` = self else { return }
                    self.updateVolume(Double(audioSession.outputVolume), animated: true)
                }
            }
        } else {
            updateVolume()
        }
        #else
        #endif
    }

    /// Resume audio session. Call this once the app becomes active after being pushed in background
    @objc public func resume() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Unable to initialize AVAudioSession")
            return
        }
    }

    fileprivate func setup() {
        resume()
        updateVolume(Double(AVAudioSession.sharedInstance().outputVolume), animated: false)
        audioSessionOutputVolumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume) { [weak self] audioSession, _ in
            guard let `self` = self else { return }
            self.updateVolume(Double(audioSession.outputVolume), animated: true)
        }

        backgroundColor = .clear

        volume.setVolumeThumbImage(UIImage(), for: UIControl.State())
        volume.isUserInteractionEnabled = false
        volume.alpha = 0.0001
        volume.showsRouteButton = false

        addSubview(volume)

        overlay.backgroundColor = .black
        addSubview(overlay)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        overlay.frame = frame
        overlay.layer.cornerRadius = overlay.frame.height / 2
        overlay.frame = CGRect(x: 0, y: 0, width: frame.size.width * CGFloat(volumeLevel), height: frame.size.height)
    }

    fileprivate func updateVolume(_ value: Double, animated: Bool) {
        delegate?.subtleVolume(self, willChange: value)
        volumeLevel = value

        UIView.animate(withDuration: animated ? 0.1 : 0, animations: { () -> Void in
            self.overlay.frame.size.width = self.frame.size.width * CGFloat(self.volumeLevel)
        })

        UIView.animateKeyframes(withDuration: animated ? 1.5 : 0, delay: 0, options: .beginFromCurrentState, animations: { () -> Void in
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2, animations: {
                switch self.animation {
                case .none: break
                case .fadeIn:
                    self.alpha = 1
                case .slideDown:
                    self.alpha = 1
                    self.transform = CGAffineTransform.identity
                }
            })

            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2, animations: { () -> Void in
                switch self.animation {
                case .none: break
                case .fadeIn:
                    self.alpha = 0.0001
                case .slideDown:
                    self.alpha = 0.0001
                    self.transform = CGAffineTransform(translationX: 0, y: -self.frame.height)
                }
            })

        }) { _ in
            self.delegate?.subtleVolume(self, didChange: value)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
