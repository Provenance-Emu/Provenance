//
//  RecentlyPlayedCollectionCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/15/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
import RxSwift

public let PageIndicatorHeight: CGFloat = 2.5

protocol SubCellItem {
    associatedtype Cell: UICollectionViewCell
    func configure(in cell: Cell)
    static var identifier: String { get }
    static func registerCell(in collectionView: UICollectionView)
}

class CollectionViewInCollectionViewCell<Item: SubCellItem>: UICollectionViewCell, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
    var minimumInteritemSpacing: CGFloat {
        #if os(tvOS)
            return 16.0
        #else
            return 8.0
        #endif
    }
    private let internalDisposeBag = DisposeBag()
    var disposeBag = DisposeBag()
    let items = PublishSubject<[Item]>()

    public static var identifier: String {
        String(describing: Self.self)
    }

    var numberOfRows = 1

    var subCellSize: CGSize {
        #if os(tvOS)
            return CGSize(width: 350, height: 244)
        #else
            let ratio = 5.0 / 4.0
            let width = 100.0
            let height = width * ratio
            return CGSize(width: width, height: height)
        #endif
    }

    #if os(tvOS)

// MARK: tvOS focus

        override var preferredFocusEnvironments: [UIFocusEnvironment] {
            return [internalCollectionView]
        }

        override var canBecomeFocused: Bool {
            return false
        }

        func collectionView(_: UICollectionView, canFocusItemAt _: IndexPath) -> Bool {
            return false
        }
    #endif

    lazy var layout: CenterViewFlowLayout = {
        let layout = CenterViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = minimumInteritemSpacing
        layout.minimumInteritemSpacing = minimumInteritemSpacing

        //		let spacing : CGFloat = numberOfRows > 1 ? PageIndicatorHeight + 5 : PageIndicatorHeight
        //		let height = max(0, (self.bounds.height / CGFloat(numberOfRows)) - spacing)
        //		let minimumItemsPerPageRow : CGFloat = 3.0
        //		let width = self.bounds.width - ((layout.minimumInteritemSpacing) * (minimumItemsPerPageRow) * 0.5)
        //		//		let square = min(width, height)
        //		let square = 120
        // TODO: Fix me, hard coded these cause the maths are weird with CenterViewFlowLayout and margins - Joe M
        layout.itemSize = subCellSize
        return layout
    }()

    lazy var internalCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.clipsToBounds = false // allows tvOS magnifcations to overflow the borders
        collectionView.remembersLastFocusedIndexPath = false

        #if os(iOS)
            collectionView.isPagingEnabled = true
        #else
            //		collectoinView.isScrollEnabled = false
        #endif
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 2, left: 2, bottom: 0, right: 2)
        collectionView.indicatorStyle = .white
        return collectionView
    }()

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        Item.registerCell(in: internalCollectionView)

        items.bind(to: internalCollectionView.rx.items(cellIdentifier: Item.identifier, cellType: Item.Cell.self)) { _, item, cell in
            item.configure(in: cell)
        }
        .disposed(by: internalDisposeBag)
        items.bind(onNext: { _ in self.refreshCollectionView() }).disposed(by: internalDisposeBag)
        internalCollectionView.rx.setDelegate(self).disposed(by: internalDisposeBag)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = .init()
    }

    @objc
    func rotated() {
        refreshCollectionView()
    }

    func setupViews() {
        addSubview(internalCollectionView)

        internalCollectionView.frame = bounds

        #if os(iOS)
            NotificationCenter.default.addObserver(self, selector: #selector(CollectionViewInCollectionViewCell.rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
        #endif

        let margins = self.layoutMarginsGuide

        internalCollectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
        internalCollectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0).isActive = true
        internalCollectionView.heightAnchor.constraint(equalTo: margins.heightAnchor, constant: 36).isActive = true

        // setup page indicator layout
        addSubview(pageIndicator)

        //			pageIndicator.leadingAnchor.constraint(lessThanOrEqualTo: margins.leadingAnchor, constant: 8).isActive = true
        //			pageIndicator.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor, constant: 8).isActive = true
        pageIndicator.centerXAnchor.constraint(equalTo: margins.centerXAnchor).isActive = true
        #if os(tvOS)
            pageIndicator.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 20).isActive = true
        #else
            pageIndicator.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 0).isActive = true
        #endif
        pageIndicator.heightAnchor.constraint(equalToConstant: PageIndicatorHeight).isActive = true
        pageIndicator.pageCount = layout.numberOfPages
        // internalCollectionView
    }

    override func layoutMarginsDidChange() {
        super.layoutMarginsDidChange()
        internalCollectionView.flashScrollIndicators()
        pageIndicator.pageCount = layout.numberOfPages
    }

    lazy var pageIndicator: PillPageControl = {
        let pageIndicator = PillPageControl(frame: CGRect(origin: CGPoint(x: bounds.midX - 38.2, y: bounds.maxY - 18), size: CGSize(width: 38, height: PageIndicatorHeight)))
        pageIndicator.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        pageIndicator.activeTint = UIColor(white: 1.0, alpha: 0.6)
        pageIndicator.inactiveTint = UIColor(white: 1.0, alpha: 0.3)

        return pageIndicator
    }()

    func refreshCollectionView() {
        internalCollectionView.invalidateIntrinsicContentSize()
        internalCollectionView.collectionViewLayout.invalidateLayout()
        internalCollectionView.reloadData()
        pageIndicator.pageCount = layout.numberOfPages
    }

    /// whether or not dragging has ended
    fileprivate var endDragging = false

    /// the current page
    var currentIndex: Int = 0 {
        didSet {
            updateAccessoryViews()
        }
    }

    override func didTransition(from oldLayout: UICollectionViewLayout, to newLayout: UICollectionViewLayout) {
        super.didTransition(from: oldLayout, to: newLayout)
        pageIndicator.pageCount = layout.numberOfPages
    }

    /**
     Update accessory views (i.e. UIPageControl, UIButtons).
     */
    func updateAccessoryViews() {
        pageIndicator.pageCount = layout.numberOfPages
        //		pageIndicator.currentPage = currentIndex
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = scrollView.contentOffset.x / scrollView.bounds.width
        let progressInPage = scrollView.contentOffset.x - (page * scrollView.bounds.width)
        let progress = CGFloat(page) + progressInPage
        pageIndicator.progress = progress
    }

    /**
     scroll view did end dragging
     - parameter scrollView: the scroll view
     - parameter decelerate: wether the view is decelerating or not.
     */
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            endScrolling(scrollView)
        } else {
            endDragging = true
        }
    }

    /**
     Scroll view did end decelerating
     */
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if endDragging {
            endDragging = false
            endScrolling(scrollView)
        }
    }

    /**
     end scrolling
     */
    fileprivate func endScrolling(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        let page = (scrollView.contentOffset.x + (0.5 * width)) / width
        currentIndex = Int(page)
    }
}

