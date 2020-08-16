//
//  UI+SectionedViewType.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 6/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)
import Foundation
import UIKit
import Differentiator

func indexSet(_ values: [Int]) -> IndexSet {
    let indexSet = NSMutableIndexSet()
    for i in values {
        indexSet.add(i)
    }
    return indexSet as IndexSet
}

extension UITableView : SectionedViewType {
  
    public func insertItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.insertRows(at: paths, with: animationStyle)
    }
    
    public func deleteItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.deleteRows(at: paths, with: animationStyle)
    }
    
    public func moveItemAtIndexPath(_ from: IndexPath, to: IndexPath) {
        self.moveRow(at: from, to: to)
    }
    
    public func reloadItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.reloadRows(at: paths, with: animationStyle)
    }
    
    public func insertSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.insertSections(indexSet(sections), with: animationStyle)
    }
    
    public func deleteSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.deleteSections(indexSet(sections), with: animationStyle)
    }
    
    public func moveSection(_ from: Int, to: Int) {
        self.moveSection(from, toSection: to)
    }
    
    public func reloadSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.reloadSections(indexSet(sections), with: animationStyle)
    }
}

extension UICollectionView : SectionedViewType {
    public func insertItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.insertItems(at: paths)
    }
    
    public func deleteItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.deleteItems(at: paths)
    }

    public func moveItemAtIndexPath(_ from: IndexPath, to: IndexPath) {
        self.moveItem(at: from, to: to)
    }
    
    public func reloadItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.reloadItems(at: paths)
    }
    
    public func insertSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.insertSections(indexSet(sections))
    }
    
    public func deleteSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.deleteSections(indexSet(sections))
    }
    
    public func moveSection(_ from: Int, to: Int) {
        self.moveSection(from, toSection: to)
    }
    
    public func reloadSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.reloadSections(indexSet(sections))
    }
}

public protocol SectionedViewType {
    func insertItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation)
    func deleteItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation)
    func moveItemAtIndexPath(_ from: IndexPath, to: IndexPath)
    func reloadItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation)
    
    func insertSections(_ sections: [Int], animationStyle: UITableView.RowAnimation)
    func deleteSections(_ sections: [Int], animationStyle: UITableView.RowAnimation)
    func moveSection(_ from: Int, to: Int)
    func reloadSections(_ sections: [Int], animationStyle: UITableView.RowAnimation)
}

extension SectionedViewType {
    public func batchUpdates<Section>(_ changes: Changeset<Section>, animationConfiguration: AnimationConfiguration) {
        typealias Item = Section.Item
        
        deleteSections(changes.deletedSections, animationStyle: animationConfiguration.deleteAnimation)
        
        insertSections(changes.insertedSections, animationStyle: animationConfiguration.insertAnimation)
        for (from, to) in changes.movedSections {
            moveSection(from, to: to)
        }
        
        deleteItemsAtIndexPaths(
            changes.deletedItems.map { IndexPath(item: $0.itemIndex, section: $0.sectionIndex) },
            animationStyle: animationConfiguration.deleteAnimation
        )
        insertItemsAtIndexPaths(
            changes.insertedItems.map { IndexPath(item: $0.itemIndex, section: $0.sectionIndex) },
            animationStyle: animationConfiguration.insertAnimation
        )
        reloadItemsAtIndexPaths(
            changes.updatedItems.map { IndexPath(item: $0.itemIndex, section: $0.sectionIndex) },
            animationStyle: animationConfiguration.reloadAnimation
        )
        
        for (from, to) in changes.movedItems {
            moveItemAtIndexPath(
                IndexPath(item: from.itemIndex, section: from.sectionIndex),
                to: IndexPath(item: to.itemIndex, section: to.sectionIndex)
            )
        }
    }
}
#endif
