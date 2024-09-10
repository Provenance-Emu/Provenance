//
//  PVCheatsViewControllerDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import PVLibrary
import PVRealm

protocol PVCheatsViewControllerDelegate: AnyObject {
    func cheatsViewControllerDone(_ cheatsViewController: PVCheatsViewController)
    func cheatsViewControllerCreateNewState(_ cheatsViewController: PVCheatsViewController,
                                            code: String,
                                            type: String,
                                            codeType: String,
                                            cheatIndex: UInt8,
                                            enabled: Bool,
                                            completion: @escaping CheatsCompletion)
    func cheatsViewControllerUpdateState(_:Any,
                                         cheat: PVCheats,
                                         cheatIndex: UInt8,
                                         completion: @escaping CheatsCompletion)
    func cheatsViewController(_ cheatsViewController: PVCheatsViewController, load state: PVCheats)
    func getCheatTypes() -> [String]
}
