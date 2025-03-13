import Foundation
import PVSupport
import PVEmulatorCore
import PVLogging
internal import enum PVCoreBridge.CoreOption
internal import struct PVCoreBridge.CoreOptionValueDisplay
internal import struct PVCoreBridge.CoreOptionEnumValue

extension PVRetroArchCoreOptions: SubCoreOptional {

    nonisolated(unsafe) public static func options(forSubcoreIdentifier identifier: String, systemName: String) -> [CoreOption]? {
        var subCoreOptions: [CoreOption] = []
        var isDOS = false

        DLOG("Getting options for forSubcoreIdentifier: \(identifier), systemName: \(systemName)")

//        if (identifier.contains("mupen")) {
//            subCoreOptions.append(mupenRDPOption)
//        }
        if (identifier.contains("mame")) {
            subCoreOptions.append(mameOSDOption)
        }
        if (systemName.contains("psx") ||
            systemName.contains("snes") ||
            systemName.contains("nes") ||
            systemName.contains("saturn") ||
            systemName.contains("dreamcast") ||
            systemName.contains("neogeo") ||
            systemName.contains("gb")
        ) {
            analogDpadControllerOption = {
                .bool(.init(
                    title: ENABLE_ANALOG_DPAD,
                    description: nil,
                    requiresRestart: false),
                      defaultValue: true)
            }()
        }
        subCoreOptions.append(analogDpadControllerOption)

        if (systemName.contains("retroarch")) {
            subCoreOptions.append(numKeyControllerOption)
        }

        if (systemName.contains("dos") ||
             systemName.contains("mac") ||
             systemName.contains("appleII") ||
            systemName.contains("xt") ||
            systemName.contains("st") ||
             systemName.contains("pc98")) {
            isDOS=true
            subCoreOptions.append(numKeyControllerOption)
        }
        if EmulationState.shared.isOn,
           systemName.contains("appleII") {
            subCoreOptions.append(apple2MachineOption)
        }
        analogKeyControllerOption = {
            .bool(.init(
                title: ENABLE_ANALOG_KEY,
                description: nil,
                requiresRestart: false),
                  defaultValue: !isDOS)}()
        subCoreOptions.append(analogKeyControllerOption)

        let subCoreGroup:CoreOption = .group(.init(title: "Core Options",
                                                description: "Override options for \(identifier) Core"),
                                          subOptions: subCoreOptions)

        var coreOptions = self.options

        coreOptions.append(contentsOf: [subCoreGroup])

        // Load dynamic options from RetroArch core
//        let frameworkIdentifier: String = identifier.replacingOccurrences(of: ".framework", with: "")
//        let frameworkPath = Bundle.main.bundlePath + "/Frameworks/" + identifier
//        let corePath = "\(frameworkPath)/\(frameworkIdentifier)"
//        ILOG("frameworkIdentifier: \(frameworkIdentifier), frameworkPath: \(frameworkPath), corePath: \(corePath)")
//        let loader = RetroArchCoreOptionsLoader(corePath: corePath)
//        if let dynamicOptions = loader.loadCoreOptions() {
//            let dynamicGroup: CoreOption = .group(
//                .init(
//                    title: "Dynamic Options",
//                    description: "Options loaded from RetroArch core"
//                ),
//                subOptions: dynamicOptions
//            )
//            coreOptions.append(dynamicGroup)
//        }

        return coreOptions
    }
}

@objc public class PVRetroArchCoreOptions: NSObject, CoreOptions, @unchecked Sendable {

    public static var options: [CoreOption] {
        var options = [CoreOption]()
        var coreOptions: [CoreOption] = [gsOption]

        coreOptions.append(retroArchControllerOption)

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
        return options + PVRetroArchCoreBridge.processRetroOptions()
    }

