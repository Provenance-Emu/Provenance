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
import PVLogging

// these are the defaults assuming Dark mode, etc.
private let _fullscreenColor = UIColor.black.withAlphaComponent(0.8)
private let _destructiveButtonColor = UIColor.systemRed.withAlphaComponent(0.5)
private let _borderWidth = 4.0
private let _fontTitleF = 1.25
private let _animateDuration = 0.150

// os specific defaults
#if os(tvOS)
    private let _blurFullscreen = false
    private let _font = UIFont.systemFont(ofSize: 24.0)
    private let _inset:CGFloat = 16.0
    private let _maxTextWidthF:CGFloat = 0.25
    private let _backgroundColor = UIColor(red:0.1, green:0.1, blue:0.1, alpha:1)      // secondarySystemGroupedBackground
    private let _defaultButtonColor = UIColor(white: 0.2, alpha: 1)
#else
    private let _blurFullscreen = true
    private let _font = UIFont.preferredFont(forTextStyle: .body)
    private let _inset:CGFloat = 16.0
    private let _maxTextWidthF:CGFloat = 0.50
    private let _backgroundColor = UIColor.secondarySystemGroupedBackground
    private let _defaultButtonColor = UIColor.systemGray4
#endif

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

// take over (aka mock) the UIAlertController initializer and return our class
func UIAlertController(title: String?, message: String?, preferredStyle style: UIAlertController.Style) -> UIAlertControllerProtocol {
    TVAlertController.init(title:title, message: message, preferredStyle: style)
}

extension UIAlertController : UIAlertControllerProtocol { }

final class TVAlertController: UIViewController, UIAlertControllerProtocol {

    var preferredStyle = UIAlertController.Style.alert
    var actions = [UIAlertAction]()
    var textFields:[UITextField]?
    var preferredAction: UIAlertAction?
    var cancelAction: UIAlertAction?

    var autoDismiss = true          // a UIAlertController is always autoDismiss

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

    convenience init(title: String?, message: String?, preferredStyle: UIAlertController.Style) {
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

    var spacing: CGFloat {
        get {
            return stack.spacing
        }
        set {
            stack.spacing = newValue
        }
    }

    var font = _font {
        didSet {
             spacing = floor(font.lineHeight / 4.0)
        }
    }

    // MARK: UIAlertControllerProtocol

    override var title: String? {
        set {
            let label = stack.arrangedSubviews[0] as! UILabel
            label.text = newValue
            label.font = .boldSystemFont(ofSize: font.pointSize * _fontTitleF)
            label.numberOfLines = 0
            label.textAlignment = .center
            label.preferredMaxLayoutWidth = maxTextWidth
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
            label.preferredMaxLayoutWidth = maxTextWidth
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
        let w = (UIApplication.shared.windows.first { $0.isKeyWindow }?.bounds.width ?? UIScreen.main.bounds.width)  * 0.50
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
        #if os(tvOS)
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

    override var preferredContentSize: CGSize {
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

    override func viewWillLayoutSubviews() {
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
            print("Action Button Pressed ", now, Pressed.timestamp)
            self.dismiss(animated:true, completion: {
                if let timestamp = Pressed.timestamp,
                   (now == timestamp || now - timestamp > 500) {
                    Pressed.timestamp = now
                    action.callActionHandler()
                } else {
                    print("Action Doubled: Skipped ", now, Pressed.timestamp)
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
    override func viewDidDisappear(_ animated: Bool) {
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

    override var preferredFocusEnvironments: [UIFocusEnvironment] {

        // if we have a preferredAction make that the first to get focus, but we gotta find it.
        if let button = button(for: preferredAction) {
            return [button]
        }

        return super.preferredFocusEnvironments
    }

    #if os(iOS)
    // if we dont have a FocusSystem then select the preferredAction
    // TODO: detect focus sytem on iPad iOS 15+ ???
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let button = preferredFocusEnvironments.first as? TVButton {
            button.isSelected = true
        }
    }
    #endif

    // MARK: zoom in and zoom out

    override func viewWillAppear(_ animated: Bool) {
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
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let content = view.subviews.last, isFullscreen {
            UIView.animate(withDuration: _animateDuration) {
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

extension UIControl.State : Hashable {}

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

#if os(iOS)

extension TVAlertController : ControllerButtonPress {

}

extension UIAlertController : ControllerButtonPress {
    func controllerButtonPress(_ type: ButtonType) {
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
