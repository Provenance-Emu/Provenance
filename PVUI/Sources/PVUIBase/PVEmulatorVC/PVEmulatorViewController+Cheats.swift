//
//  PVEmulatorViewController+Cheats.swift
//  Provenance
//

import PVLibrary
import PVSupport
import PVPrimitives
import RealmSwift
import PVRealm
import PVLogging
import PVCoreBridge

#if canImport(UIKit)
import UIKit
#endif
import PVEmulatorCore

private let cheatErrorDomain = "com.provenance-emu.cheats"

extension PVEmulatorViewController {

    /// Pre-compiled regex patterns used to normalize cheat code strings.
    private static let cheatNormalizeRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[^a-zA-Z0-9-\\[\\]:+]+|[\\s]+", options: .caseInsensitive)
    }()
    private static let cheatMultiPlusRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[+]+|[\\s]+", options: .caseInsensitive)
    }()
    private static let cheatLeadTrailPlusRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^[+]+|[+]+$", options: .caseInsensitive)
    }()

    @MainActor
    func setCheatState(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool, completion: @escaping CheatsCompletion) async {
        if let gameWithCheat = core as? GameWithCheat {
            // Normalize code: replace non-alphanumeric separators with '+', collapse multiples, strip leading/trailing
            let upper = code.uppercased()
            var range = NSRange(upper.startIndex..., in: upper)
            var modString = Self.cheatNormalizeRegex.stringByReplacingMatches(in: upper, range: range, withTemplate: "+")
            range = NSRange(modString.startIndex..., in: modString)
            modString = Self.cheatMultiPlusRegex.stringByReplacingMatches(in: modString, range: range, withTemplate: "+")
            range = NSRange(modString.startIndex..., in: modString)
            modString = Self.cheatLeadTrailPlusRegex.stringByReplacingMatches(in: modString, range: range, withTemplate: "")
            DLOG("Formatted CheatCode \(modString)")
            if gameWithCheat.setCheat(code: modString, type: type, codeType: codeType, cheatIndex: cheatIndex, enabled: enabled) {
                DLOG("Succeeded applying cheat: \(modString) \(type) \(enabled)")
                guard let realm = try? await Realm() else {
                    ELOG("Realm() failed")
                    return
                }
                // Look up coreIdentifier before any await to avoid @ThreadSafe re-resolution issues
                let coreIdentifier = self.core.coreIdentifier
                let gameMD5 = self.game.md5Hash
                guard !gameMD5.isEmpty else {
                    ELOG("Game MD5 hash is empty — cannot save cheat")
                    completion(.error(.realmWriteError(NSError(domain: cheatErrorDomain, code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Game has no MD5 hash; cannot save cheat"]))))
                    return
                }
                guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: coreIdentifier) else {
                    completion(.error(.noCoreFound(coreIdentifier ?? "nil")))
                    return
                }

                do {
                    let baseFilename = "\(gameMD5).\(Date().timeIntervalSinceReferenceDate)"
                    let saveURL = cheatsPath.appendingPathComponent("\(baseFilename).svc", isDirectory: false)
                    let saveFile = PVFile(withURL: saveURL, relativeRoot: .iCloud)
                    var frozenCheat: PVCheats?
                    try realm.write {
                        // Look up game strictly from this realm instance.
                        // Do NOT fall back to self.game (@ThreadSafe) — it may belong to a
                        // different Realm instance and would cause a cross-Realm relationship crash.
                        guard let realmGame = realm.object(ofType: PVGame.self, forPrimaryKey: gameMD5) else {
                            throw NSError(domain: cheatErrorDomain, code: 0,
                                          userInfo: [NSLocalizedDescriptionKey: "Game not found in Realm (md5=\(gameMD5))"])
                        }
                        let cs = PVCheats(withGame: realmGame, core: core, code: modString, type: type, codeType: codeType, enabled: enabled, file: saveFile)
                        realm.add(cs)
                        // Freeze immediately so it can be safely used across thread boundaries
                        frozenCheat = cs.freeze()
                    }
                    if let frozenCheat, !frozenCheat.isInvalidated {
                        do {
                            let url = try await LibrarySerializer.storeMetadata(frozenCheat)
                            ILOG("Serialized cheats state metadata to (\(url.path))")
                        } catch {
                            ELOG("Failed to serialize cheats metadata. \(error)")
                        }
                    }
                } catch {
                    completion(.error(.realmWriteError(error)))
                    return
                }
                // All done successfully
                completion(.success)
            } else {
                let error = NSError(domain: cheatErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid cheat code"])
                completion(.error(.coreCheatsError(error)))
            }
        } else {
            WLOG("Core \(core.description) doesn't support cheats states.")
            completion(.error(.cheatsUnsupportedByCore))
        }
    }

    func cheatsViewControllerUpdateState(_: Any, cheat: PVCheats, cheatIndex: UInt8,
        completion: @escaping CheatsCompletion) {
        if let gameWithCheat = core as? GameWithCheat {
            let cheatCode = cheat.code ?? ""
            let cheatType = cheat.type ?? ""
            let codeType = cheat.codeType
            if gameWithCheat.setCheat(code: cheatCode, type: cheatType, codeType: codeType, cheatIndex: cheatIndex, enabled: cheat.enabled) {
                ILOG("Succeeded applying cheat: \(cheatCode) \(cheatType) \(cheat.enabled)")
                completion(.success)
            } else {
                let error = NSError(domain: cheatErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid cheat code"])
                completion(.error(.coreCheatsError(error)))
            }
        } else {
            WLOG("Core \(core.description) doesn't support cheats states.")
            completion(.error(.cheatsUnsupportedByCore))
        }
    }

    /// Resolve the libretro cheat system name for the current game's system.
    ///
    /// Uses `libretroCheatSystemName` which maps to the actual cht/ directory name
    /// in the libretro cheat database (may differ from `libretroDatabaseName` used
    /// for thumbnail URLs — e.g. DOOM cheats live under "PrBoom").
    private var gameLibretroDatabaseName: String? {
        guard let sysID = SystemIdentifier(rawValue: game.systemIdentifier) else { return nil }
        let name = sysID.libretroCheatSystemName
        return name == "Unknown" ? nil : name
    }

    @objc func showCheatsMenu() {
        // Guard against a nil game reference — @ThreadSafe resolves an Optional
        // and the IUO force-unwrap below would crash if the Realm object is gone.
        guard game != nil else {
            ELOG("showCheatsMenu: game is nil, cannot present cheat sheet")
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.recoverCheatCodes()
        }

        self.core.resetCheatCodes()

        #if os(tvOS)
        // Use SwiftUI-based cheats view on tvOS for reliability
        let cheatsVC = TVOSCheatsHostingController(
            cheats: game.cheats,
            coreID: core.coreIdentifier,
            cheatTypes: getCheatTypes(),
            gameMD5: game.md5Hash,
            gameTitle: game.title,
            gameSystemIdentifier: gameLibretroDatabaseName,
            romSerial: game.romSerial,
            onSaveCheat: { [weak self] code, type, codeType, cheatIndex, enabled in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.setCheatState(code: code, type: type, codeType: codeType, cheatIndex: cheatIndex, enabled: enabled) { result in
                        switch result {
                        case .success:
                            DLOG("Cheat saved successfully")
                        case let .error(error):
                            ELOG("Error saving cheat: \(error)")
                        }
                    }
                }
            },
            onUpdateCheat: { [weak self] cheat, cheatIndex in
                guard let self = self else { return }
                self.cheatsViewControllerUpdateState(self, cheat: cheat, cheatIndex: cheatIndex) { result in
                    switch result {
                    case .success:
                        DLOG("Cheat updated successfully")
                    case let .error(error):
                        ELOG("Error updating cheat: \(error)")
                    }
                }
            },
            onDone: { [weak self] in
                guard let self = self else { return }
                // Don't resume emulation here - the presenting menu handles that.
                // Calling setPauseEmulation/isShowingMenu directly would unpause the game
                // even if the pause menu is still visible behind this sheet.
                self.enableControllerInput(false)
                // Ensure the emulator view can receive gesture events again
                self.view.becomeFirstResponder()
            }
        )
        cheatsVC.modalPresentationStyle = .blurOverFullScreen
        present(cheatsVC, animated: true)
        return
        #endif

        #if os(iOS)
        let cheatsVC = iOSCheatsHostingController(
            cheats: game.cheats,
            coreID: core.coreIdentifier,
            cheatTypes: getCheatTypes(),
            gameMD5: game.md5Hash,
            gameTitle: game.title,
            gameSystemIdentifier: gameLibretroDatabaseName,
            romSerial: game.romSerial,
            onSaveCheat: { [weak self] code, type, codeType, cheatIndex, enabled in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.setCheatState(code: code, type: type, codeType: codeType, cheatIndex: cheatIndex, enabled: enabled) { result in
                        switch result {
                        case .success:
                            DLOG("Cheat saved successfully")
                        case let .error(error):
                            ELOG("Error saving cheat: \(error)")
                        }
                    }
                }
            },
            onUpdateCheat: { [weak self] cheat, cheatIndex in
                guard let self = self else { return }
                self.cheatsViewControllerUpdateState(self, cheat: cheat, cheatIndex: cheatIndex) { result in
                    switch result {
                    case .success:
                        DLOG("Cheat updated successfully")
                    case let .error(error):
                        ELOG("Error updating cheat: \(error)")
                    }
                }
            },
            onDone: { [weak self] in
                guard let self = self else { return }
                // Don't resume emulation here - the presenting menu handles that.
                // Calling setPauseEmulation/isShowingMenu directly would unpause the game
                // even if the pause menu is still visible behind this sheet.
                self.enableControllerInput(false)
            }
        )
        cheatsVC.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad ? .formSheet : .pageSheet
        self.enableControllerInput(false)
        present(cheatsVC, animated: true)
        #endif
    }

    func getCheatTypes() -> [String] {
        guard let gameWithCheat = core as? GameWithCheat else {
            return []
        }
        return gameWithCheat.cheatCodeTypes
    }

    @MainActor
    func recoverCheatCodes() async {
        do {
            let fileManager = FileManager.default

            /// Collect .svc.json files from a directory, returning empty array if the directory doesn't exist.
            func svcFiles(in directory: URL) throws -> [URL] {
                guard fileManager.fileExists(atPath: directory.path) else { return [] }
                return try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey]
                ).filter { $0.lastPathComponent.hasSuffix(".svc.json") }
            }

            // Scan both the new Cheats/ directory and the legacy Save States directory so that
            // existing .svc.json files written before this path change are still recovered.
            let newFiles = try svcFiles(in: cheatsPath)
            let legacyFiles = try svcFiles(in: saveStatePath)

            // Deduplicate by filename — prefer the copy in cheatsPath if it exists in both.
            var seen = Set<String>()
            var merged: [URL] = []
            for url in newFiles + legacyFiles {
                let name = url.lastPathComponent.lowercased()
                if seen.insert(name).inserted {
                    merged.append(url)
                }
            }

            let directoryContents = try merged.sorted(by: {
                let date0 = try $0.promisedItemResourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                let date1 = try $1.promisedItemResourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                return date0.compare(date1) == .orderedAscending
            })

            let realm = try await Realm()

            var cheats: [String: Bool] = [:]
            game.realm?.refresh()
            for code in game.cheats {
                if let fileURL = code.file?.url {
                    cheats[fileURL.lastPathComponent.lowercased()] = true
                }
                cheats[code.id] = true
            }
            for url in directoryContents {
                let file = url.lastPathComponent.lowercased()
                if fileManager.fileExists(atPath: url.path) &&
                    file.contains("svc.json") &&
                    cheats.index(forKey: file.replacingOccurrences(of: "svc.json", with: "svc")) == nil {
                    do {
                        guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: core.coreIdentifier) else {
                            presentError("No core in database with id \(self.core.coreIdentifier ?? "null")", source: self.view)
                            return
                        }
                        let cheatInfo = try LibrarySerializer.retrieve(url, as: PVCheats.DomainType.self)
                        if !cheatInfo.id.isEmpty,
                           realm.object(ofType: PVCheats.self, forPrimaryKey: cheatInfo.id) != nil {
                            continue
                        } else {
                            // Build the PVCheats object directly using the already-open realm
                            // so we never open a second Realm instance inside the write path
                            // (asRealm() used to call try! Realm() which could crash).
                            do {
                                try realm.write {
                                    guard let pvGame = realm.object(ofType: PVGame.self, forPrimaryKey: cheatInfo.game.md5Hash) else {
                                        ELOG("recoverCheatCodes: game not found for md5=\(cheatInfo.game.md5Hash), skipping")
                                        return
                                    }
                                    let fileURL = cheatInfo.game.file.fileName.cheatsPath
                                        .appendingPathComponent(cheatInfo.file.fileName)
                                    let saveFile = PVFile(withURL: fileURL, relativeRoot: .iCloud)
                                    let pvCheat = PVCheats(
                                        withGame: pvGame,
                                        core: core,
                                        code: cheatInfo.code,
                                        type: cheatInfo.type,
                                        codeType: cheatInfo.codeType,
                                        enabled: cheatInfo.enabled,
                                        file: saveFile
                                    )
                                    pvCheat.id = cheatInfo.id
                                    pvCheat.date = cheatInfo.date
                                    pvCheat.lastOpened = cheatInfo.lastOpened
                                    realm.add(pvCheat)
                                }
                            } catch {
                                ELOG("Failed to add recovered cheat to Realm: \(error)")
                            }
                        }
                    } catch {
                        ELOG("Error recovering cheat: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            ELOG("Error recovering cheat codes: \(error)")
        }
    }
}

@objc extension PVEmulatorCore {
    @objc public func setCheat(code: String, type: String, enabled: Bool) -> Bool {
        return false
    }
    @objc public var supportsCheatCode: Bool {
        return false
    }
    /* This is list of cheat code types (will be passed to codeType) */
    @objc public var cheatCodeTypes: [String] {
        return []
    }
    /* This is always called, with blank codeType if none is provided */
    @objc public func setCheat(
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool) -> Bool {
        return self.setCheat(code: code, type: type, enabled: enabled)
    }
    @objc public func resetCheatCodes() {
    }
}
