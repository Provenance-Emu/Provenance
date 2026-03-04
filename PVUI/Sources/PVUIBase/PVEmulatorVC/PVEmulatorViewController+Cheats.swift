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

#if canImport(UIKit)
import UIKit
#endif
import PVEmulatorCore

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
                guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: self.core.coreIdentifier) else {
                    completion(.error(.noCoreFound(self.core.coreIdentifier ?? "nil")))
                    return
                }
                do {
                    let baseFilename = "\(game.md5Hash).\(Date().timeIntervalSinceReferenceDate)"
                    let saveURL = await saveStatePath.appendingPathComponent("\(baseFilename).svc", isDirectory: false)
                    let saveFile = await PVFile(withURL: saveURL, relativeRoot: .iCloud)
                    /* In order to avoid modifying realm schema the codeType is added in the
                       type field next to cheat code name with -~- separator */
                    let saveType = codeType.isEmpty ? type : "\(type)-~-\(codeType)"
                    var cheatsState: PVCheats?
                    try realm.write {
                        let cs = PVCheats(withGame: self.game, core: core, code: modString, type: saveType, enabled: false, file: saveFile)
                        realm.add(cs)
                        cheatsState = cs
                    }
                    if let cheatsState {
                        Task {
                            await LibrarySerializer.storeMetadata(cheatsState, completion: { result in
                                switch result {
                                case let .success(url):
                                    ILOG("Serialized cheats state metadata to (\(url.path))")
                                case let .error(error):
                                    ELOG("Failed to serialize cheats metadata. \(error)")
                                }
                            })
                        }
                    }
                } catch {
                    completion(.error(.realmWriteError(error)))
                    return
                }
                // All done successfully
                completion(.success)
            } else {
                let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid cheat code"])
                completion(.error(.coreCheatsError(error)))
            }
        } else {
            WLOG("Core \(core.description) doesn't support cheats states.")
            completion(.error(.cheatsUnsupportedByCore))
            return
        }
    }

    func cheatsViewControllerUpdateState(_: Any, cheat: PVCheats, cheatIndex: UInt8,
        completion: @escaping CheatsCompletion) {
        if let gameWithCheat = core as? GameWithCheat {
            var cheatType = cheat.type ?? ""
            var codeType = ""
            if cheatType.contains("-~-") {
                let types = cheatType.components(separatedBy: "-~-")
                cheatType = types[0]
                codeType = types[1]
            }
            if gameWithCheat.setCheat(code: cheat.code, type:cheatType, codeType: codeType, cheatIndex: cheatIndex, enabled:cheat.enabled) {
                ILOG("Succeeded applying cheat: \(cheat.code ?? "null") \(cheat.type ?? "null") \(cheat.enabled)")
                completion(.success)
            } else {
                let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid cheat code"])
                completion(.error(.coreCheatsError(error)))
            }
        } else {
            WLOG("Core \(core.description) doesn't support cheats states.")
            completion(.error(.cheatsUnsupportedByCore))
            return
        }
    }

    /// Resolve the libretro database name for the current game's system.
    private var gameLibretroDatabaseName: String? {
        guard let sysID = SystemIdentifier(rawValue: game.systemIdentifier) else { return nil }
        let name = sysID.libretroDatabaseName
        return name == "Unknown" ? nil : name
    }

    @objc func showCheatsMenu() {
        Task.detached { [weak self ] in
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
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
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
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
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

    func recoverCheatCodes() async {
        do {
            let fileManager = FileManager.default
            let directoryContents = try await fileManager.contentsOfDirectory(
                at: saveStatePath,
                includingPropertiesForKeys:[.contentModificationDateKey]
            ).filter { $0.lastPathComponent.hasSuffix(".svc.json") }
            .sorted(by: {
                let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
                let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
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
                        let cheat = try LibrarySerializer.retrieve(url, as: PVCheats.DomainType.self)
                        if !cheat.id.isEmpty,
                           realm.object(ofType: PVCheats.self, forPrimaryKey: cheat.id) != nil {
                            continue
                        } else {
                            @ThreadSafe var cheat: PVCheats? = await cheat.asRealm()
                            if let cheat = cheat {
                                realm.writeAsync {
                                    realm.add(cheat)
                                }
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

import PVEmulatorCore
import PVCoreBridge

@objc extension PVEmulatorCore {
    @objc public func setCheat(code: String, type: String, enabled: Bool) -> Bool {
        return false
    }
    @objc public var supportsCheatCode: Bool {
        return false
    }
    /* This is list of cheat code types (will be passed to codeType) */
    @objc public var cheatCodeTypes: [String] {
        return [];
    }
    /* This is always called, with blank codeType if none is provided */
    @objc public func setCheat(
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool) -> Bool {
        return self.setCheat(code:code, type:type, enabled:enabled)
    }
    @objc public func resetCheatCodes() {
    }
}
