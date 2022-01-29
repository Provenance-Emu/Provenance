//  TVAlertController.swift
//  Wombat
//
//  implement a custom UIAlertController for tvOS, using a UIStackView full of buttons and duct tape.
//
//  Oh it also works on iOS...
//
//  Created by Todd Laney on 22/01/2022.
//

import UIKit

protocol UIAlertControllerProtocol : UIViewController {

     func addAction(_ action: UIAlertAction)
     var actions: [UIAlertAction] { get }
    
     var preferredAction: UIAlertAction? { get set }

     func addTextField(configurationHandler: ((UITextField) -> Void)?)
     var textFields: [UITextField]? { get }

     var title: String? { get set }
     var message: String? { get set }
     var preferredStyle: UIAlertController.Style { get }
}

// take over the UIAlertController initializer and return our class sometimes....
func UIAlertController(title: String?, message: String?, preferredStyle style: UIAlertController.Style) -> UIAlertControllerProtocol {
    #if os(tvOS)
        return TVAlertController.init(title:title, message: message, preferredStyle: style)
    #else
        if style == .actionSheet {
            return UIAlertController.init(title:title, message: message, preferredStyle: style)
            //return TVAlertController.init(title:title, message: message, preferredStyle: style)
        }
        else {
            return UIAlertController.init(title:title, message: message, preferredStyle: style)
            //return TVAlertController.init(title:title, message: message, preferredStyle: style)
        }
    #endif
}

extension UIAlertController : UIAlertControllerProtocol { }

class TVAlertController: UIViewController, UIAlertControllerProtocol {
    
    var preferredStyle = UIAlertController.Style.alert
    var actions = [UIAlertAction]()
    var textFields:[UITextField]?
    var preferredAction: UIAlertAction?
    var cancelAction: UIAlertAction?
    
    var autoDismiss = true          // a UIAlertController is always autoDismiss

    // these are the PV defaults assuming Dark mode, etc.
    private let _fullscreenColor = UIColor.black.withAlphaComponent(0.8)
    private let _blur = false
    private let _backgroundColor = UIColor(red:0.11, green:0.11, blue:0.12, alpha:1)      // secondarySystemGroupedBackground
    private let _borderWidth = 4.0
    private let _insets = UIEdgeInsets(top:32, left:32, bottom:32, right:32)
    private let _maxWidth = (UIApplication.shared.keyWindow?.bounds.width ?? UIScreen.main.bounds.width)  * 0.80

    private let stack = {() -> UIStackView in
        let stack = UIStackView(arrangedSubviews: [UILabel(), UILabel()])
        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .fill
        stack.spacing = 8
        return stack
    }()

    // MARK: init
    
    convenience init(title: String?, message: String?, preferredStyle: UIAlertController.Style) {
        self.init(nibName:nil, bundle: nil)
        self.preferredStyle = preferredStyle
        self.title = title
        self.message = message
        self.modalPresentationStyle = .overFullScreen    // default to .overFullScreen OR .blurOverFullScreen
        self.modalTransitionStyle = .crossDissolve
    }
    
    var spacing: CGFloat {
        get {
            return stack.spacing
        }
        set {
            stack.spacing = newValue
        }
    }
    
    var font = UIFont.preferredFont(forTextStyle: .body) {
        didSet {
            spacing = floor(font.lineHeight / 8.0);
        }
    }
    
    // MARK: UIAlertControllerProtocol

    override var title: String? {
        set {
            let label = stack.arrangedSubviews[0] as! UILabel
            label.text = newValue
            #if os(iOS)
                label.font = .preferredFont(forTextStyle: .headline)
            #else
                label.font = .boldSystemFont(ofSize: font.pointSize * 1.5)
            #endif
            label.numberOfLines = 0
            label.textAlignment = .center
            label.preferredMaxLayoutWidth = _maxWidth
        }
        get {
            return (stack.arrangedSubviews[0] as? UILabel)?.text
        }
    }

    var message: String? {
        set {
            let label = stack.arrangedSubviews[1] as! UILabel
            label.text = newValue
            label.font = self.font
            label.numberOfLines = 0
            label.textAlignment = .center
            label.preferredMaxLayoutWidth = _maxWidth
        }
        get {
            return (stack.arrangedSubviews[1] as? UILabel)?.text
        }
    }

    func addAction(_ action: UIAlertAction) {
        if action.style == .cancel {
            cancelAction = action
            if preferredStyle == .actionSheet {
                return
            }
        }
        actions.append(action)
        stack.addArrangedSubview(makeButton(action))
    }
    
