//
//  ATR800GameCore.swift
//  PVAtari800
//
//  Created by Joseph Mattiello on 1/20/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import atari800
import OpenGLES
import PVSupport

//weak var _currentCore: ATR800GameCore?

//#import <PVSupport/OERingBuffer.h>
//#import <PVSupport/DebugUtils.h>

// ataria800 project includes
public var UI_is_active : Int = 0
var UI_alt_function: Int = -1
var UI_n_atari_files_dir: Int = 0
var UI_n_saved_files_dir: Int = 0
var UI_atari_files_dir: [[Int8]] = []
var UI_saved_files_dir: [[Int8]] = []

//public typealias ATR5200ControllerState = (up: Int, down: Int, `left`: Int, `right`: Int, fire: Int, fire2: Int, start: Int, pause: Int, reset: Int)
//private weak var currentCore: ATR800GameCore?
////void ATR800WriteSoundBuffer(uint8_t *buffer, unsigned int len);
//// Atari800 platform calls
//func UI_SelectCartType(k: Int) -> Int {
//    print("Cart size: \(k)")
//
//    if (currentCore?.systemIdentifier() == "com.provenance.atari8bit") {
//        // TODO: improve detection using MD5 lookup
//        switch k {
//            case 2:
//                return CARTRIDGE_STD_2
//            case 4:
//                return CARTRIDGE_STD_4
//            case 8:
//                return CARTRIDGE_STD_8
//            case 16:
//                return CARTRIDGE_STD_16
//            case 32:
//                return CARTRIDGE_XEGS_32
//            case 40:
//                return CARTRIDGE_BBSB_40
//            case 64:
//                return CARTRIDGE_XEGS_07_64
//            case 128:
//                return CARTRIDGE_XEGS_128
//            case 256:
//                return CARTRIDGE_XEGS_256
//            case 512:
//                return CARTRIDGE_XEGS_512
//            case 1024:
//                return CARTRIDGE_ATMAX_1024
//            default:
//                return CARTRIDGE_NONE
//        }
//    }
//
//    if (currentCore?.systemIdentifier() == "com.provenance.5200") {
//        let One_Chip_16KB = [
//            "a47fcb4eedab9418ea098bb431a407aa" /* A.E. (Proto) */,
//            "45f8841269313736489180c8ec3e9588" /* Activision Decathlon, The */,
//            "1913310b1e44ad7f3b90aeb16790a850" /* Beamrider */,
//            "f8973db8dc272c2e5eb7b8dbb5c0cc3b" /* BerZerk */,
//            "e0b47a17fa6cd9d6addc1961fca43414" /* Blaster */,
//            "8123393ae9635f6bc15ddc3380b04328" /* Blue Print */,
//            "3ff7707e25359c9bcb2326a5d8539852" /* Choplifter! */,
//            "7c27d225a13e178610babf331a0759c0" /* David Crane's Pitfall II - Lost Caverns */,
//            "2bb63d65efc8682bc4dfac0fd0a823be" /* Final Legacy (Proto) */,
//            "f8f0e0a6dc2ffee41b2a2dd736cba4cd" /* H.E.R.O. */,
//            "46264c86edf30666e28553bd08369b83" /* Last Starfighter, The (Proto) */,
//            "1cd67468d123219201702eadaffd0275" /* Meteorites */,
//            "84d88bcdeffee1ab880a5575c6aca45e" /* Millipede (Proto) */,
//            "d859bff796625e980db1840f15dec4b5" /* Miner 2049er Starring Bounty Bob */,
//            "296e5a3a9efd4f89531e9cf0259c903d" /* Moon Patrol */,
//            "099706cedd068aced7313ffa371d7ec3" /* Quest for Quintana Roo */,
//            "5dba5b478b7da9fd2c617e41fb5ccd31" /* Robotron 2084 */,
//            "802a11dfcba6229cc2f93f0f3aaeb3aa" /* Space Shuttle - A Journey Into Space */,
//            "7dab86351fe78c2f529010a1ac83a4cf" /* Super Pac-Man (Proto) */,
//            "496b6a002bc7d749c02014f7ec6c303c" /* Tempest (Proto) */,
//            "33053f432f9c4ad38b5d02d1b485b5bd" /* Track and Field (Proto) */,
//            "560b68b7f83077444a57ebe9f932905a" /* Wizard of Wor */,
//            "dc45af8b0996cb6a94188b0be3be2e17" // Zone Ranger
//        ]
//
//        _ = [
//            "bae7c1e5eb04e19ef8d0d0b5ce134332" /* Astro Chase */,
//            "78ccbcbb6b4d17b749ebb012e4878008" /* Atari PAM Diagnostics (v2.0) */,
//            "32a6d0de4f1728dee163eb2d4b3f49f1" /* Atari PAM Diagnostics (v2.3) */,
//            "8576867c2cfc965cf152be0468f684a7" /* Battlezone (Proto) */,
//            "a074a1ff0a16d1e034ee314b85fa41e9" /* Buck Rogers - Planet of Zoom */,
//            "261702e8d9acbf45d44bb61fd8fa3e17" /* Centipede */,
//            "5720423ebd7575941a1586466ba9beaf" /* Congo Bongo */,
//            "1a64edff521608f9f4fa9d7bdb355087" /* Countermeasure */,
//            "27d5f32b0d46d3d80773a2b505f95046" /* Defender */,
//            "3abd0c057474bad46e45f3d4e96eecee" /* Dig Dug */,
//            "14bd9a0423eafc3090333af916cfbce6" /* Frisky Tom (Proto) */,
//            "d8636222c993ca71ca0904c8d89c4411" /* Frogger II - Threeedeep! */,
//            "dacc0a82e8ee0c086971f9d9bac14127" /* Gyruss */,
//            "936db7c08e6b4b902c585a529cb15fc5" /* James Bond 007 */,
//            "25cfdef5bf9b126166d5394ae74a32e7" /* Joust */,
//            "bc748804f35728e98847da6cdaf241a7" /* Jr. Pac-Man (Proto) */,
//            "834067fdce5d09b86741e41e7e491d6c" /* Jungle Hunt */,
//            "796d2c22f8205fb0ce8f1ee67c8eb2ca" /* Kangaroo */,
//            "d0a1654625dbdf3c6b8480c1ed17137f" /* Looney Tunes Hotel (Proto) */,
//            "24348dd9287f54574ccc40ee40d24a86" /* Microgammon SB (Proto) */,
//            "69d472a79f404e49ad2278df3c8a266e" /* Miniature Golf (Proto) */,
//            "694897cc0d98fcf2f59eef788881f67d" /* Montezuma's Revenge featuring Panama Joe */,
//            "ef9a920ffdf592546499738ee911fc1e" /* Ms. Pac-Man */,
//            "f1a4d62d9ba965335fa13354a6264623" /* Pac-Man */,
//            "fd0cbea6ad18194be0538844e3d7fdc9" /* Pole Position */,
//            "dd4ae6add63452aafe7d4fa752cd78ca" /* Popeye */,
//            "9b7d9d874a93332582f34d1420e0f574" /* Qix */,
//            "a71bfb11676a4e4694af66e311721a1b" /* RealSports Basketball (82-11-05) (Proto) */,
//            "022c47b525b058796841134bb5c75a18" /* RealSports Football */,
//            "3074fad290298d56c67f82e8588c5a8b" /* RealSports Soccer */,
//            "7e683e571cbe7c77f76a1648f906b932" /* RealSports Tennis */,
//            "ddf7834a420f1eaae20a7a6255f80a99" /* Road Runner (Proto) */,
//            "6e24e3519458c5cb95a7fd7711131f8d" /* Space Dungeon */,
//            "993e3be7199ece5c3e03092e3b3c0d1d" /* Sport Goofy (Proto) */,
//            "e2d3a3e52bb4e3f7e489acd9974d68e2" /* Star Raiders */,
//            "c959b65be720a03b5479650a3af5a511" /* Star Trek - Strategic Operations Simulator */,
//            "00beaa8405c7fb90d86be5bb1b01ea66" /* Star Wars - The Arcade Game */,
//            "595703dc459cd51fed6e2a191c462969" /* Stargate (Proto) */,
//            "4f6c58c28c41f31e3a1515fe1e5d15af" // Xari Arena (Proto)
//        ]
//
//        // Set 5200 cart type to load based on size
//        switch k {
//            case 4:
//                return CARTRIDGE_5200_4
//            case 8:
//                return CARTRIDGE_5200_8
//            case 16:
//                // Determine if 16KB cart is one-chip (NS_16) or two-chip (EE_16)
//                if let md5 = currentCore?.romMD5?.lowercased(), One_Chip_16KB.contains(md5) {
//                    return CARTRIDGE_5200_NS_16
//                } else {
//                    return CARTRIDGE_5200_EE_16
//                }
//            case 32:
//                return CARTRIDGE_5200_32
//            case 40:
//                return CARTRIDGE_5200_40 // Bounty Bob Strikes Back
//            default:
//                return CARTRIDGE_NONE
//        }
//    }
//
//    return CARTRIDGE_NONE
//}
//
//func UI_Run() {
//}
//
//func PLATFORM_Initialise(argc: UnsafeMutablePointer<Int32>?, argv: UnsafeMutablePointer<Int8>?) -> Int {
//    var argvL = argv
//    Sound_Initialise(argc, &argvL)
//
//    if Sound_enabled > 0 {
//        /* Up to this point the Sound_enabled flag indicated that we _want_ to
//                 enable sound. From now on, the flag will indicate whether audio
//                 output is enabled and working. So, since the sound output was not
//                 yet initiated, we set the flag accordingly. */
//        Sound_enabled = 1
//        /* Don't worry, Sound_Setup() will set Sound_enabled back to TRUE if
//                 it opens audio output successfully. But Sound_Setup() relies on the
//                 flag being set if and only if audio output is active. */
//        if Sound_Setup() > 0 {
//            // Start sound if opening audio output was successful.
//            Sound_Continue()
//        }
//    }
//
//    //POKEYSND_stereo_enabled = TRUE;
//
//    return 1
//}
//
//func PLATFORM_Exit(run_monitor: Int) -> Int {
//    Sound_Exit()
//
//    return 0
//}
//
//func PLATFORM_PORT(num: Int) -> Int32 {
//    guard let currentCore = currentCore else { return 0 }
//    if num < 4 && num >= 0 {
//        let state: ATR5200ControllerState = currentCore.controllerState(forPlayer: num)
//        if state.up == 1 && state.left == 1 {
//            return INPUT_STICK_UL
//        } else if state.up == 1 && state.right == 1 {
//            return INPUT_STICK_UR
//        } else if state.up == 1 {
//            return INPUT_STICK_FORWARD
//        } else if state.down == 1 && state.left == 1 {
//            return INPUT_STICK_LL
//        } else if state.down == 1 && state.right == 1 {
//            return INPUT_STICK_LR
//        } else if state.down == 1 {
//            return INPUT_STICK_BACK
//        } else if state.left == 1 {
//            return INPUT_STICK_LEFT
//        } else if state.right == 1 {
//            return INPUT_STICK_RIGHT
//        }
//        return INPUT_STICK_CENTRE
//    }
//    return 0xff
//}
//
//func PLATFORM_TRIG(num: Int) -> Int {
//    guard let currentCore = currentCore else { return 0 }
//
//    let state: ATR5200ControllerState = currentCore.controllerState(forPlayer: num)
//
//    return state.fire > 0 ? 1 : 0
//}
//
//func PLATFORM_Keyboard() -> Int {
//    return 0
//}
//
//func PLATFORM_DisplayScreen() {
//}
//
//func PLATFORM_SoundSetup(setup: inout Sound_setup_t) -> Int {
//    var buffer_samples: Int
//
//    if setup.frag_frames == 0 {
//        // Set frag_frames automatically.
//        var val = setup.frag_frames = setup.freq ?? 0 / 50
//        var pow_val: UInt = 1
//        while val >>= 1 {
//            pow_val <<= 1
//        }
//        if pow_val < setup?.frag_frames ?? 0 {
//            pow_val <<= 1
//        }
//        setup.frag_frames = pow_val
//    }
//
//    setup.sample_size = 2
//
//    buffer_samples = setup.frag_frames * setup.channels
//    setup.frag_frames = buffer_samples / setup.channels ?? 0
//
//    return 1
//}
//
//func PLATFORM_SoundExit() {
//}
//
//func PLATFORM_SoundPause() {
//}
//
//func PLATFORM_SoundContinue() {
//}
//
//func PLATFORM_SoundLock() {
//}
//
//func PLATFORM_SoundUnlock() {
//}

