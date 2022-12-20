//
//  PVEmulatorViewController+Cheats.swift
//  Provenance
//

import PVLibrary
import PVSupport
import RealmSwift
import UIKit

public enum CheatsStateError: Error {
    case coreCheatsError(Error?)
    case coreNoCheatError(Error?)
    case cheatsUnsupportedByCore
    case noCoreFound(String)
    case realmWriteError(Error)
    case realmDeletionError(Error)

    var localizedDescription: String {
        switch self {
        case let .coreCheatsError(coreError): return "Core failed to Apply Cheats: \(coreError?.localizedDescription ?? "No reason given.")"
        case let .coreNoCheatError(coreError): return "Core failed to Disable Cheats: \(coreError?.localizedDescription ?? "No reason given.")"
        case .cheatsUnsupportedByCore: return "This core does not support Cheats"
        case let .noCoreFound(id): return "No core found to match id: \(id)"
        case let .realmWriteError(realmError): return "Unable to write Cheats State to realm: \(realmError.localizedDescription)"
        case let .realmDeletionError(realmError): return "Unable to delete old Cheats States from database: \(realmError.localizedDescription)"
        }
    }
}

public enum CheatsResult {
    case success
    case error(CheatsStateError)
}

public typealias CheatsCompletion = (CheatsResult) -> Void
public typealias NoCheatCompletion = CheatsCompletion

extension PVEmulatorViewController: PVCheatsViewControllerDelegate {
    struct CheatLoadState {
        static var isFirstLoad:Bool = true
    }

    func getIsFirstLoad() -> Bool {
        return CheatLoadState.isFirstLoad
    }
    func setIsFirstLoad(isFirstLoad:Bool) {
        CheatLoadState.isFirstLoad=isFirstLoad
    }

    func setCheatState(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool, completion: @escaping CheatsCompletion) {
        if let gameWithCheat = core as? GameWithCheat {
            // convert space to +
            var regex = try! NSRegularExpression(pattern: "[^a-zA-Z0-9-:+]+|[\\s]+", options: NSRegularExpression.Options.caseInsensitive)
            var range = NSRange(location: 0, length: code.count)
            var modString = regex.stringByReplacingMatches(in: code.uppercased(), options: [], range: range, withTemplate: "+")
            // clean +++
            regex = try! NSRegularExpression(pattern: "[+]+|[\\s]+", options: NSRegularExpression.Options.caseInsensitive)
            range = NSRange(location: 0, length: modString.count)
            modString = regex.stringByReplacingMatches(in: modString, options: [], range: range, withTemplate: "+")
            // clean + at front and back of code
            regex = try! NSRegularExpression(pattern: "^[+]+|[+]+$", options: NSRegularExpression.Options.caseInsensitive)
            range = NSRange(location: 0, length: modString.count)
            modString = regex.stringByReplacingMatches(in: modString, options: [], range: range, withTemplate: "")
            NSLog("Formatted CheatCode \(modString)")
            if (gameWithCheat.setCheat(code: modString, type:type, codeType: codeType, cheatIndex: cheatIndex, enabled:enabled)) {
                DLOG("Succeeded applying cheat: \(modString) \(type) \(enabled)")
                let realm = try! Realm()
                guard let core = realm.object(ofType: PVCore.self, forPrimaryKey: self.core.coreIdentifier) else {
                    completion(.error(.noCoreFound(self.core.coreIdentifier ?? "nil")))
                    return
                }
                do {
                    let baseFilename = "\(game.md5Hash).\(Date().timeIntervalSinceReferenceDate)"
                    let saveURL = saveStatePath.appendingPathComponent("\(baseFilename).svc", isDirectory: false)
                    let saveFile = PVFile(withURL: saveURL, relativeRoot: .iCloud)
                    var saveType = type;
                    /* In order to avoid modifying realm schema the codeType is added in the
                       type field next to cheat code name with -~- separator */
                    if codeType.count > 0 {
                        saveType += "-~-" + codeType
                    }
                    var cheatsState: PVCheats!
                    try realm.write {
                        cheatsState = PVCheats(withGame: self.game, core: core, code: modString, type: saveType, enabled: enabled, file: saveFile)
                        realm.add(cheatsState)
                    }
                    LibrarySerializer.storeMetadata(cheatsState, completion: { result in
                        switch result {
                        case let .success(url):
                            ILOG("Serialized cheats state metadata to (\(url.path))")
                        case let .error(error):
                            ELOG("Failed to serialize cheats metadata. \(error)")
                        }
                    })
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

    func cheatsViewControllerDone(_: PVCheatsViewController) {
        dismiss(animated: true, completion: nil)
        core.setPauseEmulation(false)
        isShowingMenu = false
        enableControllerInput(false)
    }

    func cheatsViewControllerCreateNewState(_ cheatsViewController: PVCheatsViewController,
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool,
        completion: @escaping CheatsCompletion) {
        setCheatState(
            code: code,
            type: type,
            codeType: codeType,
            cheatIndex: cheatIndex,
            enabled: enabled,
            completion: completion
        )
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

    func cheatsViewController(_: PVCheatsViewController, load state: PVCheats) {
        dismiss(animated: true, completion: nil)
    }

    @objc func showCheatsMenu() {
        guard let cheatsNavController = UIStoryboard(name: "Cheats", bundle: nil).instantiateViewController(withIdentifier: "PVCheatsViewControllerNav") as? UINavigationController else {
            return
        }

        if let cheatsViewController = cheatsNavController.viewControllers.first as? PVCheatsViewController {
            cheatsViewController.cheats = game.cheats
            cheatsViewController.delegate = self
            cheatsViewController.coreID = core.coreIdentifier
        }
        cheatsNavController.modalPresentationStyle = .overCurrentContext

        #if os(iOS)
            if traitCollection.userInterfaceIdiom == .pad {
                cheatsNavController.modalPresentationStyle = .formSheet
            }
        #endif
        #if os(tvOS)
            cheatsNavController.modalPresentationStyle = .blurOverFullScreen
        #endif
        present(cheatsNavController, animated: true)
    }

    @objc func getCheatTypes() -> NSArray {
        if let gameWithCheat = core as? GameWithCheat {
            return gameWithCheat.cheatCodeTypes();
        }
        return [];
    }
}

@objc extension PVEmulatorCore {
    @objc public func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool {
        return false
    }
    @objc public func supportsCheatCode() -> Bool
    {
        return false
    }
    /* This is list of cheat code types (will be passed to codeType) */
    @objc public func cheatCodeTypes() -> NSArray {
        return [];
    }
    /* This is always called, with blank codeType if none is provided */
    @objc public func setCheat(
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool
    ) -> Bool {
        return self.setCheat(code:code, type:type, enabled:enabled)
    }
}
