//  RetroArchiOS
//  Created by Yoshi Sugawara on 3/3/22.
//  Copyright © 2022 RetroArch. All rights reserved.
import Foundation

protocol HelperBarActionDelegate: AnyObject {
	func keyboardButtonTapped()
	func mouseButtonTapped()
	func helpButtonTapped()
	var isKeyboardEnabled: Bool { get }
	var isMouseEnabled: Bool { get }
}

extension CocoaView {
	@objc public func setupHelperBar() {
		let helperVC = HelperBarViewController()
		let viewModel = HelperBarViewModel(delegate: helperVC, actionDelegate: self)
		helperVC.viewModel = viewModel
		addChild(helperVC)
		helperVC.didMove(toParent: self)
		helperBarView = helperVC.view
		helperBarView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(helperBarView)
		helperBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		helperBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		helperBarView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
		helperBarView.heightAnchor.constraint(equalToConstant: 75).isActive = true
	}
}

extension CocoaView: HelperBarActionDelegate {
	func keyboardButtonTapped() {
		toggleCustomKeyboard()
	}

	func mouseButtonTapped() {
		mouseHandler.enabled.toggle()
		//runloop_msg_queue_push( mouseHandler.enabled ? "Touch Mouse Enabled" : "Touch Mouse Disabled", 1, 100, true, "", 0, 0)
	}

	func helpButtonTapped() {
	}

	var isKeyboardEnabled: Bool {
		!keyboardController.view.isHidden
	}

	var isMouseEnabled: Bool {
		mouseHandler.enabled
	}
}


@objc public class EmulatorKeyboardController: UIViewController {

