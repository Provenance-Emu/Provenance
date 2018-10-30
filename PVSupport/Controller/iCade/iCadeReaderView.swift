import UIKit

/*
                EN      FR      DE
 UP ON,OFF  =   w,e     z,e     w,e
 RT ON,OFF  =   d,c     d,c     d,c
 DN ON,OFF  =   x,z     x,w     x,y
 LT ON,OFF  =   a,q     q,a     a,q
 A  ON,OFF  =   y,t     y,t     z,t
 B  ON,OFF  =   h,r     h,r     h,r
 C  ON,OFF  =   u,f     u,f     u,f
 D  ON,OFF  =   j,n     j,n     j,n
 E  ON,OFF  =   i,m     i,,     i,m
 F  ON,OFF  =   k,p     k,p     k,p
 G  ON,OFF  =   o,g     o,g     o,g
 H  ON,OFF  =   l,v     l,v     l,v
 // Mocute Extensions
 I  ON,OFF  =   [,] Left Trigger
 J  ON,OFF  =   1,2 Right Trigger
*/

/// Add the `inserting` and `removing` functions
private extension OptionSet where Element == Self {
	/// Duplicate the set and insert the given option
	func inserting(_ newMember: Self) -> Self {
		var opts = self
		opts.insert(newMember)
		return opts
	}

	/// Duplicate the set and remove the given option
	func removing(_ member: Self) -> Self {
		var opts = self
		opts.remove(member)
		return opts
	}
}

extension String {
	var length: Int {
		get {
			return self.count
		}
	}

	/// The first index of the given string
	public func indexRaw(of str: String, after: Int = 0, options: String.CompareOptions = .literal, locale: Locale? = nil) -> String.Index? {
		guard str.length > 0 else {
			// Can't look for nothing
			return nil
		}
		guard (str.length + after) <= self.length else {
			// Make sure the string you're searching for will actually fit
			return nil
		}

		let startRange = self.index(self.startIndex, offsetBy: after)..<self.endIndex
		return self.range(of: str, options: options.removing(.backwards), range: startRange, locale: locale)?.lowerBound
	}

	public func index(of str: String, after: Int = 0, options: String.CompareOptions = .literal, locale: Locale? = nil) -> Int {
		guard let index = indexRaw(of: str, after: after, options: options, locale: locale) else {
			return -1
		}
		return self.distance(from: self.startIndex, to: index)
	}
}

private let ON_STATES_EN :[Character] = "wdxayhujikol[1".map{$0}
private let OFF_STATES_EN :[Character] = "eczqtrfnmpgv]2".map{$0}
private let ON_STATES_FR :[Character] = "zdxqyhujikol".map{$0}
private let OFF_STATES_FR :[Character] = "ecwatrfn,pgv".map{$0}
private let ON_STATES_DE :[Character] = "wdxazhujikol".map{$0}
private let OFF_STATES_DE :[Character] = "ecyqtrfnmpgv".map{$0}

public final class iCadeReaderView : UIView {

	#if os(tvOS)
	private let _inputView = UIInputView(frame: CGRect.zero)
	#else
	private let _inputView = UIView(frame: CGRect.zero)
	#endif

	public var state : iCadeControllerState = iCadeControllerState()
	public weak var delegate : iCadeEventDelegate?
	public var active : Bool = false {

		willSet {
			if active == newValue && newValue {
				resignFirstResponder()
			}
		}

		didSet {
			if active {
				if UIApplication.shared.applicationState == .active {
					becomeFirstResponder()
				}
			} else {
				resignFirstResponder()
			}
		}
	}

	public internal(set) var onStates : [Character]
	public internal(set) var offStates : [Character]

	public override init(frame: CGRect) {

		let localeIdentifier = NSLocale.current.identifier
		if localeIdentifier.hasPrefix("de") {
			onStates = ON_STATES_DE
			offStates = OFF_STATES_DE
		} else if localeIdentifier.hasPrefix("fr") {
			onStates = ON_STATES_FR
			offStates = OFF_STATES_FR
		} else {
			onStates = ON_STATES_EN
			offStates = OFF_STATES_EN
		}

		super.init(frame: frame)

		NotificationCenter.default.addObserver(self, selector: #selector(self.willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(self.didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
	}

	@objc func willResignActive() {
		if active {
			resignFirstResponder()
		}
	}

	@objc func didBecomeActive() {
		if active {
			becomeFirstResponder()
		}
	}

	public override var canBecomeFirstResponder: Bool {
		return true
	}

	public override var inputView: UIView? {
		return _inputView
	}

	// MARK: - keys

	#if os(tvOS)
	public override var keyCommands: [UIKeyCommand]? {
		let allStates = onStates + offStates
		return allStates.map {
			return UIKeyCommand(input: String($0), modifierFlags: [], action: #selector(self.keyPressed(_:)))
		}
	}

	@objc func keyPressed(_ keyCommand: UIKeyCommand?) {

		print("Keypressed \(keyCommand?.input ?? "nil")")

		guard
			let keyCommand = keyCommand,
			let input = keyCommand.input else {
				print("No key input")
			return
		}

		handleIcadeInput(input)
	}
	#endif

	var cycleResponder: Int = 0
	func handleIcadeInput(_ input : String) {
		print("handleIcadeInput: \(input)")
		defer {
			cycleResponder += 1
			if cycleResponder > 20 {
				// necessary to clear a buffer that accumulates internally
				cycleResponder = 0
				resignFirstResponder()
				becomeFirstResponder()
			}
		}

		let ch = input.first!

		var stateChanged = false
		if onStates.contains(ch), let index = onStates.index(of: ch) {
			let button = iCadeControllerState(rawValue: 1 << index)
			if !state.contains(button) {
				state.formUnion(button)
				stateChanged = true
				print("New button down \(index)")
				delegate?.buttonDown(button: (1 << index))
			}
		}

		if offStates.contains(ch), let index = offStates.index(of: ch) {
			let button = iCadeControllerState(rawValue: 1 << index)
			if state.contains(button) {
				state.remove(button)
				stateChanged = true
				print("New button up \(index)")
				delegate?.buttonUp(button: (1 << index))
			}
		}

		if stateChanged {
			delegate?.stateChanged(state: state)
		}
	}
}

extension iCadeReaderView : UIKeyInput {
	// MARK: -
	// MARK: UIKeyInput Protocol Methods
	public var hasText: Bool {
		return false
	}

	public func insertText(_ text: String) {
		// does not to work on tvOS, use keyCommands + keyPressed instead
		#if os(iOS)
		handleIcadeInput(text)
		#endif
	}

	public func deleteBackward() {
		// This space intentionally left blank to complete protocol
	}
}