    func addTextField(configurationHandler: ((UITextField) -> Void)? = nil) {
        let textField = UITextField()
        textField.font = font
        textField.borderStyle = .roundedRect
        let h = font.lineHeight * 1.5
        let w = (UIApplication.shared.keyWindow?.bounds.width ?? UIScreen.main.bounds.width)  * 0.50
        textField.addConstraint(NSLayoutConstraint(item:textField, attribute:.height, relatedBy:.equal, toItem:nil, attribute:.notAnAttribute, multiplier:1.0, constant:h))
        textField.addConstraint(NSLayoutConstraint(item:textField, attribute:.width, relatedBy:.greaterThanOrEqual, toItem:nil, attribute:.notAnAttribute, multiplier:1.0, constant:w))
        textFields = textFields ?? []
        textFields?.append(textField)
        configurationHandler?(textField)
        stack.addArrangedSubview(textField)
    }
    
    // MARK: load
    
    override func viewDidLoad() {
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
        let traits = UIApplication.shared.keyWindow?.traitCollection
        if actions.count >= 8 && textFields == nil &&
            (traits?.verticalSizeClass == .compact || traits?.horizontalSizeClass == .regular) {
            doubleStack()
        }
        
        let back = UIView()
        back.addSubview(stack)
        view.addSubview(back)

        back.layer.cornerRadius = min(_insets.top, _insets.left)
        back.clipsToBounds = back.layer.cornerRadius != 0.0
        back.backgroundColor = _backgroundColor
        
        if _borderWidth != 0.0 {
            back.layer.borderWidth = _borderWidth
            back.layer.borderColor = UIApplication.shared.keyWindow?.tintColor.cgColor
        }

        if _blur {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blur.frame = back.bounds;
            back.addSubview(blur)
            back.sendSubviewToBack(blur)
        }
    }
    
    // convert stackView to two columns
    private func doubleStack() {
        var count = stack.arrangedSubviews.count;
        
        // dont merge the last item(s), if they are cancel or destructive
        count = count - (actions.reversed().firstIndex(where:{$0.style == .default}) ?? count)
        let n = (count-2) / 2
        
        let spacing = self.spacing
        for i in 0..<n {
            let lhs = stack.arrangedSubviews[2+i]
            let rhs = stack.arrangedSubviews[2+n]
            lhs.removeFromSuperview()
            rhs.removeFromSuperview()
            (lhs as? TVButton)?.setGrowDelta(spacing * 0.8, for: .focused)
            (rhs as? TVButton)?.setGrowDelta(spacing * 0.8, for: .focused)
            let hstack = UIStackView(arrangedSubviews: [lhs, rhs])
            hstack.spacing = spacing
            hstack.distribution = .fillEqually
            stack.insertArrangedSubview(hstack, at:2+i)
         }
    }

    // MARK: buttons
    
    @objc func buttonPress(_ sender:UIView?) {
        guard let tag = sender?.tag, tag != -1 else {return}
        if autoDismiss {
            cancelAction = nil  // if we did the dismiss clear this
            self.presentingViewController?.dismiss(animated:true, completion: {
                self.actions[tag].callActionHandler()
            })
        }
        else {
            self.actions[tag].callActionHandler()
        }
    }
    @objc func buttonTap(_ sender:UITapGestureRecognizer) {
        buttonPress(sender.view)
    }
    
