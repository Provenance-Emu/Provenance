//  OGLViewController.swift
//  Copyright © 2023 Provenance Emu. All rights reserved.

import Foundation
import GLKit
import os

@objc public class EmuThreeOGLViewController: GLKViewController {
	private var core: PVEmuThreeCore!
	@objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat, core: PVEmuThreeCore) {
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
	}
}