@objc(ATR800GameCore)
@objcMembers
public class ATR800GameCore: PVEmulatorCore, PV5200SystemResponderClient, PVA8SystemResponderClient {

    public static weak var current: ATR800GameCore?

    public lazy var _videoBuffer: UnsafeRawPointer = {
        let vb = calloc(1, Int(Screen_WIDTH * Screen_HEIGHT * 4))!
        return UnsafeRawPointer(vb)
    }()
    public override var videoBuffer : UnsafeRawPointer {
        return _videoBuffer
    }

    @objc
    public var soundBuffer: UnsafeMutablePointer<UInt8> = calloc(1, 2048)!.assumingMemoryBound(to: UInt8.self)
    internal var controllerStates = [ATR5200ControllerState](repeating: ATR5200ControllerState(up: 0, down: 0, left: 0, right: 0, fire: 0, fire2: 0, start: 0, pause: 0, reset: 0), count: 4)

//    private func renderToBuffer() {
//        var i: Int
//        var j: Int
//        var source = Screen_atari
//        let destination = videoBuffer
//        for i in 0..<Screen_HEIGHT {
//            for j in 0..<Screen_WIDTH {
//                var r: UInt32
//                var g: UInt32
//                var b: UInt32
//                r = Colours_table[source] >> 16
//                g = Colours_table[source] >> 8
//                b = Colours_table[source]
//                destination = destination! + 1 = b
//                destination = destination! + 1 = g
//                destination = destination! + 1 = r
//                destination = destination! + 1 = 0xff
//                source = source! + 1
//            }
//            //        source += Screen_WIDTH - ATARI_VISIBLE_WIDTH;
//        }
//    }

