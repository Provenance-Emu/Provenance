//
//  RxRealm extensions
//
//  Copyright (c) 2016 RxSwiftCommunity. All rights reserved.
//  Check the LICENSE file for details
//

import Foundation

import RealmSwift
import RxSwift
import RxCocoa
import RxRealm

#if os(iOS)
    // MARK: - iOS / UIKit

    import UIKit

    public typealias CollectionCellFactory<E: Object> = (RxCollectionViewRealmDataSource<E>, UICollectionView, IndexPath, E) -> UICollectionViewCell
    public typealias CollectionCellConfig<E: Object, CellType: UICollectionViewCell> = (CellType, IndexPath, E) -> Void

    open class RxCollectionViewRealmDataSource <E: Object>: NSObject, UICollectionViewDataSource {
        private var items: AnyRealmCollection<E>?

        // MARK: - Configuration

        public var collectionView: UICollectionView?
        public var animated = true

        // MARK: - Init
        public let cellIdentifier: String
        public let cellFactory: CollectionCellFactory<E>

        public init(cellIdentifier: String, cellFactory: @escaping CollectionCellFactory<E>) {
            self.cellIdentifier = cellIdentifier
            self.cellFactory = cellFactory
        }

        public init<CellType>(cellIdentifier: String, cellType: CellType.Type, cellConfig: @escaping CollectionCellConfig<E, CellType>) where CellType: UICollectionViewCell {
            self.cellIdentifier = cellIdentifier
            self.cellFactory = {ds, cv, ip, model in
                let cell = cv.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: ip) as! CellType
                cellConfig(cell, ip, model)
                return cell
            }
        }

        // MARK: - Data access
        public func model(at indexPath: IndexPath) -> E {
            return items![indexPath.row]
        }

        // MARK: - UICollectionViewDataSource protocol
        public func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 1
        }

        public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return items?.count ?? 0
        }

        public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            return cellFactory(self, collectionView, indexPath, items![indexPath.row])
        }

        // MARK: - Applying changeset to the collection view
        private let fromRow = {(row: Int) in return IndexPath(row: row, section: 0)}

        func applyChanges(items: AnyRealmCollection<E>, changes: RealmChangeset?) {
            if self.items == nil {
                self.items = items
            }

        guard let collectionView = collectionView else {
            fatalError("You have to bind a collection view to the data source.")
        }

        guard animated else {
            collectionView.reloadData()
            return
        }

        guard let changes = changes else {
            collectionView.reloadData()
            return
        }

        let lastItemCount = collectionView.numberOfItems(inSection: 0)
        guard items.count == lastItemCount + changes.inserted.count - changes.deleted.count else {
            collectionView.reloadData()
            return
        }

        collectionView.performBatchUpdates({[unowned self] in
            collectionView.deleteItems(at: changes.deleted.map(self.fromRow))
            collectionView.reloadItems(at: changes.updated.map(self.fromRow))
            collectionView.insertItems(at: changes.inserted.map(self.fromRow))
        }, completion: nil)
    }
}

#elseif os(OSX)
// MARK: - macOS / Cocoa

import Cocoa

    public typealias CollectionItemFactory<E: Object> = (RxCollectionViewRealmDataSource<E>, NSCollectionView, IndexPath, E) -> NSCollectionViewItem
    public typealias CollectionItemConfig<E: Object, ItemType: NSCollectionViewItem> = (ItemType, IndexPath, E) -> Void

    open class RxCollectionViewRealmDataSource <E: Object>: NSObject, NSCollectionViewDataSource {

        private var items: AnyRealmCollection<E>?

        // MARK: - Configuration

        public var collectionView: NSCollectionView?
        public var animated = true

        // MARK: - Init
        public let itemIdentifier: String
        public let itemFactory: CollectionItemFactory<E>

        public weak var delegate: NSCollectionViewDelegate?
        public weak var dataSource: NSCollectionViewDataSource?

        public init(itemIdentifier: String, itemFactory: @escaping CollectionItemFactory<E>) {
            self.itemIdentifier = itemIdentifier
            self.itemFactory = itemFactory
        }

        public init<ItemType>(itemIdentifier: String, itemType: ItemType.Type, itemConfig: @escaping CollectionItemConfig<E, ItemType>) where ItemType: NSCollectionViewItem {
            self.itemIdentifier = itemIdentifier
            self.itemFactory = { ds, cv, ip, model in
              let item = cv.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: itemIdentifier), for: ip) as! ItemType
                itemConfig(item, ip, model)
                return item
            }
        }

        // MARK: - NSCollectionViewDataSource protocol
        public func numberOfSections(in collectionView: NSCollectionView) -> Int {
            return 1
        }

        public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            return items?.count ?? 0
        }

        @available(OSX 10.11, *)
        public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            return itemFactory(self, collectionView, indexPath, items![indexPath.item])
        }

        // MARK: - Proxy unimplemented data source and delegate methods
        open override func responds(to aSelector: Selector!) -> Bool {
            if RxCollectionViewRealmDataSource.instancesRespond(to: aSelector) {
                return true
            } else if let delegate = delegate {
                return delegate.responds(to: aSelector)
            } else if let dataSource = dataSource {
                return dataSource.responds(to: aSelector)
            } else {
                return false
            }
        }

        open override func forwardingTarget(for aSelector: Selector!) -> Any? {
            return delegate ?? dataSource
        }

        // MARK: - Applying changeset to the collection view
        private let fromRow = {(row: Int) in return IndexPath(item: row, section: 0)}

        func applyChanges(items: AnyRealmCollection<E>, changes: RealmChangeset?) {
            if self.items == nil {
                self.items = items
            }

            guard let collectionView = collectionView else {
                fatalError("You have to bind a collection view to the data source.")
            }

            guard animated else {
                collectionView.reloadData()
                return
            }

            guard let changes = changes else {
                collectionView.reloadData()
                return
            }

            let lastItemCount = collectionView.numberOfItems(inSection: 0)
            guard items.count == lastItemCount + changes.inserted.count - changes.deleted.count else {
                collectionView.reloadData()
                return
            }

            collectionView.performBatchUpdates({[unowned self] in
                //TODO: this should be animated, but doesn't seem to be?
                collectionView.animator().deleteItems(at: Set(changes.deleted.map(self.fromRow)))
                collectionView.animator().reloadItems(at: Set(changes.updated.map(self.fromRow)))
                collectionView.animator().insertItems(at: Set(changes.inserted.map(self.fromRow)))
            }, completionHandler: nil)
        }
    }


#endif
