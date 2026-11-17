//
//  PVThinLibretroCore+FDSDiskActions.swift
//  PVCoreBridgeRetro
//
//  Famicom Disk System disk handling for the libretro NES cores.
//
//  These cores have no menu of their own for the disk drive: they put the two
//  drive actions on RetroPad shoulder buttons, and the NES layout has none
//  (`PVNESButton` stops at Select and Start), so a player on touch controls or
//  a skin could never turn a disk over. The actions are offered in the pause
//  menu instead, and each one presses the button the core listens to.
//
//  Which button does what was read from each shipped dylib's input descriptors
//  (`CoresRetro/RetroArch/modules/*_libretro_ios.dylib`), not from upstream
//  source. FCEUmm and Nestopia agree; Mesen has the two the other way round and
//  a different second action:
//
//      FCEUmm    L "(FDS) Disk Side Change"   R "(FDS) Insert/Eject Disk"
//      Nestopia  L "(FDS) Disk Side Change"   R "(FDS) Eject Disk"
//      Mesen     L "(FDS) Insert Next Disk"   R "(FDS) Switch Disk Side"
//

import Foundation
import PVCoreBridge
import PVLogging
import PVSystems

// MARK: - Model

/// One disk drive action of a libretro NES core, and the RetroPad button it is on.
struct ThinFDSDiskAction: Equatable {
    let title: String
    let button: RetroJoypad

    static let switchSideTitle = "Switch Disk Side"
    static let insertOrEjectTitle = "Insert or Eject Disk"
    static let insertNextDiskTitle = "Insert Next Disk"

    /// The actions to offer for `system` running on the libretro core `coreIdentifier`
    /// (`fceumm.libretro.framework`, …). Empty for anything but an FDS game on a
    /// core whose buttons were read from its dylib.
    static func actions(system: SystemIdentifier?, coreIdentifier: String?) -> [ThinFDSDiskAction] {
        guard system == .FDS, let core = coreIdentifier?.lowercased() else { return [] }
        // "mesen-s" is the SNES core.
        if core.hasPrefix("mesen.") || core == "mesen" {
            return [ThinFDSDiskAction(title: switchSideTitle, button: .r),
                    ThinFDSDiskAction(title: insertNextDiskTitle, button: .l)]
        }
        if core.hasPrefix("fceumm") || core.hasPrefix("nestopia") {
            return [ThinFDSDiskAction(title: switchSideTitle, button: .l),
                    ThinFDSDiskAction(title: insertOrEjectTitle, button: .r)]
        }
        return []
    }
}

/// A button press that lasts a fixed number of emulated frames.
///
/// A pause-menu action is chosen while the core is paused, so the press cannot be
/// timed by the clock: it would be over before the core ran again. It is counted
/// in polls instead, one per frame, so the core sees the button held for
/// `heldFrames` frames whenever it resumes.
struct ThinButtonPulse: Equatable {
    /// Frames the button stays down. The cores act on the press edge; a handful of
    /// frames is clear of any core that samples input late in the frame.
    static let heldFrames = 6
    static let player = 0

    enum Step: Equatable {
        case press
        case hold
        case release
    }

    let button: RetroJoypad
    private(set) var framesLeft: Int
    private var isDown = false

    init(button: RetroJoypad, heldFrames: Int = ThinButtonPulse.heldFrames) {
        self.button = button
        self.framesLeft = max(1, heldFrames)
    }

    var isFinished: Bool { isDown && framesLeft == 0 }

    /// The step for the next frame: `press` once, `hold` while frames remain, then `release`.
    mutating func advance() -> Step {
        guard isDown else {
            isDown = true
            return .press
        }
        guard framesLeft > 0 else { return .release }
        framesLeft -= 1
        return framesLeft == 0 ? .release : .hold
    }
}

// MARK: - CoreActions

extension PVThinLibretroCore: CoreActions {

    /// `CoreAction` defaults to the destructive style; these change nothing that can be lost.
    #if canImport(UIKit) || canImport(WatchKit)
    private static let plainActionStyle: CoreActionAlertStyle = .default
    #else
    private static let plainActionStyle: CoreActionAlertStyle = .informational
    #endif

    private var fdsDiskActions: [ThinFDSDiskAction] {
        ThinFDSDiskAction.actions(system: SystemIdentifier(rawValue: systemIdentifier ?? ""),
                                  coreIdentifier: coreIdentifier)
    }

    public var coreActions: [CoreAction]? {
        let actions = fdsDiskActions
        guard !actions.isEmpty else { return nil }
        return actions.map { CoreAction(title: $0.title, style: Self.plainActionStyle) }
    }

    public func selected(action: CoreAction) {
        guard let diskAction = fdsDiskActions.first(where: { $0.title == action.title }) else {
            WLOG("ThinCore: unknown core action \(action.title)")
            return
        }
        ILOG("ThinCore FDS: \(diskAction.title) presses \(diskAction.button) for \(ThinButtonPulse.heldFrames) frames")
        queueButtonPulse(ThinButtonPulse(button: diskAction.button))
    }
}
