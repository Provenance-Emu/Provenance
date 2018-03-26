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
        collectionView?.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: "SearchResultCell")
        collectionView?.contentInset = UIEdgeInsets(top: 40, left: 80, bottom: 40, right: 80)
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchResultCell", for: indexPath) as! PVGameLibraryCollectionViewCell

        if let game = searchResults?[indexPath.item] {
            cell.game = game
        }
        cell.setNeedsLayout()
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let game = searchResults?[indexPath.item] {
            load(game)
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
}

extension PVSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""

        let sorted = RomDatabase.sharedInstance.all(PVGame.self, filter: NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText])).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        searchResults = sorted
        collectionView?.reloadData()
    }
}
