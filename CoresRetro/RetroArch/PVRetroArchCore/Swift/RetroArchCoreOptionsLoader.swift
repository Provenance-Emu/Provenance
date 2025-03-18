import Foundation
import PVLogging
internal import enum PVCoreBridge.CoreOption
internal import struct PVCoreBridge.CoreOptionValueDisplay
internal import struct PVCoreBridge.CoreOptionEnumValue
//import PVCoreBridgeRetro

/// Helper class to load RetroArch core options
class RetroArchCoreOptionsLoader {

    private let corePath: String
    private var coreHandle: UnsafeMutableRawPointer?
    private var environCb: retro_environment_t?
    private var coreOptions: [CoreOption] = []
    private var updateDisplayCallback: ((String, Bool) -> Void)?

    /// Initialize with core framework path
    init(corePath: String) {
        self.corePath = corePath
    }

    /// Load the core and get its options
    func loadCoreOptions() -> [PVCoreBridge.CoreOption]? {
        guard loadCore() else { return nil }
        defer { unloadCore() }

        /// Get the retro_set_environment function pointer
        typealias RetroSetEnvironmentFn = @convention(c) (retro_environment_t) -> Void
        guard let retroSetEnvironment = getFunctionPointer(name: "retro_set_environment") as RetroSetEnvironmentFn? else {
            ELOG("Failed to find symbol for `retro_set_environment`, \(corePath)")
            return nil
        }

        /// Set up environment callback
        retroSetEnvironment { (cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool in
            return RetroArchCoreOptionsLoader.handleEnvironmentCallback(cmd: cmd, data: data)
        }

        /// Store the environment callback
        self.environCb = { (cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool in
            return RetroArchCoreOptionsLoader.handleEnvironmentCallback(cmd: cmd, data: data)
        }

        return getCoreOptions()
    }

    // MARK: - Core Loading

    private func loadCore() -> Bool {
        coreHandle = dlopen(corePath, RTLD_LAZY | RTLD_LOCAL)
        return coreHandle != nil
    }

    private func unloadCore() {
        if let handle = coreHandle {
            dlclose(handle)
        }
    }

    // MARK: - RetroArch API

    private func getCoreOptions() -> [CoreOption]? {
               /// Get the retro_get_system_info function pointer
        typealias RetroGetSystemInfoFn = @convention(c) (UnsafeMutableRawPointer) -> Void
        guard let retroGetSystemInfo = getFunctionPointer(name:"retro_get_system_info") as RetroGetSystemInfoFn? else {
            ELOG("Failed to find symbol for `retro_get_system_info`, \(corePath)")
            return nil
        }
            /// Get the retro_get_system_av_info function pointer
        typealias RetroGetSystemAVInfoFn = @convention(c) (UnsafeMutableRawPointer) -> Void
        guard let retroGetSystemAVInfo = getFunctionPointer(name:"retro_get_system_av_info") as RetroGetSystemAVInfoFn? else {
            ELOG("Failed to find symbol for `retro_get_system_av_info`, \(corePath)")
            return nil
        }

        /// Create system info struct
        var systemInfo = retro_system_info(
            library_name: nil,
            library_version: nil,
            valid_extensions: nil,
            need_fullpath: false,
            block_extract: false
        )
        withUnsafeMutablePointer(to: &systemInfo) { pointer in
            retroGetSystemInfo(UnsafeMutableRawPointer(pointer))
        }

        ILOG("systemInfo: library_name:\(String(describing: systemInfo.library_name)), library_version:\(String(describing: systemInfo.library_version)), valid_extensions:\(String(describing: systemInfo.valid_extensions))")

        /// Create system AV info struct
        var systemAVInfo = retro_system_av_info(
            geometry: retro_game_geometry(),
            timing: retro_system_timing()
        )
        withUnsafeMutablePointer(to: &systemAVInfo) { pointer in
            retroGetSystemAVInfo(UnsafeMutableRawPointer(pointer))
        }

        ILOG("systemAVInfo: aspect_ratio:\(systemAVInfo.geometry.aspect_ratio), sample_rate:\(systemAVInfo.timing.sample_rate)")

        guard let environCb = self.environCb else {
            ELOG("Environment callback not set")
            return nil
        }

        /// Get core options using retro_environment
        var varRequest = retro_variable()
        let success = environCb(RETRO_ENVIRONMENT_GET_VARIABLE, &varRequest)
        DLOG("environCb() Success: \(success)")

        /// Parse core options from the variable request
        if let key = varRequest.key, let value = varRequest.value {
            let keyString = String(cString: key)
            let valueString = String(cString: value)
            return RetroArchCoreOptionsLoader.parseCoreOptions(key: keyString, value: valueString)
        }

        return nil
    }

    private static func parseCoreOptions(key: String, value: String) -> [CoreOption]? {
        /// Parse the value string which is in format "Description; Option1|Option2|Option3"
        let components = value.components(separatedBy: ";")
        guard components.count >= 2 else {
            return nil
        }

        let description = components[0].trimmingCharacters(in: .whitespaces)
        let options = components[1].components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        /// Create CoreOptionValueDisplay
        let display = CoreOptionValueDisplay(
            title: key,
            description: description,
            requiresRestart: false
        )

        /// Create enum values
        let enumValues = options.enumerated().map { index, option in
            CoreOptionEnumValue(title: option, description: nil, value: index)
        }

        return [.enumeration(display, values: enumValues, defaultValue: 0)]
    }

    private func getFunctionPointer<T>(name: String) -> T? {
        guard let handle = coreHandle else { return nil }
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    static func handleEnvironmentCallback(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
        switch cmd {
        case UInt32(RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION):
            /// Return the core options version we support
            if let version = data?.assumingMemoryBound(to: UInt32.self) {
                version.pointee = 2 /// We support version 2
                return true
            }
            return false

        case UInt32(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2):
            /// Handle core options v2
            if let options = data?.assumingMemoryBound(to: retro_core_options_v2.self) {
                return processCoreOptionsV2(options: options.pointee)
            }
            return false

        case UInt32(RETRO_ENVIRONMENT_GET_VARIABLE):
            /// Handle variable requests
            if let varPtr = data?.assumingMemoryBound(to: retro_variable.self) {
                let variable = varPtr.pointee
                if let key = variable.key, let value = variable.value {
                    let keyString = String(cString: key)
                    let valueString = String(cString: value)
                    return parseCoreOptions(key: keyString, value: valueString) != nil
                }
            }
            return false

        case UInt32(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_UPDATE_DISPLAY_CALLBACK):
            /// Handle update display callback
            if let cb = data?.assumingMemoryBound(to: retro_core_options_update_display_callback.self) {
                return setupUpdateDisplayCallback(callback: cb.pointee)
            }
            return false

        default:
            /// Handle other environment commands
            return false
        }
    }

    private static func processCoreOptionsV2(options: retro_core_options_v2) -> Bool {
        /// Process core options v2 definitions
        guard let categories = options.categories, let definitions = options.definitions else {
            return false
        }

        /// Convert core options to Swift format
        var coreOptions: [CoreOption] = []
        var currentGroup: CoreOption?

        var i = 0
        while definitions[i].key != nil {
            let def = definitions[i]

            /// Create group if needed
            if let categoryKey = def.category_key, let category = findCategory(key: String(cString: categoryKey), in: categories) {
                let display = CoreOptionValueDisplay(
                    title: String(cString: category.desc),
                    description: String(cString: category.info),
                    requiresRestart: false
                )
                currentGroup = .group(display, subOptions: [])
            }

            /// Create core option
            if let option = createCoreOption(from: def) {
                if let group = currentGroup {
                    /// Add option to current group
                    switch group {
                    case .group(let display, var subOptions):
                        subOptions.append(option)
                        currentGroup = .group(display, subOptions: subOptions)
                    default:
                        break
                    }
                } else {
                    /// Add standalone option
                    coreOptions.append(option)
                }
            }

            i += 1
        }

        /// Add any remaining group to the options
        if let group = currentGroup {
            coreOptions.append(group)
        }

        /// Store the processed options
        // TODO: How do we get these?
        // Maybe a static cache?
        // self.coreOptions = coreOptions
        DLOG("coreOptions: \(coreOptions.map(\.key).joined(separator: ", "))")
        return true
    }

    private static func createCoreOption(from def: retro_core_option_v2_definition) -> CoreOption? {
        /// Convert a single core option definition to Swift format
        guard let key = def.key, let desc = def.desc else {
            return nil
        }

        /// Create display info
        let display = CoreOptionValueDisplay(
            title: String(cString: desc),
            description: String(cString: def.info),
            requiresRestart: false
        )

        /// Parse values
        var values: [CoreOptionEnumValue] = []
        var defaultValueIndex = 0

        /// Access the values array using pointer arithmetic
        let valuesPtr = withUnsafePointer(to: def.values) { $0 }
        for i in 0..<RETRO_NUM_CORE_OPTION_VALUES_MAX {
            let value = valuesPtr.advanced(by: Int(i)).pointee.0 // This probably makes a bad pointer
            if value.value == nil {
                break /// Stop at the null terminator
            }

            if let valueStr = value.value {
                if let defaultVal = def.default_value, strcmp(valueStr, defaultVal) == 0 {
                    defaultValueIndex = Int(i)
                }
                values.append(CoreOptionEnumValue(
                    title: String(cString: value.label ?? valueStr),
                    description: nil,
                    value: Int(i)
                ))
            }
        }

        /// Create appropriate CoreOption type
        if !values.isEmpty {
            return .enumeration(display, values: values, defaultValue: defaultValueIndex)
        } else {
            /// Handle other option types if needed
            return nil
        }
    }

    private static func findCategory(key: String, in categories: UnsafePointer<retro_core_option_v2_category>) -> retro_core_option_v2_category? {
        /// Find a category by key
        var i = 0
        while categories[i].key != nil {
            if strcmp(categories[i].key, key) == 0 {
                return categories[i]
            }
            i += 1
        }
        return nil
    }

    private static func setupUpdateDisplayCallback(callback: retro_core_options_update_display_callback) -> Bool {
        /// Set up the update display callback
//        self.updateDisplayCallback = { (key: String, visible: Bool) in
//            /// Handle visibility updates
//            // TODO: Implement visibility handling
//        }
        return true
    }
}

/// Global environment callback function
@_cdecl("environmentCallback")
func environmentCallback(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
    return EnvironmentCallbackHandler.shared.handle(cmd: cmd, data: data)
}

/// Singleton helper class to handle environment callbacks
private class EnvironmentCallbackHandler {
    static let shared = EnvironmentCallbackHandler()
    private init() {}

    var options: [CoreOption] = []

    func reset() {
        ELOG("Resetting...")
        options.removeAll()
    }

    func handle(cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
        switch cmd {
        case RETRO_ENVIRONMENT_GET_VARIABLE:
            /// Handle variable requests
            if let varPtr = data?.assumingMemoryBound(to: retro_variable.self) {
                let variable = varPtr.pointee
                if let option = CoreOption.fromRetroVariable(variable) {
                    options.append(option)
                }
            }
            return true

        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            /// Handle variable update requests
            if let updatePtr = data?.assumingMemoryBound(to: Bool.self) {
                updatePtr.pointee = false /// For now, we don't track updates
            }
            return true

        default:
            /// Handle other environment commands
            return false
        }
    }
}

// MARK: - RetroArch C API

/// Define RetroArch constants from libretro.h
let RETRO_ENVIRONMENT_GET_VARIABLE: UInt32 = 15
let RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: UInt32 = 17

/// Define retro_variable struct with proper alignment
@frozen
@_alignment(8)
public struct retro_variable {
    var key: UnsafePointer<CChar>?
    var value: UnsafePointer<CChar>?
}

/// Define retro_system_info struct with proper alignment
@frozen
@_alignment(8)
public struct retro_system_info {
    var library_name: UnsafePointer<CChar>?
    var library_version: UnsafePointer<CChar>?
    var valid_extensions: UnsafePointer<CChar>?
    var need_fullpath: Bool
    var block_extract: Bool
}

/// Define retro_system_av_info struct with proper alignment
@frozen
@_alignment(8)
public struct retro_system_av_info {
    var geometry: retro_game_geometry
    var timing: retro_system_timing
}

/// Define retro_game_geometry struct with proper alignment
@frozen
@_alignment(8)
public struct retro_game_geometry {
    var base_width: UInt32 = 0
    var base_height: UInt32 = 0
    var max_width: UInt32 = 0
    var max_height: UInt32 = 0
    var aspect_ratio: Float = 0.0
}

/// Define retro_system_timing struct with proper alignment
@frozen
@_alignment(8)
public struct retro_system_timing {
    var fps: Double = 0.0
    var sample_rate: Double = 0.0
}

// MARK: - Helper Extensions

extension CoreOption {
    /// Create a CoreOption from RetroArch variable
    fileprivate static func fromRetroVariable(_ variable: retro_variable) -> CoreOption? {
        guard let key = variable.key, let value = variable.value else {
            return nil
        }

        let keyString = String(cString: key)
        let valueString = String(cString: value)

        /// Parse the value string which is in format "Description; Option1|Option2|Option3"
        let components = valueString.components(separatedBy: ";")
        guard components.count >= 2 else {
            return nil
        }

        let description = components[0].trimmingCharacters(in: .whitespaces)
        let options = components[1].components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        /// Create CoreOptionValueDisplay
        let display = CoreOptionValueDisplay(
            title: keyString,
            description: description,
            requiresRestart: false
        )

        /// Create enum values
        let enumValues = options.enumerated().map { index, option in
            CoreOptionEnumValue(title: option, description: nil, value: index)
        }

        return .enumeration(
            display,
            values: enumValues,
            defaultValue: 0
        )
    }
}
