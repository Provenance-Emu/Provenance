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
import RxSwift
import RxDataSources
import UIKit

extension PVSearchViewController {
    static func createEmbeddedInNavigationController(gameLibrary: PVGameLibrary) -> UINavigationController {
        let searchViewController = PVSearchViewController(gameLibrary: gameLibrary)
        let searchController = UISearchController(searchResultsController: searchViewController)
        searchViewController.searchController = searchController
        let searchContainerController = UISearchContainerViewController(searchController: searchController)
        searchContainerController.title = "Search"
        return UINavigationController(rootViewController: searchContainerController)
    }
}

final class PVSearchViewController: UICollectionViewController, GameLaunchingViewController {
    private let gameLibrary: PVGameLibrary
    fileprivate var searchController: UISearchController!
    private let disposeBag = DisposeBag()

    init(gameLibrary: PVGameLibrary) {
        self.gameLibrary = gameLibrary
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = .init(top: 20, left: 0, bottom: 20, right: 0)
        super.init(collectionViewLayout: flowLayout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        #if os(iOS)
            collectionView?.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #else
            collectionView?.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #endif
        collectionView?.contentInset = UIEdgeInsets(top: 40, left: 80, bottom: 40, right: 80)

        let sections: Observable<[Section]> = searchController
            .rx.searchText
            .compactMap { $0 }
            .flatMap { self.gameLibrary.search(for: $0) }
            .map { games in [Section(items: games)] }

        let dataSource = RxCollectionViewSectionedReloadDataSource<Section>(configureCell: { _, collectionView, indexPath, game -> UICollectionViewCell in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier, for: indexPath) as! PVGameLibraryCollectionViewCell
            cell.game = game
            cell.setNeedsLayout()
            return cell
        })

        sections.bind(to: collectionView.rx.items(dataSource: dataSource)).disposed(by: disposeBag)
        collectionView.rx.modelSelected(PVGame.self)
            .bind(onNext: { self.load($0, sender: self.collectionView, core: nil) })
            .disposed(by: disposeBag)

        let longPressRecognizer = UILongPressGestureRecognizer()
        collectionView.addGestureRecognizer(longPressRecognizer)
        longPressRecognizer.rx.event
            .filter { $0.state == .began }
            .compactMap { self.collectionView.indexPathForItem(at: $0.location(in: self.collectionView) ) }
            .map { try self.collectionView.rx.model(at: $0) }
            .flatMapLatest({ (game: PVGame) -> Observable<PVGame> in
                let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                let (action, selected) = UIAlertAction.createReactive(title: "Toggle Favorite", style: .default)
                actionSheet.addAction(action)
                self.present(actionSheet, animated: true)
                return selected.map { _ in game }
            })
            .flatMapLatest({ game in
                self.gameLibrary.toggleFavorite(for: game)
                    .catchError { _ in
                        ELOG("Failed to toggle Favourite for game \(game.title)")
                        return .never()
                }
            })
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    private struct Section: SectionModelType {
        let items: [PVGame]

        init(items: [PVGame]) {
            self.items = items
        }

        init(original: PVSearchViewController.Section, items: [PVGame]) {
            self.init(items: items)
        }
    }
}

private extension UIAlertAction {
    static func createReactive(title: String?, style: Style) -> (UIAlertAction, Observable<Void>) {
        let didSelect = PublishSubject<UIAlertAction>()
        let action = UIAlertAction(title: title, style: style, handler: didSelect.onNext)
        return (action, didSelect.map { _ in})
    }
}
