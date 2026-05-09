import Foundation
import PVSupport
import PVEmulatorCore
import PVLogging
import PVCoreBridge

extension PVRetroArchCoreOptions: SubCoreOptional {

    nonisolated public static func options(forSubcoreIdentifier identifier: String, systemName: String) -> [CoreOption]? {
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
        if EmulationState.shared.stateSubject.value.isOn,
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

        guard !subCoreOptions.isEmpty else {
            return nil
        }

        return [subCoreGroup]
    }
}

@objc public class PVRetroArchCoreOptions: NSObject, CoreOptions, @unchecked Sendable {

    public static var options: [CoreOption] {
        var options = [CoreOption]()
        var coreOptions: [CoreOption] = [gsOption]

        coreOptions.append(retroArchControllerOption)

        if UIDevice.current.userInterfaceIdiom == .pad {
            let hasMultipleScreens: Bool
            if #available(iOS 16.0, tvOS 16.0, *) {
                hasMultipleScreens = UIApplication.shared.openSessions.contains { $0.scene?.session.role == .windowExternalDisplayNonInteractive }
            } else {
                hasMultipleScreens = UIScreen.screens.count > 1
            }
            if hasMultipleScreens {
                coreOptions.append(secondScreenOption)
            }
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
            description: "Must also be enabled in the RetroArch configuration for overlays if not already enabled.",
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
extension PVRetroArchCoreCore: CoreOptional, SubCoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        return PVRetroArchCoreOptions.options + (options(forSubcoreIdentifier: identifier, systemName: systemName) ?? [])
    }

    public static func options(forSubcoreIdentifier identifier: String, systemName: String) -> [PVCoreBridge.CoreOption]? {
        return PVRetroArchCoreOptions.options(forSubcoreIdentifier: identifier.isEmpty ? self.identifier : identifier, systemName: systemName.isEmpty ? self.systemName : systemName)
    }

    private static var identifier: String {
        let name = EmulationState.shared.stateSubject.value.coreClassName
        return name.isEmpty ? "retroarch" : name
    }