    @objc public
    func controllerState(forPlayer playerNum: Int) -> ATR5200ControllerState {
        var state = ATR5200ControllerState(up: 0, down: 0, left: 0, right: 0, fire: 0, fire2: 0, start: 0, pause: 0, reset: 0)
        if playerNum < 4 {
            state = controllerStates[playerNum]
        }
        return state
    }

    @objc public
    override init() {
        super.init()
        ATR800GameCore.current = self
    }

    deinit {
        Atari800_Exit(0)
        free(&_videoBuffer)
        free(soundBuffer)
        if ATR800GameCore.current == self {
            ATR800GameCore.current = nil
        }
    }

// MARK: - Execution

    // TODO: Make me real
//    override public var systemIdentifier: String? { return "com.provenance.5200" }

    public var biosDirectoryPath: String? { return biosPath }

//    override public func loadFile(atPath path: String?) throws {
//        // Set the default palette (NTSC)
//        let palettePath = Bundle(for: type(of: self)).path(forResource: "Default", ofType: "act")!
//        strcpy(COLOURS_NTSC_external.filename, palettePath.utf8CString)
//        COLOURS_NTSC_external.loaded = 1
//
//        Atari800_tv_mode = Atari800_TV_NTSC
//
//        /* It is necessary because of the CARTRIDGE_ColdStart (there must not be the
//             registry-read value available at startup) */
//        CARTRIDGE_main.type = Int32(CARTRIDGE_NONE)
//
//        Colours_PreInitialise()
//
//        if (systemIdentifier() == "com.provenance.5200") {
//            // Set 5200.rom BIOS path
//            let biosDirectory = biosDirectoryPath()!
//            let biosPath = URL(fileURLWithPath: biosDirectory).appendingPathComponent("5200.rom").absoluteString
//
//            SYSROM_SetPath(biosPath.utf8CString, 1, SYSROM_5200)
//
//            // Setup machine type
//            Atari800_SetMachineType(Int32(Atari800_MACHINE_5200))
//            MEMORY_ram_size = 16
//        } else if (systemIdentifier() == "com.provenance.atari8bit") {
//            let biosPath = biosDirectoryPath()!
//
//            let basicFileName = URL(fileURLWithPath: biosPath).appendingPathComponent("ataribas.rom").absoluteString.utf8CString
//            let osbFileNam = URL(fileURLWithPath: biosPath).appendingPathComponent("atariosb.rom").absoluteString.utf8CString
//            let xlFileName = URL(fileURLWithPath: biosPath).appendingPathComponent("atarixl.rom").absoluteString.utf8CString
//
//            SYSROM_SetPath(basicFileName, 1, SYSROM_BASIC_C)
//            SYSROM_SetPath(osbFileName, 2, SYSROM_B_NTSC, SYSROM_800_CUSTOM)
//            SYSROM_SetPath(xlFileName, 1, SYSROM_BB01R2)
//
//            // Setup machine type as Atari 130XE
//            Atari800_SetMachineType(Int32(Atari800_MACHINE_XLXE))
//            MEMORY_ram_size = 128
//            Atari800_builtin_basic = 1
//            Atari800_keyboard_leds = 0
//            Atari800_f_keys = 0
//            Atari800_jumper = 0
//            Atari800_builtin_game = 0
//            Atari800_keyboard_detached = 0
//
//            // Disable on-screen disk activity indicator
//            Screen_show_disk_led = 0
//        }
//
//        var arg: Int = 4
//        let argc: Int = arg
//        let argv = ["", "-sound", "-audio8", "-dsprate 44100"]
//
//        guard Colours_Initialise(argc, argv) else {
//            print("Failed to initialize part of atari800")
//            throw EmulatorCoreErrorCode.couldNotLoadRom
//        }
//
//        guard Atari800_InitialiseMachine() else {
//            print("** Failed to initialize machine")
//            throw EmulatorCoreErrorCode.couldNotLoadRom
//        }
//
//        // Open and try to automatically detect file type, not 100% accurate
//        if !AFILE_OpenFile(path?.utf8CString, 1, 1, false) {
//            print("Failed to open file")
//            let userInfo = [
//                NSLocalizedDescriptionKey: "Failed to load game.",
//                NSLocalizedFailureReasonErrorKey: "atari800 failed to load ROM.",
//                NSLocalizedRecoverySuggestionErrorKey: "Check that file isn't corrupt and in format atari800 supports."
//            ]
//
//            let newError = NSError(domain: EmulatorCoreErrorCodeDomain, code: Int(EmulatorCoreErrorCode.couldNotLoadRom), userInfo: userInfo)
//            throw newError
//        }
//
//        // TODO - still need this?
//        // Install requested ROM cartridge
//        if CARTRIDGE_main.type == CARTRIDGE_UNKNOWN {
//            CARTRIDGE_SetType(&CARTRIDGE_main, UI_SelectCartType(CARTRIDGE_main.size))
//        }
//
//        //POKEYSND_Init(POKEYSND_FREQ_17_EXACT, 44100, 1, POKEYSND_BIT16);
//
//        return
//    }

//    public override func executeFrame() {
//        if controller1 != nil || controller2 != nil {
//            pollControllers()
//        }
//
//        Atari800_Frame()
//
//        let size = UInt32(44100 / (Atari800_tv_mode == Atari800_TV_NTSC ? 59.9 : 50) * 2)
//
//        Sound_Callback(soundBuffer, size)
//
//        //NSLog(@"Sound_desired.channels %d frag_frames %d freq %d sample_size %d", Sound_desired.channels, Sound_desired.frag_frames, Sound_desired.freq, Sound_desired.sample_size);
//        //NSLog(@"Sound_out.channels %d frag_frames %d freq %d sample_size %d", Sound_out.channels, Sound_out.frag_frames, Sound_out.freq, Sound_out.sample_size);
//
//        ringBuffer(at: 0).write(&soundBuffer, maxLength: UInt(size))
//
//        renderToBuffer()
//    }

