import Foundation
import PVCoreBridge

/// Helper class to load RetroArch core options
class RetroArchCoreOptionsLoader {

    private let corePath: String
    private var coreHandle: UnsafeMutableRawPointer?

    /// Initialize with core framework path
    init(corePath: String) {
        self.corePath = corePath
    }

    /// Load the core and get its options
    func loadCoreOptions() -> [CoreOption]? {
        guard loadCore() else { return nil }
        defer { unloadCore() }

        return getCoreOptions()
    }

    // MARK: - Core Loading

    private func loadCore() -> Bool {
        coreHandle = dlopen(corePath, RTLD_NOW)
        return coreHandle != nil
    }

    private func unloadCore() {
        if let handle = coreHandle {
            dlclose(handle)
        }
    }

    // MARK: - RetroArch API

    private func getCoreOptions() -> [CoreOption]? {
        /// Get the retro_environment function pointer
        guard let retroEnvironment = getFunctionPointer(name: "retro_environment") as (@convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool)? else {
            return nil
        }

        /// Get the retro_set_environment function pointer
        guard let retroSetEnvironment = getFunctionPointer(name: "retro_set_environment") as (@convention(c) (@convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool) -> Void)? else {
            return nil
        }

        /// Reset the global callback handler
        EnvironmentCallbackHandler.shared.reset()

        /// Set the environment callback
        retroSetEnvironment(environmentCallback)

        /// Call retro_environment to get variables
        var varRequest = retro_variable()
        retroEnvironment(RETRO_ENVIRONMENT_GET_VARIABLE, &varRequest)

        return EnvironmentCallbackHandler.shared.options
    }

    private func getFunctionPointer<T>(name: String) -> T? {
        guard let handle = coreHandle else { return nil }
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
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

/// Define retro_variable struct
struct retro_variable {
    var key: UnsafePointer<CChar>?
    var value: UnsafePointer<CChar>?
}

// MARK: - Helper Extensions

extension CoreOption {
    /// Create a CoreOption from RetroArch variable
    static func fromRetroVariable(_ variable: retro_variable) -> CoreOption? {
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
