import Foundation
extension PVRetroArchCore: CoreOptional {
    static var gsOption: CoreOption = {
         .enumeration(.init(title: "Graphics Handler",
               description: "(Requires Restart)",
               requiresRestart: true),
          values: [
               .init(title: "Metal", description: "Metal", value: 0),
               .init(title: "OpenGL", description: "OpenGL", value: 1),
               .init(title: "Vulkan", description: "Vulkan", value: 2)
          ],
          defaultValue: 0)
    }()
    static var retroArchControllerOption: CoreOption = {
        .bool(.init(
            title: USE_RETROARCH_CONTROLLER,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }()
    static var secondScreenOption: CoreOption = {
        .bool(.init(
            title: USE_SECOND_SCREEN,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }()
    static var mupenRDPOption: CoreOption = {
          .enumeration(.init(title: "Mupen RDP Plugin",
               description: "(Requires Restart)",
               requiresRestart: true),
          values: [
               .init(title: "Angrylion", description: "Angrylion", value: 0),
               .init(title: "GlideN64", description: "GlideN64", value: 1)
          ],
          defaultValue: 1)
    }()
    static var apple2MachineOption: CoreOption = {
          .enumeration(.init(title: "System Model",
               description: "(Requires Restart)",
               requiresRestart: true),
          values: [
               .init(title: "Apple II", description: "Apple II", value: 210),
               .init(title: "Apple IIp", description: "Apple IIp", value: 211),
               .init(title: "Apple IIe", description: "Apple IIe", value: 212),
               .init(title: "Apple IIe enhanced", description: "Apple IIe enhanced", value: 213),
               .init(title: "Apple IIc", description: "Apple IIc", value: 220),
               .init(title: "Apple IIgs", description: "Apple IIgs", value: 221),
               .init(title: "Apple III", description: "Apple III", value: 222),
          ],
          defaultValue: 212)
    }()
    static var volumeOption: CoreOption = {
        .enumeration(.init(title: "Audio Volume",
                           description: "",
                           requiresRestart: false),
                     values: [
                        .init(title: "100%", description: "100%", value: 100),
                        .init(title: "90%", description: "90%", value: 90),
                        .init(title: "80%", description: "80%", value: 80),
                        .init(title: "70%", description: "70%", value: 70),
                        .init(title: "60%", description: "60%", value: 60),
                        .init(title: "50%", description: "50%", value: 50),
                        .init(title: "40%", description: "40%", value: 40),
                        .init(title: "30%", description: "30%", value: 30),
                        .init(title: "20%", description: "20%", value: 20),
                        .init(title: "10%", description: "10%", value: 10),
                        .init(title: "0%", description: "0%", value: 0),
                     ],
                     defaultValue: 80)
    }()
    static var ffOption: CoreOption = {
        .enumeration(.init(title: "Fast Forward Speed",
                           description: "",
                           requiresRestart: false),
                     values: [
                        .init(title: "125%", description: "125%", value: 125),
                        .init(title: "150%", description: "150%", value: 150),
                        .init(title: "175%", description: "175%", value: 175),
                        .init(title: "200%", description: "200%", value: 200),
                        .init(title: "225%", description: "225%", value: 225),
                        .init(title: "250%", description: "250%", value: 250),
                        .init(title: "275%", description: "275%", value: 275),
                        .init(title: "300%", description: "300%", value: 300),
                        .init(title: "500%", description: "500%", value: 500),
                        .init(title: "1000%", description: "1000%", value: 1000),
                        .init(title: "Unlimited", description: "Unlimited", value: 0),
                     ],
                     defaultValue: 125)
    }()
    static var smOption: CoreOption = {
        .enumeration(.init(title: "Slow Motion Speed",
                           description: "",
                           requiresRestart: false),
                     values: [
                        .init(title: "125%", description: "125%", value: 125),
                        .init(title: "150%", description: "150%", value: 150),
                        .init(title: "175%", description: "175%", value: 175),
                        .init(title: "200%", description: "200%", value: 200),
                        .init(title: "225%", description: "225%", value: 225),
                        .init(title: "250%", description: "250%", value: 250),
                        .init(title: "275%", description: "275%", value: 275),
                        .init(title: "300%", description: "300%", value: 300),
                        .init(title: "500%", description: "500%", value: 500),
                     ],
                     defaultValue: 125)
    }()
    static var analogKeyControllerOption: CoreOption = {
        .bool(.init(
            title: ENABLE_ANALOG_KEY,
            description: nil,
            requiresRestart: false),
              defaultValue: true)}()
    static var analogDpadControllerOption: CoreOption = {
        .bool(.init(
            title: ENABLE_ANALOG_DPAD,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }()
    static var numKeyControllerOption: CoreOption = {
        .bool(.init(
            title: ENABLE_NUM_KEY,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }()
    static var mameOSDOption: CoreOption = {
        .bool(.init(
            title: "Launch into OSD",
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }()

    public static var options: [CoreOption] {
        var options = [CoreOption]()
        var coreOptions: [CoreOption] = [gsOption]
        var isDOS=false
        coreOptions.append(retroArchControllerOption)
        if (self.coreClassName.contains("mupen")) {
            coreOptions.append(mupenRDPOption)
        }
        if (self.coreClassName.contains("mame_libretro")) {
            coreOptions.append(mameOSDOption)
        }
        if (self.systemName.contains("psx") ||
            self.systemName.contains("snes") ||
            self.systemName.contains("nes") ||
            self.systemName.contains("saturn") ||
            self.systemName.contains("dreamcast") ||
            self.systemName.contains("gb")
        ) {
            analogDpadControllerOption = {
                .bool(.init(
                    title: ENABLE_ANALOG_DPAD,
                    description: nil,
                    requiresRestart: false),
                      defaultValue: true)
            }()
        }
        coreOptions.append(analogDpadControllerOption)
        if (self.systemName.contains("retroarch")) {
            coreOptions.append(numKeyControllerOption)
        }
        
        if (self.systemName.contains("dos") ||
             self.systemName.contains("mac") ||
             self.systemName.contains("appleII") ||
             self.systemName.contains("pc98")) {
            isDOS=true
            coreOptions.append(numKeyControllerOption)
        }
        if let status = PVEmulatorCore.status["isOn"],
           (status && self.systemName.contains("appleII")) {
            coreOptions.append(apple2MachineOption)
        }
        analogKeyControllerOption = {
            .bool(.init(
                title: ENABLE_ANALOG_KEY,
                description: nil,
                requiresRestart: false),
                  defaultValue: !isDOS)}()
        coreOptions.append(analogKeyControllerOption)
        if (UIScreen.screens.count > 1 && UIDevice.current.userInterfaceIdiom == .pad) {
            coreOptions.append(secondScreenOption)
        }
        coreOptions.append(volumeOption)
        coreOptions.append(ffOption)
        coreOptions.append(smOption)
        let coreGroup:CoreOption = .group(.init(title: "RetroArch Core",
                                                description: "Override options for RetroArch Core"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }
}

@objc public extension PVRetroArchCore {
    @objc var gs: Int {
        PVRetroArchCore.valueForOption(PVRetroArchCore.gsOption).asInt ?? 0
    }
    @objc var retroControl: Bool {
        PVRetroArchCore.valueForOption(PVRetroArchCore.retroArchControllerOption).asBool
    }
    @objc var secondScreen: Bool {
        PVRetroArchCore.valueForOption(PVRetroArchCore.secondScreenOption).asBool
    }
    @objc func parseOptions() {
        var optionValues:String = ""
        var optionValuesFile: String = ""
        var optionOverwrite: Bool = false
        self.gsPreference = NSNumber(value: gs).int8Value
        self.volume = NSNumber(value: PVRetroArchCore.valueForOption(PVRetroArchCore.volumeOption).asInt ?? 100).int32Value
        self.ffSpeed = NSNumber(value: PVRetroArchCore.valueForOption(PVRetroArchCore.ffOption).asInt ?? 300).int32Value
        self.smSpeed = NSNumber(value: PVRetroArchCore.valueForOption(PVRetroArchCore.smOption).asInt ?? 300).int32Value
        self.bindAnalogKeys = PVRetroArchCore.valueForOption(PVRetroArchCore.analogKeyControllerOption).asBool
        self.bindAnalogDpad = PVRetroArchCore.valueForOption(PVRetroArchCore.analogDpadControllerOption).asBool
        self.bindNumKeys = false
        self.retroArchControls = true
        self.hasTouchControls=false
        self.extractArchive=true
        if (UIScreen.screens.count > 1 && UIDevice.current.userInterfaceIdiom == .pad) {
            self.hasSecondScreen = secondScreen;
        }
        if let systemIdentifier = self.systemIdentifier {
            if (systemIdentifier.contains("psp")) {
                self.gsPreference = 2; // Use Vulkan PSP
            }
            if (systemIdentifier.contains("snes") ||
                systemIdentifier.contains("nes")  ||
                systemIdentifier.contains("dreamcast")  ||
                systemIdentifier.contains("genesis")  ||
                systemIdentifier.contains("saturn")  ||
                systemIdentifier.contains("3DO")  ||
                systemIdentifier.contains("gb")  ||
                systemIdentifier.contains("segacd")  ||
                systemIdentifier.contains("gba")  ||
                systemIdentifier.contains("psx")  ||
                systemIdentifier.contains("neogeo")  ||
                systemIdentifier.contains("mame")  ||
                systemIdentifier.contains("pce") ||
                systemIdentifier.contains("ds") ||
                systemIdentifier.contains("psp") ||
                systemIdentifier.contains("n64")) {
                self.retroArchControls = retroControl
                self.hasTouchControls = true
            }
            if (systemIdentifier.contains("dos")  ||
                systemIdentifier.contains("mac")  ||
                systemIdentifier.contains("pc98")) {
                optionValues += "input_auto_game_focus = \"1\"\n"
                self.retroArchControls = retroControl
                self.hasTouchControls = true
                self.bindNumKeys = PVRetroArchCore.valueForOption(PVRetroArchCore.numKeyControllerOption).asBool
            }
            if (systemIdentifier.contains("appleII")) {
                optionValues += "input_auto_game_focus = \"1\"\n"
                self.machineType = NSNumber(value: PVRetroArchCore.valueForOption(PVRetroArchCore.apple2MachineOption).asInt ?? 201).int32Value
                self.retroArchControls = retroControl
                self.hasTouchControls = true
                self.bindNumKeys = PVRetroArchCore.valueForOption(PVRetroArchCore.numKeyControllerOption).asBool
                var bios:[String:[String:Int]] = [:]
                if (self.machineType == 210) {
                    bios["apple2.zip"]=["4ae2d493f4729d38e66fdace56a73f6c":11870]
                } else if (self.machineType == 211) {
                    bios["apple2p.zip"]=["164f25a6fb200130e5a724e053d8c4e4":9211]
                } else if (self.machineType == 213) {
                    bios["apple2ee.zip"]=["9f738381801944d792f4640ec46c7ed8":16762]
                } else if (self.machineType == 220) {
                    bios["apple2c.zip"]=["db527949e418044f067bc234da67fafa":16974]
                } else if (self.machineType == 221) {
                    bios["apple2gs.zip"]=["e43302d686bafe6007a1175bc7d562ae":174146]
                } else if (self.machineType == 222) {
                    bios["apple3.zip"]=["a300cffeaf2c31238a2922e6a1f03065":7174]
                    bios["a3fdc.zip"]=["2b50e7c8a9f2b55ddd2ace9fecdd6a60":262]
                }
                if let biosPath = self.biosPath {
                    storeJSON(bios, to:URL(fileURLWithPath: biosPath.appending("/requirements.json")))
                }
            }
            if (systemIdentifier.contains("dos")   ||
                systemIdentifier.contains("mac")   ||
                systemIdentifier.contains("pc98")  ||
                systemIdentifier.contains("neo")   ||
                systemIdentifier.contains("mame")  ||
                systemIdentifier.contains("appleII")) {
                self.extractArchive = false;
            }
        }
        if let coreIdentifier = self.coreIdentifier {
            if (coreIdentifier.contains("melonds")) {
                optionValues += "melonds_touch_mode = \"Touch\"\n"
                optionValuesFile = "melonDS/melonDS.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("mupen")) {
                let rdpOpt = PVRetroArchCore.valueForOption(PVRetroArchCore.mupenRDPOption).asInt ?? 1
                if (rdpOpt == 0) {
                    optionValues += "mupen64plus-rdp-plugin = \"angrylion\"\n"
                } else {
                    optionValues += "mupen64plus-rdp-plugin = \"gliden64\"\n";
                }
                optionValuesFile = "Mupen64Plus-Next/Mupen64Plus-Next.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("ppsspp")) {
                optionValues += "ppsspp_cpu_core = \"Interpreter\"\n"
                optionValues += "ppsspp_internal_resolution = \"1920x1088\"\n"
                optionValues += "ppsspp_texture_scaling_level = \"5x\"\n"
                optionValuesFile = "PPSSPP/PPSSPP.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("mame_libretro")) {
                optionValues += "mame_read_config = \"enabled\"\n"
                optionValues += "mame_write_config = \"enabled\"\n"
                optionValues += "mame_boot_to_bios = \"enabled\"\n"
                optionValues += "mame_mame_paths_enable = \"enabled\"\n"
                optionValues += "mame_boot_to_osd = \"" + (PVRetroArchCore.valueForOption(PVRetroArchCore.mameOSDOption).asBool  ? "enabled" :
                "disabled") + "\"\n"
                optionValues += "mame_boot_from_cli = \"enabled\"\n"
                optionValues += "mame_cheats_enable = \"enabled\"\n"
                optionValuesFile = "MAME/MAME.opt"
                optionOverwrite = true
            }
            if (coreIdentifier.contains("psx_hw")) {
                optionValues += "beetle_psx_hw_renderer = \"hardware_vk\"\n"
                optionValues += "beetle_psx_hw_renderer_software_fb = \"enabled\"\n"
                optionValues += "beetle_psx_hw_pgxp_2d_tol = \"0px\"\n"
                optionValues += "beetle_psx_hw_pgxp_mode = \"memory only\"\n"
                optionValues += "beetle_psx_hw_pgxp_nclip = \"enabled\"\n"
                optionValues += "beetle_psx_hw_internal_resolution = \"2x\"\n"
                optionValues += "beetle_psx_hw_dither_mode = \"internal resolution\"\n"
                optionValues += "beetle_psx_hw_pgxp_texture = \"enabled\"\n"
                optionValues += "beetle_psx_hw_pgxp_vertex = \"enabled\"\n";
                optionValues += "beetle_psx_hw_msaa = \"16x\"\n";
                optionValues += "beetle_psx_hw_filter = \"xBR\"\n";
                optionValues += "beetle_psx_hw_adaptive_smoothing = \"enabled\"\n";
                optionValuesFile = "Beetle PSX HW/Beetle PSX HW.opt"
                optionOverwrite = false
            } else if (coreIdentifier.contains("psx")) {
                optionValues += "beetle_psx_gxp_2d_tol = \"0px\"\n"
                optionValues += "beetle_psx_pgxp_mode = \"memory only\"\n"
                optionValues += "beetle_psx_pgxp_nclip = \"enabled\"\n"
                optionValues += "beetle_psx_internal_resolution = \"2x\"\n"
                optionValues += "beetle_psx_dither_mode = \"internal resolution\"\n"
                optionValues += "beetle_psx_pgxp_texture = \"enabled\"\n"
                optionValues += "beetle_psx_pgxp_vertex = \"enabled\"\n";
                optionValuesFile = "Beetle PSX/Beetle PSX.opt"
                optionOverwrite = false
            }
        }
        self.coreOptionConfig = optionValues;
        self.coreOptionConfigPath = optionValuesFile
        self.coreOptionOverwrite = optionOverwrite
    }
}

extension PVRetroArchCore: GameWithCheat {
	@objc public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
		do {
			NSLog("Calling setCheat \(code) \(type) \(codeType)")
			try self.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
			return true
		} catch let error {
            NSLog("Error setCheat \(error)")
			return false
		}
	}
    @objc
    public var supportsCheatCode: Bool { return true }
    @objc
    public var cheatCodeTypes: [String] { return [] }
}

@objc public extension PVRetroArchCore {
    @objc func useSecondaryScreen() {
        if UIScreen.screens.count > 1 {
            let secondaryScreen:UIScreen = UIScreen.screens[1]
            if (self.window == nil) {
                let secondaryWindow = UIWindow(frame: secondaryScreen.bounds)
                self.window = secondaryWindow
                self.window.screen = UIScreen.main
                if let touchController = CocoaView.get().parent, let emuController = touchController.parent {
                    emuController.removeFromParent()
                    secondaryWindow.rootViewController = emuController
                }
                self.window.isHidden=false
            }
            self.window.screen = secondaryScreen
        }
    }
    @objc func usePrimaryScreen() {
        if UIScreen.screens.count > 1 && self.window != nil && self.window != UIApplication.shared.keyWindow {
            self.window.screen = UIScreen.main
        }
    }
}

extension PVRetroArchCore: CoreActions {
    public var coreActions: [CoreAction]? {
        return [CoreAction(title: "Game Options (RetroArch Options Menu)", options: nil, style:.default)]
    }
    public func selected(action: CoreAction) {
        switch action.title {
            case "Game Options (RetroArch Options Menu)":
                menuToggle()
                break;
            default:
                print("Unknown action: " + action.title)
        }
    }
}

func storeJSON<T: Encodable>(_ object: T, to url: URL) {
    let encoder = JSONEncoder()
    do {
        let data = try encoder.encode(object)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
    } catch {
        NSLog(error.localizedDescription)
    }
}


func retrieveJSON<T: Decodable>(_ url: URL, as type: T.Type) -> T? {
    if !FileManager.default.fileExists(atPath: url.path) {
        fatalError("File at path \(url.path) does not exist!")
    }

    if let data = FileManager.default.contents(atPath: url.path) {
        let decoder = JSONDecoder()
        do {
            let model = try decoder.decode(type, from: data)
            return model
        } catch {
            NSLog(error.localizedDescription)
        }
    } else {
        NSLog("No data at \(url.path)!")
    }
    return nil
}