	class EmulatorKeyboardPassthroughView: UIView {
		override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
			let hitView = super.hitTest(point, with: event)
			if hitView == self {
				return nil
			}
			return hitView
		}
	}

	@objc let leftKeyboardModel: EmulatorKeyboardViewModel
	@objc let rightKeyboardModel: EmulatorKeyboardViewModel

	@objc lazy var leftKeyboardView: EmulatorKeyboardView = {
		  let view = leftKeyboardModel.createView()
		  view.delegate = self
		  return view
	 }()
	 @objc lazy var rightKeyboardView: EmulatorKeyboardView = {
		  let view = rightKeyboardModel.createView()
		  view.delegate = self
		  return view
	 }()
	 var keyboardConstraints = [NSLayoutConstraint]()

	init(leftKeyboardModel: EmulatorKeyboardViewModel, rightKeyboardModel: EmulatorKeyboardViewModel) {
		self.leftKeyboardModel = leftKeyboardModel
		self.rightKeyboardModel = rightKeyboardModel
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func loadView() {
		view = EmulatorKeyboardPassthroughView()
	}

	 override public func viewDidLoad() {
		  super.viewDidLoad()
		  setupView()

		  let panGesture = UIPanGestureRecognizer(target: self, action: #selector(draggedView(_:)))
		  leftKeyboardView.dragMeView.isUserInteractionEnabled = true
		  leftKeyboardView.dragMeView.addGestureRecognizer(panGesture)
		  let panGestureRightKeyboard = UIPanGestureRecognizer(target: self, action: #selector(draggedView(_:)))
		  rightKeyboardView.dragMeView.isUserInteractionEnabled = true
		  rightKeyboardView.dragMeView.addGestureRecognizer(panGestureRightKeyboard)
	 }

	 func setupView() {
		  NSLayoutConstraint.deactivate(keyboardConstraints)
		  keyboardConstraints.removeAll()
		  leftKeyboardView.translatesAutoresizingMaskIntoConstraints = false
		  view.addSubview(leftKeyboardView)
		  leftKeyboardView.heightAnchor.constraint(equalToConstant: 270).isActive = true
		  leftKeyboardView.widthAnchor.constraint(equalToConstant: 180).isActive = true
		  keyboardConstraints.append(contentsOf: [
				leftKeyboardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
				leftKeyboardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
		  ])
		  rightKeyboardView.translatesAutoresizingMaskIntoConstraints = false
		  view.addSubview(rightKeyboardView)
		  keyboardConstraints.append(contentsOf: [
				rightKeyboardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
				rightKeyboardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
		  ])
		  rightKeyboardView.heightAnchor.constraint(equalToConstant: 270).isActive = true
		  rightKeyboardView.widthAnchor.constraint(equalToConstant: 180).isActive = true
		  NSLayoutConstraint.activate(keyboardConstraints)
	 }

	 func setupViewFrames() {
		  // initial placement on the bottom corners
		  // since we don't know the frame of this view yet until layout time,
		  // assume it's taking the full screen
		  let screenFrame = UIScreen.main.bounds
		  let keyboardHeight: CGFloat = 250.0
		  let keyboardWidth: CGFloat = 180.0
		  let bottomLeftFrame = CGRect(
				x: 0,
				y: screenFrame.size.height - 40 - keyboardHeight - 20,
				width: keyboardWidth, height: keyboardHeight)
		  let bottomRightFrame = CGRect(
				x: screenFrame.size.width - 20 - keyboardWidth,
				y:screenFrame.size.height - 40 - keyboardHeight - 20,
				width: keyboardWidth, height: keyboardHeight
		  )
		  view.addSubview(leftKeyboardView)
		  view.addSubview(rightKeyboardView)
		  leftKeyboardView.frame = bottomLeftFrame
		  rightKeyboardView.frame = bottomRightFrame
	 }

	 func setupKeyModels() {
		  leftKeyboardView.setupWithModel(leftKeyboardModel)
		  rightKeyboardView.setupWithModel(rightKeyboardModel)
	 }

	 @objc func draggedView(_ sender:UIPanGestureRecognizer){
		  guard let keyboardView = sender.view?.superview else {
				return
		  }
		  let translation = sender.translation(in: self.view)
		  keyboardView.center = CGPoint(x: keyboardView.center.x + translation.x, y: keyboardView.center.y + translation.y)
		  sender.setTranslation(CGPoint.zero, in: self.view)
	 }
}

extension EmulatorKeyboardController: EmulatorKeyboardViewDelegate {
	 func toggleAlternateKeys() {
		  for keyboard in [leftKeyboardView, rightKeyboardView] {
				keyboard.toggleKeysStackView()
		  }
	 }
	 func refreshModifierStates() {
		  for keyboard in [leftKeyboardView, rightKeyboardView] {
				keyboard.refreshModifierStates()
		  }
	 }
	 func updateTransparency(toAlpha alpha: Float) {
		  for keyboard in [leftKeyboardView, rightKeyboardView] {
				keyboard.alpha = CGFloat(alpha)
		  }
	 }
}
extension CocoaView {
	@objc public func setupMouseSupport() {
		view.isMultipleTouchEnabled = true;
		mouseHandler = EmulatorTouchMouseHandler(view: view, delegate: self as? EmulatorTouchMouseHandlerDelegate)
	}

	open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		 mouseHandler.touchesBegan(touches: touches, event: event)
	}

	open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		 mouseHandler.touchesMoved(touches: touches)
	}

	open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		 mouseHandler.touchesCancelled(touches: touches, event: event)
	}

	open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		 mouseHandler.touchesEnded(touches: touches, event: event)
	}
}


