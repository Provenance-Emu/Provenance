//
//  PVEmulatorViewController+Cheats.swift
//  Provenance
//

import PVLibrary
import PVSupport
import PVPrimitives
import PVSystems
import RealmSwift
import PVRealm
import PVLogging
import PVCoreBridge

#if canImport(UIKit)
import UIKit
#endif
import PVEmulatorCore

// MARK: - Cheat Code Normalization

private enum CheatCodeNormalizer {
    /// Matches non-alphanumeric characters (excluding hyphens, brackets, colons, and plus)
    /// and whitespace — replaced with '+' as the canonical multi-code separator.
    private static let separatorRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[^a-zA-Z0-9-\\[\\]:+]+|[\\s]+", options: .caseInsensitive)
    }()
    /// Collapses runs of '+' into a single '+'.
    private static let multiPlusRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[+]+|[\\s]+", options: .caseInsensitive)
    }()
    /// Strips leading and trailing '+' characters.
    private static let leadTrailPlusRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^[+]+|[+]+$", options: .caseInsensitive)
    }()

    /// Normalizes a raw cheat code string into a canonical form:
    /// uppercased, non-alphanumeric separators → '+', collapsed, trimmed.
    static func normalize(_ code: String) -> String {
        let upper = code.uppercased()
        var range = NSRange(upper.startIndex..., in: upper)
        var result = separatorRegex.stringByReplacingMatches(in: upper, range: range, withTemplate: "+")
        range = NSRange(result.startIndex..., in: result)
        result = multiPlusRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "+")
        range = NSRange(result.startIndex..., in: result)
        result = leadTrailPlusRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        return result
    }
}

// MARK: - Cheat State Management

extension PVEmulatorViewController {

