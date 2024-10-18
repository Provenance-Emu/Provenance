//
//  GameSharingViewController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import PVLibrary

public protocol GameSharingViewController: AnyObject {
    func share(for game: PVGame, sender: Any?) async
}
