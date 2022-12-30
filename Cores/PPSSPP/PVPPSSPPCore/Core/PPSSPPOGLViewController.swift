//
//  Provenance
//  Created by Joseph Mattiello on 9/12/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
import GLKit
import os

@objc public class PPSSPPOGLViewController: GLKViewController {
	private var core: PVPPSSPPCore!
	@objc public init(resFactor: Int8, videoWidth: CGFloat, videoHeight: CGFloat, core: PVPPSSPPCore) {
		super.init(nibName: nil, bundle: nil)
		self.core = core;
		self.view.isUserInteractionEnabled = false
		self.view.contentMode = .scaleToFill
		self.view.translatesAutoresizingMaskIntoConstraints = false
		self.view.contentScaleFactor = 1
		self.preferredFramesPerSecond = 120;
	}
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
	required init?(coder: NSCoder) {
		super.init(coder:coder);
	}
	@objc public override func viewDidLoad() {
		super.viewDidLoad()
		if core != nil {
			NSLog("Starting VM\n");
			core.startVM(self.view);
		}
	}

	@objc public override func glkView(_: GLKView, drawIn:CGRect) {
		if core != nil {
			core.executeFrame();
		}
	}

	@objc public override func viewDidLayoutSubviews() {
		if core != nil {
			NSLog("View Size Changed\n");
            core.refreshScreenSize();
        }
	}

}