    private static var systemName: String {
        let name = EmulationState.shared.stateSubject.value.systemName
        return name.isEmpty ? "retroarch" : name
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

            /// Snapshot for the value handler so the `@Sendable` closure does not capture the mutable `values` buffer.
            let enumValuesForValueHandler = values

            /// Create a value handler closure that will update the RetroArch option
            let valueHandler: @Sendable (OptionValueRepresentable) -> Void = { newValue in
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
                        for (idx, value) in enumValuesForValueHandler.enumerated() {
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
        /// [PPSSPP-DIAG] Log entry only when running PPSSPP — the
        /// `coreLibraryName` lookup goes through RetroArch's runloop state, so
        /// it's nil-safe to read here even before retro_load_game runs.
        let diagSystemName = EmulationState.shared.stateSubject.value.systemName.lowercased()
        let diagIsPSP = diagSystemName.contains("psp")
        if diagIsPSP {
            let diagCoreName = PVRetroArchCoreBridge.coreLibraryName() ?? "<nil>"
            let diagOptsPath = PVRetroArchCoreBridge.perCoreOptionsPath() ?? "<nil>"
            let diagExists: Bool
            if let path = PVRetroArchCoreBridge.perCoreOptionsPath() {
                diagExists = FileManager.default.fileExists(atPath: path)
            } else {
                diagExists = false
            }
            ILOG("[PPSSPP-DIAG] synchronizeOptionsWithRetroArch ENTER systemName=\(diagSystemName) coreLibraryName=\(diagCoreName) perCoreOptionsPath=\(diagOptsPath) exists=\(diagExists)")
        }

        guard let optionsPtr: UnsafeMutablePointer<core_option_manager_t> = getOptions() else {
            WLOG("Failed to get RetroArch options manager")
            if diagIsPSP {
                ILOG("[PPSSPP-DIAG] synchronizeOptionsWithRetroArch EXIT early — getOptions() returned nil (RetroArch options manager not yet initialized)")
            }
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
        if diagIsPSP {
            ILOG("[PPSSPP-DIAG] synchronizeOptionsWithRetroArch EXIT normal completion")
        }
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
        self.retroArchControls = retroControl
        self.hasTouchControls=false
        self.extractArchive=true

        if UIDevice.current.userInterfaceIdiom == .pad {
            let hasMultiple: Bool
            if #available(iOS 16.0, tvOS 16.0, *) {
                hasMultiple = UIApplication.shared.openSessions.contains { $0.scene?.session.role == .windowExternalDisplayNonInteractive }
            } else {
                hasMultiple = UIScreen.screens.count > 1
            }
            if hasMultiple {
                self.hasSecondScreen = secondScreen
            }
        }

        if let systemIdentifier = self.systemIdentifier?.lowercased() {
            if (systemIdentifier.contains("psp")) {
                /// [PPSSPP-DIAG] Diagnostic entry log — captures runtime context
                /// when the PSP/RetroArch branch is entered. Logging-only; no
                /// behavior change.
                let diagOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
                ILOG("[PPSSPP-DIAG] parseOptions PSP branch entry: systemIdentifier=\(self.systemIdentifier ?? "<nil>") coreIdentifier=\(self.coreIdentifier) osVersion=\(diagOSVersion)")

                /// PPSSPP fast-memory + Vulkan worked on older iOS/tvOS builds, but
                /// iOS/tvOS 26+ can fail MemoryMap_Setup with vm_remap errors.
                /// Keep fast path on older OSes and apply a stability fallback on 26+.
                #if os(iOS) || os(tvOS)
                if #available(iOS 26, tvOS 26, *) {
                    self.gsPreference = 1 // OpenGL ES fallback on 26+
                    ILOG("PPSSPP fallback: iOS/tvOS 26+ detected, forcing OpenGL ES and disabling fast memory to avoid MemoryMap vm_remap boot failures")
                    ILOG("[PPSSPP-DIAG] writing option: ppsspp_fast_memory = \"disabled\"")
                    optionValues += "ppsspp_fast_memory = \"disabled\"\n";
                } else {
                    self.gsPreference = 2 // Preserve historical Vulkan path.
                    ILOG("PPSSPP config: preserving Vulkan + fast memory on pre-iOS/tvOS 26")
                    ILOG("[PPSSPP-DIAG] writing option: ppsspp_fast_memory = \"enabled\"")
                    optionValues += "ppsspp_fast_memory = \"enabled\"\n";
                }
                #else
                self.gsPreference = 2 // Preserve historical Vulkan path.
                ILOG("PPSSPP config: non-iOS/tvOS platform, preserving Vulkan + fast memory")
                ILOG("[PPSSPP-DIAG] writing option: ppsspp_fast_memory = \"enabled\" (non-iOS/tvOS)")
                optionValues += "ppsspp_fast_memory = \"enabled\"\n";
                #endif

                ILOG("[PPSSPP-DIAG] picked gsPreference=\(self.gsPreference) (1=GLES, 2=Vulkan); optionValues length so far=\(optionValues.count)")

                ILOG("[PPSSPP-DIAG] writing option: ppsspp_ignore_bad_memory_access = \"enabled\"")
                optionValues += "ppsspp_ignore_bad_memory_access = \"enabled\"\n";

                optionValuesFile = "PPSSPP/PPSSPP.opt"
                optionOverwrite = false
                ILOG("[PPSSPP-DIAG] PSP branch complete: optionValuesFile=\(optionValuesFile) optionOverwrite=\(optionOverwrite) total optionValues length=\(optionValues.count)")
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
        let coreIdentifier = self.coreIdentifier.lowercased()
        if (coreIdentifier.contains("vecx")) {
                // Hardware mode broken, force software mode
                optionValues += "vecx_bloom_brightness = \"4\"\n"
                optionValues += "vecx_bloom_width = \"8x\"\n"
                optionValues += "vecx_line_brightness = \"4\"\n"
                optionValues += "vecx_line_color = \"Green\"\n"
                optionValues += "vecx_line_width = \"4\"\n"
                optionValues += "vecx_res_hw = \"824x1024\"\n"
                optionValues += "vecx_res_multi = \"3\"\n"
//                optionValues += "vecx_scale_x = \"1\"\n"
//                optionValues += "vecx_scale_y = \"1\"\n"
//                optionValues += "vecx_shift_x = \"0\"\n"
//                optionValues += "vecx_shift_y = \"0\"\n"
                optionValues += "vecx_use_hw = \"Hardware\"\n"
                optionValuesFile = "VecX/VecX.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("melonds")) {
                optionValues += "melonds_touch_mode = \"Touch\"\n"
                optionValuesFile = "melonDS/melonDS.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("mupen")) {
//                let rdpOpt = PVRetroArchCoreBridge.valueForOption(PVRetroArchCoreOptions.mupenRDPOption).asInt ?? 0
//                if (rdpOpt == 0) {
                    optionValues += "mupen64plus-rdp-plugin = \"angrylion\"\n"
//                } else {
//                    optionValues += "mupen64plus-rdp-plugin = \"gliden64\"\n";
//                }
                // ParallelRSP requires JIT. tvOS does not expose JIT to regular
                // (non-debug) builds; Xcode-attached or other privileged debug
                // sessions can enable it, but this is uncommon for end-user builds.
                // On iOS 26+ the W×X enforcement also prevents JIT for standard
                // builds. Use the interpreted CXD4 RSP in both cases.
                // On iOS < 26, ParallelRSP is the better-performing choice.
                #if os(tvOS)
                optionValues += "mupen64plus-rsp-plugin = \"cxd4\"\n"
                #elseif os(iOS)
                if #available(iOS 26, *) {
                    optionValues += "mupen64plus-rsp-plugin = \"cxd4\"\n"
                } else {
                    optionValues += "mupen64plus-rsp-plugin = \"parallel\"\n"
                }
                #else
                optionValues += "mupen64plus-rsp-plugin = \"hle\"\n"
                #endif
                optionValuesFile = "Mupen64Plus-Next/Mupen64Plus-Next.opt"
                #if os(iOS) || os(tvOS)
                // Read the existing .opt file so we can do targeted in-place updates.
                let mupenOptPath = (self.retroArchRootPath ?? "") + "/config/Mupen64Plus-Next/Mupen64Plus-Next.opt"
                DLOG("Mupen64Plus-Next: opt file path: \(mupenOptPath)")
                // Use fileExists to distinguish "no file" (fresh install) from "empty file"
                // (needs migration). String(contentsOfFile:) returns nil for both, so relying
                // solely on .isEmpty would cause iOS<26 to skip writing an empty file because
                // optionOverwrite=false only writes when the file is ABSENT from disk.
                let mupenOptFileExists = FileManager.default.fileExists(atPath: mupenOptPath)
                let existingMupenOpt = mupenOptFileExists ? ((try? String(contentsOfFile: mupenOptPath, encoding: .utf8)) ?? "") : ""
                // Must patch RSP when JIT is unavailable for standard builds:
                // tvOS (JIT is only reachable via Xcode debugger or special entitlements
                // — not typical for end users), or iOS 26+ (W×X enforcement).
                let mustPatchRSP: Bool = {
                    #if os(tvOS)
                    return true
                    #else
                    if #available(iOS 26, *) { return true }
                    return false
                    #endif
                }()
                if mustPatchRSP {
                    // Must overwrite so any stale "parallel" RSP line is replaced with "cxd4".
                    // Strategy: preserve ALL user settings from the existing file, patching
                    // only the rsp-plugin line. Fall back to defaults on a fresh install.
                    //
                    // Note: the pak/rumble regression was introduced by commit efe5e0d36
                    // which set optionOverwrite=true and wiped the whole file. This is NOT
                    // an inherent iOS 26 / tvOS limitation — it was a regression from that fix.
                    if !mupenOptFileExists {
                        // Fresh install: optionValues already has rdp + rsp, add pak default.
                        ILOG("Mupen64Plus-Next: fresh install — writing defaults with pak1 = rumble")
                        optionValues += "mupen64plus-pak1 = \"rumble\"\n"
                    } else {
                        // Existing file: rebuild from full content, patching only what we must.
                        // This preserves user-configured audio, video, gameplay, and pak options.
                        // Strip the old rsp-plugin line; we'll re-append with the correct value.
                        var mergedLines = existingMupenOpt.components(separatedBy: "\n")
                            .filter { !$0.hasPrefix("mupen64plus-rsp-plugin") }
                        // Drop trailing empty strings so appended lines don't produce blank-line gaps.
                        while mergedLines.last == "" { mergedLines.removeLast() }
                        mergedLines.append("mupen64plus-rsp-plugin = \"cxd4\"")
                        ILOG("Mupen64Plus-Next: patched rsp-plugin = cxd4 in existing .opt")
                        // Ensure rdp-plugin is present (defensive: existing file may predate our defaults).
                        let hasRdpPlugin = mergedLines.contains { $0.hasPrefix("mupen64plus-rdp-plugin") }
                        if !hasRdpPlugin {
                            mergedLines.insert("mupen64plus-rdp-plugin = \"angrylion\"", at: 0)
                            ILOG("Mupen64Plus-Next: rdp-plugin missing from existing .opt — adding angrylion default")
                        }
                        // Add pak1 default only if absent (honour user-configured pak type).
                        let hasPak1 = mergedLines.contains { $0.hasPrefix("mupen64plus-pak1 ") }
                        if !hasPak1 {
                            mergedLines.append("mupen64plus-pak1 = \"rumble\"")
                            ILOG("Mupen64Plus-Next: no pak1 setting found — defaulting pak1 = rumble")
                        } else {
                            ILOG("Mupen64Plus-Next: preserving existing pak1 setting in .opt")
                        }
                        optionValues = mergedLines.joined(separator: "\n") + "\n"
                    }
                    optionOverwrite = true
                } else {
                    // iOS < 26 only (tvOS is handled above via mustPatchRSP=true).
                    // write-only-if-not-exists: optionOverwrite=false means the Obj-C layer
                    // skips the write when the file is already present.
                    if !mupenOptFileExists {
                        // Fresh install: write defaults including pak1=rumble.
                        ILOG("Mupen64Plus-Next: iOS<26 fresh install — writing defaults with pak1 = rumble")
                        optionValues += "mupen64plus-pak1 = \"rumble\"\n"
                        optionOverwrite = false
                    } else {
                        // Existing file: check for all required settings and add any that are missing.
                        // optionOverwrite=false would skip the write entirely, so we must switch
                        // to a merge+overwrite when any required setting is absent.
                        // Build lines array once — reused for both the presence checks and the merge.
                        var mergedLines = existingMupenOpt.components(separatedBy: "\n")
                        let hasPak1 = mergedLines.contains { $0.hasPrefix("mupen64plus-pak1 ") }
                        let hasRdpPlugin = mergedLines.contains { $0.hasPrefix("mupen64plus-rdp-plugin") }
                        let hasRspPlugin = mergedLines.contains { $0.hasPrefix("mupen64plus-rsp-plugin") }
                        if hasPak1 && hasRdpPlugin && hasRspPlugin {
                            ILOG("Mupen64Plus-Next: iOS<26 all required settings present — preserving existing .opt")
                            // Clear stale optionValues so the Obj-C layer does not receive the
                            // rdp/rsp defaults set earlier; those are already in the file.
                            optionValues = ""
                            optionValuesFile = ""
                            optionOverwrite = false
                        } else {
                            while mergedLines.last == "" { mergedLines.removeLast() }
                            // Defensive: ensure rdp-plugin is present (matches iOS 26+ merge behaviour).
                            if !hasRdpPlugin {
                                mergedLines.insert("mupen64plus-rdp-plugin = \"angrylion\"", at: 0)
                                ILOG("Mupen64Plus-Next: iOS<26 rdp-plugin missing — adding angrylion default")
                            }
                            // Defensive: ensure rsp-plugin is present (matches iOS 26+ merge behaviour).
                            // Without this, files predating the rsp-plugin feature lose the parallel default
                            // when optionValues is replaced entirely by the merged content below.
                            if !hasRspPlugin {
                                mergedLines.append("mupen64plus-rsp-plugin = \"parallel\"")
                                ILOG("Mupen64Plus-Next: iOS<26 rsp-plugin missing — adding parallel default")
                            }
                            if !hasPak1 {
                                mergedLines.append("mupen64plus-pak1 = \"rumble\"")
                                ILOG("Mupen64Plus-Next: iOS<26 adding missing pak1 = rumble to existing .opt")
                            }
                            optionValues = mergedLines.joined(separator: "\n") + "\n"
                            optionOverwrite = true
                        }
                    }
                }
                #else
                optionOverwrite = false
                #endif
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
                optionValues += "mame_boot_to_osd = \"" + (PVRetroArchCoreBridge.valueForOption(PVRetroArchCoreOptions.mameOSDOption).asBool  ? "enabled" :
                "disabled") + "\"\n"
                optionValues += "mame_boot_from_cli = \"enabled\"\n"
                optionValues += "mame_cheats_enable = \"enabled\"\n"
                optionValuesFile = "MAME/MAME.opt"
                optionOverwrite = true
            }
            if coreIdentifier.contains("hatari") || self.systemIdentifier?.lowercased().contains("atarist") == true {
                /// hatari_boot_hd MUST be "disabled" to prevent the core from passing --acsi ""
                /// when no HD image is configured. Using optionOverwrite = true because:
                /// 1. RetroArch loads the .opt file into memory BEFORE our repair code runs
                /// 2. A stale invalid value in the file corrupts the in-memory variable store
                /// 3. The in-memory repair never takes effect for the current session
                /// By always overwriting, we guarantee a clean state every launch.
                ///
                /// NOTE: The primary fix for --acsi "" is in the bundled hatari.cfg template
                /// (Resources/hatari.cfg) which now includes [HardDisk] and [ACSI] sections
                /// with all HD/ACSI emulation disabled.  This .opt file write is a secondary
                /// defence that ensures the core option variable also reads "disabled".
                let hatariOptPath = (self.retroArchRootPath ?? "") + "/config/Hatari/Hatari.opt"
                let optBefore = (try? String(contentsOfFile: hatariOptPath, encoding: .utf8)) ?? "(not found)"
                DLOG("Hatari: hatari_boot_hd BEFORE fix in \(hatariOptPath):\n\(optBefore)")
                optionValues += "hatari_boot_hd = \"disabled\"\n"
                // Prevent hatari from opening its internal SDL GUI dialog on startup.
                // The dialog calls input_gui() before RetroArch sets input callbacks,
                // causing a NULL pointer crash (EXC_BAD_ACCESS in input_gui+60).
                optionValues += "hatari_start_in_ui = \"disabled\"\n"
                optionValuesFile = "Hatari/Hatari.opt"
                optionOverwrite = true
                ILOG("Hatari: queued hatari_boot_hd = \"disabled\" → will overwrite \(hatariOptPath)")
                DLOG("Hatari: hatari_boot_hd AFTER scheduled write — new content will be:\n\(optionValues)")
            }
            if coreIdentifier.contains("virtualjaguar") || self.systemIdentifier?.lowercased().contains("jaguar") == true {
                optionValues += "virtualjaguar_p1_numpad_to_kb = \"numbers\"\n"
                optionValues += "virtualjaguar_p2_numpad_to_kb = \"numbers\"\n"
                optionValues += "virtualjaguar_usefastblitter = \"enabled\"\n"
                optionValuesFile = "Virtual Jaguar/Virtual Jaguar.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("prboom")) {
                optionValues += "prboom-rumble = \"enabled\"\n"
                optionValuesFile = "PrBoom/PrBoom.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("dosbox")) {
                optionValues += "dosbox_pure_mouse_input = \"pad\"\n"
                optionValues += "dosbox_pure_midi = \"enabled\"\n"

                optionValuesFile = "DOSBox-pure/DOSBox-pure.opt"
                optionOverwrite = false
            }
            if (coreIdentifier.contains("psx_hw")) {
                // OpenGL hardware renderer — Vulkan via MoltenVK crashes on device-lost
                // during teardown (GPU timeout → vkDestroyPipeline on freed objects).
                // OpenGL avoids this while keeping PGXP, upscaling, and all HW features.
                optionValues += "beetle_psx_hw_renderer = \"hardware\"\n"
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
        self.coreOptionConfig = optionValues;
        self.coreOptionConfigPath = optionValuesFile
        self.coreOptionOverwrite = optionOverwrite
    }
}

@objc public extension PVRetroArchCoreBridge {
    /// Finds the first external-display window scene, if any.
    private static var externalWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.session.role == .windowExternalDisplayNonInteractive }
    }

    /// Finds the primary app window scene.
    private static var primaryWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.session.role == .windowApplication }
    }

    @objc func useSecondaryScreen() {
        guard let externalScene = Self.externalWindowScene else { return }
        if self.window == nil {
            let secondaryWindow = UIWindow(windowScene: externalScene)
            self.window = secondaryWindow
            if let touchController = CocoaView.get().parent, let emuController = touchController.parent {
                emuController.removeFromParent()
                secondaryWindow.rootViewController = emuController
            }
            secondaryWindow.isHidden = false
        } else {
            self.window?.windowScene = externalScene
        }
    }

    @objc func usePrimaryScreen() {
        guard Self.externalWindowScene != nil,
              let win = self.window,
              let primaryScene = Self.primaryWindowScene else { return }
        win.windowScene = primaryScene
    }
}

