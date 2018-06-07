//  DynamicCollectionViewFlowLayout.swiftg
//  DynamicCollectionViewFlowLayout ( https://github.com/xmartlabs/XLActionController )
//
//  Copyright (c) 2015 Xmartlabs ( whttp://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

open class DynamicCollectionViewFlowLayout: UICollectionViewFlowLayout {


    // MARK: - Properties definition 
    
    open var dynamicAnimator: UIDynamicAnimator?
    open var itemsAligment = UIControlContentHorizontalAlignment.center

    open lazy var collisionBehavior: UICollisionBehavior? = {
        let collision = UICollisionBehavior(items: [])
        return collision
    }()

    open lazy var dynamicItemBehavior: UIDynamicItemBehavior? = {
        let dynamic = UIDynamicItemBehavior(items: [])
        dynamic.allowsRotation = false
        return dynamic
    }()
    
    open lazy var gravityBehavior: UIGravityBehavior? = {
        let gravity = UIGravityBehavior(items: [])
        gravity.gravityDirection = CGVector(dx: 0, dy: -1)
        gravity.magnitude = 4.0
        return gravity
    }()
    
    open var useDynamicAnimator = false {
        didSet(newValue) {
            guard useDynamicAnimator != newValue else {
                return
            }
            
            if useDynamicAnimator {
                dynamicAnimator = UIDynamicAnimator(collectionViewLayout: self)

                dynamicAnimator!.addBehavior(collisionBehavior!)
                dynamicAnimator!.addBehavior(dynamicItemBehavior!)
                dynamicAnimator!.addBehavior(gravityBehavior!)
            }
        }
    }
    
    // MARK: - Intialize
    
    override init() {
        super.init()
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    fileprivate func initialize() {
        minimumInteritemSpacing = 0
        minimumLineSpacing = 0
    }

    // MARK: - UICollectionViewFlowLayout overrides
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let animator = dynamicAnimator else {
            return super.layoutAttributesForElements(in: rect)
        }

        let items = animator.items(in: rect) as NSArray
        return items.flatMap { $0 as? UICollectionViewLayoutAttributes }
    }
    
    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let indexPath = indexPath
        
        guard let animator = dynamicAnimator else {
            return super.layoutAttributesForItem(at: indexPath)
        }
        
