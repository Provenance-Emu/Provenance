//  MTLViewController.swift
//  Copyright © 2023 Provenance Emu. All rights reserved.

import Foundation
import UIKit
import MetalKit
import os

@objc public class AzaharVulkanViewController: UIViewController {
	private var core: PVAzaharCoreBridge!
	private var metalView: MTKView!
	private var dev: MTLDevice!

    @objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat, core: PVAzaharCoreBridge) {
		super.init(nibName: nil, bundle: nil)
		self.core = core;
		self.dev = MTLCreateSystemDefaultDevice()!
		metalView = MTKView(frame: UIScreen.main.bounds, device: dev)
		metalView.isUserInteractionEnabled=true
		metalView.contentMode = .scaleToFill;
		metalView.colorPixelFormat = .bgra8Unorm;
		metalView.depthStencilPixelFormat = .depth32Float
		metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.preferredFramesPerSecond = 120
	}
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
	required init?(coder: NSCoder) {
		super.init(coder:coder)
	}
	@objc public override func viewDidLoad() {
		NSLog("VulkanViewController: View Did Load\n")
		self.view=metalView;
        NSLog("VulkanViewController: Starting VM\n")
        core.startVM(self.view)
        
        // Keyboard
        NotificationCenter.default.addObserver(forName: .init("openKeyboard"), object: nil, queue: .main) { notification in
            guard let config = notification.object as? KeyboardConfig else {
                return
            }
            
            let alertController = TVAlertController(title: nil, message: nil, preferredStyle: .alert)
            alertController.preferredContentSize = CGSize(width: 300, height: 300)

            let cancelAction: UIAlertAction = .init(title: "Cancel", style: .cancel) { _ in
                NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                    "buttonPressed" : 0,
                    "keyboardText" : ""
                ])
            }
            
            let okayButton: UIAlertAction = .init(title: "OK", style: .default) { _ in
                guard let textFields = alertController.textFields, let textField = textFields.first else {
                    return
                }
                
                NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                    "buttonPressed" : 0,
                    "keyboardText" : textField.text ?? ""
                ])
            }
            
            alertController.addTextField()
            
            switch config.buttonConfig {
            case .single:
                alertController.addAction(okayButton)
            case .dual:
                alertController.addAction(okayButton)
                alertController.addAction(cancelAction)
            case .triple:
                alertController.addAction(okayButton)
                alertController.addAction(cancelAction)
                break
            case .none:
                break
            @unknown default:
                break
            }
            
            
            self.present(alertController, animated: true)
        }
	}
	@objc public override func viewDidLayoutSubviews() {
        NSLog("View Size Changed\n")
        core.refreshScreenSize()
	}
}

@available(iOS 13.0, tvOS 13.0, *)
@objc public class PVMTLView: MTKView, MTKViewDelegate {
	private let queue: DispatchQueue = DispatchQueue.init(label: "renderQueue", qos: .userInteractive)
	private var hasSuspended: Bool = false
	private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
	private let context: CIContext
	private let commandQueue: MTLCommandQueue
	private var nearestNeighborRendering: Bool
	private var integerScaling: Bool
	private var checkForRedundantFrames: Bool
	private var currentScale: CGFloat = 1.0
	private var viewportOffset: CGPoint = CGPoint.zero
	private var lastDrawableSize: CGSize = CGSize.zero
	private var tNesScreen: CGAffineTransform = CGAffineTransform.identity
	private var gameScreenSize: CGSize = CGSize.zero
	private var resolutionFactor: Int8 = 1
	static private let elementLength: Int = 4
	static private let bitsPerComponent: Int = 8

	required init(coder: NSCoder) {
		let dev: MTLDevice = MTLCreateSystemDefaultDevice()!
        // Check if the GPU is at least the A9
        let featureSet: MTLFeatureSet
    #if os(tvOS)
        featureSet = .tvOS_GPUFamily2_v2
    #else
        featureSet = .iOS_GPUFamily3_v2
    #endif
        guard dev.supportsFeatureSet(featureSet) else {
            assertionFailure("GPU doesn't support required MTL feature set.")
            fatalError("GPU doesn't support required MTL feature set.")
        }

		let commandQueue = dev.makeCommandQueue()!
		self.context = CIContext.init(mtlCommandQueue: commandQueue, options: [.cacheIntermediates: false])
		self.commandQueue = commandQueue
		self.nearestNeighborRendering = true
		self.checkForRedundantFrames = true
		self.integerScaling = true
		super.init(coder: coder)
	}

