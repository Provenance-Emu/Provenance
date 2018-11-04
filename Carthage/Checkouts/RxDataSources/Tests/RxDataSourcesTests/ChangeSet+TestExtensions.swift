//
//  ChangeSet+TestExtensions.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 11/26/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import Foundation
import Differentiator
import RxDataSources

fileprivate class ItemModelTypeWrapper<I> {
    let item: I

    var deleted: Bool = false
    var updated: Bool = false
    var moved: IndexPath? = nil

    init(item: I) {
        self.item = item
    }
}

fileprivate class SectionModelTypeWrapper<S: SectionModelType> {
    var updated: Bool = false
    var deleted: Bool = false
    var moved: Int? = nil

    var items: [ItemModelTypeWrapper<S.Item>]

    let section: S

    init(section: S) {
        self.section = section
        self.items = section.items.map { ItemModelTypeWrapper(item: $0) }
    }
}

extension Changeset {
    func onlyContains(
        insertedSections: Int = 0,
        deletedSections: Int = 0,
        movedSections: Int = 0,
        updatedSections: Int = 0,
        insertedItems: Int = 0,
        deletedItems: Int = 0,
        movedItems: Int = 0,
        updatedItems: Int = 0
    ) -> Bool {
        if self.insertedSections.count != insertedSections {
            return false
        }

        if self.deletedSections.count != deletedSections {
            return false
        }

        if self.movedSections.count != movedSections {
            return false
        }

        if self.updatedSections.count != updatedSections {
            return false
        }

        if self.insertedItems.count != insertedItems {
            return false
        }

        if self.deletedItems.count != deletedItems {
            return false
        }

        if self.movedItems.count != movedItems {
            return false
        }

        if self.updatedItems.count != updatedItems {
            return false
        }

        return true
    }
}

extension Changeset {

    fileprivate func apply(original: [S]) -> [S] {

        let afterDeletesAndUpdates = applyDeletesAndUpdates(original: original)
        let afterSectionMovesAndInserts = applySectionMovesAndInserts(original: afterDeletesAndUpdates)
        let afterItemInsertsAndMoves = applyItemInsertsAndMoves(original: afterSectionMovesAndInserts)

        return afterItemInsertsAndMoves
    }

    private func applyDeletesAndUpdates(original: [S]) -> [S] {
        var resultAfterDeletesAndUpdates: [SectionModelTypeWrapper<S>] = SectionModelTypeWrapper.wrap(original)

        for index in updatedItems {
            resultAfterDeletesAndUpdates[index.sectionIndex].items[index.itemIndex].updated = true
        }

        for index in deletedItems {
            resultAfterDeletesAndUpdates[index.sectionIndex].items[index.itemIndex].deleted = true
        }

        for section in deletedSections {
            resultAfterDeletesAndUpdates[section].deleted = true
        }

        resultAfterDeletesAndUpdates = resultAfterDeletesAndUpdates.filter { !$0.deleted }

        for (sectionIndex, section) in resultAfterDeletesAndUpdates.enumerated() {
            section.items = section.items.filter { !$0.deleted }
            for (itemIndex, item) in section.items.enumerated() {
                if item.updated {
                    section.items[itemIndex] = ItemModelTypeWrapper(item: finalSections[sectionIndex].items[itemIndex])
                }
            }
        }

        return SectionModelTypeWrapper.unwrap(resultAfterDeletesAndUpdates)
    }

    private func applySectionMovesAndInserts(original: [S]) -> [S] {
        if !updatedSections.isEmpty {
            fatalError("Section updates aren't supported")
        }

        let sourceSectionIndexes = Set(movedSections.map { $0.from })
        let destinationToSourceMapping = Dictionary(
            elements: movedSections,
            keySelector: { $0.to },
            valueSelector: { $0.from }
        )
        let insertedSectionsIndexes = Set(insertedSections)

        var nextUntouchedSourceSectionIndex = -1
        func findNextUntouchedSourceSection() -> Bool {
            nextUntouchedSourceSectionIndex += 1
            while nextUntouchedSourceSectionIndex < original.count && sourceSectionIndexes.contains(nextUntouchedSourceSectionIndex) {
                nextUntouchedSourceSectionIndex += 1
            }

            return nextUntouchedSourceSectionIndex < original.count
        }

        let totalCount = original.count + insertedSections.count

        var results: [S] = []
        
        for index in 0 ..< totalCount {
            if insertedSectionsIndexes.contains(index) {
                results.append(finalSections[index])
            }
            else if let sourceIndex = destinationToSourceMapping[index] {
                results.append(original[sourceIndex])
            }
            else {
                guard findNextUntouchedSourceSection() else {
                    fatalError("Oooops, wrong commands.")
                }

                results.append(original[nextUntouchedSourceSectionIndex])
            }
        }

        return results
    }