    override public func resetEmulation() {
        Atari800_Warmstart()
    }

    override public func stopEmulation() {
        Atari800_Exit(0)
        super.stopEmulation()
    }

    override public var frameInterval: TimeInterval {
        return Atari800_tv_mode == Atari800_TV_NTSC ? Atari800_FPS_NTSC : Atari800_FPS_PAL
    }

// MARK: - Video
    public override var bufferSize: CGSize {
        return CGSize(width: CGFloat(Screen_WIDTH), height: CGFloat(Screen_HEIGHT))
    }

    public override var screenRect: CGRect {
        return CGRect(x: 24, y: 0, width: 336, height: 240)
        //    return CGRectMake(24, 0, Screen_WIDTH, Screen_HEIGHT);
    }

    public override var aspectSize: CGSize {
        // TODO: fix PAR
        //return CGSizeMake(336 * (6.0 / 7.0), 240);
        return bufferSize
    }

    public override var pixelFormat: GLenum {
        return GLenum(GL_BGRA)
    }

    public override var pixelType: GLenum {
        return GLenum(GL_UNSIGNED_BYTE)
    }

    public override var internalPixelFormat: GLenum {
        return GLenum(GL_RGBA)
    }

// MARK: - Audio
    public override var audioSampleRate: Double {
        return 44100
    }