	init(gameScreenSize: CGSize, resolutionFactor: Int8) {
		let dev: MTLDevice = MTLCreateSystemDefaultDevice()!
        // Check if the GPU is at least the A9
        let featureSet: MTLFeatureSet
    #if os(tvOS)
        featureSet = .tvOS_GPUFamily2_v2
    #else
        featureSet = .iOS_GPUFamily3_v2
    #endif
        guard dev.supportsFeatureSet(featureSet) else {
            assertionFailure("GPU doesn't support required MTL feature set.")
            fatalError("GPU doesn't support required MTL feature set.")
        }
		self.gameScreenSize = gameScreenSize
		self.resolutionFactor = resolutionFactor
		self.commandQueue = dev.makeCommandQueue()!
		self.context = CIContext.init(mtlCommandQueue: self.commandQueue, options: [.cacheIntermediates: false])
		self.nearestNeighborRendering = true
		self.checkForRedundantFrames = true
		self.integerScaling = true
		let videoBounds = CGRect( x: 0,
							y: 0,
							width: (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)),
							height: (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)))
		super.init(frame: videoBounds, device: dev)
		self.device = dev
		self.isPaused = true
		self.enableSetNeedsDisplay = false
		self.framebufferOnly = false
		self.delegate = self
		self.isOpaque = true
		self.clearsContextBeforeDrawing = true
		/* Azahar Parameters */
		self.isUserInteractionEnabled=false;
		self.contentMode = .scaleToFill;
		self.colorPixelFormat = .bgra8Unorm;
		self.depthStencilPixelFormat = .depth32Float
		self.translatesAutoresizingMaskIntoConstraints = false
		self.setResolution()
		NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive), name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	func setResolution() {
		let scale:CGFloat = UIScreen.main.scale
		if (scale != 1.0) {
			self.layer.contentsScale = scale;
			self.layer.rasterizationScale = scale;
			self.contentScaleFactor = scale;
		}
		let screenBounds=UIScreen.main.bounds
		// Resize masks
		self.layer.anchorPoint=CGPoint(x: 0, y: 0)
		let gameFrameSize = CGRect(x: 0,
								   y: 0,
								   width: (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)),
								   height: (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)))
		self.layer.frame = gameFrameSize
		self.drawableSize=CGSize(width: gameFrameSize.width, height: gameFrameSize.height)

		self.autoResizeDrawable = true
		self.autoresizingMask  = [.flexibleHeight, .flexibleWidth,
								  .flexibleRightMargin,
								  .flexibleLeftMargin]
		// Adjust to Resolution Upscaled Vulkan Render
		let xScale = screenBounds.width / (CGFloat)(gameScreenSize.width * CGFloat(resolutionFactor)) ;
		let yScale = screenBounds.height / (CGFloat)(gameScreenSize.height * CGFloat(resolutionFactor)) ;
		self.layer.setAffineTransform(
			CGAffineTransform(scaleX: xScale,
							  y: yScale)
		)
		self.autoresizesSubviews = true
		self.contentMode = .scaleToFill
	}

	var buffer: [UInt32] = [UInt32]() {
		didSet {
			guard !self.checkForRedundantFrames || self.drawableSize != self.lastDrawableSize || !self.buffer.elementsEqual(oldValue)
			else {
				return
			}

			self.queue.async { [weak self] in
				self?.draw()
			}
		}
	}

	// MARK: - MTKViewDelegate
	public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
	}

	public func draw(in view: MTKView) {
	}

	@objc private func appResignedActive() {
		self.queue.suspend()
		self.hasSuspended = true
	}

	@objc private func appBecameActive() {
		if self.hasSuspended {
			self.queue.resume()
			self.hasSuspended = false
		}
	}
}