    private func applyItemInsertsAndMoves(original: [S]) -> [S] {
        var resultAfterInsertsAndMoves: [S] = original

        let sourceIndexesThatShouldBeMoved = Set(movedItems.map { $0.from })
        let destinationToSourceMapping = Dictionary(elements: self.movedItems, keySelector: { $0.to }, valueSelector: { $0.from })
        let insertedItemPaths = Set(self.insertedItems)

        var insertedPerSection: [Int] = Array(repeating: 0, count: original.count)
        var movedInSection: [Int] = Array(repeating: 0, count: original.count)
        var movedOutSection: [Int] = Array(repeating: 0, count: original.count)

        for insertedItemPath in insertedItems {
            insertedPerSection[insertedItemPath.sectionIndex] += 1
        }

        for moveItem in movedItems {
            movedInSection[moveItem.to.sectionIndex] += 1
            movedOutSection[moveItem.from.sectionIndex] += 1
        }
        
        for (sectionIndex, section) in resultAfterInsertsAndMoves.enumerated() {

            let originalItems = section.items

            var nextUntouchedSourceItemIndex = -1
            func findNextUntouchedSourceItem() -> Bool {
                nextUntouchedSourceItemIndex += 1
                while nextUntouchedSourceItemIndex < section.items.count
                    && sourceIndexesThatShouldBeMoved.contains(ItemPath(sectionIndex: sectionIndex, itemIndex: nextUntouchedSourceItemIndex)) {
                    nextUntouchedSourceItemIndex  += 1
                }

                return nextUntouchedSourceItemIndex < section.items.count
            }

            let totalCount = section.items.count
                + insertedPerSection[sectionIndex]
                + movedInSection[sectionIndex]
                - movedOutSection[sectionIndex]

            var resultItems: [S.Item] = []

            for index in 0 ..< totalCount {
                let itemPath = ItemPath(sectionIndex: sectionIndex, itemIndex: index)
                if insertedItemPaths.contains(itemPath) {
                    resultItems.append(finalSections[itemPath.sectionIndex].items[itemPath.itemIndex])
                }
                else if let sourceIndex = destinationToSourceMapping[itemPath] {
                    resultItems.append(original[sourceIndex.sectionIndex].items[sourceIndex.itemIndex])
                }
                else {
                    guard findNextUntouchedSourceItem() else {
                        fatalError("Oooops, wrong commands.")
                    }

                    resultItems.append(originalItems[nextUntouchedSourceItemIndex])
                }
            }

            resultAfterInsertsAndMoves[sectionIndex] = S(original: section, items: resultItems)
        }

        return resultAfterInsertsAndMoves
    }
}

extension SectionModelTypeWrapper {
    static func wrap(_ sections: [S]) -> [SectionModelTypeWrapper<S>] {
        return sections.map { SectionModelTypeWrapper(section: $0) }
    }

    static func unwrap(_ sections: [SectionModelTypeWrapper<S>]) -> [S] {
        return sections.map { sectionWrapper in
            let items = sectionWrapper.items.map { $0.item }
            return S(original: sectionWrapper.section, items: items)
        }
    }
}

extension Array where Element: AnimatableSectionModelType, Element: Equatable {

    func apply(_ changes: [Changeset<Element>]) -> [Element] {
        return changes.reduce(self) { sections, changes in
            let newSections = changes.apply(original: sections)
            XCAssertEqual(newSections, changes.finalSections)
            return newSections
        }
    }
}
