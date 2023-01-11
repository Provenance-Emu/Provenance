//
//  RxRealm extensions
//
//  Copyright (c) 2016 RxSwiftCommunity. All rights reserved.
//  Check the LICENSE file for details
//

import Foundation

import RealmSwift
import RxCocoa
import RxRealm
import RxSwift

public class RxRealmDataSourceSection<E: Object> {
    public let title: String?
    public let cellIdentifier: String
    public let cellFactory: CollectionCellFactory<E>
    public private(set) var items: AnyRealmCollection<E>?
    public weak var dataSource: RxCollectionViewRealmDataSource?
    public let section: Int
    public func model(at row: Int) throws -> E {
        return items![row]
    }

    func applyChanges(items: AnyRealmCollection<E>, changes: RealmChangeset?) {
        if self.items == nil {
            self.items = items
        }

        guard let dataSource = dataSource, let collectionView = dataSource.collectionView else {
            fatalError("You have to bind a collection view to the data source.")
        }

        guard dataSource.animated else {
            collectionView.reloadSections(IndexSet(integer: section))
            return
        }

        guard let changes = changes else {
            collectionView.reloadSections([section])
            return
        }

        let lastItemCount = collectionView.numberOfItems(inSection: 0)
        guard items.count == lastItemCount + changes.inserted.count - changes.deleted.count else {
            collectionView.reloadData()
            return
        }

        collectionView.performBatchUpdates({
            let section = self.section
            let fromRow = { (row: Int) in IndexPath(row: row, section: section) }

            collectionView.deleteItems(at: changes.deleted.map(fromRow))
            collectionView.reloadItems(at: changes.updated.map(fromRow))
            collectionView.insertItems(at: changes.inserted.map(fromRow))
        }, completion: nil)
    }

    public init(title: String? = nil, cellIdentifier: String, cellFactory: @escaping CollectionCellFactory<E>, items: AnyRealmCollection<E>? = nil, dataSource: RxCollectionViewRealmDataSource? = nil, section: Int) {
        self.title = title
        self.cellIdentifier = cellIdentifier
        self.cellFactory = cellFactory
        self.items = items
        self.dataSource = dataSource
        self.section = section
    }

    public convenience init<CellType: UICollectionViewCell>(title: String? = nil, cellIdentifier: String, cellConfig: @escaping CollectionCellConfig<E, CellType>, items _: AnyRealmCollection<E>? = nil, dataSource: RxCollectionViewRealmDataSource? = nil, section: Int) {
        let cellFactory: CollectionCellFactory<E> = { _, cv, ip, model in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: ip) as! CellType
            cellConfig(cell, ip, model)
            return cell
        }
        self.init(title: title, cellIdentifier: cellIdentifier, cellFactory: cellFactory, dataSource: dataSource, section: section)
    }
}

#if os(iOS)

    // MARK: - iOS / UIKi

    import UIKit

    public typealias CollectionCellFactory<E: Object> = (RxCollectionViewRealmDataSource, UICollectionView, IndexPath, E) -> UICollectionViewCell
    public typealias CollectionCellConfig<E: Object, CellType: UICollectionViewCell> = (CellType, IndexPath, E) -> Void

    open class RxCollectionViewRealmDataSource: NSObject, UICollectionViewDataSource, SectionedViewDataSourceType {
        var sections: [RxRealmDataSourceSection<Object>]?

        var nonEmptySections: [RxRealmDataSourceSection<Object>]? {
            return sections?.filter { $0.items?.isEmpty ?? false }
        }

        // MARK: - Configuration

        public var collectionView: UICollectionView?
        public var animated = true

        // MARK: - Init

        public init(sections: [RxRealmDataSourceSection<Object>]) {
            self.sections = sections
            super.init()
            sections.forEach { $0.dataSource = self }
        }

        public init<E, CellType>(cellIdentifier: String, cellType _: CellType.Type, cellConfig: @escaping CollectionCellConfig<E, CellType>) where E: Object, CellType: UICollectionViewCell {
            super.init()
            sections = [RxRealmDataSourceSection(title: nil, cellIdentifier: cellIdentifier, cellFactory: { (_, cv, ip, model) -> UICollectionViewCell in
                let cell = cv.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: ip) as! CellType
                cellConfig(cell, ip, model as! E)
                return cell
            }, items: nil, dataSource: self, section: 0)]
        }

        // MARK: - Data access

        public func model(at indexPath: IndexPath) throws -> Any {
            let section = sections![indexPath.section]
            return try section.model(at: indexPath.row)
        }

        // MARK: - UICollectionViewDataSource protocol

        public func numberOfSections(in _: UICollectionView) -> Int {
            return nonEmptySections?.count ?? 0
        }

        public func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return nonEmptySections?[section].items?.count ?? 0
        }

        public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let section = nonEmptySections![indexPath.row]
            return section.cellFactory(self, collectionView, indexPath, section.items![indexPath.row])
        }
    }

#elseif os(OSX)

    // MARK: - macOS / Cocoa

    import Cocoa

    public typealias CollectionItemFactory<E: Object> = (RxCollectionViewRealmDataSource<E>, NSCollectionView, IndexPath, E) -> NSCollectionViewItem
    public typealias CollectionItemConfig<E: Object, ItemType: NSCollectionViewItem> = (ItemType, IndexPath, E) -> Void

    open class RxCollectionViewRealmDataSource<E: Object>: NSObject, NSCollectionViewDataSource {
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

        public init<ItemType>(itemIdentifier: String, itemType _: ItemType.Type, itemConfig: @escaping CollectionItemConfig<E, ItemType>) where ItemType: NSCollectionViewItem {
            self.itemIdentifier = itemIdentifier
            itemFactory = { _, cv, ip, model in
                let item = cv.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: itemIdentifier), for: ip) as! ItemType
                itemConfig(item, ip, model)
                return item
            }
        }

        // MARK: - NSCollectionViewDataSource protocol

        public func numberOfSections(in _: NSCollectionView) -> Int {
            return 1
        }

        public func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
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

        open override func forwardingTarget(for _: Selector!) -> Any? {
            return delegate ?? dataSource
        }

        // MARK: - Applying changeset to the collection view

        private let fromRow = { (row: Int) in IndexPath(item: row, section: 0) }

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

            collectionView.performBatchUpdates({ [unowned self] in
                // TODO: this should be animated, but doesn't seem to be?
                collectionView.animator().deleteItems(at: Set(changes.deleted.map(self.fromRow)))
                collectionView.animator().reloadItems(at: Set(changes.updated.map(self.fromRow)))
                collectionView.animator().insertItems(at: Set(changes.inserted.map(self.fromRow)))
            }, completionHandler: nil)
        }
    }

#endif
