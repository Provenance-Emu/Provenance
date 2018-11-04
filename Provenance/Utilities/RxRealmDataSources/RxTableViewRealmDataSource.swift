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

    public typealias TableCellFactory<E: Object> = (RxTableViewRealmDataSource<E>, UITableView, IndexPath, E) -> UITableViewCell
    public typealias TableCellConfig<E: Object, CellType: UITableViewCell> = (CellType, IndexPath, E) -> Void

    open class RxTableViewRealmDataSource<E: Object>: NSObject, UITableViewDataSource {

        private var items: AnyRealmCollection<E>?

        // MARK: - Configuration

        public var tableView: UITableView?
        public var animated = true
        public var rowAnimations = (
            insert: UITableView.RowAnimation.automatic,
            update: UITableView.RowAnimation.automatic,
            delete: UITableView.RowAnimation.automatic)

        public var headerTitle: String?
        public var footerTitle: String?

        // MARK: - Init
        public let cellIdentifier: String
        public let cellFactory: TableCellFactory<E>

        public init(cellIdentifier: String, cellFactory: @escaping TableCellFactory<E>) {
            self.cellIdentifier = cellIdentifier
            self.cellFactory = cellFactory
        }

        public init<CellType>(cellIdentifier: String, cellType: CellType.Type, cellConfig: @escaping TableCellConfig<E, CellType>) where CellType: UITableViewCell {
            self.cellIdentifier = cellIdentifier
            self.cellFactory = {ds, tv, ip, model in
                let cell = tv.dequeueReusableCell(withIdentifier: cellIdentifier, for: ip) as! CellType
                cellConfig(cell, ip, model)
                return cell
            }
        }

        // MARK: - Data access
        public func model(at indexPath: IndexPath) -> E {
            return items![indexPath.row]
        }

        // MARK: - UITableViewDataSource protocol
        public func numberOfSections(in tableView: UITableView) -> Int {
            return 1
        }

        public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return items?.count ?? 0
        }

        public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            return cellFactory(self, tableView, indexPath, items![indexPath.row])
        }

        public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            return headerTitle
        }

        public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            return footerTitle
        }

        // MARK: - Applying changeset to the table view
        private let fromRow = {(row: Int) in return IndexPath(row: row, section: 0)}

        func applyChanges(items: AnyRealmCollection<E>, changes: RealmChangeset?) {
            if self.items == nil {
                self.items = items
            }

            guard let tableView = tableView else {
                fatalError("You have to bind a table view to the data source.")
            }

            guard animated else {
                tableView.reloadData()
                return
            }

            guard let changes = changes else {
                tableView.reloadData()
                return
            }

            let lastItemCount = tableView.numberOfRows(inSection: 0)
            guard items.count == lastItemCount + changes.inserted.count - changes.deleted.count else {
                tableView.reloadData()
                return
            }

            tableView.beginUpdates()
            tableView.deleteRows(at: changes.deleted.map(fromRow), with: rowAnimations.delete)
            tableView.insertRows(at: changes.inserted.map(fromRow), with: rowAnimations.insert)
            tableView.reloadRows(at: changes.updated.map(fromRow), with: rowAnimations.update)
            tableView.endUpdates()
        }
    }

#elseif os(OSX)
    // MARK: - macOS / Cocoa

    import Cocoa

    public typealias TableCellFactory<E: Object> = (RxTableViewRealmDataSource<E>, NSTableView, Int, E) -> NSTableCellView
    public typealias TableCellConfig<E: Object, CellType: NSTableCellView> = (CellType, Int, E) -> Void

    open class RxTableViewRealmDataSource<E: Object>: NSObject, NSTableViewDataSource, NSTableViewDelegate {

        private var items: AnyRealmCollection<E>?

        // MARK: - Configuration

        public var tableView: NSTableView?
        public var animated = true
        public var rowAnimations = (
            insert: NSTableView.AnimationOptions.effectFade,
            update: NSTableView.AnimationOptions.effectFade,
            delete: NSTableView.AnimationOptions.effectFade)

        public weak var delegate: NSTableViewDelegate?
        public weak var dataSource: NSTableViewDataSource?

        // MARK: - Init
        public let cellIdentifier: String
        public let cellFactory: TableCellFactory<E>

        public init(cellIdentifier: String, cellFactory: @escaping TableCellFactory<E>) {
            self.cellIdentifier = cellIdentifier
            self.cellFactory = cellFactory
        }

        public init<CellType>(cellIdentifier: String, cellType: CellType.Type, cellConfig: @escaping TableCellConfig<E, CellType>) where CellType: NSTableCellView {
            self.cellIdentifier = cellIdentifier
            self.cellFactory = { ds, tv, row, model in
              let cell = tv.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: tv) as! CellType
                cellConfig(cell, row, model)
                return cell
            }
        }

        // MARK: - UITableViewDataSource protocol
        public func numberOfRows(in tableView: NSTableView) -> Int {
            return items?.count ?? 0
        }

        public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            return cellFactory(self, tableView, row, items![row])
        }

        // MARK: - Proxy unimplemented data source and delegate methods
        open override func responds(to aSelector: Selector!) -> Bool {
            if RxTableViewRealmDataSource.instancesRespond(to: aSelector) {
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

        // MARK: - Applying changeset to the table view
        private let fromRow = {(row: Int) in return IndexPath(item: row, section: 0)}

        func applyChanges(items: AnyRealmCollection<E>, changes: RealmChangeset?) {
            if self.items == nil {
                self.items = items
            }

            guard let tableView = tableView else {
                fatalError("You have to bind a table view to the data source.")
            }

            guard animated else {
                tableView.reloadData()
                return
            }

            guard let changes = changes else {
                tableView.reloadData()
                return
            }

            let lastItemCount = tableView.numberOfRows
            guard items.count == lastItemCount + changes.inserted.count - changes.deleted.count else {
                tableView.reloadData()
                return
            }
            
            tableView.beginUpdates()
            tableView.removeRows(at: IndexSet(changes.deleted), withAnimation: rowAnimations.delete)
            tableView.insertRows(at: IndexSet(changes.inserted), withAnimation: rowAnimations.insert)
            tableView.reloadData(forRowIndexes: IndexSet(changes.updated), columnIndexes: IndexSet([0]))
            tableView.endUpdates()
        }
    }
    
#endif