//  TVAlertController.swift
//  Wombat
//
//  implement a custom UIAlertController for tvOS, using a UIStackView full of buttons and duct tape.
//
//  Oh it also works on iOS...
//
//  Created by Todd Laney on 22/01/2022.
//

#if canImport(UIKit)
import UIKit
import PVLogging

// these are the defaults assuming Dark mode, etc.
let _fullscreenColor = UIColor.black.withAlphaComponent(0.8)
let _destructiveButtonColor = UIColor.systemRed.withAlphaComponent(0.5)
let _borderWidth = 4.0
let _fontTitleF = 1.25
let _animateDuration = 0.150

// os specific defaults
#if os(tvOS)
let _blurFullscreen = false
let _font = UIFont.systemFont(ofSize: 24.0)
let _inset:CGFloat = 16.0
let _maxTextWidthF:CGFloat = 0.25
let _backgroundColor = UIColor(red:0.1, green:0.1, blue:0.1, alpha:1)      // secondarySystemGroupedBackground
package let _defaultButtonColor = UIColor(white: 0.2, alpha: 1)
#else
let _blurFullscreen = true
let _font = UIFont.preferredFont(forTextStyle: .body)
let _inset:CGFloat = 16.0
let _maxTextWidthF:CGFloat = 0.50
let _backgroundColor = UIColor.secondarySystemGroupedBackground
let _defaultButtonColor = UIColor.systemGray4
#endif


internal extension UIAlertAction {
    func callActionHandler() {
        if let handler = self.value(forKey:"handler") as? NSObject {
            unsafeBitCast(handler, to:(@convention(block) (UIAlertAction) -> Void).self)(self)
        }
    }
}

extension UIAlertAction {
    convenience init(title: String, symbol:String, style: UIAlertAction.Style, handler: @escaping ((UIAlertAction) -> Void)) {
        self.init(title: title, style: style, handler: handler)
#if os(iOS)
    if let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(font: _font)) {
        self.setValue(image, forKey: "image")
    }
#endif
    }
    func getImage() -> UIImage? {
        return self.value(forKey: "image") as? UIImage
    }
}


internal protocol UIAlertControllerProtocol : UIViewController {

     func addAction(_ action: UIAlertAction)
     var actions: [UIAlertAction] { get }

     var preferredAction: UIAlertAction? { get set }

    @MainActor
     func addTextField(configurationHandler: ((UITextField) -> Void)?)
     var textFields: [UITextField]? { get }

     var title: String? { get set }
     var message: String? { get set }
     var preferredStyle: UIAlertController.Style { get }
}

// take over (aka mock) the UIAlertController initializer and return our class
internal func UIAlertController(title: String?, message: String?, preferredStyle style: UIAlertController.Style = .alert) -> UIAlertControllerProtocol {
    TVAlertController.init(title:title, message: message, preferredStyle: style)
}

extension UIAlertController : UIAlertControllerProtocol { }

internal final class TVAlertController: UIViewController, UIAlertControllerProtocol {

    internal var preferredStyle = UIAlertController.Style.alert
    internal var actions = [UIAlertAction]()
    internal var textFields:[UITextField]?
    internal var preferredAction: UIAlertAction?
    internal var cancelAction: UIAlertAction?

    internal var autoDismiss = true          // a UIAlertController is always autoDismiss

    internal private(set) var doubleStackHeight = 0

    private let stack = {() -> UIStackView in
        let stack = UIStackView(arrangedSubviews: [UILabel(), UILabel()])
        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .fill
        stack.spacing = floor(_font.lineHeight / 4.0)
        return stack
    }()

    // MARK: init

    internal convenience init(title: String?, message: String?, preferredStyle: UIAlertController.Style) {
        self.init(nibName:nil, bundle: nil)
        self.title = title
        self.message = message
        self.preferredStyle = preferredStyle

        #if os(tvOS)
            self.modalPresentationStyle = _blurFullscreen ?  .blurOverFullScreen : .overFullScreen
        #else
            self.modalPresentationStyle = .overFullScreen
            self.modalTransitionStyle = .crossDissolve
        #endif
    }

    internal var spacing: CGFloat {
        get {
            return stack.spacing
        }
        set {
            stack.spacing = newValue
        }
    }