    public static var gsOption: CoreOption {
         .enumeration(.init(title: "Graphics Handler",
               description: "(Requires Restart)",
               requiresRestart: true),
          values: [
               .init(title: "Metal", description: "Metal", value: 0),
               .init(title: "OpenGL", description: "OpenGL", value: 1),
               .init(title: "Vulkan", description: "Vulkan", value: 2)
          ],
          defaultValue: 0)
    }
    public static var retroArchControllerOption: CoreOption {
        .bool(.init(
            title: USE_RETROARCH_CONTROLLER,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }
    public static var secondScreenOption: CoreOption {
        .bool(.init(
            title: USE_SECOND_SCREEN,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }
//    public static var mupenRDPOption: CoreOption {
//          .enumeration(.init(title: "Mupen RDP Plugin",
//               description: "(Requires Restart)",
//               requiresRestart: true),
//          values: [
//               .init(title: "Angrylion", description: "Angrylion", value: 0),
//               .init(title: "GlideN64", description: "GlideN64", value: 1)
//          ],
//          defaultValue: 0)
//    }
    public static var apple2MachineOption: CoreOption {
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
    }
    public static var volumeOption: CoreOption {
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
    }
    public static var ffOption: CoreOption {
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
    }
    public static var smOption: CoreOption {
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
    }
    public static var analogKeyControllerOption: CoreOption = {
        .bool(.init(
            title: ENABLE_ANALOG_KEY,
            description: nil,
            requiresRestart: false),
              defaultValue: true)}()
    public static var analogDpadControllerOption: CoreOption = {
        .bool(.init(
            title: ENABLE_ANALOG_DPAD,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }()
    public static var numKeyControllerOption: CoreOption {
        .bool(.init(
            title: ENABLE_NUM_KEY,
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }
    public static var mameOSDOption: CoreOption {
        .bool(.init(
            title: "Launch into OSD",
            description: nil,
            requiresRestart: false),
              defaultValue: false)
    }
}

// MARK: - PVRetroArchCoreCore
extension PVRetroArchCoreCore: @preconcurrency CoreOptional, SubCoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        return PVRetroArchCoreOptions.options + (options(forSubcoreIdentifier: identifier, systemName: systemName) ?? [])
    }

    public static func options(forSubcoreIdentifier identifier: String, systemName: String) -> [PVCoreBridge.CoreOption]? {
        return PVRetroArchCoreOptions.options(forSubcoreIdentifier: identifier.isEmpty ? self.identifier : identifier, systemName: systemName.isEmpty ? self.systemName : systemName)
    }

    private static var identifier: String {
        EmulationState.shared.coreClassName.isEmpty ? "retroarch" : EmulationState.shared.coreClassName
    }

    private static var systemName: String {
        EmulationState.shared.systemName.isEmpty ? "retroarch" : EmulationState.shared.systemName
    }
}

// MARK: - PVRetroArchCoreBridge

extension PVRetroArchCoreBridge: CoreOptional, SubCoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        return PVRetroArchCoreOptions.options
    }

    public static func options(forSubcoreIdentifier identifier: String, systemName: String) -> [PVCoreBridge.CoreOption]? {
        PVRetroArchCoreOptions.options(forSubcoreIdentifier: identifier, systemName: systemName)
    }

    public static func processRetroOptions() -> [CoreOption] {
        guard let optionsPtr: UnsafeMutablePointer<core_option_manager_t> = PVRetroArchCoreBridge.getOptions() else {
            return []
        }

        /// Array to hold all processed options
        var processedOptions: [CoreOption] = []

        /// Get the core_option_manager struct
        let optionsManager = optionsPtr.pointee

        /// Process categories first
        var categoryMap: [String: [CoreOption]] = [:]

        /// Process all options
        for i in 0..<optionsManager.size {
            /// Get option at index i
            let optionPtr = optionsManager.opts.advanced(by: Int(i))
            let option = optionPtr.pointee

            /// Get option key
            guard let key = option.key.map({ String(cString: $0) }) else {
                continue
            }

            /// Get option description to use as title
            let title = option.desc.map { String(cString: $0) } ?? key

            /// Get option info/help text
            let info = option.info.map { String(cString: $0) }

            /// Check if option is visible
            let isVisible = option.visible

            /// Skip invisible options
            if !isVisible {
                continue
            }

            /// Get option values
            var values: [CoreOptionEnumValue] = []
            if let valsList = option.vals {
                let valsCount = valsList.pointee.size

                for j in 0..<valsCount {
                    guard let valStr = valsList.pointee.elems.advanced(by: Int(j)).pointee.data else {
                        continue
                    }

                    let valueStr = String(cString: valStr)

                    /// Get label if available
                    var labelStr = valueStr
                    if let labelsList = option.val_labels,
                       j < labelsList.pointee.size,
                       let label = labelsList.pointee.elems.advanced(by: Int(j)).pointee.data {
                        labelStr = String(cString: label)
                    }

                    values.append(CoreOptionEnumValue(
                        title: labelStr,
                        description: valueStr,
                        value: Int(j)
                    ))
                }
            }

            /// Create the CoreOption
            let coreOption: CoreOption

            /// Create display info - using desc for title instead of key
            let display = CoreOptionValueDisplay(
                title: title,
                description: info,
                requiresRestart: false
            )

            /// Create a value handler closure that will update the RetroArch option
            let valueHandler: (OptionValueRepresentable) -> Void = { newValue in
                var valIdx: size_t = 0

                // Find the option index
                if core_option_manager_get_idx(optionsPtr, key, &valIdx) {
                    // Convert the new value to the appropriate index
                    if let intValue = newValue as? Int {
                        // For enumeration values, use the integer directly
                        core_option_manager_set_val(optionsPtr, valIdx, size_t(intValue), true)
                    } else if let boolValue = newValue as? Bool {
                        // For boolean values, convert to 0/1
                        core_option_manager_set_val(optionsPtr, valIdx, boolValue ? 1 : 0, true)
                    } else if let stringValue = newValue as? String {
                        // For string values, find the matching option
                        for (idx, value) in values.enumerated() {
                            if value.title == stringValue || value.description == stringValue {
                                core_option_manager_set_val(optionsPtr, valIdx, size_t(idx), true)
                                break
                            }
                        }
                    }
                }
            }

            /// Create appropriate option type based on values
            if values.count == 2
                &&
                // We probably don't need this check because RA treats
                // options with 2 values as bools already
               (values[1].title.lowercased() == "enabled" || values[1].title.lowercased() == "on" || values[1].title.lowercased() == "true") &&
               (values[0].title.lowercased() == "disabled" || values[0].title.lowercased() == "off" || values[0].title.lowercased() == "false")
            {
                /// This is likely a boolean option
                coreOption = .bool(display, defaultValue: Int(option.default_index) == 0, valueHandler: valueHandler)
            } else if values.count > 0 {
                /// This is an enumeration option
                coreOption = .enumeration(display, values: values, defaultValue: Int(option.default_index), valueHandler: valueHandler)
            } else {
                /// Fallback to string option
                coreOption = .string(display, defaultValue: "", valueHandler: valueHandler)
            }

            /// Add to category map if it has a category
            if let categoryKey = option.category_key.map({ String(cString: $0) }) {
                if categoryMap[categoryKey] == nil {
                    categoryMap[categoryKey] = []
                }
                categoryMap[categoryKey]?.append(coreOption)
            } else {
                /// No category, add directly to processed options
                processedOptions.append(coreOption)
            }
        }

        /// Process categories and add them as groups
        for i in 0..<optionsManager.cats_size {
            let categoryPtr = optionsManager.cats.advanced(by: Int(i))
            let category = categoryPtr.pointee

            /// Get category key
            guard let key = category.key.map({ String(cString: $0) }) else {
                continue
            }

            /// Get category options
            guard let categoryOptions = categoryMap[key], !categoryOptions.isEmpty else {
                continue
            }

            /// Get category description
            let description = category.desc.map { String(cString: $0) } ?? key

            /// Get category info
            let info = category.info.map { String(cString: $0) }

            /// Create group option
            let groupOption = CoreOption.group(
                CoreOptionValueDisplay(
                    title: description,
                    description: info,
                    requiresRestart: false
                ),
                subOptions: categoryOptions
            )

            processedOptions.append(groupOption)
        }

        return processedOptions
    }

    /// Synchronizes all stored option values with RetroArch's internal option system
    /// Call this when initializing the core to ensure RetroArch has the correct option values
    @objc public static func synchronizeOptionsWithRetroArch() {
        guard let optionsPtr: UnsafeMutablePointer<core_option_manager_t> = getOptions() else {
            WLOG("Failed to get RetroArch options manager")
            return
        }

        // Get all options including dynamic ones
        let allOptions = PVRetroArchCoreOptions.options

        // Create a map of option keys to their CoreOption objects for quick lookup
        var optionMap: [String: CoreOption] = [:]

        // Helper function to recursively process options and build the map
        func processOptions(_ options: [CoreOption]) {
            for option in options {
                optionMap[option.key] = option

                // If it's a group, process its suboptions
                if case let .group(_, subOptions) = option {
                    processOptions(subOptions)
                }
            }
        }

        // Build the option map
        processOptions(allOptions)

        // Get the core_option_manager struct
        let optionsManager = optionsPtr.pointee

        // Iterate through all RetroArch options
        for i in 0..<optionsManager.size {
            let optionPtr = optionsManager.opts.advanced(by: Int(i))
            let option = optionPtr.pointee

            // Get option key
            guard let key = option.key.map({ String(cString: $0) }) else {
                continue
            }

            // Find the corresponding CoreOption
            guard let coreOption = optionMap[key] else {
                continue
            }

            // Get the stored value for this option
            let optionValue: CoreOptionValue = PVRetroArchCoreOptions.valueForOption(coreOption)

            // Find the option index in RetroArch
            var optIdx: size_t = 0
            guard core_option_manager_get_idx(optionsPtr, key, &optIdx) else {
                continue
            }

            // Set the value based on its type
            switch optionValue {
            case .bool(let value):
                // For boolean values, convert to 0/1
                core_option_manager_set_val(optionsPtr, optIdx, value ? 1 : 0, false)

            case .int(let value):
                // For integer values, use directly
                core_option_manager_set_val(optionsPtr, optIdx, size_t(value), false)

            case .string(let value):
                // For string values, find the matching option
                if let valsList = option.vals {
                    let valsCount = valsList.pointee.size

                    for j in 0..<valsCount {
                        guard let valStr = valsList.pointee.elems.advanced(by: Int(j)).pointee.data else {
                            continue
                        }

                        let valueStr = String(cString: valStr)
                        if valueStr == value {
                            core_option_manager_set_val(optionsPtr, optIdx, j, false)
                            break
                        }
                    }
                }

            case .float(let value):
                // For float values, convert to string and find matching option
                let valueStr = String(value)
                if let valsList = option.vals {
                    let valsCount = valsList.pointee.size

                    for j in 0..<valsCount {
                        guard let valStr = valsList.pointee.elems.advanced(by: Int(j)).pointee.data else {
                            continue
                        }

                        let optionValueStr = String(cString: valStr)
                        if optionValueStr == valueStr {
                            core_option_manager_set_val(optionsPtr, optIdx, j, false)
                            break
                        }
                    }
                }

            case .notFound:
                // If no value is found, set to default
                core_option_manager_set_default(optionsPtr, optIdx, false)
            }
        }

        // After setting all options, flush the changes to ensure they're applied
        if let conf = optionsManager.conf {
            core_option_manager_flush(optionsPtr, conf)
        }

        ILOG("Synchronized all options with RetroArch")
    }
}

@objc public extension PVRetroArchCoreBridge {
    @objc var gs: Int {
        PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.gsOption).asInt ?? 0
    }
    @objc var retroControl: Bool {
        PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.retroArchControllerOption).asBool
    }
    @objc var secondScreen: Bool {
        PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.secondScreenOption).asBool
    }
    @objc func parseOptions() {
        var optionValues:String = ""
        var optionValuesFile: String = ""
        var optionOverwrite: Bool = false
        self.gsPreference = NSNumber(value: gs).int8Value
        self.volume = NSNumber(value: PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.volumeOption).asInt ?? 100).int32Value
        self.ffSpeed = NSNumber(value: PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.ffOption).asInt ?? 300).int32Value
        self.smSpeed = NSNumber(value: PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.smOption).asInt ?? 300).int32Value
        self.bindAnalogKeys = PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.analogKeyControllerOption).asBool
        self.bindAnalogDpad = PVRetroArchCoreOptions.valueForOption(PVRetroArchCoreOptions.analogDpadControllerOption).asBool
        self.bindNumKeys = false
        self.retroArchControls = true
        self.hasTouchControls=false
        self.extractArchive=true
        if (UIScreen.screens.count > 1 && UIDevice.current.userInterfaceIdiom == .pad) {
            self.hasSecondScreen = secondScreen;
        }
        if let systemIdentifier = self.systemIdentifier?.lowercased() {
            if (systemIdentifier.contains("psp")) {
                self.gsPreference = 2; // Use Vulkan PSP
            }
            
            let systemsWithBindNumlock: Set<String> = [
                "snes", "nes", "dreamcast", "genesis",
                "3do", "gb", "segacd", "gba", "psx",
                "neogeo", "mame", "ds", "psp", "n64",
//                "saturn", "pce", "pcecd", "sgfx"
            ]
            if ( systemsWithBindNumlock.contains(where: systemIdentifier.contains) ) {
                self.retroArchControls = retroControl
                self.hasTouchControls = true
            }
            if (systemIdentifier.contains("dos")  ||
                systemIdentifier.contains("mac")  ||
                systemIdentifier.contains("doom")  ||
                systemIdentifier.contains("quake")  ||
                systemIdentifier.contains("pc98")) {
                optionValues += "input_auto_game_focus = \"1\"\n"
                self.retroArchControls = retroControl
                self.hasTouchControls = true
                self.bindNumKeys = PVRetroArchCoreBridge.valueForOption(PVRetroArchCoreOptions.numKeyControllerOption).asBool
            }
            if (systemIdentifier.contains("appleII")) {
                optionValues += "input_auto_game_focus = \"1\"\n"
                self.machineType = NSNumber(value: PVRetroArchCoreBridge.valueForOption(PVRetroArchCoreOptions.apple2MachineOption).asInt ?? 201).int32Value
                self.retroArchControls = retroControl
                self.hasTouchControls = true
                self.bindNumKeys = PVRetroArchCoreBridge.valueForOption(PVRetroArchCoreOptions.numKeyControllerOption).asBool
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
//            if (coreIdentifier.contains("mupen")) {
//                let rdpOpt = PVRetroArchCoreBridge.valueForOption(PVRetroArchCoreOptions.mupenRDPOption).asInt ?? 0
//                if (rdpOpt == 0) {
//                    optionValues += "mupen64plus-rdp-plugin = \"angrylion\"\n"
//                } else {
//                    optionValues += "mupen64plus-rdp-plugin = \"gliden64\"\n";
//                }
//                optionValuesFile = "Mupen64Plus-Next/Mupen64Plus-Next.opt"
//                optionOverwrite = false
//            }
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
                optionValues += "mame_boot_to_osd = \"" + (PVRetroArchCoreBridge.valueForOption(PVRetroArchCoreOptions.mameOSDOption).asBool  ? "enabled" :
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

extension PVRetroArchCoreCore: GameWithCheat {
	@objc public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
		do {
			ILOG("Calling setCheat \(code) \(type) \(codeType)")
            try self._bridge.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
			return true
		} catch let error {
            ILOG("Error setCheat \(error)")
			return false
		}
	}
    @objc
    public var supportsCheatCode: Bool { return true }
    @objc
    public var cheatCodeTypes: [String] { return [] }
}

@objc public extension PVRetroArchCoreBridge {
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

extension PVRetroArchCoreCore: CoreActions {
    public var coreActions: [CoreAction]? {
        var actions = [CoreAction(title: "RetroArch Menu", options: nil, style:.default)]
        if _bridge.numberOfDiscs > 1 {
            actions +=  [CoreAction(title: "Toggle Eject", options: nil, style:.default)]
        }
        return actions
    }
    public func selected(action: CoreAction) {
        switch action.title {
            case "RetroArch Menu":
                menuToggle()
                break
            case "Toggle Eject":
                _bridge.toggleEjectState()
                break
            default:
                WLOG("Unknown action: " + action.title)
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
