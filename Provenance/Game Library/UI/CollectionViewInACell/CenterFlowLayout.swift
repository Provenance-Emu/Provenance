//
//  CenterFlowLayout.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/15/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import UIKit

final class CenterViewFlowLayout: UICollectionViewFlowLayout {
    var canvasSize: CGSize {
        return collectionView?.frame.size ?? .zero
    }

    var columnCount: Int {
        let halfMargin = minimumLineSpacing / 2.0
        let fullMargin = minimumLineSpacing

        let usableWidth: CGFloat = canvasSize.width - fullMargin

        let itemWidthPlusMargin = itemSize.width + fullMargin

        let columns = (usableWidth / itemWidthPlusMargin).rounded(.down)

        return Int(columns)
    }

    var rowCount: Int {
        let count = Int((canvasSize.height - itemSize.height) / (itemSize.height + minimumInteritemSpacing) + 1)
        return max(count, 1)
    }

    var itemCount: Int? {
        guard let collectionView = self.collectionView else {
            return nil
        }
        let count = collectionView.dataSource?.collectionView(collectionView, numberOfItemsInSection: 0)
        return count
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView = self.collectionView else {
            return .zero
        }
        // Only support single section for now.
        // Only support Horizontal scroll
        let count = collectionView.dataSource?.collectionView(collectionView, numberOfItemsInSection: 0) ?? 0
        var contentSize = canvasSize
        if scrollDirection == UICollectionView.ScrollDirection.horizontal {
            let page = ceilf(Float(count) / Float(rowCount * columnCount))
            contentSize.width = CGFloat(CGFloat(page) * canvasSize.width).rounded(.toNearestOrEven)
        }
        return contentSize
    }

    var numberOfPages: Int {
        guard let itemCount = itemCount else {
            return 1
        }
        let itemsPerPage = maxItemsPerPage
        if itemsPerPage == 0 {
            return 1
        }
        return Int(ceil((CGFloat(itemCount) / CGFloat(itemsPerPage))))
    }

    var maxItemsPerPage: Int {
        return rowCount * columnCount
    }

    // TODO: Fixme when true
    #if os(tvOS)
        var evenlyDistributeItemsInRemainderPage = false
    #else
        var evenlyDistributeItemsInRemainderPage = false
    #endif

    func frameForItemAtIndexPath(_ indexPath: IndexPath) -> CGRect {
        var allItemsWidth: CGFloat = 0
        if columnCount > 1 {
            allItemsWidth = (CGFloat(columnCount) * itemSize.width) + (CGFloat(columnCount - 1) * minimumLineSpacing)
        } else {
            allItemsWidth = itemSize.width
        }

        var pageMarginX = (canvasSize.width - allItemsWidth) / 2.0
        var pageMarginY = (canvasSize.height - CGFloat(rowCount) * itemSize.height - (rowCount > 1 ? CGFloat(rowCount - 1) * (minimumInteritemSpacing / 2.0) : 0)) / 2.0
        pageMarginX = abs(pageMarginX)
        pageMarginY = abs(pageMarginY)

        let page = Int(CGFloat(indexPath.row) / CGFloat(rowCount * columnCount))
        let remainder = Int(CGFloat(indexPath.row) - CGFloat(page) * CGFloat(maxItemsPerPage))
        let row = Int(CGFloat(remainder) / CGFloat(columnCount))
        let column = Int(CGFloat(remainder) - CGFloat(row) * CGFloat(columnCount))

        var cellFrame = CGRect.zero

        let xOffset: CGFloat
        // Calculate centering of cells if page is unfilled
        if evenlyDistributeItemsInRemainderPage {
            // TODO: multiple row version of this var
            let numberOfCellsInRow = numberOfCellsInPage(page + 1)
            // TODO: multiple row version of this var
            let maxItemsPerRow = maxItemsPerPage
            let unusedCellsInRow = maxItemsPerRow - numberOfCellsInRow
            let unusedWidth = (itemSize.width + minimumLineSpacing) * CGFloat(unusedCellsInRow - 1)
            let unusedWidthPerCell = unusedWidth / CGFloat(numberOfCellsInRow)
            let odd = numberOfCellsInRow % 2 != 0
            xOffset = unusedWidthPerCell * CGFloat(column + 1) + (odd ? unusedWidthPerCell / 2.0 : 0)
        } else {
            xOffset = 0
        }

        let itemHeight = min(itemSize.height, canvasSize.height)

        cellFrame.origin.x = (pageMarginX + CGFloat(column) * (itemSize.width + minimumLineSpacing) + xOffset).rounded(.toNearestOrEven)
        cellFrame.origin.y = (pageMarginY + CGFloat(row) * (itemHeight + minimumInteritemSpacing)).rounded(.toNearestOrEven)
        cellFrame.size.width = (itemSize.width).rounded(.toNearestOrEven)
        cellFrame.size.height = itemHeight.rounded(.toNearestOrEven)

        if scrollDirection == UICollectionView.ScrollDirection.horizontal {
            cellFrame.origin.x += CGFloat(page) * canvasSize.width
        }

        return cellFrame
    }

    func numberOfCellsInPage(_ pageNumber: Int) -> Int {
        if pageNumber == numberOfPages, let itemCount = itemCount {
            return itemCount - ((pageNumber - 1) * maxItemsPerPage)
        } else {
            return maxItemsPerPage
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attr = super.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }
        attr.frame = frameForItemAtIndexPath(indexPath)
        return attr
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return super.layoutAttributesForElements(in: rect)?.compactMap({ (attr) -> UICollectionViewLayoutAttributes? in
            let idxPath = attr.indexPath
            let itemFrame = self.frameForItemAtIndexPath(idxPath)
            if itemFrame.intersects(rect) {
                let nAttr = self.layoutAttributesForItem(at: idxPath)
                return nAttr
            } else {
                return nil
            }
        })
    }

    override func shouldInvalidateLayout(forBoundsChange _: CGRect) -> Bool {
        return true
    }
}