private extension PVGameLibraryCollectionViewCell {
    static var identifier: String {
        String(describing: self)
    }

    static func registerCell(in collectionView: UICollectionView, identifier: String) {
        // TODO: Use nib for cell once we drop iOS 8 and can use layouts
        #if os(iOS)
            collectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: identifier)
        #else
            collectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: identifier)
        #endif
    }
}

extension PVGame: SubCellItem {
    func configure(in cell: PVGameLibraryCollectionViewCell) {
        cell.game = self
    }

    static var identifier: String {
        Cell.identifier
    }
    static func registerCell(in collectionView: UICollectionView) {
        Cell.registerCell(in: collectionView, identifier: Self.identifier)
    }
    typealias Cell = PVGameLibraryCollectionViewCell
}

extension PVSaveState: SubCellItem {
    func configure(in cell: PVSaveStateCollectionViewCell) {
        cell.saveState = self
    }

    static var identifier: String {
        "SaveStateView"
    }
    static func registerCell(in collectionView: UICollectionView) {
        #if os(tvOS)
            collectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: Self.identifier)
        #else
            collectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: Self.identifier)
        #endif
    }
}

extension PVRecentGame: SubCellItem {
    func configure(in cell: PVGameLibraryCollectionViewCell) {
        cell.game = game
    }

    static var identifier: String {
        Cell.identifier
    }
    static func registerCell(in collectionView: UICollectionView) {
        Cell.registerCell(in: collectionView, identifier: Self.identifier)
    }
    typealias Cell = PVGameLibraryCollectionViewCell
}

extension CollectionViewInCollectionViewCell {
    func item(at point: CGPoint) -> Item? {
        let internalPoint = internalCollectionView.convert(point, from: superview)
        guard let indexPath = internalCollectionView.indexPathForItem(at: internalPoint)
            else { return nil }
        return try? internalCollectionView.rx.model(at: indexPath)
    }
}
