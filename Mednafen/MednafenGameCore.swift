//
//  MednafenGameCore.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/8/18.
//

import UIKit
import PVSupport
//import PVMednafen.Private

extension MednafenGameCore: DiscSwappable {
    public var numberOfDiscs: UInt {
        return maxDiscs
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        switch systemType {
        case .PSX:
            return numberOfDiscs > 1
        default:
            return false
        }
    }

    public func swapDisc(number: UInt) {
        setPauseEmulation(false)

        let index = number - 1
        setMedia(true, forDisc: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.setMedia(false, forDisc: index)
        }
    }
}

extension MednafenGameCore: CoreActions {
	public var coreActions : [CoreAction]? {
		switch systemType {
		case .virtualBoy:
			return [CoreAction(title: "Change Palette", options: nil)]
		default:
			return nil
		}
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
