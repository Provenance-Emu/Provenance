//
//  PVSaveStatesViewControllerDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import Foundation
import PVLibrary

public
protocol PVSaveStatesViewControllerDelegate: AnyObject {
    func saveStatesViewControllerDone(_ saveStatesViewController: PVSaveStatesViewController)
    func saveStatesViewControllerCreateNewState(_ saveStatesViewController: PVSaveStatesViewController) async throws -> Bool
    func saveStatesViewControllerOverwriteState(_ saveStatesViewController: PVSaveStatesViewController, state: PVSaveState) async throws -> Bool
    // TODO: This should either throw or have a callback as well
    func saveStatesViewController(_ saveStatesViewController: PVSaveStatesViewController, load state: PVSaveState)
}
