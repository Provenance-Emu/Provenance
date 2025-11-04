//  OGLViewController.swift
//  Copyright © 2023 Provenance Emu. All rights reserved.

import Foundation
import GLKit
import os

@objc public class EmuThreeOGLViewController: GLKViewController {
	private var core: PVEmuThreeCoreBridge!
	@objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat, core: PVEmuThreeCoreBridge) {
		super.init(nibName: nil, bundle: nil)
		self.core = core;
		self.view.isUserInteractionEnabled = false
		self.view.contentMode = .scaleToFill
		self.view.translatesAutoresizingMaskIntoConstraints = false
		self.view.contentScaleFactor = 1
	}
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
	required init?(coder: NSCoder) {
		super.init(coder:coder);
	}
	@objc public override func viewDidLoad() {
		super.viewDidLoad()
		NSLog("Starting VM\n");
        core.startVM(self.view);

        // Keyboard
        NotificationCenter.default.addObserver(forName: .init("openKeyboard"), object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let config = notification.object as? KeyboardConfig else {
                return
            }

            /// Check if already presenting something to prevent crashes
            if self.presentedViewController != nil {
                /// Dismiss existing presentation or wait
                self.presentedViewController?.dismiss(animated: false) {
                    self.showKeyboard(with: config)
                }
                return
            }

            self.showKeyboard(with: config)
        }
    }

    private func showKeyboard(with config: KeyboardConfig) {
        let alertController = TVAlertController(title: config.hintText, message: nil, preferredStyle: .alert)
        alertController.preferredContentSize = CGSize(width: 500, height: 300)

        /// Configure button text from config if available
        let okayTitle = config.buttonText?.first ?? "OK"
        let cancelTitle = config.buttonText?.count ?? 0 > 1 ? config.buttonText?[1] : "Cancel"

        let cancelAction: UIAlertAction = .init(title: cancelTitle, style: .cancel) { _ in
            NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                "buttonPressed" : 1,
                "keyboardText" : ""
            ])
        }

        let okayButton: UIAlertAction = .init(title: okayTitle, style: .default) { _ in
            guard let textFields = alertController.textFields, let textField = textFields.first else {
                NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                    "buttonPressed" : 0,
                    "keyboardText" : ""
                ])
                return
            }

            let text = textField.text ?? ""

            /// Validate input based on accept mode
            var isValid = true
            switch config.acceptMode {
            case .notEmpty:
                isValid = !text.isEmpty
            case .notEmptyAndNotBlank:
                isValid = !text.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            case .notBlank:
                isValid = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            case .fixedLength:
                isValid = text.count == config.maxTextLength
            default:
                isValid = true
            }

            if !isValid {
                /// Show error and keep keyboard open
                let errorAlert = UIAlertController(title: "Invalid Input", message: "Please check your input.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(errorAlert, animated: true)
                return
            }

            NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                "buttonPressed" : 0,
                "keyboardText" : text
            ])
        }

        alertController.addTextField { [weak self] textField in
            textField.placeholder = config.hintText
            textField.text = ""

            /// Configure keyboard type and constraints
            if config.preventDigit {
                textField.keyboardType = .default
            } else if config.maxDigits > 0 {
                textField.keyboardType = .numberPad
            } else {
                textField.keyboardType = .default
            }

            if config.multilineMode {
                textField.contentVerticalAlignment = .top
            }

            /// Set max length if specified
            if config.maxTextLength > 0 {
                let maxLength = config.maxTextLength
                textField.addTarget(self, action: #selector(self?.textFieldDidChange(_:)), for: .editingChanged)
                textField.tag = Int(maxLength)
            }

            /// Make text field first responder to show keyboard immediately
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
        }

        switch config.buttonConfig {
        case .single:
            alertController.addAction(okayButton)
            alertController.preferredAction = okayButton
        case .dual:
            alertController.addAction(cancelAction)
            alertController.addAction(okayButton)
            alertController.preferredAction = okayButton
        case .triple:
            let forgotTitle = config.buttonText?.count ?? 0 > 2 ? config.buttonText?[2] : "I Forgot"
            let forgotAction = UIAlertAction(title: forgotTitle, style: .default) { _ in
                NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                    "buttonPressed" : 2,
                    "keyboardText" : ""
                ])
            }
            alertController.addAction(cancelAction)
            alertController.addAction(forgotAction)
            alertController.addAction(okayButton)
            alertController.preferredAction = okayButton
        case .none:
            break
        @unknown default:
            break
        }

        self.present(alertController, animated: true)
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        /// Enforce max length using tag value
        let maxLength = textField.tag
        if maxLength > 0,
           let text = textField.text,
           text.count > maxLength {
            textField.text = String(text.prefix(maxLength))
        }
	}
}
