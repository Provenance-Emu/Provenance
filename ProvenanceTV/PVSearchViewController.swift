//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVSearchViewController.swift
//  Provenance
//
//  Created by James Addyman on 12/06/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import UIKit
import RealmSwift

class PVSearchViewController: UICollectionViewController, GameLaunchingViewController {
    var mustRefreshDataSource: Bool = false

    var searchResults: Results<PVGame>?

    override func viewDidLoad() {
        super.viewDidLoad()
        RomDatabase.sharedInstance.refresh()
        (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)

		if #available(iOS 9.0, tvOS 9.0, *) {
			#if os(iOS)
			collectionView?.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
			#else
			collectionView?.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
			#endif
		} else {
			collectionView?.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
		}
		collectionView?.contentInset = UIEdgeInsets(top: 40, left: 80, bottom: 40, right: 80)

		let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(PVSearchViewController.longPressRecognized(_:)))
		collectionView?.addGestureRecognizer(longPressRecognizer)

    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier, for: indexPath) as! PVGameLibraryCollectionViewCell

        if let game = searchResults?[indexPath.item] {
            cell.game = game
        }
        cell.setNeedsLayout()
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let game = searchResults?[indexPath.item] {
			load(game, sender:collectionView, core: nil)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 250, height: 360)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 88
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 30
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 40, left: 40, bottom: 120, right: 40)
    }

	@objc func longPressRecognized(_ recognizer: UILongPressGestureRecognizer) {
		guard let collectionView = collectionView else {
			return
		}

		if recognizer.state == .began, let indexPath = collectionView.indexPathForItem(at: recognizer.location(in: collectionView)), let game = searchResults?[indexPath.item] {

			let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

//			actionSheet.addAction(UIAlertAction(title: "Game Info", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//				self.moreInfo(for: game)
//			}))

			actionSheet.addAction(UIAlertAction(title: "Toggle Favorite", style: .default, handler: {(_ action: UIAlertAction) -> Void in
				self.toggleFavorite(for: game)
			}))

//			actionSheet.addAction(UIAlertAction(title: "Rename", style: .default, handler: {(_ action: UIAlertAction) -> Void in
//				self.renameGame(game)
//			}))

			present(actionSheet, animated: true, completion: nil)
		}
	}
}

extension PVSearchViewController {
	func toggleFavorite(for game: PVGame) {
		do {
			try RomDatabase.sharedInstance.writeTransaction {
				game.isFavorite = !game.isFavorite
			}

			register3DTouchShortcuts()
		} catch {
			ELOG("Failed to toggle Favourite for game \(game.title)")
		}
	}
}

extension PVSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""

        let sorted = RomDatabase.sharedInstance.all(PVGame.self, filter: NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText])).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        searchResults = sorted
        collectionView?.reloadData()
    }
}
