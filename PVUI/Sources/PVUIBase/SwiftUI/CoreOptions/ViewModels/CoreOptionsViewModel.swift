import Foundation
import RealmSwift
import PVCoreBridge
import PVLibrary
import Combine

@MainActor
final class CoreOptionsViewModel: ObservableObject {
    /// Published list of available cores that implement CoreOptional
    @Published private(set) var availableCores: [PVCore] = []

    /// The currently selected core for options display
    @Published var selectedCore: (core: PVCore, coreClass: CoreOptional.Type)?

    /// Optional game MD5 for per-game scoped reads/writes.
    /// When set, option reads and writes use the per-game key prefix.
    var gameMD5: String?

    private var cancellables = Set<AnyCancellable>()

    init(gameMD5: String? = nil) {
        self.gameMD5 = gameMD5
        loadAvailableCores()
    }

    /// Load all cores that implement CoreOptional
    private func loadAvailableCores() {
        let unsupportedCores = Defaults[.unsupportedCores]
        let isAppStore = AppState.shared.isAppStore
        let realm = try! Realm()
        
        availableCores = realm.objects(PVCore.self)
            .sorted(byKeyPath: "projectName")
            .filter { pvcore in
                guard let _ = NSClassFromString(pvcore.principleClass) as? CoreOptional.Type else {
                    return false
                }
                
                // Keep the core if:
                // 1. It's not disabled, OR it's disabled but unsupportedCores is true
                // 2. AND (It's not app store disabled, OR we're not in the app store) — always hard-hidden in App Store builds
                let keepDueToDisabled = !pvcore.disabled || unsupportedCores
                let keepDueToAppStoreDisabled = !pvcore.appStoreDisabled || !isAppStore
                
                return keepDueToDisabled && keepDueToAppStoreDisabled
            }
    }

    /// Select a core to display its options
    func selectCore(_ core: PVCore) {
        guard let coreClass = NSClassFromString(core.principleClass) as? CoreOptional.Type else {
            return
        }

        selectedCore = (core: core, coreClass: coreClass)
    }

    /// Get the current value for an option, respecting the per-game scope when `gameMD5` is set.
    func currentValue(for option: CoreOption) -> Any? {
        guard let coreClass = selectedCore?.coreClass else { return nil }
        let md5 = gameMD5

        switch option {
        case .bool(_, let defaultValue, _):
            return coreClass.storedValueForOption(Bool.self, option.key, andMD5: md5) ?? defaultValue
        case .string(_, let defaultValue, _):
            return coreClass.storedValueForOption(String.self, option.key, andMD5: md5) ?? defaultValue
        case .enumeration(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Int.self, option.key, andMD5: md5) ?? defaultValue
        case .range(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Int.self, option.key, andMD5: md5) ?? defaultValue
        case .rangef(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Float.self, option.key, andMD5: md5) ?? defaultValue
        case .multi(_, let values, _):
            return coreClass.storedValueForOption(String.self, option.key, andMD5: md5) ?? values.first?.title
        case .group(_, _):
            return nil
        @unknown default:
            return nil
        }
    }

    /// Set a new value for an option, respecting the per-game scope when `gameMD5` is set.
    func setValue(_ value: Any, for option: CoreOption) {
        guard let coreClass = selectedCore?.coreClass else { return }
        let md5 = gameMD5

        switch value {
        case let boolValue as Bool:
            coreClass.setValue(boolValue, forOption: option, andMD5: md5)
        case let stringValue as String:
            coreClass.setValue(stringValue, forOption: option, andMD5: md5)
        case let intValue as Int:
            coreClass.setValue(intValue, forOption: option, andMD5: md5)
        case let floatValue as Float:
            coreClass.setValue(floatValue, forOption: option, andMD5: md5)
        default:
            break
        }
    }

    /// Returns true if a per-game override exists for the option and the current `gameMD5`.
    func hasPerGameOverride(for option: CoreOption) -> Bool {
        guard let coreClass = selectedCore?.coreClass, let md5 = gameMD5 else { return false }
        return coreClass.hasPerGameOverride(for: option, md5: md5)
    }

    /// Resets the per-game override for a single option (no-op when `gameMD5` is nil).
    func resetOption(_ option: CoreOption) {
        guard let coreClass = selectedCore?.coreClass, let md5 = gameMD5 else { return }
        coreClass.resetOption(option, forMD5: md5)
    }

    /// Resets all per-game overrides for the current game (no-op when `gameMD5` is nil).
    func resetAllPerGameOptions() {
        guard let coreClass = selectedCore?.coreClass, let md5 = gameMD5 else { return }
        coreClass.resetAllOptions(forMD5: md5)
    }
}