    public override var channelCount: AVAudioChannelCount {
        return 1
    }

// MARK: - Save States
//    func saveStateToFile(atPath fileName: String) throws {
//        assert(false, "Shouldn't be here since we overload the async version")
//    }
//
//    func saveStateToFile(atPath fileName: String, completionHandler block: @escaping (Error?) -> Void) {
//        var cStr = fileName.cString(using: .utf8)!
//        withUnsafePointer(to: &cStr) {
//            let cs = UnsafePointer<Int8>($0)
//            let success = StateSav_SaveAtariState($0, "wb", true)
//            if !success {
//                block(EmulatorCoreErrorCode.couldNotSaveState)
//            } else {
//                block(nil)
//            }
//        }
//    }
//
//    func loadStateFromFile(atPath fileName: String?) throws {
//        assert(false, "Shouldn't be here since we overload the async version")
//    }
//
//    func loadStateFromFile(atPath fileName: String, completionHandler block: @escaping (Bool, Error?) -> Void) {
//        let success = StateSav_ReadAtariState(fileName.utf8CString, "rb")
//        if !success {
//            let userInfo = [
//                NSLocalizedDescriptionKey: "Failed to save state.",
//                NSLocalizedFailureReasonErrorKey: "Core failed to load save state.",
//                NSLocalizedRecoverySuggestionErrorKey: ""
//            ]
//
//            let newError = NSError(domain: EmulatorCoreErrorCodeDomain, code: Int(EmulatorCoreErrorCodeCouldNotLoadSaveState), userInfo: userInfo)
//
//            block(false, newError)
//        } else {
//            block(true, nil)
//        }
//    }

// MARK: - Input
    public func mouseMoved(at point: CGPoint) {
    }

