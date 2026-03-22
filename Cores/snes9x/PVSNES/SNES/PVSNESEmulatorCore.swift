//
//  PVSNESEmulatorCore.swift
//  PVSNES
//

import PVSupport
import Foundation
import PVEmulatorCore

import Foundation
import PVCoreBridge
#if canImport(GameController)
import GameController
#endif
#if canImport(OpenGLES)
import OpenGLES
import OpenGLES.ES3
#endif
import PVLogging
import PVAudio
import PVEmulatorCore
import PVCoreObjCBridge

@objc
@objcMembers
open class PVSNES9xEmulatorCore: PVEmulatorCore, @unchecked Sendable {

    // MARK: Video

    // MARK: Lifecycle

    public required init() {
        super.init()
        self.bridge = (PVSNESEmulatorCoreBridge() as! any ObjCBridgedCoreBridge)
    }

    // MARK: - RetroAchievements backing storage

    /// Weak reference to the OSD delegate (stored here because Swift extensions
    /// cannot add stored properties).
    weak var _achievementsDelegate: (any RetroAchievementsOSDDelegate)?

    /// Hardcore mode flag.
    var _hardcoreMode: Bool = false
}

extension PVSNES9xEmulatorCore: PVSNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (bridge as! PVSNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVSNESButton, forPlayer player: Int) {
        (bridge as! PVSNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVSNES9xEmulatorCore: ArchiveSupport {
    public var supportedArchiveFormats: ArchiveSupportOptions {
        return [.gzip, .zip]
    }
}


// MARK: - MouseResponder

extension PVSNES9xEmulatorCore: MouseResponder {

    public var gameSupportsMouse: Bool {
        return (bridge as! PVSNESEmulatorCoreBridge).isSNESMouseGame
    }

    public var requiresMouse: Bool { false }

#if canImport(GameController)
    @available(iOS 14.0, tvOS 14.0, *)
    public func didScroll(_ cursor: GCDeviceCursor) {}

    public var mouseMovedHandler: GCMouseMoved? { nil }
#endif

    public func mouseMoved(atPoint point: CGPoint) {
        let snesBridge = bridge as! PVSNESEmulatorCoreBridge
#if os(tvOS)
        // On tvOS the Siri Remote pan handler delivers per-event *relative* deltas in
        // view-point units — not normalised [0,1] absolute positions.  Pass them through
        // the dedicated delta path so we don't double-differentiate or misscale.
        snesBridge.snesMouseMoved(byDelta: point)
#else
        snesBridge.snesMouseMoved(to: point)
#endif
    }

    public func leftMouseDown(atPoint point: CGPoint) {
        (bridge as! PVSNESEmulatorCoreBridge).snesLeftMouseDown()
    }

    public func leftMouseUp() {
        (bridge as! PVSNESEmulatorCoreBridge).snesLeftMouseUp()
    }

    public func rightMouseDown(atPoint point: CGPoint) {
        (bridge as! PVSNESEmulatorCoreBridge).snesRightMouseDown()
    }

    public func rightMouseUp() {
        (bridge as! PVSNESEmulatorCoreBridge).snesRightMouseUp()
    }
}

extension PVSNESEmulatorCoreBridge: GameWithCheat {
    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            try self.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
            return true
        } catch let error {
            NSLog("Error setCheat \(error)")
            return false
        }
    }

    public var cheatCodeTypes: [String] {
        return ["Game Genie", "Pro Action Replay", "Gold Finger", "Raw Code"]
    }

    public var supportsCheatCode: Bool
    {
        return true
    }
}