    internal var font = _font {
        didSet {
             spacing = floor(font.lineHeight / 4.0)
        }
    }

    // MARK: UIAlertControllerProtocol

    internal override var title: String? {
        set {
            if let label = stack.arrangedSubviews.first(where: {$0 is UILabel}) as? UILabel {
                label.text = newValue
                label.font = .boldSystemFont(ofSize: font.pointSize * _fontTitleF)
                label.numberOfLines = 0
                label.textAlignment = .center
                label.preferredMaxLayoutWidth = maxTextWidth
            }
        }
        get {
            return (stack.arrangedSubviews.first(where: {$0 is UILabel}) as? UILabel)?.text
        }
    }

    internal var message: String? {
        set {
            let label = stack.arrangedSubviews[1] as! UILabel
            label.text = newValue
            label.font = self.font
            label.numberOfLines = 0
            label.textAlignment = .center
            label.preferredMaxLayoutWidth = maxTextWidth
        }
        get {
            return (stack.arrangedSubviews[1] as? UILabel)?.text
        }
    }

    internal func addAction(_ action: UIAlertAction) {
        if action.style == .cancel {
            cancelAction = action
            if preferredStyle == .actionSheet {
                return
            }
        }
        actions.append(action)
        stack.addArrangedSubview(makeButton(action))
    }

    internal func addTextField(configurationHandler: ((UITextField) -> Void)? = nil) {
        let textField = UITextField()
        textField.font = font
        textField.borderStyle = .roundedRect
        let h = font.lineHeight * 1.5
        let w = (UIApplication.shared.windows.first { $0.isKeyWindow }?.bounds.width ?? UIScreen.main.bounds.width)  * 0.50
        textField.addConstraint(NSLayoutConstraint(item:textField, attribute:.height, relatedBy:.equal, toItem:nil, attribute:.notAnAttribute, multiplier:1.0, constant:h))
        textField.addConstraint(NSLayoutConstraint(item:textField, attribute:.width, relatedBy:.greaterThanOrEqual, toItem:nil, attribute:.notAnAttribute, multiplier:1.0, constant:w))
        textFields = textFields ?? []
        textFields?.append(textField)
        configurationHandler?(textField)
        stack.addArrangedSubview(textField)
    }

    // MARK: load