/// User-facing labels for pause-menu quick actions.
private enum RetroArchActionTitle {
    static let retroArchMenu = RetroArchCoreActionTitles.internalMenu
    static let toggleEject = "Toggle Eject"
    static let toggleTouchKeyboard = RetroArchCoreActionTitles.toggleTouchKeyboard
    static let toggleTouchMouse = RetroArchCoreActionTitles.toggleTouchMouse
}

extension PVRetroArchCoreCore: CoreActions {
    public var coreActions: [CoreAction]? {
        var actions = [CoreAction(title: RetroArchActionTitle.retroArchMenu, options: nil, style: .default)]
#if !os(tvOS)
        if canToggleTouchKeyboard {
            actions.append(CoreAction(title: RetroArchActionTitle.toggleTouchKeyboard, options: nil, style: .default))
        }
        if canToggleTouchMouse {
            actions.append(CoreAction(title: RetroArchActionTitle.toggleTouchMouse, options: nil, style: .default))
        }
#endif
        if _bridge.numberOfDiscs > 1 {
            actions.append(CoreAction(title: RetroArchActionTitle.toggleEject, options: nil, style: .default))
        }
        return actions
    }
    public func selected(action: CoreAction) {
        switch action.title {
        case RetroArchActionTitle.retroArchMenu:
            menuToggle()
        case RetroArchActionTitle.toggleEject:
            _bridge.toggleEjectState()
#if !os(tvOS)
        case RetroArchActionTitle.toggleTouchKeyboard:
            toggleTouchKeyboard()
        case RetroArchActionTitle.toggleTouchMouse:
            toggleTouchMouse()
#endif
        default:
            WLOG("Unknown action: " + action.title)
        }
    }
}

