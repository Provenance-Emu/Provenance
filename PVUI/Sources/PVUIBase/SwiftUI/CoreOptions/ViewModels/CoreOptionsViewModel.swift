import Foundation
import RealmSwift
import PVCoreBridge
import PVLibrary
import Combine

// MARK: - CoreOptionsScope

/// Describes the scope at which core options are read and written.
///
/// When a game context is provided, reads and writes use the per-game
/// override key (`<ClassName>.<md5>.<optionKey>`), falling back to the
/// per-core global key automatically. When no game context is set,
/// only the per-core global key is used.
enum CoreOptionsScope: Equatable {
    /// Options apply to all games played with this core.
    case perCore
    /// Options are scoped to a specific game, identified by its MD5 hash.
    case perGame(md5: String, displayName: String)
}

// MARK: - CoreOptionsViewModel

@MainActor
final class CoreOptionsViewModel: ObservableObject {
    /// Published list of available cores that implement CoreOptional
    @Published private(set) var availableCores: [PVCore] = []

    /// The currently selected core for options display
    @Published var selectedCore: (core: PVCore, coreClass: CoreOptional.Type)?

    /// MD5 hash of the currently scoped game, or `nil` for core-global scope.
    @Published private(set) var gameMD5: String?

    /// Human-readable display name for the currently scoped game.
    @Published private(set) var gameDisplayName: String?

    private var cancellables = Set<AnyCancellable>()

    /// The current read/write scope — `.perGame` when a game context is set,
    /// `.perCore` otherwise.
    var scope: CoreOptionsScope {
        if let md5 = gameMD5, let name = gameDisplayName {
            return .perGame(md5: md5, displayName: name)
        }
        return .perCore
    }

    /// Create a view model with an optional game context.
    ///
    /// - Parameter game: When non-nil, reads and writes are scoped to this
    ///   game's MD5 hash so per-game overrides are applied.
    init(game: PVGame? = nil) {
        if let game = game, !game.md5Hash.isEmpty {
            self.gameMD5 = game.md5Hash
            self.gameDisplayName = game.title
        }
        loadAvailableCores()
    }

    /// Configure the view model for a specific game context.
    ///
    /// Pass `nil` to revert to core-global scope. A game with an empty
    /// `md5Hash` is treated the same as `nil` (per-core scope).
    func setGame(_ game: PVGame?) {
        guard let game = game, !game.md5Hash.isEmpty else {
            gameMD5 = nil
            gameDisplayName = nil
            return
        }
        gameMD5 = game.md5Hash
        gameDisplayName = game.title
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

    /// Get the current value for an option, respecting the active scope.
    ///
    /// When `scope == .perGame`, the per-game key is checked first and falls
    /// back to the per-core global key automatically via `storedValueForOption`.
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

    /// Set a new value for an option, respecting the active scope.
    ///
    /// When `scope == .perGame`, the value is written to the per-game key so
    /// it does not affect other games using the same core.
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

    /// Returns `true` if the active game has a per-game override stored for
    /// the given option. Always returns `false` in `.perCore` scope.
    ///
    /// Use this to show an "overridden" badge in the option row UI.
    func hasPerGameOverride(for option: CoreOption) -> Bool {
        guard let coreClass = selectedCore?.coreClass,
              let md5 = gameMD5 else { return false }
        return coreClass.hasPerGameOverride(for: option, md5: md5)
    }

    /// Reset a single option to its effective default for the current scope.
    ///
    /// - In `.perGame` scope: removes the per-game override key so the option
    ///   reverts to the per-core global value on the next read.
    /// - In `.perCore` scope: writes the option's declared default value to
    ///   the per-core global key.
    func resetToDefault(option: CoreOption) {
        guard let coreClass = selectedCore?.coreClass else { return }

        switch scope {
        case .perGame(let md5, _):
            coreClass.resetOption(option, forMD5: md5)
        case .perCore:
            if let defaultValue = option.defaultValue {
                coreClass.setValue(defaultValue, forOption: option)
            }
        }
    }
}