    private func makeButton(_ action:UIAlertAction) -> UIView {
        guard let idx = actions.firstIndex(of:action) else {fatalError()}
        
        let btn = TVButton()
        btn.tag = idx
        btn.setTitle(action.title, for: .normal)
        btn.setTitleColor(UIColor.white, for: .normal)
        btn.setTitleColor(UIColor.gray, for: .disabled)
        
        let spacing = self.spacing
        btn.contentEdgeInsets = UIEdgeInsets(top:spacing, left:spacing*2, bottom:spacing, right:spacing*2)
        
        btn.setGrowDelta(min(_insets.left, _insets.right) * 0.5, for: .focused)

        #if os(iOS)
            btn.font = self.font
            btn.layer.cornerRadius = h/4
            let h = font.lineHeight * 1.5
            btn.addConstraint(NSLayoutConstraint(item:btn, attribute:.height, relatedBy:.equal, toItem:nil, attribute:.notAnAttribute, multiplier:1.0, constant:h))
        #endif

        btn.addTarget(self, action: #selector(buttonPress(_:)), for: .primaryActionTriggered)
        
        if action.style == .destructive {
            btn.backgroundColor = .systemRed
            //btn.setTitleColor(.systemRed, for:.focused)
            //btn.setTitleColor(.systemRed, for:.highlighted)
        }
        
        return btn
    }
    
    // MARK: dismiss
    
    @objc func afterDismiss() {
        cancelAction?.callActionHandler()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.perform(#selector(afterDismiss), with:nil, afterDelay:0)
    }
    @objc func tapBackgroundToDismiss(_ sender:UITapGestureRecognizer) {
        #if os(iOS)
            let pt = sender.location(in: self.view)
            if view.subviews.first?.frame.contains(pt) == true {
                return;
            }
        #endif
        // only automaticly dismiss if there is a cancel button
        if cancelAction != nil && autoDismiss {
            presentingViewController?.dismiss(animated:true, completion:nil)
        }
    }
    
    // MARK: layout and size
    
    private var isFullscreen: Bool {
        return view.window?.bounds == view.bounds
    }
    
    override var preferredContentSize: CGSize {
        get {
            var size = stack.systemLayoutSizeFitting(.zero)
            size.width = min(size.width, _maxWidth)
            if size != .zero {
                size.width  += (_insets.left + _insets.right)
                size.height += (_insets.top + _insets.bottom)
            }
            return size
        }
        set {
            super.preferredContentSize = newValue
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let content = view.subviews.first else {return}
        
        view.backgroundColor = isFullscreen ? _fullscreenColor : nil

        let rect = CGRect(origin: .zero, size: self.preferredContentSize)
        stack.frame = rect.inset(by: _insets)
        content.bounds = rect
        content.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
     }
    
    // MARK: focus
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        
        // if we have a preferredAction make that the first to get focus, but we gotta find it.
        if let action = preferredAction, let idx = actions.firstIndex(of:action), idx != 0 {
            if let view = stack.viewWithTag(idx) {
                return [view]
            }
        }
        
        return super.preferredFocusEnvironments
    }
    
    // MARK: zoom in and zoom out
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // get the content view, dont animate if we are in a popup
        if let content = view.subviews.first, isFullscreen {
            let size = preferredContentSize
            let scale = min(1.0, min(view.bounds.size.width * 0.95 / size.width, view.bounds.size.height * 0.95 / size.height))
            
            content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
            UIView.animate(withDuration: 0.200) {
                content.transform = CGAffineTransform(scaleX:scale, y:scale)
            }
        }
    }
    
    #if os(iOS)
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let content = view.subviews.first, isFullscreen {
            UIView.animate(withDuration: 0.200) {
                content.transform = CGAffineTransform(scaleX:0.001, y:0.001)
            }
        }
    }
    #endif
}

// MARK: UIAlertAction

private extension UIAlertAction {
    func callActionHandler() {
        if let handler = self.value(forKey:"handler") as? NSObject {
            unsafeBitCast(handler, to:(@convention(block) (UIAlertAction)->Void).self)(self)
        }
    }
}

// MARK: MENU

#if os(iOS)
extension UIAlertControllerProtocol {
    
    // convert a UIAlertController to a UIMenu so it can be used as a context menu
    @available(iOS 13.0, *)
    func convertToMenu() -> UIMenu {

        // convert UIAlertActions to UIActions via compactMap
        let menu_actions = self.actions.compactMap { (alert_action) -> UIAction? in
            
            // filter out .cancel actions for action sheets, keep them for alerts
            if self.preferredStyle == .actionSheet && alert_action.style == .cancel {
                return nil
            }

            let title = alert_action.title ?? ""
            let attributes = (alert_action.style == .destructive) ? UIMenuElement.Attributes.destructive : []
            return UIAction(title: title, attributes: attributes) { _ in
                alert_action.callActionHandler()
            }
        }
        
        return UIMenu(title: (self.title ?? ""), children: menu_actions)
    }
}
#endif

// MARK: Button

extension UIControl.State : Hashable {}

private class TVButton : UIButton {
    
    convenience init() {
        self.init(type:.custom)
    }

    override func didMoveToWindow() {
        
        // these are the defaults if not set
        _color[.normal]       = _color[.normal] ?? backgroundColor ?? .init(white:0.222, alpha:1)
        _color[.focused]      = _color[.focused] ?? tintColor
        _color[.highlighted]  = _color[.highlighted] ?? tintColor
        
        _grow[.focused] = _grow[.focused] ?? 16.0

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
        return  _color[state] ?? _color[state.subtracting(.focused)] ?? _color[state.subtracting(.highlighted)] ?? _color[.normal] ?? self.backgroundColor
    }

    private var _grow = [UIControl.State:CGFloat]()
    func setGrowDelta(_ scale:CGFloat, for state: UIControl.State) {
        _grow[state] = scale
        if self.window != nil { update() }
    }
    func getGrowDelta(for state: UIControl.State) -> CGFloat {
        return _grow[state] ?? _grow[state.subtracting(.focused)] ?? _grow[state.subtracting(.highlighted)] ?? _grow[.normal] ?? 0.0
    }

    private func update() {
        self.backgroundColor = getBackgroundColor(for: self.state)
        if self.bounds.width != 0 {
            let scale = 1.0 + getGrowDelta(for: state) / (self.bounds.width * 0.5)
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.200) {
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