    public func leftMouseDown(at point: CGPoint) {
    }

    public func leftMouseUp() {
    }

    public func rightMouseDown(at point: CGPoint) {
    }

    public func rightMouseUp() {
    }

    //- (void)keyDown:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
    //{

    //}

    //- (void)keyUp:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
    //{

    //}

    public func didPush(_ button: PVA8Button, forPlayer player: Int) {
        let index = player - 1

        switch button {
            case .fire:
                controllerStates[index].fire = 1
            case .up:
                controllerStates[index].up = 1
                //INPUT_key_code = AKEY_UP ^ AKEY_CTRL;
                //INPUT_key_code = INPUT_STICK_FORWARD;
            case .down:
                controllerStates[index].down = 1
            case .left:
                controllerStates[index].left = 1
            case .right:
                controllerStates[index].right = 1
            default:
                break
        }
    }

    public func didRelease(_ button: PVA8Button, forPlayer player: Int) {
        let index = player - 1

        switch button {
            case .fire:
                controllerStates[index].fire = 0
            case .up:
                controllerStates[index].up = 0
                //INPUT_key_code = AKEY_UP ^ AKEY_CTRL;
                //INPUT_key_code = INPUT_STICK_FORWARD;
            case .down:
                controllerStates[index].down = 0
            case .left:
                controllerStates[index].left = 0
            case .right:
                controllerStates[index].right = 0
            default:
                break
        }
    }

