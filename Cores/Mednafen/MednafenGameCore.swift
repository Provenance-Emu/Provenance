//
//  MednafenGameCore.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/8/18.
//

import PVSupport
//import PVMednafenPrivate
import PVMednafen.Private

@objc
public
enum MednaSystem : Int {
    case GB
    case GBA
    case GG
    case lynx
    case MD
    case NES
    case neoGeo
    case PCE
    case PCFX
    case SMS
    case SNES
    case PSX
    case virtualBoy
    case wonderSwan
    case unknown
}

@objc
@objcMembers
public
class MednafenGameCore: PVEmulatorCore {
    @objc public var isStartPressed = false
    @objc public var isSelectPressed = false
    @objc public var isAnalogModePressed = false
    @objc public var systemType: MednaSystem = .unknown
    @objc public var maxDiscs: UInt = 0

//    private func setMedia(_ `open`: Bool, forDisc disc: Int)
//    private func changeDisplayMode()
}

// for Swift
@objc
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
            changeDisplayMode()
		default:
			print("Unknown action: "+action.title)
		}
	}
}
