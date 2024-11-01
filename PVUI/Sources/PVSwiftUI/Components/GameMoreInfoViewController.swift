//
//  GameMoreInfoViewController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/31/24.
//

import Foundation
import SwiftUI
import PVLibrary
import RealmSwift
import PVUIBase
import PVRealm
import PVLogging
import PVUIBase

struct GameMoreInfoViewController: UIViewControllerRepresentable {
    typealias UIViewControllerType = GameMoreInfoPageViewController

    let game: PVGame

    func updateUIViewController(_ uiViewController: GameMoreInfoPageViewController, context: Context) {
        // No need to update anything here
    }

    func makeUIViewController(context: Context) -> GameMoreInfoPageViewController {
        let firstVC = UIStoryboard(name: "GameMoreInfo", bundle: BundleLoader.module).instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController

        // Ensure we're using a frozen copy of the game
        let frozenGame = game.isFrozen ? game : game.freeze()
        firstVC.game = frozenGame

        let moreInfoCollectionVC = GameMoreInfoPageViewController()
        moreInfoCollectionVC.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
        return moreInfoCollectionVC
    }
}
