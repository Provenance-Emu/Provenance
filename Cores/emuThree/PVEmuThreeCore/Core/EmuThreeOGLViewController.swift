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
        NotificationCenter.default.addObserver(forName: .init("openKeyboard"), object: nil, queue: .main) { notification in
            guard let config = notification.object as? KeyboardConfig else {
                return
            }
            
            let alertController = TVAlertController(title: nil, message: nil, preferredStyle: .alert)
            alertController.preferredContentSize = CGSize(width: 500, height: 300)

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
            
            switch config.buttonConfig {
            case .single:
                alertController.addAction(okayButton)
            case .dual:
                alertController.addAction(cancelAction)
                alertController.addAction(okayButton)
            case .triple:
                break
            case .none:
                break
            @unknown default:
                break
            }
            
            
            alertController.addTextField()
            self.present(alertController, animated: true)
        }
	}
}