        return animator.layoutAttributesForCell(at: indexPath) ?? setupAttributesForIndexPath(indexPath)
    }

    override open func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        
        updateItems.filter { $0.updateAction == .insert && layoutAttributesForItem(at: $0.indexPathAfterUpdate!) == nil } .forEach {
              setupAttributesForIndexPath($0.indexPathAfterUpdate)
        }
    }

    // MARK: - Helpers

    fileprivate func topForItemAt(indexPath: IndexPath) -> CGFloat {
        guard let unwrappedCollectionView = collectionView else {
            return CGFloat(0.0)
        }
        
        // Top within item's section
        var top = CGFloat((indexPath as NSIndexPath).item) * itemSize.height

        if (indexPath as NSIndexPath).section > 0 {
            let lastItemOfPrevSection = unwrappedCollectionView.numberOfItems(inSection: (indexPath as NSIndexPath).section - 1)
            // Add previous sections height recursively. We have to add the sectionInsets and the last section's item height
            let inset = (unwrappedCollectionView.delegate as? UICollectionViewDelegateFlowLayout)?.collectionView?(unwrappedCollectionView, layout: self, insetForSectionAt: (indexPath as NSIndexPath).section) ?? sectionInset
            top += topForItemAt(indexPath: IndexPath(item: lastItemOfPrevSection - 1, section: (indexPath as NSIndexPath).section - 1)) + inset.bottom + inset.top + itemSize.height
        }

        return top
    }

    private func isRTL(for view: UIView) -> Bool {
        return UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .rightToLeft
    }

    @discardableResult
    func setupAttributesForIndexPath(_ indexPath: IndexPath?) -> UICollectionViewLayoutAttributes? {
        guard let indexPath = indexPath, let animator = dynamicAnimator, let collectionView = collectionView else {
            return nil
        }
        
        let delegate: UICollectionViewDelegateFlowLayout = collectionView.delegate as! UICollectionViewDelegateFlowLayout
        
        let collectionItemSize = delegate.collectionView!(collectionView, layout: self, sizeForItemAt: indexPath)
        
        // UIDynamic animator will animate this item from initialFrame to finalFrame.
        
        // Items will be animated from far bottom to its final position in the collection view layout
        let originY = collectionView.frame.size.height - collectionView.contentInset.top
        var frame = CGRect(x: 0, y: topForItemAt(indexPath: indexPath), width: collectionItemSize.width, height: collectionItemSize.height)
        var initialFrame = CGRect(x: 0, y: originY + frame.origin.y, width: collectionItemSize.width, height: collectionItemSize.height)

        // Calculate x position depending on alignment value

        let collectionViewContentWidth = collectionView.bounds.size.width - collectionView.contentInset.left - collectionView.contentInset.right
        let rightMargin = (collectionViewContentWidth - frame.size.width)
        let leftMargin = CGFloat(0.0)

        var translationX: CGFloat
        switch itemsAligment {
        case .center:
            translationX = (collectionViewContentWidth - frame.size.width) * 0.5
        case .fill, .left:
            translationX = leftMargin
        case .right:
            translationX = rightMargin
        case .leading:
            translationX = isRTL(for: collectionView) ? rightMargin : leftMargin
        case .trailing:
            translationX = isRTL(for: collectionView) ? leftMargin : rightMargin
        }

        frame.origin.x = translationX
        frame.origin.y -= collectionView.contentInset.bottom
        initialFrame.origin.x = translationX

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = initialFrame

        let attachmentBehavior: UIAttachmentBehavior

        let collisionBehavior = UICollisionBehavior(items: [attributes])

        let itemBehavior = UIDynamicItemBehavior(items: [attributes])
        itemBehavior.allowsRotation = false

        if (indexPath as NSIndexPath).item == 0 {
            let mass = CGFloat(collectionView.numberOfItems(inSection: (indexPath as NSIndexPath).section))

            itemBehavior.elasticity = (0.70 / mass)

            var topMargin = CGFloat(1.5)
            if (indexPath as NSIndexPath).section > 0 {
                topMargin -= sectionInset.top + sectionInset.bottom
            }
            let fromPoint = CGPoint(x: frame.minX, y: frame.minY + topMargin)
            let toPoint = CGPoint(x: frame.maxX, y: fromPoint.y)
            collisionBehavior.addBoundary(withIdentifier: "top" as NSCopying, from: fromPoint, to: toPoint)

            attachmentBehavior = UIAttachmentBehavior(item: attributes, attachedToAnchor:CGPoint(x: frame.midX, y: frame.midY))
            attachmentBehavior.length = 1
            attachmentBehavior.damping = 0.30 * sqrt(mass)
            attachmentBehavior.frequency = 5.0
            
        } else {
            itemBehavior.elasticity = 0.0

            let fromPoint = CGPoint(x: frame.minX, y: frame.minY)
            let toPoint = CGPoint(x: frame.maxX, y: fromPoint.y)
            collisionBehavior.addBoundary(withIdentifier: "top" as NSCopying, from: fromPoint, to: toPoint)

            let prevPath = IndexPath(item: (indexPath as NSIndexPath).item - 1, section: (indexPath as NSIndexPath).section)
            let prevItemAttributes = layoutAttributesForItem(at: prevPath)!
            attachmentBehavior = UIAttachmentBehavior(item: attributes, attachedTo: prevItemAttributes)
            attachmentBehavior.length = itemSize.height
            attachmentBehavior.damping = 0.0
            attachmentBehavior.frequency = 0.0
        }

        animator.addBehavior(attachmentBehavior)
        animator.addBehavior(collisionBehavior)
        animator.addBehavior(itemBehavior)
        
        return attributes
    }

    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let animator = dynamicAnimator else {
            return super.shouldInvalidateLayout(forBoundsChange: newBounds)
        }

        guard let unwrappedCollectionView = collectionView else {
            return super.shouldInvalidateLayout(forBoundsChange: newBounds)
        }
        
        animator.behaviors
            .filter { $0 is UIAttachmentBehavior || $0 is UICollisionBehavior || $0 is UIDynamicItemBehavior}
            .forEach { animator.removeBehavior($0) }
        
        for section in 0..<unwrappedCollectionView.numberOfSections {
            for item in 0..<unwrappedCollectionView.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)
                setupAttributesForIndexPath(indexPath)
            }
        }
        
        return false
    }
}