    internal override func viewDidLoad() {
        super.viewDidLoad()

        // setup a tap to dissmiss
        #if os(tvOS)
            let tap = UITapGestureRecognizer(target:self, action: #selector(tapBackgroundToDismiss(_:)))
            tap.allowedPressTypes = [.menu]
            view.addGestureRecognizer(tap)
        #else
            view.addGestureRecognizer(UITapGestureRecognizer(target:self, action: #selector(tapBackgroundToDismiss(_:))))
        #endif

        // *maybe* convert into a two-collumn stack
        let traits = UIApplication.shared.windows.first { $0.isKeyWindow }?.traitCollection
        if actions.count >= 8 && textFields == nil &&
            (traits?.verticalSizeClass == .compact || traits?.horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .phone) {
            doubleStack()
        }

        let menu = UIView()
        menu.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.centerXAnchor.constraint(equalTo:menu.centerXAnchor).isActive = true
        stack.centerYAnchor.constraint(equalTo:menu.centerYAnchor).isActive = true
        view.addSubview(menu)

        menu.layer.cornerRadius = _inset
        menu.backgroundColor = isFullscreen ? _backgroundColor : nil
        view.backgroundColor = (isFullscreen && !_blurFullscreen) ? _fullscreenColor : nil

        #if os(iOS)
        if _blurFullscreen && isFullscreen {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blur.frame = view.bounds
            view.insertSubview(blur, at: 0)
        }
        #endif
    }

    // convert menu to two columns
    private func doubleStack() {

        // dont merge non destructive or cancel items
        let count = actions.firstIndex(where: {$0.style != .default}) ?? actions.count
        let n = count / 2
        self.doubleStackHeight = n  // remember this

        let spacing = self.spacing
        for i in 0..<n {
            guard let lhs = button(for:actions[i]),
                  let rhs = button(for:actions[i+n]),
                  let idx = stack.arrangedSubviews.firstIndex(of: lhs)
                  else { break }
            lhs.removeFromSuperview()
            rhs.removeFromSuperview()
            (lhs as? TVButton)?.setGrowDelta(spacing * 0.5, for: .focused)
            (rhs as? TVButton)?.setGrowDelta(spacing * 0.5, for: .focused)
            (lhs as? TVButton)?.setGrowDelta(spacing * 0.5, for: .selected)
            (rhs as? TVButton)?.setGrowDelta(spacing * 0.5, for: .selected)
            let hstack = UIStackView(arrangedSubviews: [lhs, rhs])
            hstack.spacing = spacing
            hstack.distribution = .fillEqually
            stack.insertArrangedSubview(hstack, at:idx)
         }
    }

    #if !os(tvOS) && !os(iOS)
    /*
    override var popoverPresentationController: UIPopoverPresentationController? {

        // if caller is asking for a ppc, they must want a popup!
        guard let tc = UIApplication.shared.windows.first { $0.isKeyWindow }?.traitCollection else {
            ELOG("Nil train collection")
            return nil
        }
        if tc.userInterfaceIdiom == .pad && tc.horizontalSizeClass == .regular {
            self.modalPresentationStyle = .popover
        } else {
            self.modalPresentationStyle = .automatic
        }

        return super.popoverPresentationController
    }
     */
    #endif

    // MARK: layout and size

    // are we fullscreen (aka not a popover)
    private var isFullscreen: Bool {
        #if os(tvOS) || os(macOS)
            return true
        #else
            return modalPresentationStyle == .overFullScreen
        #endif
    }

    private var maxTextWidth: CGFloat {
        let width = UIApplication.shared.windows.first { $0.isKeyWindow }?.bounds.width ?? UIScreen.main.bounds.width
        let tc = UIApplication.shared.windows.first { $0.isKeyWindow }?.traitCollection

        if tc?.horizontalSizeClass == .compact {
            return width * 0.80
        }

        return width * _maxTextWidthF
    }

    internal override var preferredContentSize: CGSize {
        get {
            var size = stack.systemLayoutSizeFitting(.zero)
            if size != .zero {
                size.width  += (_inset * 2)
                size.height += (_inset * 2)
            }
            return size
        }
        set {
            super.preferredContentSize = newValue
        }
    }

    internal override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let content = view.subviews.last else {return}

        let rect = CGRect(origin: .zero, size: self.preferredContentSize)
        stack.frame = rect.insetBy(dx:_inset, dy:_inset)
        content.bounds = rect
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        content.center = CGPoint(x: safe.midX, y: safe.midY)

        if _borderWidth != 0.0 && isFullscreen {
            content.layer.borderWidth = _borderWidth
            content.layer.borderColor = view.tintColor.cgColor
        }
    }

    // MARK: buttons

    private func tag2idx(_ tag:Int) -> Int? {
        let idx = tag - 8675309
        return actions.indices.contains(idx) ? idx : nil
    }
    private func idx2tag(_ idx:Int) -> Int {
        return idx + 8675309
    }

    internal func button(for action:UIAlertAction?) -> UIButton? {
        if let action = action, let idx = actions.firstIndex(of:action) {
            if let btn = stack.viewWithTag(idx2tag(idx)) as? UIButton {
                return btn
            }
        }
        return nil
    }

    private func action(for button:UIButton?) -> UIAlertAction? {
        if let button = button, let idx = tag2idx(button.tag) {
            return actions[idx]
        }
        return nil
    }

    struct Pressed {
            static var timestamp:Int?
    }
    @objc func buttonPress(_ sender:UIButton?) {
        guard let action = action(for: sender) else {return}
#if os(iOS)
        if autoDismiss {
            cancelAction = nil  // if we did the dismiss clear this
            preferredAction = nil
            let now:Int = Int(Date().timeIntervalSince1970 * 1000)
            if (Pressed.timestamp == nil) {
                Pressed.timestamp = now
            }
            ILOG("Action Button Pressed \(now) \(Pressed.timestamp ?? 0)")
            self.dismiss(animated:true, completion: {
                if let timestamp = Pressed.timestamp,
                   (now == timestamp || now - timestamp > 500) {
                    Pressed.timestamp = now
                    action.callActionHandler()
                } else {
                    ILOG("Action Doubled: Skipped \(now) \(Pressed.timestamp ?? 0)")
                }
            })
        } else {
            action.callActionHandler()
        }
#else
        if autoDismiss {
            cancelAction = nil  // if we did the dismiss clear this
            self.presentingViewController?.dismiss(animated:true, completion: {
                action.callActionHandler()
            })
        } else {
            action.callActionHandler()
        }
#endif
    }
    @objc func buttonTap(_ sender:UITapGestureRecognizer) {
        buttonPress(sender.view as? UIButton)
    }

    private func makeButton(_ action:UIAlertAction) -> UIView {
        guard let idx = actions.firstIndex(of:action) else {fatalError()}

        let btn = TVButton()
        btn.tag = idx2tag(idx)
        btn.setAttributedTitle(NSAttributedString(string:action.title ?? "", attributes:[.font:self.font]), for: .normal)
        btn.setTitleColor(UIColor.label, for: .normal)
        btn.setTitleColor(UIColor.gray, for: .disabled)

        let spacing = self.spacing
        btn.contentEdgeInsets = UIEdgeInsets(top:spacing, left:spacing*2, bottom:spacing, right:spacing*2)

        if let image = action.getImage() {
            btn.tintColor = .white
            btn.setImage(image, for: .normal)
            btn.contentEdgeInsets = UIEdgeInsets(top:spacing, left:spacing*2, bottom:spacing, right:spacing*3)
            btn.titleEdgeInsets = UIEdgeInsets(top:0, left:spacing, bottom:0, right:-spacing)
            #if os(tvOS)
                btn.imageView?.adjustsImageWhenAncestorFocused = false
            #endif
        }

        btn.setGrowDelta(_inset * 0.25, for: .focused)
        btn.setGrowDelta(_inset * 0.25, for: .selected)

        let h = font.lineHeight * 1.5
        btn.addConstraint(NSLayoutConstraint(item:btn, attribute:.height, relatedBy:.equal, toItem:nil, attribute:.notAnAttribute, multiplier:1.0, constant:h))
        btn.layer.cornerRadius = h/4

        btn.addTarget(self, action: #selector(buttonPress(_:)), for: .primaryActionTriggered)

        if action.style == .destructive {
            btn.backgroundColor = _destructiveButtonColor
            btn.setBackgroundColor(_destructiveButtonColor.withAlphaComponent(1), for:.focused)
            btn.setBackgroundColor(_destructiveButtonColor.withAlphaComponent(1), for:.highlighted)
            btn.setBackgroundColor(_destructiveButtonColor.withAlphaComponent(1), for:.selected)
        } else {
            btn.backgroundColor = _defaultButtonColor
        }

        return btn
    }

    // MARK: dismiss

    @objc func afterDismiss() {
#if !os(iOS)
        cancelAction?.callActionHandler()
#endif
    }
    internal override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.perform(#selector(afterDismiss), with:nil, afterDelay:0)
    }
    @objc func tapBackgroundToDismiss(_ sender:UITapGestureRecognizer) {
        #if os(iOS)
            let pt = sender.location(in: self.view)
            if view.subviews.last?.frame.contains(pt) == true {
                return
            }
        #endif
        // only automaticly dismiss if there is a cancel button
        if cancelAction != nil && autoDismiss {
#if os(iOS)
            cancelAction?.callActionHandler()
            self.dismiss(animated:true, completion:nil)
#else
            presentingViewController?.dismiss(animated:true, completion:nil)
#endif
        }
    }

    // MARK: focus

    public override var preferredFocusEnvironments: [UIFocusEnvironment] {

        // if we have a preferredAction make that the first to get focus, but we gotta find it.
        if let button = button(for: preferredAction) {
            return [button]
        }

        return super.preferredFocusEnvironments
    }

    #if os(iOS)
    // if we dont have a FocusSystem then select the preferredAction
    // TODO: detect focus sytem on iPad iOS 15+ ???
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let button = preferredFocusEnvironments.first as? TVButton {
            button.isSelected = true
        }
    }
    #endif

    // MARK: zoom in and zoom out

    internal override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // get the content view, dont animate if we are in a popup
        if let content = view.subviews.last, isFullscreen {
            let size = preferredContentSize
            let scale = min(1.0, min(view.bounds.size.width * 0.95 / size.width, view.bounds.size.height * 0.95 / size.height))

            content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
            UIView.animate(withDuration: _animateDuration) {
                content.transform = CGAffineTransform(scaleX:scale, y:scale)
            }
        }
    }

    #if os(iOS)
    internal override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let content = view.subviews.last, isFullscreen {
            UIView.animate(withDuration: _animateDuration) {
                content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
            }
        }
    }
    #endif
}