#if !os(tvOS)
private extension PVRetroArchCoreCore {
    /// Returns the active `CocoaView`, synchronizing to the main queue when required.
    func activeCocoaView() -> CocoaView? {
        if Thread.isMainThread {
            return CocoaView.get()
        }
        var view: CocoaView?
        DispatchQueue.main.sync {
            view = CocoaView.get()
        }
        return view
    }

    /// Indicates whether the custom RetroArch keyboard can be shown.
    var canToggleTouchKeyboard: Bool {
        guard let cocoaView = activeCocoaView() else { return false }
        return cocoaView.keyboardController != nil
    }

    /// Indicates whether the touch mouse handler is available.
    var canToggleTouchMouse: Bool {
        guard let cocoaView = activeCocoaView() else { return false }
        return cocoaView.mouseHandler != nil
    }

    /// Toggle the RetroArch custom keyboard and mirror the helper-bar behavior.
    func toggleTouchKeyboard() {
        DispatchQueue.main.async {
            let cocoaView = CocoaView.get()
            guard let keyboardController = cocoaView.keyboardController else {
                return
            }
            cocoaView.toggleCustomKeyboard()
            let keyboardVisible = !keyboardController.view.isHidden
            let notificationName = keyboardVisible ? Notification.Name("HideTouchControls") : Notification.Name("ShowTouchControls")
            NotificationCenter.default.post(name: notificationName, object: nil)
        }
    }

