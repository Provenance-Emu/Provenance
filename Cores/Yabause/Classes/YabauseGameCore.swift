//
//  PVYabauseGameCore.swift
//  PVYabause
//
//  Created by Joseph Mattiello on 10/14/18.
//

import Foundation
import PVSupport
import OpenGLES
import Yabause
import PVYabause.Private

@objc
public enum YabauseError : Int, Error {
    case generic
}

@objc
@objcMembers
public class PVYabauseGameCore : PVEmulatorCore, PVSaturnSystemResponderClient {

    static public let USE_THREADS = 0

    // ToDo: Fix
    static public let SAMPLERATE = 44100
    static public let SAMPLEFRAME = SAMPLERATE / 60

    static public let HIRES_WIDTH = 356
    static public let HIRES_HEIGHT = 256

    static public let SNDCORE_OE: Int32 = 11

    public var firstRun = false

    public var width: Int = PVYabauseGameCore.HIRES_WIDTH
    public var height: Int = PVYabauseGameCore.HIRES_HEIGHT

    override public var pixelFormat: GLenum { return GLenum(GL_RGBA) }

    override public var internalPixelFormat: GLenum {
        return GLenum(GL_RGBA)
    }

    override public var pixelType: GLenum {
        return GLenum(GL_UNSIGNED_BYTE)
    }

    override public var audioSampleRate: Double {
        return Double(PVYabauseGameCore.SAMPLERATE)
    }

    override public var channelCount: AVAudioChannelCount {
        return 2
    }

    override public var bufferSize: CGSize {
        return CGSize(width: PVYabauseGameCore.HIRES_WIDTH, height: PVYabauseGameCore.HIRES_HEIGHT)
    }

    override public var aspectSize: CGSize {
        return CGSize(width: width, height: height)
    }

    override public var screenRect: CGRect {
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    public var videoLock = NSLock()

    public var paused = false
    public var filename : String?

    public var maxDiscs : UInt = 0

    override public func resetEmulation() {
        super.resetEmulation()
        firstRun = true
        YabauseResetButton()
    }

    override public func stopEmulation() {
        firstRun = true
        super.stopEmulation()
    }

    public func startYabauseEmulation() {
        YabauseInit(&yinit)
        YabauseSetDecilineMode(1)
        OSDChangeCore(OSDCORE_DUMMY)
    }

    public func saveStateToFile(atPath path: String) throws {
        var saveError: Int32 = 0
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            ScspMuteAudio(SCSP_MUTE_SYSTEM)
            path.withCString {
                saveError = YabSaveState($0)
            }
            ScspUnMuteAudio(SCSP_MUTE_SYSTEM)
        }

        //    NSDictionary *userInfo = @{
        //                               NSLocalizedDescriptionKey: @"Failed to save state.",
        //                               NSLocalizedFailureReasonErrorKey: @"Stella does not support save states.",
        //                               NSLocalizedRecoverySuggestionErrorKey: @"Check for future updates on ticket #753."
        //                               };
        //
        //    NSError *newError = [NSError errorWithDomain:EmulatorCoreErrorCodeDomain
        //                                            code:EmulatorCoreErrorCodeCouldNotSaveState
        //                                        userInfo:userInfo];
        //
        //    *error = newError;
        if saveError != 0 {
            throw YabauseError.generic
        }
    }

    public func loadStateFromFile(atPath path: String) throws {
        var loadError: Int32 = 0

        ScspMuteAudio(SCSP_MUTE_SYSTEM)
        path.withCString {
            loadError = YabLoadState($0)
        }
        ScspUnMuteAudio(SCSP_MUTE_SYSTEM)

        if loadError != 0 {
            throw YabauseError.generic
        }
    }

    override public var supportsSaveStates: Bool {
        return true
    }

    // MARK: -
    // MARK: Inputs
    public func didPush(_ button: PVSaturnButton, forPlayer player: Int) {
        let c = player == 0 ? c1 : c2
        switch button {
        case .up:
            PerPadUpPressed(c)
        case .down:
            PerPadDownPressed(c)
        case .left:
            PerPadLeftPressed(c)
        case .right:
            PerPadRightPressed(c)
        case .start:
            PerPadStartPressed(c)
        case .l:
            PerPadLTriggerPressed(c)
        case .r:
            PerPadRTriggerPressed(c)
        case .a:
            PerPadAPressed(c)
        case .b:
            PerPadBPressed(c)
        case .c:
            PerPadCPressed(c)
        case .x:
            PerPadXPressed(c)
        case .y:
            PerPadYPressed(c)
        case .z:
            PerPadZPressed(c)
        default:
            break
        }
    }

