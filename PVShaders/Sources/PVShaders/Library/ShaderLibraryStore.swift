//
//  ShaderLibraryStore.swift
//  PVShaders
//
//  The user's filter state: selections per scope, parameter overrides,
//  favorites and recents. Selections, parameters and favorites sync through
//  iCloud key-value storage (`register()`); recents stay on the device.
//

import Foundation
import Observation
import Defaults
import PVLogging
import PVSettings

@MainActor
@Observable
public final class ShaderLibraryStore {
    public static let shared = ShaderLibraryStore()

    /// Most recently applied filters, newest first.
    public static let recentsLimit = 10
    /// Per-game selections kept in the synced payload.
    static let syncedGameSelectionLimit = 500
    /// Removals older than this are forgotten.
    static let tombstoneLifetime: TimeInterval = 90 * 24 * 60 * 60

    enum StorageKey {
        static let selections = "shaderLibrary.selections"
        static let parameters = "shaderLibrary.parameters"
        static let favorites = "shaderLibrary.favorites"
        static let recents = "shaderLibrary.recents"
        static let migrated = "shaderLibrary.migratedLegacyFilterMode"
    }

    enum SyncKey {
        static let selections = "pv.shaders.selections"
        static let parameters = "pv.shaders.parameters"
        static let favorites = "pv.shaders.favorites"
    }

    public private(set) var selections = StampedMap<ShaderSelection>()
    /// Keyed `"<shader id>|<parameter name>"`.
    public private(set) var parameters = StampedMap<Float>()
    public private(set) var favorites = StampedMap<Bool>()
    public private(set) var recents: [ShaderID] = []

    /// Bumped on every change, so renderers can cheaply notice edits.
    public private(set) var revision = 0

    @ObservationIgnored private let defaults: UserDefaults
    /// Resolved on first use: loading the library manifest is not free, and the
    /// store is created at launch to register for sync.
    @ObservationIgnored private let catalogProvider: () -> ShaderCatalog
    private var catalog: ShaderCatalog { catalogProvider() }

    public init(defaults: UserDefaults = .standard, catalog: @autoclosure @escaping () -> ShaderCatalog = .shared) {
        self.defaults = defaults
        self.catalogProvider = catalog
        selections = Self.load(StorageKey.selections, from: defaults) ?? StampedMap()
        parameters = Self.load(StorageKey.parameters, from: defaults) ?? StampedMap()
        favorites = Self.load(StorageKey.favorites, from: defaults) ?? StampedMap()
        recents = (defaults.stringArray(forKey: StorageKey.recents) ?? []).map(ShaderID.init(rawValue:))
        migrateLegacyFilterModeIfNeeded()
    }

    // MARK: - Selections

    public func selection(for scope: ShaderScope) -> ShaderSelection? {
        selections[scope.key]
    }

    /// Sets (or with `nil`, clears) a scope's selection.
    public func setSelection(_ selection: ShaderSelection?, for scope: ShaderScope) {
        selections.set(selection, for: scope.key)
        if case .global = scope, let selection, let legacy = selection.legacyMode {
            // Keep the legacy key in step for code that still reads it.
            Defaults[.metalFilterMode] = legacy
        }
        if case .always(let id) = selection {
            noteUsed(id)
        }
        didChange(StorageKey.selections, sync: SyncKey.selections)
    }

    /// The selection in effect for a game: game, then system, then global.
    public func effectiveSelection(gameMD5: String?, systemID: String?) -> ShaderSelection {
        if let md5 = gameMD5, !md5.isEmpty, let selection = selection(for: .game(md5)) {
            return selection
        }
        if let systemID, let selection = selection(for: .system(systemID)) {
            return selection
        }
        return selection(for: .global) ?? .off
    }

    /// The scope whose selection is in effect, for "applies to" labels.
    public func effectiveScope(gameMD5: String?, systemID: String?) -> ShaderScope {
        if let md5 = gameMD5, !md5.isEmpty, selection(for: .game(md5)) != nil { return .game(md5) }
        if let systemID, selection(for: .system(systemID)) != nil { return .system(systemID) }
        return .global
    }

    // MARK: - Parameters

    static func parameterKey(_ shader: ShaderID, _ name: String) -> String { "\(shader.rawValue)|\(name)" }

    /// The value to render with: the override if set, else the preset default.
    public func value(of parameter: ShaderParameterDescriptor, in shader: ShaderID) -> Float {
        if shader.kind == .native {
            return NativeShaderParameters.value(of: parameter)
        }
        return parameters[Self.parameterKey(shader, parameter.name)] ?? parameter.initial
    }

    /// Whether the user changed `parameter` from the preset default.
    public func isOverridden(_ parameter: ShaderParameterDescriptor, in shader: ShaderID) -> Bool {
        value(of: parameter, in: shader) != parameter.initial
    }

    /// Sets a parameter; `nil` (or the default value) removes the override.
    public func setValue(_ value: Float?, of parameter: ShaderParameterDescriptor, in shader: ShaderID) {
        let clamped = value.map(parameter.clamp)
        let stored = clamped == parameter.initial ? nil : clamped
        if shader.kind == .native {
            NativeShaderParameters.set(stored, for: parameter)
        }
        parameters.set(stored, for: Self.parameterKey(shader, parameter.name))
        didChange(StorageKey.parameters, sync: SyncKey.parameters)
    }