    /// Toggle the touch mouse handler while surfacing the RetroArch toast.
    func toggleTouchMouse() {
        DispatchQueue.main.async {
            let cocoaView = CocoaView.get()
            guard let mouseHandler = cocoaView.mouseHandler else {
                return
            }
            mouseHandler.enabled.toggle()
            let message = mouseHandler.enabled ? "Touch Mouse Enabled" : "Touch Mouse Disabled"
            runloop_msg_queue_push(
                message.cString(using: .utf8)!,
                message.lengthOfBytes(using: .utf8),
                1,
                100,
                true,
                nil,
                MESSAGE_QUEUE_ICON_DEFAULT,
                MESSAGE_QUEUE_CATEGORY_SUCCESS
            )
        }
    }
}
#endif

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

extension PVRetroArchCoreBridge {
    /// Set a RetroArch option by exact key or title/label match
    @objc public static func setOption(keyOrTitle: String, valueIndex: Int) {
        guard let optionsPtr: UnsafeMutablePointer<core_option_manager_t> = getOptions() else { return }
        var idx: size_t = 0
        // Try direct key match first
        if core_option_manager_get_idx(optionsPtr, keyOrTitle, &idx) {
            core_option_manager_set_val(optionsPtr, idx, size_t(valueIndex), true)
            if let conf = optionsPtr.pointee.conf { core_option_manager_flush(optionsPtr, conf) }
            return
        }
        // Otherwise, scan by title/labels
        let opts = optionsPtr.pointee
        for i in 0..<opts.size {
            let opt = opts.opts.advanced(by: Int(i)).pointee
            if let desc = opt.desc, String(cString: desc) == keyOrTitle {
                core_option_manager_set_val(optionsPtr, size_t(i), size_t(valueIndex), true)
                if let conf = optionsPtr.pointee.conf { core_option_manager_flush(optionsPtr, conf) }
                return
            }
        }
    }
}