extension CocoaView {
	var leftKeyboardModel: EmulatorKeyboardViewModel {
		return EmulatorKeyboardViewModel(keys: [
			[
				EmulatorKeyboardKey(label: "1", code: Int(RETROK_1.rawValue)),
				EmulatorKeyboardKey(label: "2", code: Int(RETROK_2.rawValue)),
				EmulatorKeyboardKey(label: "3", code: Int(RETROK_3.rawValue)),
				EmulatorKeyboardKey(label: "4", code: Int(RETROK_4.rawValue)),
				EmulatorKeyboardKey(label: "5", code: Int(RETROK_5.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "Q", code: Int(RETROK_q.rawValue)),
				EmulatorKeyboardKey(label: "W", code: Int(RETROK_w.rawValue)),
				EmulatorKeyboardKey(label: "E", code: Int(RETROK_e.rawValue)),
				EmulatorKeyboardKey(label: "R", code: Int(RETROK_r.rawValue)),
				EmulatorKeyboardKey(label: "T", code: Int(RETROK_t.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "A", code: Int(RETROK_a.rawValue)),
				EmulatorKeyboardKey(label: "S", code: Int(RETROK_s.rawValue)),
				EmulatorKeyboardKey(label: "D", code: Int(RETROK_d.rawValue)),
				EmulatorKeyboardKey(label: "F", code: Int(RETROK_f.rawValue)),
				EmulatorKeyboardKey(label: "G", code: Int(RETROK_g.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "Z", code: Int(RETROK_z.rawValue)),
				EmulatorKeyboardKey(label: "X", code: Int(RETROK_x.rawValue)),
				EmulatorKeyboardKey(label: "C", code: Int(RETROK_c.rawValue)),
				EmulatorKeyboardKey(label: "V", code: Int(RETROK_v.rawValue)),
				EmulatorKeyboardKey(label: "B", code: Int(RETROK_b.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "SHIFT", code: Int(RETROK_LSHIFT.rawValue), keySize: .standard, isModifier: true, imageName: "shift", imageNameHighlighted: "shift.fill"),
				EmulatorKeyboardKey(label: "Fn", code: 9000, keySize: .standard, imageName: "fn"),
				EmulatorKeyboardKey(label: "CTRL", code: Int(RETROK_LCTRL.rawValue), isModifier: true, imageName: "control"),
				EmulatorKeyboardKey(label: "Space", code: Int(RETROK_SPACE.rawValue), keySize: .wide)
			]
		],
		alternateKeys: [
			[
				EmulatorKeyboardKey(label: "ESC", code: Int(RETROK_ESCAPE.rawValue), imageName: "escape"),
				SliderKey(keySize: .standard)
			],
			[
				EmulatorKeyboardKey(label: "F1", code: Int(RETROK_F1.rawValue)),
				EmulatorKeyboardKey(label: "F2", code: Int(RETROK_F2.rawValue)),
				EmulatorKeyboardKey(label: "F3", code: Int(RETROK_F3.rawValue)),
				EmulatorKeyboardKey(label: "F4", code: Int(RETROK_F4.rawValue)),
				EmulatorKeyboardKey(label: "F5", code: Int(RETROK_F5.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "-", code: Int(RETROK_MINUS.rawValue)),
				EmulatorKeyboardKey(label: "=", code: Int(RETROK_EQUALS.rawValue)),
				EmulatorKeyboardKey(label: "/", code: Int(RETROK_SLASH.rawValue)),
				EmulatorKeyboardKey(label: "[", code: Int(RETROK_LEFTBRACKET.rawValue)),
				EmulatorKeyboardKey(label: "]", code: Int(RETROK_RIGHTBRACKET.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: ";", code: Int(RETROK_SEMICOLON.rawValue)),
				EmulatorKeyboardKey(label: "~", code: Int(RETROK_TILDE.rawValue)),
				EmulatorKeyboardKey(label: ":", code: Int(RETROK_COLON.rawValue)),
				EmulatorKeyboardKey(label: "?", code: Int(RETROK_QUESTION.rawValue)),
				EmulatorKeyboardKey(label: "!", code: Int(RETROK_EXCLAIM.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "SHIFT", code: Int(RETROK_LSHIFT.rawValue), keySize: .standard, isModifier: true, imageName: "shift", imageNameHighlighted: "shift.fill"),
				EmulatorKeyboardKey(label: "Fn", code: 9000, keySize: .standard, imageName: "fn"),
				EmulatorKeyboardKey(label: "CTRL", code: Int(RETROK_LCTRL.rawValue), isModifier: true, imageName: "control"),
				EmulatorKeyboardKey(label: "Space", code: Int(RETROK_SPACE.rawValue), keySize: .wide)
			]
		])
	}

	var rightKeyboardModel: EmulatorKeyboardViewModel {
		EmulatorKeyboardViewModel(keys: [
			[
				EmulatorKeyboardKey(label: "6", code: Int(RETROK_6.rawValue)),
				EmulatorKeyboardKey(label: "7", code: Int(RETROK_7.rawValue)),
				EmulatorKeyboardKey(label: "8", code: Int(RETROK_8.rawValue)),
				EmulatorKeyboardKey(label: "9", code: Int(RETROK_9.rawValue)),
				EmulatorKeyboardKey(label: "0", code: Int(RETROK_0.rawValue))
			],
			[
				EmulatorKeyboardKey(label: "Y", code: Int(RETROK_y.rawValue)),
				EmulatorKeyboardKey(label: "U", code: Int(RETROK_u.rawValue)),
				EmulatorKeyboardKey(label: "I", code: Int(RETROK_i.rawValue)),
				EmulatorKeyboardKey(label: "O", code: Int(RETROK_o.rawValue)),
				EmulatorKeyboardKey(label: "P", code: Int(RETROK_p.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "H", code: Int(RETROK_h.rawValue)),
				EmulatorKeyboardKey(label: "J", code: Int(RETROK_j.rawValue)),
				EmulatorKeyboardKey(label: "K", code: Int(RETROK_k.rawValue)),
				EmulatorKeyboardKey(label: "L", code: Int(RETROK_l.rawValue)),
				EmulatorKeyboardKey(label: "'", code: Int(RETROK_QUOTE.rawValue))
			],
			[
				EmulatorKeyboardKey(label: "N", code: Int(RETROK_n.rawValue)),
				EmulatorKeyboardKey(label: "M", code: Int(RETROK_m.rawValue)),
				EmulatorKeyboardKey(label: ",", code: Int(RETROK_COMMA.rawValue)),
				EmulatorKeyboardKey(label: ".", code: Int(RETROK_PERIOD.rawValue)),
				EmulatorKeyboardKey(label: "BKSPC", code: Int(RETROK_BACKSPACE.rawValue), imageName: "delete.left", imageNameHighlighted: "delete.left.fill")
			],
			[
				EmulatorKeyboardKey(label: "Alt", code: Int(RETROK_LALT.rawValue), isModifier: true, imageName: "alt"),
				EmulatorKeyboardKey(label: "tab", code: Int(RETROK_TAB.rawValue), imageName: "arrow.right.to.line"),
				EmulatorKeyboardKey(label: "RETURN", code: Int(RETROK_RETURN.rawValue), keySize: .wide)
			],
		],
		alternateKeys: [
			[
				EmulatorKeyboardKey(label: "F6", code: Int(RETROK_F6.rawValue)),
				EmulatorKeyboardKey(label: "F7", code: Int(RETROK_F7.rawValue)),
				EmulatorKeyboardKey(label: "F8", code: Int(RETROK_F8.rawValue)),
				EmulatorKeyboardKey(label: "F9", code: Int(RETROK_F9.rawValue)),
				EmulatorKeyboardKey(label: "F10", code: Int(RETROK_F10.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "PAGEUP", code: Int(RETROK_PAGEUP.rawValue), imageName: "arrow.up.doc"),
				EmulatorKeyboardKey(label: "HOME", code: Int(RETROK_HOME.rawValue), imageName: "house"),
				EmulatorKeyboardKey(label: "INS", code: Int(RETROK_INSERT.rawValue), imageName: "text.insert"),
				EmulatorKeyboardKey(label: "END", code: Int(RETROK_END.rawValue)),
				EmulatorKeyboardKey(label: "PAGEDWN", code: Int(RETROK_PAGEDOWN.rawValue), imageName: "arrow.down.doc"),
			],
			[
				EmulatorKeyboardKey(label: "F11", code: Int(RETROK_F11.rawValue)),
				EmulatorKeyboardKey(label: "⬆️", code: Int(RETROK_UP.rawValue), imageName: "arrow.up"),
				SpacerKey(),
				SpacerKey(),
				EmulatorKeyboardKey(label: "F12", code: Int(RETROK_F12.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "⬅️", code: Int(RETROK_LEFT.rawValue), imageName: "arrow.left"),
				EmulatorKeyboardKey(label: "⬇️", code: Int(RETROK_DOWN.rawValue), imageName: "arrow.down"),
				EmulatorKeyboardKey(label: "➡️", code: Int(RETROK_RIGHT.rawValue), imageName: "arrow.right"),
				SpacerKey(),
				EmulatorKeyboardKey(label: "DEL", code: Int(RETROK_DELETE.rawValue), imageName: "clear", imageNameHighlighted: "clear.fill"),
			],
			[
				EmulatorKeyboardKey(label: "RETURN", code: Int(RETROK_RETURN.rawValue), keySize: .wide)
			]
		])
	}

	@objc public func setupEmulatorKeyboard() {
		keyboardController = EmulatorKeyboardController(leftKeyboardModel: leftKeyboardModel, rightKeyboardModel: rightKeyboardModel)
		keyboardController.leftKeyboardModel.delegate = self;
		keyboardController.rightKeyboardModel.delegate = self;
		addChild(keyboardController)
		keyboardController.didMove(toParent: self)
		keyboardController.view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(keyboardController.view)
		keyboardController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		keyboardController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		keyboardController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
		keyboardController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
		keyboardController.leftKeyboardModel.delegate = self
		keyboardController.rightKeyboardModel.delegate = self
		keyboardController.leftKeyboardModel.modifierDelegate = self
		keyboardController.rightKeyboardModel.modifierDelegate = self
		keyboardController.view.isHidden = true
		keyboardModifierState = 0
	}
}

extension CocoaView: EmulatorKeyboardKeyPressedDelegate {
	func keyUp(_ key: KeyCoded) {
		print("keyUp: code=\(key.keyCode) keyboardModifierState = \(keyboardModifierState)")
		apple_direct_input_keyboard_event(false, UInt32(key.keyCode), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
	}

	func keyDown(_ key: KeyCoded) {
		print("keyDown: code=\(key.keyCode) keyboardModifierState = \(keyboardModifierState)")
		apple_direct_input_keyboard_event(true, UInt32(key.keyCode), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
	}
}

extension CocoaView: EmulatorKeyboardModifierPressedDelegate {
	func modifierPressedWithKey(_ key: KeyCoded, enable: Bool) {
		switch UInt32(key.keyCode) {
		case RETROK_LSHIFT.rawValue:
			if enable {
				keyboardModifierState |= RETROKMOD_SHIFT.rawValue
				apple_direct_input_keyboard_event(true, UInt32(RETROK_LSHIFT.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
			} else {
				keyboardModifierState &= ~RETROKMOD_SHIFT.rawValue
				apple_direct_input_keyboard_event(false, UInt32(RETROK_LSHIFT.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
			}
		case RETROK_LCTRL.rawValue:
			if enable {
				keyboardModifierState |= RETROKMOD_CTRL.rawValue
				apple_direct_input_keyboard_event(true, UInt32(RETROK_LCTRL.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
			} else {
				keyboardModifierState &= ~RETROKMOD_CTRL.rawValue
				apple_direct_input_keyboard_event(false, UInt32(RETROK_LCTRL.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
			}
		case RETROK_LALT.rawValue:
			if enable {
				keyboardModifierState |= RETROKMOD_ALT.rawValue
				apple_direct_input_keyboard_event(true, UInt32(RETROK_LALT.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
			} else {
				keyboardModifierState &= ~RETROKMOD_ALT.rawValue
				apple_direct_input_keyboard_event(false, UInt32(RETROK_LALT.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
			}
		default:
			break
		}
	}

	func isModifierEnabled(key: KeyCoded) -> Bool {
		switch UInt32(key.keyCode) {
		case RETROK_LSHIFT.rawValue:
			return (keyboardModifierState & RETROKMOD_SHIFT.rawValue) != 0
		case RETROK_LCTRL.rawValue:
			return (keyboardModifierState & RETROKMOD_CTRL.rawValue) != 0
		case RETROK_LALT.rawValue:
			return (keyboardModifierState & RETROKMOD_ALT.rawValue) != 0
		default:
			break
		}
		return false
	}
}


class HelperBarViewController: UIViewController {
	var viewModel = HelperBarViewModel()

	private let indicatorImageView: UIImageView = {
		let imageView = UIImageView(frame: .zero)
		imageView.image = UIImage(systemName: "arrow.down.circle")
		imageView.tintColor = .white
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.alpha = 0
		imageView.isUserInteractionEnabled = true
		return imageView
	}()

	private let navigationBar: UINavigationBar = {
		let navBar = UINavigationBar()
		navBar.barTintColor = .black
		navBar.isTranslucent = true
		navBar.alpha = 0.7
		navBar.tintColor = .white
		navBar.isHidden = true
		return navBar
	}()

	override func viewDidLoad() {
		viewModel.delegate = self
		setupViews()
		setupBarItems()
	}

	override func viewDidAppear(_ animated: Bool) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
			self?.showIndicatorAndFadeAway()
		}
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
			self?.showIndicatorAndFadeAway()
		}
	}

	private func setupViews() {
        let scale = UIScreen.main.scale
		indicatorImageView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(indicatorImageView)
		indicatorImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6 * scale).isActive = true
		indicatorImageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -6 * scale).isActive = true
		indicatorImageView.heightAnchor.constraint(equalToConstant: 15 * scale).isActive = true
		indicatorImageView.widthAnchor.constraint(equalTo: indicatorImageView.heightAnchor).isActive = true
		view.addSubview(navigationBar)
		navigationBar.translatesAutoresizingMaskIntoConstraints = false
		navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
		navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
		tap.delegate = self
		view.addGestureRecognizer(tap)
		view.isUserInteractionEnabled = true
		let indicatorTap = UITapGestureRecognizer(target: self, action: #selector(didTapIndicator(_:)))
		indicatorImageView.addGestureRecognizer(indicatorTap)
		navigationBar.delegate = self
	}

	private func setupBarItems() {
		 let barButtonItems = viewModel.createBarButtonItems()
		 let navItem = UINavigationItem()
		 navItem.rightBarButtonItems = barButtonItems
		 navigationBar.items = [navItem]
		 updateBarItems()
	}

	private func updateBarItems() {
		guard let navItem = navigationBar.items?[0],
				let barButtonItems = navItem.rightBarButtonItems else {
			return
		}
		for barButtonItem in barButtonItems {
			guard let helperBarItem = viewModel.barItemMapping[barButtonItem] else {
				continue
			}
			if helperBarItem.isSelected {
				barButtonItem.image = helperBarItem.selectedImage
			} else {
				barButtonItem.image = helperBarItem.image
			}
		}
	}

	private func showIndicatorAndFadeAway() {
		UIView.animateKeyframes(withDuration: 4.0, delay: 0) {
			UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1/7) { [weak self] in
				self?.indicatorImageView.alpha = 1.0
			}

			UIView.addKeyframe(withRelativeStartTime: 1/3, relativeDuration: 6/7) { [weak self] in
				self?.indicatorImageView.alpha = 0.0
			}
		}
	}

	var tappedIndicator = false

	@objc func didTap(_ sender: UITapGestureRecognizer) {
        	let scale = UIScreen.main.scale
		let point = sender.location(in: view)
        	indicatorImageView.layer.removeAllAnimations()
        	indicatorImageView.alpha = 1.0
        	tappedIndicator = false
        	DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            		if !(self?.tappedIndicator ?? false) {
                		self?.showIndicatorAndFadeAway()
            		}
        	}
	}

	@objc func didTapIndicator(_ sender: UITapGestureRecognizer) {
		viewModel.didInteractWithBar = true
		indicatorImageView.layer.removeAllAnimations()
		indicatorImageView.alpha = 0
		tappedIndicator = true
	}
}

extension HelperBarViewController: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		true
	}
}

extension HelperBarViewController: HelperBarViewModelDelegate {
	func setNavigationBarHidden(_ isHidden: Bool) {
		navigationBar.isHidden = isHidden
	}
	func updateNavigationBarItems() {
		updateBarItems()
	}
}

extension HelperBarViewController: UINavigationBarDelegate {
	func position(for bar: UIBarPositioning) -> UIBarPosition {
		return .topAttached
	}
}