    public func didRelease(_ button: PVSaturnButton, forPlayer player: Int) {
        let c = player == 0 ? c1 : c2
        switch button {
        case .up:
            PerPadUpReleased(c)
        case .down:
            PerPadDownReleased(c)
        case .left:
            PerPadLeftReleased(c)
        case .right:
            PerPadRightReleased(c)
        case .start:
            PerPadStartReleased(c)
        case .l:
            PerPadLTriggerReleased(c)
        case .r:
            PerPadRTriggerReleased(c)
        case .a:
            PerPadAReleased(c)
        case .b:
            PerPadBReleased(c)
        case .c:
            PerPadCReleased(c)
        case .x:
            PerPadXReleased(c)
        case .y:
            PerPadYReleased(c)
        case .z:
            PerPadZReleased(c)
        default:
            break
        }
    }

    #if HAVE_LIBGL
    var rendersToOpenGL: Bool {
        return true
    }
    #endif

    public override func executeFrame() {
        if firstRun {
            DLOG("Yabause executeFrame firstRun, lazy init")
            initYabause(withCDCore: CDCORE_DUMMY)
            startYabauseEmulation()
            firstRun = false
        } else {
            videoLock.lock()
            ScspUnMuteAudio(SCSP_MUTE_SYSTEM)
            YabauseExec()
            ScspMuteAudio(SCSP_MUTE_SYSTEM)
            videoLock.unlock()
        }
    }

    func initYabause(withCDCore cdcore: Int32) {
        guard let filename = filename else {
            // TODO: Throw here
            return
        }
        let `extension` = URL(fileURLWithPath: filename).pathExtension
        let romExtensions = ["cue", "ccd", "mds", "iso"]
        if romExtensions.contains(`extension`), let biosPath = biosPath {
            yinit.cdcoretype = CDCORE_ISO
            filename.withCString {
                yinit.cdpath = $0
            }

            // Get a BIOS
            // sega_101.bin mpr-17933.bin saturn_bios.bin
            let bios = URL(fileURLWithPath: biosPath).appendingPathComponent("saturn_bios.bin").absoluteString

            ILOG("Loading ROM. Will try to setup Saturn BIOS at path: " + bios)

            // If a "Saturn EU.bin" BIOS exists, use it otherwise emulate BIOS
            if FileManager.default.fileExists(atPath: bios) {
                ILOG("BIOS found : " + bios)
                bios.withCString {
                    yinit.biospath = $0
                }
            } else {
                WLOG("No BIOS found")
                yinit.biospath = nil
            }
        } else {
            // Assume we've a BIOS file and we want to run it
            yinit.cdcoretype = CDCORE_DUMMY
            filename.withCString {
                yinit.biospath = $0
            }
        }

        yinit.percoretype = PERCORE_DEFAULT
        yinit.sh2coretype = SH2CORE_INTERPRETER

        #if HAVE_LIBGL
        yinit.vidcoretype = VIDCORE_OGL
        #else
        yinit.vidcoretype = VIDCORE_SOFT
        #endif

        yinit.sndcoretype = PVYabauseGameCore.SNDCORE_OE
        //    yinit.m68kcoretype = M68KCORE_MUSASHI;
        yinit.m68kcoretype = M68KCORE_C68K
        #if true
        yinit.carttype = CART_DRAM32MBIT //4MB RAM Expansion Cart
        #else
        yinit.carttype = CART_NONE
        #endif
        yinit.regionid = u8(REGION_AUTODETECT)
        yinit.buppath = nil
        yinit.mpegpath = nil
        yinit.videoformattype = VIDEOFORMATTYPE_NTSC
        yinit.frameskip = 1
        yinit.clocksync = 0
        yinit.basetime = 0
        #if USE_THREADS
        yinit.usethreads = 1
        yinit.numthreads = 2
        #else
        yinit.usethreads = 0
        #endif

        // Take care of the Battery Save file to make Save State happy
        let path = filename
        let extensionlessFilename = URL(fileURLWithPath: (path as NSString).lastPathComponent).deletingPathExtension().absoluteString

        if let batterySavesDirectory = batterySavesPath {
            try? FileManager.default.createDirectory(atPath: batterySavesDirectory, withIntermediateDirectories: true, attributes: nil)
            let filePath = URL(fileURLWithPath: batterySavesDirectory).appendingPathComponent(URL(fileURLWithPath: extensionlessFilename).appendingPathExtension("sav").absoluteString).absoluteString

            if !filePath.isEmpty {
                DLOG("BRAM: " + filePath)
                filePath.withCString {
                    yinit.buppath = $0
                }
            }
        }
    }

}

#if false
 extension PVYabauseGameCore: DiscSwappable {
    func setMedia(_ inserted: Bool, forDisc disc: UInt) {

    }

    public var numberOfDiscs: UInt {
        return self.numberOfDiscs
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        return numberOfDiscs > 1
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
#endif
