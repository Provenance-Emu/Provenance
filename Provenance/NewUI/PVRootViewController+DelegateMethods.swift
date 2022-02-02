//
//  PVRootViewController+DelegateMethods.swift
//  Provenance
//
//  Created by Ian Clawson on 1/30/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary

// MARK: - PVControllerMethodsDelegate methods

@available(iOS 14.0.0, tvOS 14.0.0, *)
extension PVRootViewController: PVRootDelegate {
    func attemptToDelete(game: PVGame) {
        do {
            try self.delete(game: game)
        } catch {
            self.presentError(error.localizedDescription)
        }
    }
}

// MARK: - Methods from PVGameLibraryViewController

@available(iOS 14.0.0, tvOS 14.0.0, *)
extension PVRootViewController {
    func delete(game: PVGame) throws {
        try RomDatabase.sharedInstance.delete(game: game)
//        loadLastKnownNavOption()
        // we're still retaining a refernce to the removed game, causing a realm crash. Need to reload the view
    }
}
