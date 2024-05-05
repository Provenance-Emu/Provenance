//  RetroArchiOS
//  Created by Yoshi Sugawara on 3/3/22.
//  Copyright © 2022 RetroArch. All rights reserved.
import Foundation

protocol HelperBarActionDelegate: AnyObject {
	func keyboardButtonTapped()
	func mouseButtonTapped()
	func helpButtonTapped()
    func settingsButtonTapped()
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
	        if isKeyboardEnabled {
	            NotificationCenter.default.post(name: Notification.Name("HideTouchControls"), object: nil)
	        } else {
	            NotificationCenter.default.post(name: Notification.Name("ShowTouchControls"), object: nil)
	        }
	}

	func mouseButtonTapped() {
#if !os(tvOS)
		mouseHandler.enabled.toggle()
		//runloop_msg_queue_push( mouseHandler.enabled ? "Touch Mouse Enabled" : "Touch Mouse Disabled", 1, 100, true, "", 0, 0)
#endif
	}

    func settingsButtonTapped() {
        menuToggle();
    }
    
	func helpButtonTapped() {
	}

	var isKeyboardEnabled: Bool {
		!keyboardController.view.isHidden
	}

	var isMouseEnabled: Bool {
#if os(tvOS)
        false
#else
		mouseHandler.enabled
#endif
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
              keyboard.toggleAltStackView()
		  }
	 }
    func toggleNumKeys() {
         for keyboard in [leftKeyboardView, rightKeyboardView] {
             keyboard.toggleNumStackView()
         }
    }
    func toggleKeys() {
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
#if !os(tvOS)
		view.isMultipleTouchEnabled = true;
        mouseHandler = EmulatorTouchMouseHandler(view: view, delegate: self as? EmulatorTouchMouseHandlerDelegate)
#endif
	}

	open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
#if !os(tvOS)
		 mouseHandler.touchesBegan(touches: touches, event: event)
#endif
	}

	open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
#if !os(tvOS)
        mouseHandler.touchesMoved(touches: touches)
#endif
	}

	open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
#if !os(tvOS)
        mouseHandler.touchesCancelled(touches: touches, event: event)
#endif
	}

	open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
#if !os(tvOS)
        mouseHandler.touchesEnded(touches: touches, event: event)
