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
        guard let firstVC = UIStoryboard(name: "GameMoreInfo", bundle: BundleLoader.module).instantiateViewController(withIdentifier: "gameMoreInfoVC") as? PVGameMoreInfoViewController else {
            ELOG("Failed to instantiate PVGameMoreInfoViewController from GameMoreInfo storyboard")
            let fallback = GameMoreInfoPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
            let errorVC = UIViewController()
            let label = UILabel()
            label.text = "Failed to load game info"
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            errorVC.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: errorVC.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: errorVC.view.centerYAnchor)
            ])
            fallback.setViewControllers([errorVC], direction: .forward, animated: false, completion: nil)
            return fallback
        }

        let frozenGame = game.isFrozen ? game : game.freeze()
        firstVC.game = frozenGame

        let provenanceStoryboard = UIStoryboard(name: "Provenance", bundle: BundleLoader.module)
        guard let moreInfoGamePageVC = provenanceStoryboard.instantiateViewController(withIdentifier: "gameMoreInfoPageVC") as? GameMoreInfoPageViewController else {
            ELOG("Failed to instantiate GameMoreInfoPageViewController from Provenance storyboard")
            let fallback = GameMoreInfoPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
            fallback.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
            return fallback
        }

        moreInfoGamePageVC.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
        return moreInfoGamePageVC
    }
}
