//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVSearchViewController.swift
//  Provenance
//
//  Created by James Addyman on 12/06/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import RealmSwift
import RxSwift
import UIKit

final class PVSearchViewController: UICollectionViewController, GameLaunchingViewController {
    var mustRefreshDataSource: Bool = false

    private let gameLibrary: PVGameLibrary
    private let disposeBag = DisposeBag()
    var searchResults: Results<PVGame>?

    init(collectionViewLayout layout: UICollectionViewLayout, gameLibrary: PVGameLibrary) {
        self.gameLibrary = gameLibrary
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

    override func numberOfSections(in _: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
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
            load(game, sender: collectionView, core: nil)
        }
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return CGSize(width: 250, height: 360)
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        return 88
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        return 30
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt _: Int) -> UIEdgeInsets {
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

            actionSheet.addAction(UIAlertAction(title: "Toggle Favorite", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.gameLibrary.toggleFavorite(for: game)
                    .catchError { _ in
                        ELOG("Failed to toggle Favourite for game \(game.title)")
                        return .never()
                }
                .subscribe()
                .disposed(by: self.disposeBag)
            }))

            //			actionSheet.addAction(UIAlertAction(title: "Rename", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            //				self.renameGame(game)
            //			}))

            present(actionSheet, animated: true, completion: nil)
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
