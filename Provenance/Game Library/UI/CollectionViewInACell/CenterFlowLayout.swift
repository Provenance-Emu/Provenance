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
		let itemsPerPage = CGFloat(rowCount * columnCount)
		if itemsPerPage == 0 {
			return 1
		}
		return Int(ceil((CGFloat(itemCount) / itemsPerPage)))
	}

	func frameForItemAtIndexPath(_ indexPath: IndexPath) -> CGRect {
		let pageMarginX = (canvasSize.width - CGFloat(columnCount) * self.itemSize.width - (columnCount > 1 ? CGFloat(columnCount - 1) * (self.minimumLineSpacing/2.0) : 0)) / 2.0
		let pageMarginY = (canvasSize.height - CGFloat(rowCount) * self.itemSize.height - (rowCount > 1 ? CGFloat(rowCount - 1) * (self.minimumInteritemSpacing/2.0) : 0)) / 2.0

		let page = Int(CGFloat(indexPath.row) / CGFloat(rowCount * columnCount))
		let remainder = Int(CGFloat(indexPath.row) - CGFloat(page) * CGFloat(rowCount * columnCount))
		let row = Int(CGFloat(remainder) / CGFloat(columnCount))
		let column = Int(CGFloat(remainder) - CGFloat(row) * CGFloat(columnCount))

		var cellFrame = CGRect.zero
		cellFrame.origin.x = pageMarginX + CGFloat(column) * (self.itemSize.width + self.minimumLineSpacing)
		cellFrame.origin.y = pageMarginY + CGFloat(row) * (self.itemSize.height + self.minimumInteritemSpacing)
		cellFrame.size.width = self.itemSize.width
		cellFrame.size.height = self.itemSize.height

		if self.scrollDirection == UICollectionViewScrollDirection.horizontal {
			cellFrame.origin.x += CGFloat(page) * canvasSize.width
		}

		return cellFrame
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
}