    public func didPush(_ button: PV5200Button, forPlayer player: Int) {
        switch button {
            case .fire1:
                controllerStates[player].fire = 1
            case .fire2:
                INPUT_key_shift = 1 //AKEY_SHFTCTRL
            case .up:
                controllerStates[player].up = 1
                //INPUT_key_code = AKEY_UP ^ AKEY_CTRL;
                //INPUT_key_code = INPUT_STICK_FORWARD;
            case .down:
                controllerStates[player].down = 1
            case .left:
                controllerStates[player].left = 1
            case .right:
                controllerStates[player].right = 1
            case .start:
                //            controllerStates[player].start = 1;
                INPUT_key_code = AKEY_5200_START
            case .pause:
                //            controllerStates[player].pause = 1;
                INPUT_key_code = AKEY_5200_PAUSE
            case .reset:
                //            controllerStates[player].reset = 1;
                INPUT_key_code = AKEY_5200_RESET
            case .number1:
                INPUT_key_code = AKEY_5200_1
            case .number2:
                INPUT_key_code = AKEY_5200_2
            case .number3:
                INPUT_key_code = AKEY_5200_3
            case .number4:
                INPUT_key_code = AKEY_5200_4
            case .number5:
                INPUT_key_code = AKEY_5200_5
            case .number6:
                INPUT_key_code = AKEY_5200_6
            case .number7:
                INPUT_key_code = AKEY_5200_7
            case .number8:
                INPUT_key_code = AKEY_5200_8
            case .number9:
                INPUT_key_code = AKEY_5200_9
            case .number0:
                INPUT_key_code = AKEY_5200_0
            case .asterisk:
                INPUT_key_code = AKEY_5200_ASTERISK
            case .pound:
                INPUT_key_code = AKEY_5200_HASH
            default:
                break
        }
    }

    public func didRelease(_ button: PV5200Button, forPlayer player: Int) {
        switch button {
            case .fire1:
                controllerStates[player].fire = 0
            case .fire2:
                INPUT_key_shift = 0
            case .up:
                controllerStates[player].up = 0
                //INPUT_key_code = 0xff;
            case .down:
                controllerStates[player].down = 0
            case .left:
                controllerStates[player].left = 0
            case .right:
                controllerStates[player].right = 0
            case .start:
                INPUT_key_code = AKEY_NONE
            case .pause:
                INPUT_key_code = AKEY_NONE
            case .reset:
                INPUT_key_code = AKEY_NONE
            case .number1:
                INPUT_key_code = AKEY_NONE
            case .number2:
                INPUT_key_code = AKEY_NONE
            case .number3:
                INPUT_key_code = AKEY_NONE
            case .number4:
                INPUT_key_code = AKEY_NONE
            case .number5:
                INPUT_key_code = AKEY_NONE
            case .number6:
                INPUT_key_code = AKEY_NONE
            case .number7:
                INPUT_key_code = AKEY_NONE
            case .number8:
                INPUT_key_code = AKEY_NONE
            case .number9:
                INPUT_key_code = AKEY_NONE
            case .number0:
                INPUT_key_code = AKEY_NONE
            case .asterisk:
                INPUT_key_code = AKEY_NONE
            case .pound:
                INPUT_key_code = AKEY_NONE
            default:
                break
        }
    }