#endif
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
                EmulatorKeyboardKey(label: "SHIFT", code: Int(RETROK_LSHIFT.rawValue), keySize: .standard, isModifier: true, imageName: "shift"),
                EmulatorKeyboardKey(label: "CTRL", code: Int(RETROK_LCTRL.rawValue), isModifier: true, imageName: "control"),
                EmulatorKeyboardKey(label: "Fn", code: 9000, keySize: .standard, imageName: "fn"),
                EmulatorKeyboardKey(label: "Num", code: 9001, keySize: .wide),
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
				EmulatorKeyboardKey(label: "SHIFT", code: Int(RETROK_LSHIFT.rawValue), keySize: .standard, isModifier: true, imageName: "shift"),
                EmulatorKeyboardKey(label: "CTRL", code: Int(RETROK_LCTRL.rawValue), isModifier: true, imageName: "control"),
                EmulatorKeyboardKey(label: "Fn", code: 9000, keySize: .standard, imageName: "fn"),
                EmulatorKeyboardKey(label: "Num", code: 9001, keySize: .wide),
			]
        ],
        numKeys: [
                [
                    EmulatorKeyboardKey(label: "~", code: Int(RETROK_TILDE.rawValue)),
                    EmulatorKeyboardKey(label: "!", code: Int(RETROK_EXCLAIM.rawValue)),
                    EmulatorKeyboardKey(label: "@", code: Int(RETROK_AT.rawValue)),
                    EmulatorKeyboardKey(label: "#", code: Int(RETROK_HASH.rawValue)),
                    EmulatorKeyboardKey(label: "$", code: Int(RETROK_DOLLAR.rawValue)),
                ],
                [
                    EmulatorKeyboardKey(label: "Tab", code: Int(RETROK_TAB.rawValue), keySize: .wide),
                    EmulatorKeyboardKey(label: "`", code: Int(RETROK_BACKQUOTE.rawValue)),
                    EmulatorKeyboardKey(label: "^", code: Int(RETROK_CARET.rawValue)),
                    EmulatorKeyboardKey(label: "&", code: Int(RETROK_AMPERSAND.rawValue)),
                    EmulatorKeyboardKey(label: "|", code: Int(RETROK_BAR.rawValue)),
                ],
                [
                    EmulatorKeyboardKey(label: "Alt", code: Int(RETROK_LALT.rawValue), isModifier: true),
                    EmulatorKeyboardKey(label: "(", code: Int(RETROK_LEFTPAREN.rawValue)),
                    EmulatorKeyboardKey(label: ")", code: Int(RETROK_RIGHTPAREN.rawValue)),
                    EmulatorKeyboardKey(label: "_", code: Int(RETROK_UNDERSCORE.rawValue)),
                    EmulatorKeyboardKey(label: "=", code: Int(RETROK_KP_EQUALS.rawValue)),
                ],
                [
                    EmulatorKeyboardKey(label: "{", code: Int(RETROK_LEFTBRACE.rawValue)),
                    EmulatorKeyboardKey(label: "}", code: Int(RETROK_RIGHTBRACE.rawValue)),
                    EmulatorKeyboardKey(label: ">", code: Int(RETROK_GREATER.rawValue)),
                    EmulatorKeyboardKey(label: "<", code: Int(RETROK_LESS.rawValue)),
                    EmulatorKeyboardKey(label: "'", code: Int(RETROK_QUOTE.rawValue)),
                ],
                [
                    EmulatorKeyboardKey(label: "SHIFT", code: Int(RETROK_LSHIFT.rawValue), keySize: .standard, isModifier: true, imageName: "shift"),
                    EmulatorKeyboardKey(label: "CTRL", code: Int(RETROK_LCTRL.rawValue), isModifier: true, imageName: "control"),
                    EmulatorKeyboardKey(label: "Fn", code: 9000, keySize: .standard, imageName: "fn"),
                    EmulatorKeyboardKey(label: "Num", code: 9001, keySize: .wide),
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
				EmulatorKeyboardKey(label: "BKSPC", code: Int(RETROK_BACKSPACE.rawValue), imageName: "delete.left")
			],
			[
				EmulatorKeyboardKey(label: "Alt", code: Int(RETROK_LALT.rawValue), isModifier: true),
                EmulatorKeyboardKey(label: "Space", code: Int(RETROK_SPACE.rawValue), keySize: .wide),
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
                EmulatorKeyboardKey(label: "F12", code: Int(RETROK_F12.rawValue)),
                EmulatorKeyboardKey(label: "@", code: Int(RETROK_AT.rawValue)),
				EmulatorKeyboardKey(label: "\\", code: Int(RETROK_BACKSLASH.rawValue)),
			],
			[
				EmulatorKeyboardKey(label: "⬅️", code: Int(RETROK_LEFT.rawValue), imageName: "arrow.left"),
				EmulatorKeyboardKey(label: "⬇️", code: Int(RETROK_DOWN.rawValue), imageName: "arrow.down"),
				EmulatorKeyboardKey(label: "➡️", code: Int(RETROK_RIGHT.rawValue), imageName: "arrow.right"),
                EmulatorKeyboardKey(label: "\"", code: Int(RETROK_QUOTEDBL.rawValue)),
				EmulatorKeyboardKey(label: "DEL", code: Int(RETROK_DELETE.rawValue)),
			],
			[
                EmulatorKeyboardKey(label: "Alt", code: Int(RETROK_LALT.rawValue), isModifier: true),
                EmulatorKeyboardKey(label: "Space", code: Int(RETROK_SPACE.rawValue), keySize: .wide),
				EmulatorKeyboardKey(label: "RETURN", code: Int(RETROK_RETURN.rawValue), keySize: .wide)
			]
		],
        numKeys: [
          [
              EmulatorKeyboardKey(label: "Num Lock", code: Int(RETROK_NUMLOCK.rawValue), keySize: .wide, isModifier: true),
              EmulatorKeyboardKey(label: "/", code: Int(RETROK_KP_DIVIDE.rawValue)),
              EmulatorKeyboardKey(label: "*", code: Int(RETROK_KP_MULTIPLY.rawValue)),
              EmulatorKeyboardKey(label: "-", code: Int(RETROK_KP_MINUS.rawValue)),
          ],
          [
              EmulatorKeyboardKey(label: "7", code: Int(RETROK_KP7.rawValue)),
              EmulatorKeyboardKey(label: "8", code: Int(RETROK_KP8.rawValue)),
              EmulatorKeyboardKey(label: "9", code: Int(RETROK_KP9.rawValue)),
              EmulatorKeyboardKey(label: "+", code: Int(RETROK_KP_PLUS.rawValue), keySize: .wide),
          ],
          [
              EmulatorKeyboardKey(label: "4", code: Int(RETROK_KP4.rawValue)),
              EmulatorKeyboardKey(label: "5", code: Int(RETROK_KP5.rawValue)),
              EmulatorKeyboardKey(label: "6", code: Int(RETROK_KP6.rawValue)),
              EmulatorKeyboardKey(label: "BKSPC", code: Int(RETROK_BACKSPACE.rawValue), keySize: .wide, imageName: "delete.left"),
          ],
          [
              EmulatorKeyboardKey(label: "1", code: Int(RETROK_KP1.rawValue)),
              EmulatorKeyboardKey(label: "2", code: Int(RETROK_KP2.rawValue)),
              EmulatorKeyboardKey(label: "3", code: Int(RETROK_KP3.rawValue)),
              EmulatorKeyboardKey(label: "Space", code: Int(RETROK_SPACE.rawValue), keySize: .wide),
          ],
          [
              EmulatorKeyboardKey(label: "0", code: Int(RETROK_KP0.rawValue), keySize: .wide),
              EmulatorKeyboardKey(label: ".", code: Int(RETROK_PERIOD.rawValue)),
              EmulatorKeyboardKey(label: "RETURN", code: Int(RETROK_KP_ENTER.rawValue), keySize: .wide)
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
        apple_init_small_keyboard();
        if ((keyboardModifierState & RETROKMOD_SHIFT.rawValue) != 0) {
            if (UInt32(key.keyCode) == RETROK_UP.rawValue) {
                apple_direct_input_keyboard_event(false, UInt32(RETROK_KP8.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
            if (UInt32(key.keyCode) == RETROK_DOWN.rawValue) {
                apple_direct_input_keyboard_event(false, UInt32(RETROK_KP2.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
            if (UInt32(key.keyCode) == RETROK_LEFT.rawValue) {
                apple_direct_input_keyboard_event(false, UInt32(RETROK_KP4.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
            if (UInt32(key.keyCode) == RETROK_RIGHT.rawValue) {
                apple_direct_input_keyboard_event(false, UInt32(RETROK_KP6.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
        }
        apple_direct_input_keyboard_event(false, UInt32(key.keyCode), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
	}

	func keyDown(_ key: KeyCoded) {
        print("keyDown: code=\(key.keyCode) keyboardModifierState = \(keyboardModifierState)");
        apple_init_small_keyboard();
        if ((keyboardModifierState & RETROKMOD_SHIFT.rawValue) != 0) {
            if (UInt32(key.keyCode) == RETROK_UP.rawValue) {
                apple_direct_input_keyboard_event(true, UInt32(RETROK_KP8.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
            if (UInt32(key.keyCode) == RETROK_DOWN.rawValue) {
                apple_direct_input_keyboard_event(true, UInt32(RETROK_KP2.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
            if (UInt32(key.keyCode) == RETROK_LEFT.rawValue) {
                apple_direct_input_keyboard_event(true, UInt32(RETROK_KP4.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
            if (UInt32(key.keyCode) == RETROK_RIGHT.rawValue) {
                apple_direct_input_keyboard_event(true, UInt32(RETROK_KP6.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
                return
            }
        }
		apple_direct_input_keyboard_event(true, UInt32(key.keyCode), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
	}
}

extension CocoaView: EmulatorKeyboardModifierPressedDelegate {
	func modifierPressedWithKey(_ key: KeyCoded, enable: Bool) {
		switch UInt32(key.keyCode) {
        case RETROK_NUMLOCK.rawValue:
            if enable {
                keyboardModifierState |= RETROKMOD_NUMLOCK.rawValue
                apple_direct_input_keyboard_event(true, UInt32(RETROK_NUMLOCK.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
            } else {
                keyboardModifierState &= ~RETROKMOD_NUMLOCK.rawValue
                apple_direct_input_keyboard_event(false, UInt32(RETROK_NUMLOCK.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
            }
        case RETROK_CAPSLOCK.rawValue:
            if enable {
                keyboardModifierState |= RETROKMOD_CAPSLOCK.rawValue
                apple_direct_input_keyboard_event(true, UInt32(RETROK_CAPSLOCK.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
            } else {
                keyboardModifierState &= ~RETROKMOD_CAPSLOCK.rawValue
                apple_direct_input_keyboard_event(false, UInt32(RETROK_CAPSLOCK.rawValue), 0, keyboardModifierState, UInt32(RETRO_DEVICE_KEYBOARD))
            }
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
        case RETROK_NUMLOCK.rawValue:
            return (keyboardModifierState & RETROKMOD_NUMLOCK.rawValue) != 0
        case RETROK_CAPSLOCK.rawValue:
            return (keyboardModifierState & RETROKMOD_CAPSLOCK.rawValue) != 0
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

struct KeyPosition {
    let row: Int
    let column: Int
}

@objc class EmulatorKeyboardViewModel: NSObject, KeyRowsDataSource {
    var keys = [[KeyCoded]]()
    var alternateKeys: [[KeyCoded]]?
    var numKeys: [[KeyCoded]]?
    var modifiers: [Int16: KeyCoded]?
    
    var isDraggable = true
    
    @objc weak var delegate: EmulatorKeyboardKeyPressedDelegate?
    @objc weak var modifierDelegate: EmulatorKeyboardModifierPressedDelegate?
    
    init(keys: [[KeyCoded]], alternateKeys: [[KeyCoded]]? = nil, numKeys: [[KeyCoded]]? = nil) {
        self.keys = keys
        self.alternateKeys = alternateKeys
        self.numKeys = numKeys
    }
    
    func createView() -> EmulatorKeyboardView {
        let view = EmulatorKeyboardView()
        view.viewModel = self
        return view
    }
    
    func keyForPositionAt(_ position: KeyPosition) -> KeyCoded? {
        guard position.row < keys.count else {
            return nil
        }
        let row = keys[position.row]
        guard position.column < row.count else {
            return nil
        }
        return row[position.column]
    }
    
    func modifierKeyToggleStateForKey(_ key: KeyCoded) -> Bool {
        return key.isModifier && (modifierDelegate?.isModifierEnabled(key: key) ?? false)
    }
    
    func keyPressed(_ key: KeyCoded) {
        if key.isModifier {
            let isPressed = modifierDelegate?.isModifierEnabled(key: key) ?? false
            modifierDelegate?.modifierPressedWithKey(key, enable: !isPressed)
            return
        }
        delegate?.keyDown(key)
    }
    
    func keyReleased(_ key: KeyCoded) {
        if key.isModifier {
            return
        }
        delegate?.keyUp(key)
    }
    
    // KeyCoded can support a shifted key label
    // view can update with shifted key labels?
    // cluster can support alternate keys and view can swap them out?
}

//
//  EmulatorKeyboard.swift
//
//  Created by Yoshi Sugawara on 7/30/20.
//

// TODO: shift key should change the label of the keys to uppercase (need callback mechanism?)
// pan gesture to outer edges of keyboard view for better dragging

@objc protocol EmulatorKeyboardKeyPressedDelegate: AnyObject {
    func keyDown(_ key: KeyCoded)
    func keyUp(_ key: KeyCoded)
}

@objc protocol EmulatorKeyboardModifierPressedDelegate: AnyObject {
    func modifierPressedWithKey(_ key: KeyCoded, enable: Bool)
    func isModifierEnabled(key: KeyCoded) -> Bool
}

protocol EmulatorKeyboardViewDelegate: AnyObject {
    func toggleAlternateKeys()
    func toggleNumKeys()
    func toggleKeys()
    func refreshModifierStates()
    func updateTransparency(toAlpha alpha: Float)
}

class EmulatorKeyboardView: UIView {
   
    #if os(tvOS)
    static var keyboardBackgroundColor = UIColor.systemGray.withAlphaComponent(0.5)
    #else
    static var keyboardBackgroundColor = UIColor.systemGray6.withAlphaComponent(0.5)
    #endif
    static var keyboardCornerRadius = 6.0
   static var keyboardDragColor = UIColor.systemGray
   
   static var keyCornerRadius = 6.0
   static var keyBorderWidth = 1.0
   
   static var rowSpacing = 12.0
   static var keySpacing = 8.0
   
   static var keyNormalFont = UIFont.systemFont(ofSize: 12)
   static var keyPressedFont = UIFont.boldSystemFont(ofSize: 24)
   
#if os(tvOS)
    static var keyNormalBackgroundColor = UIColor.systemGray.withAlphaComponent(0.5)
#else
    static var keyNormalBackgroundColor = UIColor.systemGray4.withAlphaComponent(0.5)
#endif
   static var keyNormalBorderColor = keyNormalBackgroundColor
   static var keyNormalTextColor = UIColor.label
   

#if os(tvOS)
    static var keyPressedBackgroundColor = UIColor.systemGray
#else
    static var keyPressedBackgroundColor = UIColor.systemGray2
#endif
   static var keyPressedBorderColor = keyPressedBackgroundColor
   static var keyPressedTextColor = UIColor.label
   

#if os(tvOS)
    static var keySelectedBackgroundColor = UIColor.systemGray.withAlphaComponent(0.8)
#else
    static var keySelectedBackgroundColor = UIColor.systemGray2.withAlphaComponent(0.8)
#endif
   static var keySelectedBorderColor = keySelectedBackgroundColor
   static var keySelectedTextColor = UIColor.label
   
    var viewModel = EmulatorKeyboardViewModel(keys: [[KeyCoded]]()) {
        didSet {
            setupWithModel(viewModel)
        }
    }
    var modifierButtons = Set<EmulatorKeyboardButton>()
    
    weak var delegate: EmulatorKeyboardViewDelegate?
    
    private lazy var keyRowsStackView: UIStackView = {
       let stackView = UIStackView()
       stackView.translatesAutoresizingMaskIntoConstraints = false
       stackView.axis = .vertical
       stackView.distribution = .equalCentering
       stackView.spacing = Self.rowSpacing
       return stackView
    }()
    
    private lazy var alternateKeyRowsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .equalCentering
        stackView.spacing = Self.rowSpacing
        stackView.isHidden = true
        return stackView
    }()
    
    private lazy var numKeyRowsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .equalCentering
        stackView.spacing = Self.rowSpacing
        stackView.isHidden = true
        return stackView
    }()
    
    let dragMeView: UIView = {
      let view = UIView(frame: .zero)
      view.backgroundColor = EmulatorKeyboardView.keyboardDragColor
      view.translatesAutoresizingMaskIntoConstraints = false
      view.widthAnchor.constraint(equalToConstant: 80).isActive = true
      view.heightAnchor.constraint(equalToConstant: 2).isActive = true
      let outerView = UIView(frame: .zero)
      outerView.backgroundColor = .clear
      outerView.translatesAutoresizingMaskIntoConstraints = false
      outerView.addSubview(view)
      view.centerXAnchor.constraint(equalTo: outerView.centerXAnchor).isActive = true
      view.centerYAnchor.constraint(equalTo: outerView.centerYAnchor).isActive = true
      outerView.heightAnchor.constraint(equalToConstant: 20).isActive = true
      outerView.widthAnchor.constraint(equalToConstant: 100).isActive = true
      return outerView
    }()
    
    private var pressedKeyViews = [UIControl: UIView]()
    
    convenience init() {
        self.init(frame: CGRect.zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = Self.keyboardBackgroundColor
        layer.cornerRadius = Self.keyboardCornerRadius
        layoutMargins = UIEdgeInsets(top: 16, left: 4, bottom: 16, right: 4)
        insetsLayoutMarginsFromSafeArea = false
        addSubview(keyRowsStackView)
        keyRowsStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor).isActive = true
        keyRowsStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 4.0).isActive = true
        keyRowsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -4.0).isActive = true
        addSubview(alternateKeyRowsStackView)
        alternateKeyRowsStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor).isActive = true
        alternateKeyRowsStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 4.0).isActive = true
        alternateKeyRowsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -4.0).isActive = true
        addSubview(numKeyRowsStackView)
        numKeyRowsStackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor).isActive = true
        numKeyRowsStackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 4.0).isActive = true
        numKeyRowsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -4.0).isActive = true
        addSubview(dragMeView)
        dragMeView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        dragMeView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
    
    
    @objc private func keyPressed(_ sender: EmulatorKeyboardButton) {
        if sender.key.keyCode == 9000 { // hack for now
            return
        }
        if sender.key.keyCode == 9001 { // hack for now
            return
        }
        if !sender.key.isModifier {
           // make a "stand-in" for our key, and scale up key
           let view = UIView()
           view.backgroundColor = EmulatorKeyboardView.keyPressedBackgroundColor
           view.layer.cornerRadius = EmulatorKeyboardView.keyCornerRadius
           view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
           view.frame = sender.convert(sender.bounds, to: self)
           addSubview(view)
           
           var tx = 0.0
           let ty = sender.bounds.height * -1.20
           
           if let window = self.window {
               let rect = sender.convert(sender.bounds, to:window)
               
               if rect.maxX > window.bounds.width * 0.9 {
                   tx = sender.bounds.width * -0.5
               }
               if rect.minX < window.bounds.width * 0.1 {
                   tx = sender.bounds.width * 0.5
               }
           }

           sender.superview!.bringSubviewToFront(sender)
           sender.transform = CGAffineTransform(translationX:tx, y:ty).scaledBy(x:2, y:2)
           
           pressedKeyViews[sender] = view
        }
        viewModel.keyPressed(sender.key)
    }
    
    @objc private func keyCancelled(_ sender: EmulatorKeyboardButton) {
       sender.transform = .identity
       if let view = pressedKeyViews[sender] {
          view.removeFromSuperview()
          pressedKeyViews.removeValue(forKey: sender)
       }
    }
    
    @objc private func keyReleased(_ sender: EmulatorKeyboardButton) {
       sender.transform = .identity
       if sender.key.keyCode == 9000 {
          delegate?.toggleAlternateKeys()
          return
       }
       if sender.key.keyCode == 9001 {
          delegate?.toggleNumKeys()
          return
       }
       if let view = pressedKeyViews[sender] {
          view.removeFromSuperview()
          pressedKeyViews.removeValue(forKey: sender)
       }
       sender.isSelected = viewModel.modifierKeyToggleStateForKey(sender.key)
       viewModel.keyReleased(sender.key)
       self.delegate?.refreshModifierStates()
    }
    
    func setupWithModel(_ model: EmulatorKeyboardViewModel) {
        for row in model.keys {
            let keysInRow = createKeyRow(keys: row)
            keyRowsStackView.addArrangedSubview(keysInRow)
        }
        if let altKeys = model.alternateKeys {
            for row in altKeys {
                let keysInRow = createKeyRow(keys: row)
                alternateKeyRowsStackView.addArrangedSubview(keysInRow)
            }
        }
        if let numKeys = model.numKeys {
            for row in numKeys {
                let keysInRow = createKeyRow(keys: row)
                numKeyRowsStackView.addArrangedSubview(keysInRow)
            }
        }
        if !model.isDraggable {
            dragMeView.isHidden = true
        }
    }
    
    func toggleKeysStackView() {
        if viewModel.keys != nil {
            keyRowsStackView.isHidden = false;
            alternateKeyRowsStackView.isHidden = true
            numKeyRowsStackView.isHidden = true
            refreshModifierStates()
        }
    }
    
    func toggleAltStackView() {
        if viewModel.alternateKeys != nil {
            if (alternateKeyRowsStackView.isHidden) {
                alternateKeyRowsStackView.isHidden = false;
                keyRowsStackView.isHidden = true
                numKeyRowsStackView.isHidden = true
            } else {
                numKeyRowsStackView.isHidden = true
                keyRowsStackView.isHidden = false
                alternateKeyRowsStackView.isHidden = true
            }
            refreshModifierStates()
        }
    }
    
    func toggleNumStackView() {
        if viewModel.numKeys != nil {
            if (numKeyRowsStackView.isHidden) {
                numKeyRowsStackView.isHidden = false
                keyRowsStackView.isHidden = true
                alternateKeyRowsStackView.isHidden = true
            } else {
                numKeyRowsStackView.isHidden = true
                keyRowsStackView.isHidden = false
                alternateKeyRowsStackView.isHidden = true
            }
            refreshModifierStates()
        }
    }
    func refreshModifierStates() {
       modifierButtons.forEach{ button in
          button.isSelected = viewModel.modifierKeyToggleStateForKey(button.key)
       }
    }
    
    private func createKey(_ keyCoded: KeyCoded) -> UIButton {
       let key = EmulatorKeyboardButton(key: keyCoded)
       if let imageName = keyCoded.keyImageName {
          key.tintColor = EmulatorKeyboardView.keyNormalTextColor
          key.setImage(UIImage(systemName: imageName), for: .normal)
          if let highlightedImageName = keyCoded.keyImageNameHighlighted {
             key.setImage(UIImage(systemName: highlightedImageName), for: .highlighted)
             key.setImage(UIImage(systemName: highlightedImageName), for: .selected)
          }
       } else {
          key.setTitle(keyCoded.keyLabel, for: .normal)
          key.titleLabel?.font = EmulatorKeyboardView.keyNormalFont
          key.setTitleColor(EmulatorKeyboardView.keyNormalTextColor, for: .normal)
          key.setTitleColor(EmulatorKeyboardView.keySelectedTextColor, for: .selected)
          key.setTitleColor(EmulatorKeyboardView.keyPressedTextColor, for: .highlighted)
       }
       
       key.translatesAutoresizingMaskIntoConstraints = false
       key.widthAnchor.constraint(equalToConstant: (25 * CGFloat(keyCoded.keySize.rawValue))).isActive = true
       key.heightAnchor.constraint(equalToConstant: 35).isActive = true
       key.backgroundColor = EmulatorKeyboardView.keyNormalBackgroundColor
       key.layer.borderWidth = EmulatorKeyboardView.keyBorderWidth
       key.layer.borderColor = EmulatorKeyboardView.keyNormalBorderColor.cgColor
       key.layer.cornerRadius = EmulatorKeyboardView.keyCornerRadius
       key.addTarget(self, action: #selector(keyPressed(_:)), for: .touchDown)
       key.addTarget(self, action: #selector(keyReleased(_:)), for: .touchUpInside)
       key.addTarget(self, action: #selector(keyReleased(_:)), for: .touchUpOutside)
       key.addTarget(self, action: #selector(keyCancelled(_:)), for: .touchCancel)
       if keyCoded.isModifier {
          modifierButtons.update(with: key)
       }
       return key
    }

    private func createKeyRow(keys: [KeyCoded]) -> UIStackView {
        let subviews: [UIView] = keys.enumerated().map { index, keyCoded -> UIView in
            if keyCoded is SpacerKey {
                let spacer = UIView()
                spacer.widthAnchor.constraint(equalToConstant: 25.0 * CGFloat(keyCoded.keySize.rawValue)).isActive = true
                spacer.heightAnchor.constraint(equalToConstant: 25.0).isActive = true
                return spacer
            } else if let sliderKey = keyCoded as? SliderKey {
                sliderKey.keyboardView = self
                return sliderKey.createView()
            }
            return createKey(keyCoded)
        }
        let stack = UIStackView(arrangedSubviews: subviews)
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.spacing = 8
        return stack
    }
}

extension UIImage {
    static func dot(size:CGSize, color:UIColor) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin:.zero, size:size))
        }
    }
}

//
//  HelperBarItem.swift
//  RetroArchiOS
//
//  Created by Yoshi Sugawara on 3/1/22.
//  Copyright © 2022 RetroArch. All rights reserved.
//

protocol HelperBarItem {
   var image: UIImage? { get }
   var selectedImage: UIImage? { get }
   var isSelected: Bool { get }
   var shortDescription: String { get }
   var longDescription: String? { get }
   func action()
}

struct KeyboardBarItem: HelperBarItem {
   let image = UIImage(systemName: "keyboard")
   let selectedImage = UIImage(systemName: "keyboard.fill")
   var isSelected: Bool { actionDelegate?.isKeyboardEnabled ?? false }
   let shortDescription = Strings.shortDescription
   let longDescription: String? = Strings.longDescription
   weak var actionDelegate: HelperBarActionDelegate?
   
   init(actionDelegate: HelperBarActionDelegate?) {
      self.actionDelegate = actionDelegate
   }
   
   func action() {
      actionDelegate?.keyboardButtonTapped()
   }
   
   struct Strings {
      static let shortDescription = NSLocalizedString("An on-screen keyboard", comment: "Description for on-screen keyboard item on helper bar")
      static let longDescription = NSLocalizedString("An on-screen keyboard for cores that require keyboard input.", comment: "Description for on-screen keyboard item on helper bar")
   }
}

struct MouseBarItem: HelperBarItem {
   let image = UIImage(systemName: "computermouse")
   let selectedImage = UIImage(systemName: "computermouse.fill")
   var isSelected: Bool { actionDelegate?.isMouseEnabled ?? false }
   let shortDescription = NSLocalizedString("Use the touch screen for mouse input.", comment: "Description for touch screen mouse item on helper bar")
   var longDescription: String? { nil }
   weak var actionDelegate: HelperBarActionDelegate?

   init(actionDelegate: HelperBarActionDelegate?) {
      self.actionDelegate = actionDelegate
   }

   func action() {
      actionDelegate?.mouseButtonTapped()
   }
}


struct SettingsBarItem: HelperBarItem {
   let image = UIImage(systemName: "gear.circle")
   let selectedImage = UIImage(systemName: "gear.circle.fill")
   var isSelected: Bool { false }
   let shortDescription = NSLocalizedString("Game Options Menu", comment:"Settings Menu")
   var longDescription: String? { nil }
   weak var actionDelegate: HelperBarActionDelegate?

   init(actionDelegate: HelperBarActionDelegate?) {
      self.actionDelegate = actionDelegate
   }

   func action() {
       actionDelegate?.settingsButtonTapped()
   }
}

//
//  HelperBarViewModel.swift
//  RetroArchiOS
//
//  Created by Yoshi Sugawara on 3/1/22.
//  Copyright © 2022 RetroArch. All rights reserved.
//

import Combine

protocol HelperBarViewModelDelegate: AnyObject {
   func setNavigationBarHidden(_ isHidden: Bool)
   func updateNavigationBarItems()
}

class HelperBarViewModel {
   @Published var didInteractWithBar = false
   private var cancellable: AnyCancellable?
   private var timer: DispatchSourceTimer?
   
   weak var delegate: HelperBarViewModelDelegate?
   weak var actionDelegate: HelperBarActionDelegate?
   
   lazy var barItems: [HelperBarItem] = [
      SettingsBarItem(actionDelegate: actionDelegate),
      KeyboardBarItem(actionDelegate: actionDelegate),
      MouseBarItem(actionDelegate: actionDelegate)
   ]
   
   var barItemMapping = [UIBarButtonItem: HelperBarItem]()
   
   init(delegate: HelperBarViewModelDelegate? = nil, actionDelegate: HelperBarActionDelegate? = nil) {
      self.delegate = delegate
      self.actionDelegate = actionDelegate
      setupSubscription()
   }
   
   // Create a timer that will hide the navigation bar after 3 seconds if it's not interacted with
   private func setupTimer() {
      timer = DispatchSource.makeTimerSource()
      timer?.setEventHandler(handler: { [weak self] in
         guard let self = self else { return }
         if !self.didInteractWithBar {
            DispatchQueue.main.async { [weak self] in
               self?.didInteractWithBar = false
               self?.delegate?.setNavigationBarHidden(true)
            }
         }
      })
      timer?.schedule(deadline: .now() + .seconds(3))
      timer?.resume()
   }

   // Listen for changes on didInteractWithBar
   private func setupSubscription() {
      cancellable = $didInteractWithBar
         .receive(on: RunLoop.main)
         .sink(receiveValue: { [weak self] didInteract in
            print("didInteract changed to \(didInteract)")
            if didInteract {
               self?.delegate?.setNavigationBarHidden(false)
               self?.timer?.cancel()
               self?.setupTimer()
               self?.didInteractWithBar = false
            }
      })
   }
   
   func createBarButtonItems() -> [UIBarButtonItem] {
      barItemMapping.removeAll()
      return barItems.map{ [weak self] item in
         let barButtonItem = UIBarButtonItem(image: item.image, style: .plain, target: self, action: #selector(self?.didTapBarItem(_:)))
         self?.barItemMapping[barButtonItem] = item
         return barButtonItem
      }
   }
   
   @objc private func didTapBarItem(_ sender: UIBarButtonItem) {
      guard let item = barItemMapping[sender] else { return }
      item.action()
      delegate?.updateNavigationBarItems()
   }
}

//
//  EmulatorKeyCoded.swift
//  RetroArchiOS
//
//  Created by Yoshi Sugawara on 3/3/22.
//  Copyright © 2022 RetroArch. All rights reserved.
//

@objc enum KeySize: Int {
    case standard = 1, wide, wider
}

// represents a key that has an underlying code that gets sent to the emulator
@objc protocol KeyCoded: AnyObject {
    var keyLabel: String { get }
    var keyImageName: String? { get }
    var keyImageNameHighlighted: String? { get }
    var keyCode: Int { get }
    var keySize: KeySize { get }
    var isModifier: Bool { get }
}

protocol KeyRowsDataSource {
    func keyForPositionAt(_ position: KeyPosition) -> KeyCoded?
}

@objc class EmulatorKeyboardKey: NSObject, KeyCoded {
    let keyLabel: String
    var keyImageName: String?
    var keyImageNameHighlighted: String?
    let keyCode: Int
    let keySize: KeySize
    let isModifier: Bool
    
    override var description: String {
        return String(format: "\(keyLabel) (%02X)", keyCode)
    }
    init(label: String, code: Int, keySize: KeySize = .standard, isModifier: Bool = false, imageName: String? = nil, imageNameHighlighted: String? = nil)  {
        self.keyLabel = label
        self.keyCode = code
        self.keySize = keySize
        self.isModifier = isModifier
        self.keyImageName = imageName
        self.keyImageNameHighlighted = imageNameHighlighted
    }
}

class SpacerKey: KeyCoded {
    let keyLabel = ""
    let keyCode = 0
    let keySize: KeySize
    let isModifier = false
    let keyImageName: String? = nil
    let keyImageNameHighlighted: String? = nil
    init(keySize: KeySize = .standard) {
        self.keySize = keySize
    }
}

class SliderKey: KeyCoded {
   let keyLabel = ""
   let keyCode = 0
   let keySize: KeySize
   let isModifier = false
   let keyImageName: String? = nil
   let keyImageNameHighlighted: String? = nil
   weak var keyboardView: EmulatorKeyboardView?
   
   init(keySize: KeySize = .standard) {
      self.keySize = keySize
   }

#if !os(tvOS)
   func createView() -> UIView {
      let slider = UISlider(frame: .zero)

       slider.minimumValue = 0.1
       slider.maximumValue = 1.0
       slider.addTarget(self, action: #selector(adjustKeyboardAlpha(_:)), for: .valueChanged)
       slider.value = 1.0
       let size = CGSize(width:EmulatorKeyboardView.keyNormalFont.pointSize, height:EmulatorKeyboardView.keyNormalFont.pointSize)
       slider.setThumbImage(UIImage.dot(size:size, color:EmulatorKeyboardView.keyNormalTextColor), for: .normal)
       return slider
    }
   @objc func adjustKeyboardAlpha(_ sender: UISlider) {
      keyboardView?.delegate?.updateTransparency(toAlpha: sender.value)
   }
#else
    func createView() -> UIView {
        let slider = UIButton()
        slider.addTarget(self, action: #selector(adjustKeyboardAlpha(_:)), for: .valueChanged)
        let size = CGSize(width:EmulatorKeyboardView.keyNormalFont.pointSize, height:EmulatorKeyboardView.keyNormalFont.pointSize)
        return slider
    }
    @objc func adjustKeyboardAlpha(_ sender: UIButton) {
        // TODO: Do we have a tvOS slider? @JoeMatt
//        keyboardView?.delegate?.updateTransparency(toAlpha: sender.value)
    }

#endif

}

//
//  KeyboardButton.swift
//  RetroArchiOS
//
//  Created by Yoshi Sugawara on 3/3/22.
//  Copyright © 2022 RetroArch. All rights reserved.
//

import UIKit

class EmulatorKeyboardButton: UIButton {
    let key: KeyCoded
    var toggleState = false
    
    // MARK: - Functions
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let newArea = CGRect(
            x: self.bounds.origin.x - 5.0,
            y: self.bounds.origin.y - 5.0,
            width: self.bounds.size.width + 20.0,
            height: self.bounds.size.height + 20.0
        )
        return newArea.contains(point)
    }

   private func updateColors() {
        backgroundColor = isHighlighted ? EmulatorKeyboardView.keyPressedBackgroundColor : isSelected ? EmulatorKeyboardView.keySelectedBackgroundColor : EmulatorKeyboardView.keyNormalBackgroundColor
        layer.borderColor = (isHighlighted ? EmulatorKeyboardView.keyPressedBorderColor : isSelected ? EmulatorKeyboardView.keySelectedBorderColor : EmulatorKeyboardView.keyNormalBorderColor).cgColor
        titleLabel?.textColor = isHighlighted ? EmulatorKeyboardView.keyPressedTextColor : isSelected ? EmulatorKeyboardView.keySelectedTextColor : EmulatorKeyboardView.keyNormalTextColor
        titleLabel?.tintColor = titleLabel?.textColor
    }
   
    override open var isHighlighted: Bool {
        didSet {
           updateColors()
        }
    }
    
    override open var isSelected: Bool {
        didSet {
           updateColors()
        }
    }
    
    required init(key: KeyCoded) {
       self.key = key
       super.init(frame: .zero)
       updateColors()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#if !os(tvOS)
//
//  EmulatorTouchMouse.swift
//  RetroArchiOS
//
//  Created by Yoshi Sugawara on 12/27/21.
//  Copyright © 2021 RetroArch. All rights reserved.
//

/**
 Touch mouse behavior:
 - Mouse movement: Pan finger around screen
 - Left click: Tap with one finger
 - Right click: Tap with two fingers (or hold with one finger and tap with another)
 - Click-and-drag: Double tap and hold for 1 second, then pan finger around screen to drag mouse
 
 Code adapted from iDOS/dospad: https://github.com/litchie/dospad
 */

import Combine
import UIKit

@objc public protocol EmulatorTouchMouseHandlerDelegate: AnyObject {
   func handleMouseClick(isLeftClick: Bool, isPressed: Bool)
   func handleMouseMove(x: CGFloat, y: CGFloat)
   func handlePointerMove(x: CGFloat, y: CGFloat)
}

@objcMembers public class EmulatorTouchMouseHandler: NSObject, UIPointerInteractionDelegate {
   enum MouseHoldState {
      case notHeld, wait, held
   }

   struct MouseClick {
      var isRightClick = false
      var isPressed = false
   }
   
   struct TouchInfo {
      let touch: UITouch
      let origin: CGPoint
      let holdState: MouseHoldState
   }

   var enabled = false
   
   let view: UIView
   weak var delegate: EmulatorTouchMouseHandlerDelegate?
   
   private let positionChangeThreshold: CGFloat = 20.0
   private let mouseHoldInterval: TimeInterval = 1.0
   
   private var pendingMouseEvents = [MouseClick]()
   private var mouseEventPublisher: AnyPublisher<MouseClick, Never> {
      mouseEventSubject.eraseToAnyPublisher()
   }
   private let mouseEventSubject = PassthroughSubject<MouseClick, Never>()
   private var subscription: AnyCancellable?
   
   private var primaryTouch: TouchInfo?
   private var secondaryTouch: TouchInfo?
   
   private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
   
   public init(view: UIView, delegate: EmulatorTouchMouseHandlerDelegate? = nil) {
      self.view = view
      self.delegate = delegate
      super.init()
      setup()
   }
   
   private func setup() {
      subscription = mouseEventPublisher
         .sink(receiveValue: {[weak self] value in
            self?.pendingMouseEvents.append(value)
            self?.processMouseEvents()
         })
      if #available(iOS 13.4, *) {
         // get pointer interactions
         let pointerInteraction = UIPointerInteraction(delegate: self)
         self.view.addInteraction(pointerInteraction)
         self.view.isUserInteractionEnabled=true
      }
   }
   
   private func processMouseEvents() {
      guard let event = pendingMouseEvents.first else {
         return
      }
      delegate?.handleMouseClick(isLeftClick: !event.isRightClick, isPressed: event.isPressed)
      if event.isPressed {
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mouseEventSubject.send(MouseClick(isRightClick: event.isRightClick, isPressed: false))
         }
      }
      pendingMouseEvents.removeFirst()
      processMouseEvents()
   }
   
   @objc private func beginHold() {
      guard let primaryTouch = primaryTouch, primaryTouch.holdState == .wait else {
         return
      }
      self.primaryTouch = TouchInfo(touch: primaryTouch.touch, origin: primaryTouch.origin, holdState: .held)
      mediumHaptic.impactOccurred()
      delegate?.handleMouseClick(isLeftClick: true, isPressed: true)
   }
   
   private func endHold() {
      guard let primaryTouch = primaryTouch else { return }
      if primaryTouch.holdState == .notHeld {
         return
      }
      if primaryTouch.holdState == .wait {
         Thread.cancelPreviousPerformRequests(withTarget: self, selector: #selector(beginHold), object: self)
      } else {
         delegate?.handleMouseClick(isLeftClick: true, isPressed: false)
      }
      self.primaryTouch = TouchInfo(touch: primaryTouch.touch, origin: primaryTouch.origin, holdState: .notHeld)
   }
   
   public func touchesBegan(touches: Set<UITouch>, event: UIEvent?) {
      guard enabled, let touch = touches.first else {
         if #available(iOS 13.4, *), let _ = touches.first {
            let isLeftClick=(event?.buttonMask == UIEvent.ButtonMask.button(1))
            delegate?.handleMouseClick(isLeftClick: isLeftClick, isPressed: true)
         }
         return
      }
      if primaryTouch == nil {
         primaryTouch = TouchInfo(touch: touch, origin: touch.location(in: view), holdState: .wait)
         if touch.tapCount == 2 {
            self.perform(#selector(beginHold), with: nil, afterDelay: mouseHoldInterval)
         }
      } else if secondaryTouch == nil {
         secondaryTouch = TouchInfo(touch: touch, origin: touch.location(in: view), holdState: .notHeld)
      }
   }
   
   public func touchesEnded(touches: Set<UITouch>, event: UIEvent?) {
      guard enabled else {
         if #available(iOS 13.4, *) {
            let isLeftClick=(event?.buttonMask == UIEvent.ButtonMask.button(1))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
               self?.delegate?.handleMouseClick(isLeftClick: isLeftClick, isPressed: false)
            }
         }
         return
      }
      for touch in touches {
         if touch == primaryTouch?.touch {
            if touch.tapCount > 0 {
               for _ in 1...touch.tapCount {
                  mouseEventSubject.send(MouseClick(isRightClick: false, isPressed: true))
               }
            }
            endHold()
            primaryTouch = nil
            secondaryTouch = nil
         } else if touch == secondaryTouch?.touch {
            if touch.tapCount > 0 {
               mouseEventSubject.send(MouseClick(isRightClick: true, isPressed: true))
               endHold()
            }
            secondaryTouch = nil
         }
      }
      delegate?.handleMouseMove(x: 0, y: 0)
   }
   
   public func touchesMoved(touches: Set<UITouch>) {
      guard enabled else { return }
      for touch in touches {
         if touch == primaryTouch?.touch {
            let a = touch.previousLocation(in: view)
            let b = touch.location(in: view)
            if primaryTouch?.holdState == .wait && (distanceBetween(pointA: a, pointB: b) > positionChangeThreshold) {
               endHold()
            }
            delegate?.handleMouseMove(x: b.x-a.x, y: b.y-a.y)
         }
      }
   }
   
   public func touchesCancelled(touches: Set<UITouch>, event: UIEvent?) {
      guard enabled else {
         if #available(iOS 13.4, *) {
            let isLeftClick=(event?.buttonMask == UIEvent.ButtonMask.button(1))
            delegate?.handleMouseClick(isLeftClick: isLeftClick, isPressed: false)
         }
         return
      }
      for touch in touches {
         if touch == primaryTouch?.touch {
            endHold()
         }
      }
      primaryTouch = nil
      secondaryTouch = nil
   }
   
   func distanceBetween(pointA: CGPoint, pointB: CGPoint) -> CGFloat {
      let dx = pointA.x - pointB.x
      let dy = pointA.y - pointB.y
      return sqrt(dx*dx*dy*dy)
   }

   @available(iOS 13.4, *)
   public func pointerInteraction(
       _ interaction: UIPointerInteraction,
       regionFor request: UIPointerRegionRequest,
       defaultRegion: UIPointerRegion
     ) -> UIPointerRegion? {
        guard !enabled else { return defaultRegion }
        let location = request.location;
        delegate?.handlePointerMove(x: location.x, y: location.y)
        return defaultRegion
   }
}
#endif
