//
//  PVGameLibraryViewController+PeekPop.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/26/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
import UIKit

#if os(iOS)
    extension PVGameLibraryViewController: UIViewControllerPreviewingDelegate {
        func previewingContext(_: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
            if let moreInfoVC = viewControllerToCommit as? PVGameMoreInfoViewController {
                let moreInfoGamePageVC = UIStoryboard(name: "Provenance", bundle: nil).instantiateViewController(withIdentifier: "gameMoreInfoPageVC") as! GameMoreInfoPageViewController
                moreInfoGamePageVC.setViewControllers([moreInfoVC], direction: .forward, animated: false, completion: nil)
                navigationController!.show(moreInfoGamePageVC, sender: self)
            } else if let saveSaveInfoVC = viewControllerToCommit as? PVSaveStateInfoViewController {
                navigationController!.show(saveSaveInfoVC, sender: self)
            }
        }
        func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
            guard let indexPath = collectionView?.indexPathForItem(at: location),
                let cellAttributes = collectionView?.layoutAttributesForItem(at: indexPath),
                let item: Section.Item = try? collectionView?.rx.model(at: indexPath)
                else { return nil }
            // This will show the cell clearly and blur the rest of the screen for our peek.
            previewingContext.sourceRect = cellAttributes.frame

			switch item {
            case .game(let game):
                let storyBoard = UIStoryboard(name: "Provenance", bundle: nil)
                let moreInfoViewController = storyBoard.instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController
                moreInfoViewController.game = game
                moreInfoViewController.showsPlayButton = true
                return moreInfoViewController
            case .favorites:
                guard let game: PVGame = (collectionView!.cellForItem(at: indexPath) as? CollectionViewInCollectionViewCell)?.item(at: location)
                    else { return nil }

                let storyBoard = UIStoryboard(name: "Provenance", bundle: nil)
                let moreInfoViewController = storyBoard.instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController
                moreInfoViewController.game = game
                moreInfoViewController.showsPlayButton = true
                return moreInfoViewController
            case .saves:
                guard let save: PVSaveState = (collectionView!.cellForItem(at: indexPath) as? CollectionViewInCollectionViewCell)?.item(at: location)
                    else { return nil }
                let storyBoard = UIStoryboard(name: "SaveStates", bundle: nil)
                let saveStateInfoVC = storyBoard.instantiateViewController(withIdentifier: "saveStateInfoVC") as! PVSaveStateInfoViewController
                saveStateInfoVC.saveState = save
                return saveStateInfoVC
            case .recents:
                guard let game: PVRecentGame = (collectionView!.cellForItem(at: indexPath) as? CollectionViewInCollectionViewCell)?.item(at: location)
                    else { return nil }

                let storyBoard = UIStoryboard(name: "Provenance", bundle: nil)
                let moreInfoViewController = storyBoard.instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController
                moreInfoViewController.game = game.game
                moreInfoViewController.showsPlayButton = true
                return moreInfoViewController
            }
        }
    }
#endif