    func pollControllers() {
        for playerIndex in 0..<2 {
            var controllerMaybe: GCController?

            if let controller1 = controller1, playerIndex == 0 {
                controllerMaybe = controller1
            } else if let controller2 = controller2, playerIndex == 1 {
                controllerMaybe = controller2
            }

            guard let controller = controllerMaybe else { continue }

            if let gamepad = controller.extendedGamepad {
                let dpad: GCControllerDirectionPad = gamepad.dpad

                // D-Pad
                controllerStates[playerIndex].up = dpad.up.isPressed ? 1 : 0
                controllerStates[playerIndex].down = dpad.down.isPressed ? 1 : 0
                controllerStates[playerIndex].left = dpad.left.isPressed ? 1 : 0
                controllerStates[playerIndex].right = dpad.right.isPressed ? 1 : 0

                // Fire 1
                controllerStates[playerIndex].fire = (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed || gamepad.leftTrigger.isPressed) ? 1 : 0
                // Fire 2
                INPUT_key_shift = (gamepad.buttonB.isPressed || gamepad.buttonX.isPressed || gamepad.rightTrigger.isPressed) ? 1 : 0

                // The following buttons are on a shared bus. Only one at a time.
                // If none, state is reset. Since only one button can be registered
                // at a time, there has to be an preference of order.

                // Start
                if gamepad.rightShoulder.isPressed {
                    INPUT_key_code = AKEY_5200_START
                } else if gamepad.leftShoulder.isPressed {
                    INPUT_key_code = AKEY_5200_RESET
                } else {
                    INPUT_key_code = AKEY_NONE
                }
            } else if let gamepad = controller.gamepad {
                let dpad: GCControllerDirectionPad = gamepad.dpad

                // D-Pad
                controllerStates[playerIndex].up = dpad.up.isPressed ? 1 : 0
                controllerStates[playerIndex].down = dpad.down.isPressed ? 1 : 0
                controllerStates[playerIndex].left = dpad.left.isPressed ? 1 : 0
                controllerStates[playerIndex].right = dpad.right.isPressed ? 1 : 0

                // Fire 1
                controllerStates[playerIndex].fire = (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed) ? 1 : 0

                // Fire 2
                INPUT_key_shift = (gamepad.buttonB.isPressed || gamepad.buttonX.isPressed) ? 1 : 0

                // The following buttons are on a shared bus. Only one at a time.
                // If none, state is reset. Since only one button can be registered
                // at a time, there has to be an preference of order.

                // Start
                if gamepad.rightShoulder.isPressed {
                    INPUT_key_code = AKEY_5200_START
                } else if gamepad.leftShoulder.isPressed {
                    INPUT_key_code = AKEY_5200_RESET
                } else {
                    INPUT_key_code = AKEY_NONE
                }
            } else if let gamepad = controller.microGamepad {
                #if os(tvOS)
                let dpad: GCControllerDirectionPad = gamepad.dpad

                // DPAD
                controllerStates[playerIndex].up = dpad.up.value > 0.5 ? 1 : 0
                controllerStates[playerIndex].down = dpad.down.value > 0.5  ? 1 : 0
                controllerStates[playerIndex].left = dpad.left.value > 0.5  ? 1 : 0
                controllerStates[playerIndex].right = dpad.right.value > 0.5  ? 1 : 0

                //Fire
                controllerStates[playerIndex].fire = gamepad.buttonA.isPressed ? 1 : 0

                // Start
                INPUT_key_code = gamepad?.buttonX.isPressed ? AKEY_5200_START : AKEY_NONE
                #endif
            }
        }
    }

// MARK: - Misc Helper Methods
    //int16_t convertSample(uint8_t sample)
    //{
    //    float floatSample = (float)sample / 255;
    //    return (int16_t)(floatSample * 65535 - 32768);
    //}
    //
    //void ATR800WriteSoundBuffer(uint8_t *buffer, unsigned int len) {
    //    int samples = len / sizeof(uint8_t);
    //    NSUInteger newLength = len * sizeof(int16_t);
    //    int16_t *newBuffer = malloc(len * sizeof(int16_t));
    //    int16_t *dest = newBuffer;
    //    uint8_t *source = buffer;
    //    for(int i = 0; i < samples; i++) {
    //        *dest = convertSample(*source);
    //        dest++;
    //        source++;
    //    }
    //    [[_currentCore ringBufferAtIndex:0] write:newBuffer maxLength:newLength];
    //    free(newBuffer);
    //}

}
