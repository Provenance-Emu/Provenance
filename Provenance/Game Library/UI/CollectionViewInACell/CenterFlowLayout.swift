//
//  CenterFlowLayout.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/15/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import UIKit

class CenterViewFlowLayout: UICollectionViewFlowLayout {

	var canvasSize : CGSize {
		return self.collectionView?.frame.size ?? .zero
	}

	var columnCount : Int {
		return Int((canvasSize.width - self.itemSize.width) / (self.itemSize.width + self.minimumLineSpacing) + 1)
	}

	var rowCount : Int {
		let count = Int((canvasSize.height - self.itemSize.height) / (self.itemSize.height + self.minimumInteritemSpacing) + 1)
		return max(count, 1)
	}

	var itemCount : Int? {
		guard let collectionView = self.collectionView else {
			return nil
		}
		let count = collectionView.dataSource?.collectionView(collectionView, numberOfItemsInSection: 0)
		return count
	}

	override var collectionViewContentSize : CGSize {
		// Only support single section for now.
		// Only support Horizontal scroll
		let count = self.collectionView?.dataSource?.collectionView(self.collectionView!, numberOfItemsInSection: 0)
		var contentSize = canvasSize
		if self.scrollDirection == UICollectionViewScrollDirection.horizontal {
			let page = ceilf(Float(count!) / Float(rowCount * columnCount))
			contentSize.width = CGFloat(page) * canvasSize.width
		}
		return contentSize
	}

	var numberOfPages : Int {
		guard let itemCount = itemCount else {
			return 1
		}
		let itemsPerPage = maxItemsPerPage
		if itemsPerPage == 0 {
			return 1
		}
		return Int(ceil((CGFloat(itemCount) / CGFloat(itemsPerPage))))
	}

	var maxItemsPerPage : Int {
		return rowCount * columnCount
	}

	// TODO: Fixme when true
	#if os(tvOS)
	var evenlyDistributeItemsInRemainderPage = false
	#else
	var evenlyDistributeItemsInRemainderPage = false
	#endif

	func frameForItemAtIndexPath(_ indexPath: IndexPath) -> CGRect {
		var allItemsWidth : CGFloat = 0
		if columnCount > 1 {
			allItemsWidth = (CGFloat(columnCount) * self.itemSize.width) + (CGFloat(columnCount-1) * self.minimumLineSpacing)
		} else {
			allItemsWidth = self.itemSize.width
		}

		var pageMarginX = (canvasSize.width - allItemsWidth) / 2.0
		var pageMarginY = (canvasSize.height - CGFloat(rowCount) * self.itemSize.height - (rowCount > 1 ? CGFloat(rowCount - 1) * (self.minimumInteritemSpacing/2.0) : 0)) / 2.0
		pageMarginX = abs(pageMarginX)
		pageMarginY = abs(pageMarginY)

		let page = Int(CGFloat(indexPath.row) / CGFloat(rowCount * columnCount))
		let remainder = Int(CGFloat(indexPath.row) - CGFloat(page) * CGFloat(maxItemsPerPage))
		let row = Int(CGFloat(remainder) / CGFloat(columnCount))
		let column = Int(CGFloat(remainder) - CGFloat(row) * CGFloat(columnCount))

		var cellFrame = CGRect.zero

		let xOffset : CGFloat
		// Calculate centering of cells if page is unfilled
		if evenlyDistributeItemsInRemainderPage {
			// TODO: multiple row version of this var
			let numberOfCellsInRow = numberOfCellsInPage(page+1)
			// TODO: multiple row version of this var
			let maxItemsPerRow = maxItemsPerPage
			let unusedCellsInRow = maxItemsPerRow - numberOfCellsInRow
			let unusedWidth = (self.itemSize.width + self.minimumLineSpacing) * CGFloat(unusedCellsInRow - 1)
			let unusedWidthPerCell = unusedWidth / CGFloat(numberOfCellsInRow)
			let odd = numberOfCellsInRow % 2 != 0
			xOffset = unusedWidthPerCell * CGFloat(column+1) + (odd ? unusedWidthPerCell / 2.0 : 0)
		} else {
			xOffset = 0
		}

		let itemHeight = min(self.itemSize.height, canvasSize.height)

		cellFrame.origin.x = pageMarginX + CGFloat(column) * (self.itemSize.width + self.minimumLineSpacing) + xOffset
		cellFrame.origin.y = pageMarginY + CGFloat(row) * (itemHeight + self.minimumInteritemSpacing)
		cellFrame.size.width = self.itemSize.width
		cellFrame.size.height = itemHeight

		if self.scrollDirection == UICollectionViewScrollDirection.horizontal {
			cellFrame.origin.x += CGFloat(page) * canvasSize.width
		}

		return cellFrame
	}

	func numberOfCellsInPage(_ pageNumber : Int) -> Int {
		if pageNumber == numberOfPages, let itemCount = itemCount {
			return itemCount - ((pageNumber - 1) * maxItemsPerPage)
		} else {
			return maxItemsPerPage
		}
	}

	override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
		let attr = super.layoutAttributesForItem(at: indexPath)?.copy() as! UICollectionViewLayoutAttributes?
		attr!.frame = self.frameForItemAtIndexPath(indexPath)
		return attr
	}

	override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
		let originAttrs = super.layoutAttributesForElements(in: rect)
		var attrs: [UICollectionViewLayoutAttributes]? = Array<UICollectionViewLayoutAttributes>()

		for attr in originAttrs! {
			let idxPath = attr.indexPath
			let itemFrame = self.frameForItemAtIndexPath(idxPath)
			if itemFrame.intersects(rect) {
				let nAttr = self.layoutAttributesForItem(at: idxPath)
				attrs?.append(nAttr!)
			}
		}

		return attrs
	}

	override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
		return true
	}
}