    /// Resets every parameter of `shader` to its default.
    public func resetParameters(of shader: ShaderID) {
        guard let entry = catalog.entry(for: shader) else { return }
        for parameter in entry.editableParameters {
            if shader.kind == .native {
                NativeShaderParameters.set(nil, for: parameter)
            }
            parameters.set(nil, for: Self.parameterKey(shader, parameter.name))
        }
        didChange(StorageKey.parameters, sync: SyncKey.parameters)
    }

    // MARK: - Favorites and recents

    public func isFavorite(_ id: ShaderID) -> Bool { favorites[id.rawValue] == true }

    public var favoriteIDs: [ShaderID] { favorites.keys.sorted().map(ShaderID.init(rawValue:)) }

    public func setFavorite(_ favorite: Bool, _ id: ShaderID) {
        favorites.set(favorite ? true : nil, for: id.rawValue)
        didChange(StorageKey.favorites, sync: SyncKey.favorites)
    }

    public func toggleFavorite(_ id: ShaderID) { setFavorite(!isFavorite(id), id) }

    /// Records `id` as just used (front of recents).
    public func noteUsed(_ id: ShaderID) {
        recents.removeAll { $0 == id }
        recents.insert(id, at: 0)
        if recents.count > Self.recentsLimit { recents.removeLast(recents.count - Self.recentsLimit) }
        defaults.set(recents.map(\.rawValue), forKey: StorageKey.recents)
        revision += 1
    }

    // MARK: - iCloud

    /// Registers the synced state with `iCloudSettingsSync`. Call before its `setup()`.
    public func register() {
        iCloudSettingsSync.register(.init(key: SyncKey.selections,
                                          localData: { [weak self] in self.flatMap { Self.encode($0.prunedSelections()) } },
                                          merge: { [weak self] data in MainActor.assumeIsolated { self?.mergeSelections(data) } }))
        iCloudSettingsSync.register(.init(key: SyncKey.parameters,
                                          localData: { [weak self] in self.flatMap { Self.encode($0.parameters) } },
                                          merge: { [weak self] data in MainActor.assumeIsolated { self?.mergeParameters(data) } }))
        iCloudSettingsSync.register(.init(key: SyncKey.favorites,
                                          localData: { [weak self] in self.flatMap { Self.encode($0.favorites) } },
                                          merge: { [weak self] data in MainActor.assumeIsolated { self?.mergeFavorites(data) } }))
    }

    func mergeSelections(_ data: Data) {
        guard let remote = try? JSONDecoder().decode(StampedMap<ShaderSelection>.self, from: data) else { return }
        if !selections.merge(remote).isEmpty { didChange(StorageKey.selections, sync: nil) }
    }

    func mergeParameters(_ data: Data) {
        guard let remote = try? JSONDecoder().decode(StampedMap<Float>.self, from: data) else { return }
        let changed = parameters.merge(remote)
        guard !changed.isEmpty else { return }
        // Native filters render from their Defaults keys: write merged values through.
        for key in changed {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let shader = ShaderID(rawValue: parts[0])
            guard shader.kind == .native,
                  let descriptor = catalog.entry(for: shader)?.parameters.first(where: { $0.name == parts[1] }) else { continue }
            NativeShaderParameters.set(parameters[key], for: descriptor)
        }
        didChange(StorageKey.parameters, sync: nil)
    }

    func mergeFavorites(_ data: Data) {
        guard let remote = try? JSONDecoder().decode(StampedMap<Bool>.self, from: data) else { return }
        if !favorites.merge(remote).isEmpty { didChange(StorageKey.favorites, sync: nil) }
    }

    private func prunedSelections() -> StampedMap<ShaderSelection> {
        var copy = selections
        copy.prune(tombstonesBefore: Date().addingTimeInterval(-Self.tombstoneLifetime),
                   prefix: ShaderScope.gamePrefix, limit: Self.syncedGameSelectionLimit)
        return copy
    }

    // MARK: - Persistence

    private func didChange(_ storageKey: String, sync syncKey: String?) {
        switch storageKey {
        case StorageKey.selections: defaults.set(Self.encode(selections), forKey: storageKey)
        case StorageKey.parameters: defaults.set(Self.encode(parameters), forKey: storageKey)
        case StorageKey.favorites: defaults.set(Self.encode(favorites), forKey: storageKey)
        default: break
        }
        revision += 1
        if let syncKey {
            iCloudSettingsSync.pushBlob(key: syncKey)
        }
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func load<T: Decodable>(_ key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// First launch with this store: carry the legacy `metalFilterMode` over as the global selection.
    private func migrateLegacyFilterModeIfNeeded() {
        guard !defaults.bool(forKey: StorageKey.migrated) else { return }
        defaults.set(true, forKey: StorageKey.migrated)
        guard selections[ShaderScope.global.key] == nil else { return }
        let legacy = defaults.string(forKey: Defaults.Keys.metalFilterMode.name)
            .flatMap(MetalFilterModeOption.init(rawValue:)) ?? .none
        // Stamped in the past so any selection already in iCloud wins the first merge.
        selections.set(ShaderSelection(legacy: legacy), for: ShaderScope.global.key, at: .distantPast)
        defaults.set(Self.encode(selections), forKey: StorageKey.selections)
        ILOG("Shader library: migrated legacy filter mode \(legacy.rawValue)")
    }
}