// MARK: MENU

#if os(iOS)
extension UIAlertControllerProtocol {

    // convert a UIAlertController to a UIMenu so it can be used as a context menu
    func convertToMenu() -> UIMenu {

        // convert UIAlertActions to UIActions via compactMap
        let menu_actions = self.actions.compactMap { (alert_action) -> UIAction? in

            // filter out .cancel actions for action sheets, keep them for alerts
            if self.preferredStyle == .actionSheet && alert_action.style == .cancel {
                return nil
            }

            let title = alert_action.title ?? ""
            let attributes = (alert_action.style == .destructive) ? UIMenuElement.Attributes.destructive : []
            return UIAction(title: title, image:alert_action.getImage(), attributes: attributes) { _ in
                alert_action.callActionHandler()
            }
        }

        return UIMenu(title: (self.title ?? ""), children: menu_actions)
    }
}
#endif

// MARK: Button

extension UIControl.State : @retroactive Hashable {}

private class TVButton : UIButton {

    convenience init() {
        self.init(type:.custom)
    }

    override func didMoveToWindow() {

        // these are the defaults if not set
        _color[.normal]       = _color[.normal] ?? backgroundColor ?? .gray
        _color[.focused]      = _color[.focused] ?? superview?.tintColor
        _color[.highlighted]  = _color[.highlighted] ?? superview?.tintColor
        _color[.selected]     = _color[.selected] ?? superview?.tintColor

        _grow[.focused] = _grow[.focused] ?? 16.0
        _grow[.highlighted] = _grow[.highlighted] ?? 0.0
        _grow[.selected] = _grow[.selected] ?? 16.0

        if layer.cornerRadius == 0.0 {
            layer.cornerRadius = 12.0
        }
        update()
    }