    /// Applies a cheat code to the core and persists it to Realm.
    ///
    /// - Throws: `CheatsStateError` on failure.
    @MainActor
    func setCheatState(
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool
    ) async throws(CheatsStateError) {
        guard let gameWithCheat = core as? GameWithCheat else {
            WLOG("Core \(core.description) doesn't support cheats.")
            throw .cheatsUnsupportedByCore
        }

        // Capture values before any suspension point — avoids accessing
        // Realm objects (game, core) after an await.
        guard let game = self.game, !game.isInvalidated else {
            ELOG("setCheatState: game is nil or invalidated")
            throw .realmWriteError(NSError(domain: "com.provenance-emu.cheats", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Game is not available"]))
        }
        let gameMD5 = game.md5Hash
        let coreIdentifier = self.core.coreIdentifier
        let cheatsDir = cheatsPath

        guard !gameMD5.isEmpty else {
            ELOG("Game MD5 hash is empty — cannot save cheat")
            throw .realmWriteError(NSError(domain: "com.provenance-emu.cheats", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Game has no MD5 hash; cannot save cheat"]))
        }

        let normalizedCode = CheatCodeNormalizer.normalize(code)
        DLOG("Formatted CheatCode \(normalizedCode)")

        guard gameWithCheat.setCheat(code: normalizedCode, type: type, codeType: codeType,
                                     cheatIndex: cheatIndex, enabled: enabled) else {
            throw .coreCheatsError(NSError(domain: "com.provenance-emu.cheats", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid cheat code"]))
        }

        DLOG("Succeeded applying cheat: \(normalizedCode) \(type) \(enabled)")

        // Persist to Realm
        let realm: Realm
        do {
            realm = try await Realm()
        } catch {
            ELOG("Realm() failed: \(error)")
            throw .realmWriteError(error)
        }

        guard let realmCore = realm.object(ofType: PVCore.self, forPrimaryKey: coreIdentifier) else {
            throw .noCoreFound(coreIdentifier ?? "nil")
        }

        try? FileManager.default.createDirectory(at: cheatsDir, withIntermediateDirectories: true)
        let baseFilename = "\(gameMD5).\(Date().timeIntervalSinceReferenceDate)"
        let saveURL = cheatsDir.appendingPathComponent("\(baseFilename).svc", isDirectory: false)
        let saveFile = PVFile(withURL: saveURL, relativeRoot: .iCloud)

        // Write to Realm, then freeze OUTSIDE the write transaction.
        // Freezing inside realm.write{} crashes (Realm objects cannot be
        // frozen during a write transaction).
        var newCheat: PVCheats?
        do {
            try realm.write {
                guard let realmGame = realm.object(ofType: PVGame.self, forPrimaryKey: gameMD5) else {
                    throw NSError(domain: "com.provenance-emu.cheats", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Game not found in Realm (md5=\(gameMD5))"])
                }
                let cs = PVCheats(withGame: realmGame, core: realmCore, code: normalizedCode,
                                  type: type, codeType: codeType, enabled: enabled, file: saveFile)
                realm.add(cs)
                newCheat = cs
            }
        } catch {
            throw .realmWriteError(error)
        }

        // Freeze after the write transaction completes — safe to cross threads.
        guard let frozenCheat = newCheat?.freeze() else { return }
        if !frozenCheat.isInvalidated {
            do {
                let url = try await LibrarySerializer.storeMetadata(frozenCheat)
                ILOG("Serialized cheats state metadata to (\(url.path))")
            } catch {
                ELOG("Failed to serialize cheats metadata: \(error)")
            }
        }
    }

    /// Legacy completion-based wrapper for callers that haven't migrated to async.
    @MainActor
    func setCheatState(
        code: String, type: String, codeType: String,
        cheatIndex: UInt8, enabled: Bool,
        completion: @escaping CheatsCompletion
    ) async {
        do {
            try await setCheatState(code: code, type: type, codeType: codeType,
                                    cheatIndex: cheatIndex, enabled: enabled)
            completion(.success)
        } catch {
            completion(.error(error))
        }
    }

    func cheatsViewControllerUpdateState(
        _: Any, cheat: PVCheats, cheatIndex: UInt8,
        completion: @escaping CheatsCompletion
    ) {
        guard let gameWithCheat = core as? GameWithCheat else {
            WLOG("Core \(core.description) doesn't support cheats.")
            completion(.error(.cheatsUnsupportedByCore))
            return
        }
        let cheatCode = cheat.code ?? ""
        let cheatType = cheat.type ?? ""
        if gameWithCheat.setCheat(code: cheatCode, type: cheatType, codeType: cheat.codeType,
                                  cheatIndex: cheatIndex, enabled: cheat.enabled) {
            ILOG("Succeeded applying cheat: \(cheatCode) \(cheatType) \(cheat.enabled)")
            completion(.success)
        } else {
            let error = NSError(domain: "com.provenance-emu.cheats", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid cheat code"])
            completion(.error(.coreCheatsError(error)))
        }
    }

    // MARK: - Cheat Types

    func getCheatTypes() -> [String] {
        (core as? GameWithCheat)?.cheatCodeTypes ?? []
    }

    /// Resolve the libretro `cht/` folder name (e.g. `Sega - Dreamcast`) for cheat DB / online lookup.
    ///
    /// RetroArch-launched titles often store `systemIdentifier == com.provenance.retroarch`, which would map to
    /// a non-existent `Retroarch` cheat tree — prefer the linked `PVSystem`, then Flycast core detection.
    private var gameLibretroDatabaseName: String? {
        SystemIdentifier.cheatLookupLibretroFolderName(
            gameSystemIdentifier: game.systemIdentifier,
            linkedPVSystemIdentifier: game.system?.identifier,
            coreIdentifier: core.coreIdentifier
        )
    }
}

// MARK: - Cheats Menu Presentation

extension PVEmulatorViewController {

    @objc func showCheatsMenu() {
        guard game != nil else {
            ELOG("showCheatsMenu: game is nil, cannot present cheat sheet")
            return
        }

        core.resetCheatCodes()
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.recoverCheatCodes()
        }

        let cheats = Array(game.cheats)
        let coreID = core.coreIdentifier
        let cheatTypes = getCheatTypes()
        let gameMD5 = game.md5Hash
        let gameTitle = game.title
        let systemName = gameLibretroDatabaseName
        let romSerial = game.romSerial

        let onSaveCheat: (String, String, String, UInt8, Bool) -> Void = { [weak self] code, type, codeType, cheatIndex, enabled in
            guard let self else { return }
            Task { @MainActor in
                await self.setCheatState(code: code, type: type, codeType: codeType,
                                         cheatIndex: cheatIndex, enabled: enabled) { result in
                    switch result {
                    case .success: DLOG("Cheat saved successfully")
                    case let .error(error): ELOG("Error saving cheat: \(error)")
                    }
                }
            }
        }

        let onUpdateCheat: (PVCheats, UInt8) -> Void = { [weak self] cheat, cheatIndex in
            guard let self else { return }
            self.cheatsViewControllerUpdateState(self, cheat: cheat, cheatIndex: cheatIndex) { result in
                switch result {
                case .success: DLOG("Cheat updated successfully")
                case let .error(error): ELOG("Error updating cheat: \(error)")
                }
            }
        }

        #if os(tvOS)
        let cheatsVC = TVOSCheatsHostingController(
            cheats: cheats, coreID: coreID, cheatTypes: cheatTypes,
            gameMD5: gameMD5, gameTitle: gameTitle,
            gameSystemIdentifier: systemName, romSerial: romSerial,
            onSaveCheat: onSaveCheat,
            onUpdateCheat: onUpdateCheat,
            onDone: { [weak self] in
                guard let self else { return }
                self.enableControllerInput(false)
                self.view.becomeFirstResponder()
            }
        )
        cheatsVC.modalPresentationStyle = .blurOverFullScreen
        present(cheatsVC, animated: true)
        #endif

        #if os(iOS)
        let cheatsVC = iOSCheatsHostingController(
            cheats: cheats, coreID: coreID, cheatTypes: cheatTypes,
            gameMD5: gameMD5, gameTitle: gameTitle,
            gameSystemIdentifier: systemName, romSerial: romSerial,
            onSaveCheat: onSaveCheat,
            onUpdateCheat: onUpdateCheat,
            onDone: { [weak self] in
                self?.enableControllerInput(false)
            }
        )
        cheatsVC.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad ? .formSheet : .pageSheet
        self.enableControllerInput(false)
        present(cheatsVC, animated: true)
        #endif
    }
}

// MARK: - Cheat Code Recovery

extension PVEmulatorViewController {

    @MainActor
    func recoverCheatCodes() async {
        do {
            let fileManager = FileManager.default

            let cheatFiles = try collectCheatFiles(fileManager: fileManager)
            guard !cheatFiles.isEmpty else { return }

            guard let currentGame = self.game, !currentGame.isInvalidated else {
                ELOG("recoverCheatCodes: game is nil or invalidated")
                return
            }
            let gameMD5 = currentGame.md5Hash

            let realm = try await Realm()
            let existingCheatKeys = buildExistingCheatKeys(realm: realm, gameMD5: gameMD5)

            for url in cheatFiles {
                let file = url.lastPathComponent.lowercased()
                let svcKey = file.replacingOccurrences(of: "svc.json", with: "svc")

                guard existingCheatKeys[svcKey] == nil else { continue }

                do {
                    try recoverSingleCheat(from: url, realm: realm)
                } catch {
                    ELOG("Error recovering cheat from \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        } catch {
            ELOG("Error recovering cheat codes: \(error)")
        }
    }

    /// Collects .svc.json files from both the cheats directory and legacy save-states directory,
    /// deduplicating by filename (preferring the cheats directory copy).
    private func collectCheatFiles(fileManager: FileManager) throws -> [URL] {
        func svcFiles(in directory: URL) throws -> [URL] {
            guard fileManager.fileExists(atPath: directory.path) else { return [] }
            return try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ).filter { $0.lastPathComponent.hasSuffix(".svc.json") }
        }

        let newFiles = try svcFiles(in: cheatsPath)
        let legacyFiles = try svcFiles(in: saveStatePath)

        // Deduplicate — prefer cheatsPath copy
        var seen = Set<String>()
        var merged: [URL] = []
        for url in newFiles + legacyFiles {
            if seen.insert(url.lastPathComponent.lowercased()).inserted {
                merged.append(url)
            }
        }

        return try merged.sorted { lhs, rhs in
            let d0 = try lhs.promisedItemResourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate ?? .distantPast
            let d1 = try rhs.promisedItemResourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate ?? .distantPast
            return d0 < d1
        }
    }

    /// Builds a lookup of existing cheat identifiers to avoid duplicate imports.
    private func buildExistingCheatKeys(realm: Realm, gameMD5: String) -> [String: Bool] {
        var keys: [String: Bool] = [:]
        guard let realmGame = realm.object(ofType: PVGame.self, forPrimaryKey: gameMD5) else {
            return keys
        }
        for cheat in realmGame.cheats {
            if let fileURL = cheat.file?.url {
                keys[fileURL.lastPathComponent.lowercased()] = true
            }
            keys[cheat.id] = true
        }
        return keys
    }

    /// Deserializes a single .svc.json file and writes it to Realm if not already present.
    private func recoverSingleCheat(from url: URL, realm: Realm) throws {
        guard let realmCore = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
            presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
            return
        }

        let cheatInfo = try LibrarySerializer.retrieve(url, as: PVCheats.DomainType.self)

        // Skip if already in Realm by primary key
        if !cheatInfo.id.isEmpty,
           realm.object(ofType: PVCheats.self, forPrimaryKey: cheatInfo.id) != nil {
            return
        }

        try realm.write {
            guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: cheatInfo.game.md5Hash) else {
                ELOG("recoverCheatCodes: game not found for md5=\(cheatInfo.game.md5Hash), skipping")
                return
            }
            let fileURL = cheatInfo.game.file.fileName.cheatsPath
                .appendingPathComponent(cheatInfo.file.fileName)
            let saveFile = PVFile(withURL: fileURL, relativeRoot: .iCloud)
            let pvCheat = PVCheats(
                withGame: pvGame, core: realmCore,
                code: cheatInfo.code, type: cheatInfo.type,
                codeType: cheatInfo.codeType, enabled: cheatInfo.enabled,
                file: saveFile
            )
            pvCheat.id = cheatInfo.id
            pvCheat.date = cheatInfo.date
            pvCheat.lastOpened = cheatInfo.lastOpened
            realm.add(pvCheat)
        }
    }
}

// MARK: - PVEmulatorCore Cheat Defaults

@objc extension PVEmulatorCore {
    @objc public func setCheat(code: String, type: String, enabled: Bool) -> Bool {
        return false
    }
    @objc public var supportsCheatCode: Bool {
        return false
    }
    @objc public var cheatCodeTypes: [String] {
        return []
    }
    @objc public func setCheat(
        code: String, type: String, codeType: String,
        cheatIndex: UInt8, enabled: Bool
    ) -> Bool {
        return self.setCheat(code: code, type: type, enabled: enabled)
    }
    @objc public func resetCheatCodes() {
    }
}
