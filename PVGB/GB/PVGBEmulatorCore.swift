//
//  PVGBEmulatorCore.swift
//  PVGB
//
//  Created by Joseph Mattiello on 6/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVSupport

extension PVGBEmulatorCore: CoreActions {
	public var coreActions : [CoreAction]? {
		return [CoreAction(title: "Change Palette", options: nil)]
	}

	public func selected(action : CoreAction) {
		switch action.title {
		case "Change Palette":
			self.changeDisplayMode()
		default:
			print("Unknown action: "+action.title)
		}
	}
}
