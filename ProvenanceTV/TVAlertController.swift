//  TVAlertController.swift
//  Wombat
//
//  implement a custom UIAlertController for tvOS
//
//  Created by Todd Laney on 22/01/2022.
//
// TODO: make this work on iOS too!

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
    if style == .actionSheet {
        //return UIAlertController.init(title:title, message: message, preferredStyle: style)
        return TVAlertController.init(title:title, message: message, preferredStyle: style)
    }
    else {
        //return UIAlertController.init(title:title, message: message, preferredStyle: style)
        return TVAlertController.init(title:title, message: message, preferredStyle: style)
   }
}

extension UIAlertController : UIAlertControllerProtocol { }

class TVAlertController: TVPopupController, UIAlertControllerProtocol {
    var preferredStyle = UIAlertController.Style.alert
    var actions = [UIAlertAction]()
    var textFields:[UITextField]?
    var preferredAction: UIAlertAction?
    var cancelAction: UIAlertAction?
    var spacing = 8.0

    private let stack = {() -> UIStackView in
        let stack = UIStackView(arrangedSubviews: [UILabel(), UILabel()])
        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .fill
        stack.spacing = 8
        return stack
    }()
    
    init() {
        super.init(nibName:nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    convenience init(title: String?, message: String?, preferredStyle: UIAlertController.Style) {
        self.init()
        self.preferredStyle = preferredStyle
        self.title = title
        self.message = message
    }
    
    override var title: String? {
        didSet {
            let label = stack.arrangedSubviews[0] as! UILabel
            label.text = title
            label.font = .systemFont(ofSize: 48, weight: .heavy)
            label.numberOfLines = 0
            label.preferredMaxLayoutWidth = (UIApplication.shared.keyWindow?.bounds.width ?? UIScreen.main.bounds.width)  * 0.80
            label.textAlignment = .center
            
            
        }
    }

    var message: String? {
        didSet {
            let label = stack.arrangedSubviews[1] as! UILabel
            label.text = message
            label.numberOfLines = 0
            label.preferredMaxLayoutWidth = (UIApplication.shared.keyWindow?.bounds.width ?? UIScreen.main.bounds.width)  * 0.80
            label.textAlignment = .center
        }
    }

    func addAction(_ action: UIAlertAction) {
        if action.style == .cancel {
            cancelAction = action
            // TODO: should check for popup (on iOS)
            if preferredStyle == .actionSheet {
                return
            }
        }
        actions.append(action)
        stack.addArrangedSubview(makeButton(action))
    }
    
    func addTextField(configurationHandler: ((UITextField) -> Void)? = nil) {
        let textField = UITextField()
        textFields = textFields ?? []
        textFields?.append(textField)
        configurationHandler?(textField)
        stack.addArrangedSubview(textField)
    }
    
    // MARK: buttons
    
    @objc func buttonPress(_ sender:UIView?) {
        guard let tag = sender?.tag, tag != -1 else {return}
        cancelAction = nil  // if we did the dismiss clear this
        self.presentingViewController?.dismiss(animated:true, completion: {
            self.actions[tag].callActionHandler()
        })
    }
    @objc func buttonTap(_ sender:UITapGestureRecognizer) {
        buttonPress(sender.view)
    }

    private func makeButton(_ action:UIAlertAction) -> UIView {
        let seg = UISegmentedControl(items:[action.title ?? ""])
        seg.backgroundColor = (action.style == .destructive) ? .systemRed : .init(white:0.222, alpha:1)
        seg.tag = actions.firstIndex(of:action) ?? -1
        seg.isMomentary = false
        
        seg.setTitleTextAttributes([NSAttributedString.Key.foregroundColor:UIColor.white], for:.normal)
        seg.setTitleTextAttributes([NSAttributedString.Key.foregroundColor:UIColor.white], for:.selected)

        //let h = self.font.lineHeight * 1.5
        //seg.addConstraint(NSLayoutConstraint(item:seg, attribute:.height, relatedBy:.equal, toItem:nil, attribute:.notAnAttribute, multiplier:1.0, constant:h))
        seg.addGestureRecognizer(UITapGestureRecognizer(target:self, action: #selector(buttonTap(_:))))
        
        if #available(tvOS 13.0, *) {
            seg.selectedSegmentTintColor = .blue;
        }

        return seg
    }
    private func makeButton(_ actions:[UIAlertAction]) -> UIView {
        if actions.count == 1 {
            return makeButton(actions[0])
        }
        let stack = UIStackView(arrangedSubviews:actions.map({makeButton($0)}))
        stack.spacing = spacing
        return stack
    }
    
    @objc func afterDismiss() {
        cancelAction?.callActionHandler()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.perform(#selector(afterDismiss), with:nil, afterDelay:0)
    }
     
    @objc func tapBackgroundToDismiss() {
        // only automaticly dismiss if there is a cancel button
        if cancelAction != nil {
            presentingViewController?.dismiss(animated:true, completion:nil)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UITapGestureRecognizer(target:self, action: #selector(tapBackgroundToDismiss))
        #if os(tvOS)
            tap.allowedPressTypes = [.menu]
        #endif
        view.addGestureRecognizer(tap)
        
        // *maybe* convert into a two-collumn stack
        if actions.count >= 8 && textFields == nil {
            var count = stack.arrangedSubviews.count;
            // dont merge the last item(s), if it is cancel or destructive
            count = count - (actions.reversed().firstIndex(where:{$0.style == .default}) ?? count)
            let n = (count-2) / 2

            for i in 0..<n {
                let lhs = stack.arrangedSubviews[2+i]
                let rhs = stack.arrangedSubviews[2+n]
                lhs.removeFromSuperview()
                rhs.removeFromSuperview()
                let group = UIStackView(arrangedSubviews: [lhs, rhs])
                group.spacing = spacing
                group.distribution = .fillEqually
                stack.insertArrangedSubview(group, at:2+i)
             }
        }
        
        view.addSubview(stack)
    }
    
    var canBecomeFocused: Bool {
        return false    // we want buttons in stack to get the focus
    }
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let action = preferredAction, let idx = actions.firstIndex(of:action) {
            for seg in stack.arrangedSubviews.filter({$0 is UISegmentedControl}) {
                if seg.tag == idx {
                    return [seg]
                }
            }
        }
        if cancelAction == preferredAction && preferredAction != nil {
            // they want the default action to be cancel, but we dont have cancel button....
        }
        return super.preferredFocusEnvironments
    }

    // HACK *HACK* **HACK**
    // the Focus Engine can leave "focus turds" if the focus changes *too fast*
    // ....this can easily happen by swiping the SiriRemote
    // ....this is probably specific to our nested UIStackViews and UISegmentedControls
    // ....so we limit focus changes to 60Hz
    // HACK *HACK* **HACK**
    private var last_focus_time = 0.0
    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        let now = NSDate.timeIntervalSinceReferenceDate
        if now - last_focus_time < (1.0 / 60.0) {
            return false
        }
        last_focus_time = now
        return true
    }
}

private extension UIAlertAction {
    func callActionHandler() {
        if let handler = self.value(forKey:"handler") as? NSObject {
            unsafeBitCast(handler, to:(@convention(block) (UIAlertAction)->Void).self)(self)
        }
    }
}