    private var _color = [UIControl.State:UIColor]()
    func setBackgroundColor(_ color:UIColor, for state: UIControl.State) {
        _color[state]  = color
        if self.window != nil { update() }
    }
    func getBackgroundColor(for state: UIControl.State) -> UIColor? {
        return  _color[state] ?? _color[state.subtracting([.focused, .selected])] ?? _color[state.subtracting(.highlighted)] ?? _color[.normal] ?? self.backgroundColor
    }

    private var _grow = [UIControl.State:CGFloat]()
    func setGrowDelta(_ scale:CGFloat, for state: UIControl.State) {
        _grow[state] = scale
        if self.window != nil { update() }
    }
    func getGrowDelta(for state: UIControl.State) -> CGFloat {
        return _grow[state] ?? _grow[state.subtracting([.focused, .selected])] ?? _grow[state.subtracting(.highlighted)] ?? _grow[.normal] ?? 0.0
    }

    private func update() {
        self.backgroundColor = getBackgroundColor(for: self.state)
        if self.bounds.width != 0 {
            let scale = min(1.04, 1.0 + getGrowDelta(for: state) / (self.bounds.width * 0.5))
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: _animateDuration) {
                self.update()
            }
        }
    }
    override var isSelected: Bool {
        didSet {
            UIView.animate(withDuration: _animateDuration) {
                self.update()
            }
        }
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            self.update()
        }, completion: nil)
    }
}

// MARK: ControllerButtonPress
internal protocol ControllerButtonPress : UIViewController {
    typealias ButtonType = GCExtendedGamepad.ButtonType
    func controllerButtonPress(_ type:ButtonType)
}
#if os(iOS)

extension TVAlertController : ControllerButtonPress {

}

