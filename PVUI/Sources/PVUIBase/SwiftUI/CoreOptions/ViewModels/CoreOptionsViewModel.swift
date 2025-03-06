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

    private var cancellables = Set<AnyCancellable>()

    init() {
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
                // 2. AND (It's not app store disabled, OR we're not in the app store, OR unsupportedCores is true)
                let keepDueToDisabled = !pvcore.disabled || unsupportedCores
                let keepDueToAppStoreDisabled = !pvcore.appStoreDisabled || !isAppStore || unsupportedCores
                
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

    /// Get the current value for an option
    func currentValue(for option: CoreOption) -> Any? {
        guard let coreClass = selectedCore?.coreClass else { return nil }

        switch option {
        case .bool(_, let defaultValue, _):
            return coreClass.storedValueForOption(Bool.self, option.key) ?? defaultValue
        case .string(_, let defaultValue, _):
            return coreClass.storedValueForOption(String.self, option.key) ?? defaultValue
        case .enumeration(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Int.self, option.key) ?? defaultValue
        case .range(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Int.self, option.key) ?? defaultValue
        case .rangef(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Float.self, option.key) ?? defaultValue
        case .multi(_, let values, _):
            return coreClass.storedValueForOption(String.self, option.key) ?? values.first?.title
        case .group(_, _):
            return nil
        @unknown default:
            return nil
        }
    }

    /// Set a new value for an option
    func setValue(_ value: Any, for option: CoreOption) {
        guard let coreClass = selectedCore?.coreClass else { return }

        switch value {
        case let boolValue as Bool:
            coreClass.setValue(boolValue, forOption: option)
        case let stringValue as String:
            coreClass.setValue(stringValue, forOption: option)
        case let intValue as Int:
            coreClass.setValue(intValue, forOption: option)
        case let floatValue as Float:
            coreClass.setValue(floatValue, forOption: option)
        default:
            break
        }
    }
}