extension PVRetroArchCoreCore {
    /// Toggle PSX pad analog/digital depending on active core
    /// Beetle PSX: keys "beetle_psx_pad1type" / HW variant key "beetle_psx_hw_pad1type"
    /// Values typically: index 0 = digital, 1 = analog (DualShock)
    /// PCSX ReARMed: key "pcsx_rearmed_pad1type" values 0/1 or similar
    func togglePSXAnalogMode() {
        let coreId = _bridge.coreIdentifier.lowercased()
        if coreId.contains("psx_hw") {
            // Beetle PSX HW
            PVRetroArchCoreBridge.setOption(keyOrTitle: "beetle_psx_hw_pad1type", valueIndex: 1 - currentRAOptionIndex("beetle_psx_hw_pad1type"))
        } else if coreId.contains("psx") {
            // Beetle PSX (software)
            PVRetroArchCoreBridge.setOption(keyOrTitle: "beetle_psx_pad1type", valueIndex: 1 - currentRAOptionIndex("beetle_psx_pad1type"))
        } else if coreId.contains("pcsx_rearmed") {
            PVRetroArchCoreBridge.setOption(keyOrTitle: "pcsx_rearmed_pad1type", valueIndex: 1 - currentRAOptionIndex("pcsx_rearmed_pad1type"))
        }
    }

    /// Read current index for a RetroArch option key; returns 0 if not found
    private func currentRAOptionIndex(_ key: String) -> Int {
        guard let optionsPtr: UnsafeMutablePointer<core_option_manager_t> = PVRetroArchCoreBridge.getOptions() else { return 0 }
        var idx: size_t = 0
        guard core_option_manager_get_idx(optionsPtr, key, &idx) else { return 0 }
        let opt = optionsPtr.pointee.opts.advanced(by: Int(idx)).pointee
        return Int(opt.index)
    }
}