extension ControllerButtonPress where Self: TVAlertController {
    internal func controllerButtonPress(_ type: ButtonType) {
        VLOG("TVAlertController: \(type)")
        switch type {
        case .up:
            moveDefaultAction(-1)
            break;
        case .down:
            moveDefaultAction(+1)
            break;
        case .left:
            moveDefaultAction(-1000)
            break;
        case .right:
            moveDefaultAction(+1000)
            break;
        case .select:   // (aka A or ENTER)
            buttonPress(button(for: preferredAction))
            break;
#if os(iOS)
        case .back:     // (aka B or ESC)
            buttonPress(button(for: preferredAction))
            break;
#else
        case .back:     // (aka B or ESC)
            // only automaticly dismiss if there is a cancel button
            if cancelAction != nil {
                presentingViewController?.dismiss(animated:true, completion:nil)
            }
#endif
        default:
            break
        }
    }
    private func moveDefaultAction(_ dir:Int) {
        if let action = preferredAction, var idx = actions.firstIndex(of: action) {
            if doubleStackHeight != 0 {
                let n = self.doubleStackHeight
                if dir == +1 && idx == n-1 {idx = n*2-1}
                if dir == -1 && idx == n {idx = n+1}
                if dir == -1 && idx == n*2 {idx = n}
                if dir == +1000 && idx < n {idx = idx + n - 1000}
                if dir == -1000 && idx < n*2 {idx = idx - n + 1000}
            }
            idx = idx + dir
            if actions.indices.contains(idx) {
                preferredAction = actions[idx]
                button(for: action)?.isSelected = false
                button(for: preferredAction)?.isSelected = true
            }
        } else {
            preferredAction = actions.first(where: {$0.style == .default && $0.isEnabled})
            button(for: preferredAction)?.isSelected = true
        }
    }
}


extension UIAlertController : ControllerButtonPress {
    internal func controllerButtonPress(_ type: ButtonType) {
        switch type {
        case .select:   // (aka A or ENTER)
            dismiss(with: preferredAction, animated: true)
            break;
        case .back:     // (aka B or ESC)
            dismiss(with: preferredAction, animated: true)
            break;
        default:
            break
        }
    }
    private func dismiss(with action:UIAlertAction?, animated: Bool) {
        if let action = action {
            preferredAction = nil
            self.dismiss(animated: animated, completion: {
                action.callActionHandler()
            })
        }
    }
}

#endif
#elseif canImport(AppKit)
import AppKit
#endif

internal extension GCExtendedGamepad {
    enum ButtonType: String {
        case a, b, x, y
        case menu, options
        case up, down, left, right
        case l1, l2, r1, r2
        static let select = a
        static let back = b
        static let cancel = b
    }

    typealias ButtonState = Set<ButtonType>

    func readButtonState() -> ButtonState {
        var state = ButtonState()

        if buttonA.isPressed {state.formUnion([.a])}
        if buttonB.isPressed {state.formUnion([.b])}
        if buttonX.isPressed {state.formUnion([.x])}
        if buttonY.isPressed {state.formUnion([.y])}
        if buttonMenu.isPressed {state.formUnion([.menu])}
        if buttonOptions?.isPressed == true {state.formUnion([.options])}

        for pad in [dpad, leftThumbstick, rightThumbstick] {
            if pad.up.isPressed {state.formUnion([.up])}
            if pad.down.isPressed {state.formUnion([.down])}
            if pad.left.isPressed {state.formUnion([.left])}
            if pad.right.isPressed {state.formUnion([.right])}
        }

        if rightShoulder.isPressed {state.formUnion([.r1])}
        if rightTrigger.isPressed {state.formUnion([.r2])}
        if leftShoulder.isPressed {state.formUnion([.l1])}
        if leftTrigger.isPressed {state.formUnion([.l2])}

        return state
    }
}

//#endif // os(iOS)

// MARK: - Controller type detection
internal extension GCController {
    var isRemote: Bool {
        return self.extendedGamepad == nil && self.microGamepad != nil
    }
    
    var isKeyboard: Bool {
        if #available(iOS 14.0, tvOS 14.0, *) {
            return isSnapshot && vendorName?.contains("Keyboard") == true
        } else {
            return false
        }
    }
}
