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

class CollectionViewInCollectionViewCell<CellClass: UICollectionViewCell, SelectionObject>: UICollectionViewCell, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
    var minimumInteritemSpacing: CGFloat {
        #if os(tvOS)
            return 50
        #else
            return 8.0
        #endif
    }
    let disposeBag = DisposeBag()
    let items = PublishSubject<[SelectionObject]>()

    let cellId: String

    var numberOfRows = 1

    var subCellSize: CGSize {
        #if os(tvOS)
            return CGSize(width: 350, height: 280)
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

    init(frame: CGRect, cellId: String) {
        self.cellId = cellId
        super.init(frame: frame)
        setupViews()

        items.bind(to: internalCollectionView.rx.items(cellIdentifier: cellId, cellType: CellClass.self)) { _, item, cell in
            self.setCellObject(item, cell: cell)
        }
        .disposed(by: disposeBag)
        items.bind(onNext: { _ in self.refreshCollectionView() }).disposed(by: disposeBag)
        internalCollectionView.rx.setDelegate(self).disposed(by: disposeBag)
    }

    @objc
    func rotated() {
        refreshCollectionView()
    }

    func setupViews() {
        #if os(iOS)
            backgroundColor = Theme.currentTheme.gameLibraryBackground
        #endif

        addSubview(internalCollectionView)

        registerSubCellClass()
        internalCollectionView.frame = bounds

        #if os(iOS)
            NotificationCenter.default.addObserver(self, selector: #selector(CollectionViewInCollectionViewCell.rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
        #endif

        let margins = self.layoutMarginsGuide

        internalCollectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
        internalCollectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0).isActive = true
        internalCollectionView.heightAnchor.constraint(equalTo: margins.heightAnchor, constant: 0).isActive = true

        #if os(iOS)
            internalCollectionView.backgroundColor = Theme.currentTheme.gameLibraryBackground
        #endif

        // setup page indicator layout
        addSubview(pageIndicator)

        //			pageIndicator.leadingAnchor.constraint(lessThanOrEqualTo: margins.leadingAnchor, constant: 8).isActive = true
        //			pageIndicator.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor, constant: 8).isActive = true
        pageIndicator.centerXAnchor.constraint(equalTo: margins.centerXAnchor).isActive = true
        pageIndicator.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 0).isActive = true
        pageIndicator.heightAnchor.constraint(equalToConstant: PageIndicatorHeight).isActive = true
        pageIndicator.pageCount = layout.numberOfPages
        // internalCollectionView
    }

    func registerSubCellClass() {
        internalCollectionView.register(CellClass.self, forCellWithReuseIdentifier: cellId)
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
        pageIndicator.activeTint = UIColor(white: 1.0, alpha: 0.9)
        pageIndicator.activeTint = UIColor(white: 1.0, alpha: 0.3)

        #if os(iOS)
            //		pageIndicator.currentPageIndicatorTintColor = Theme.currentTheme.defaultTintColor
            //		pageIndicator.pageIndicatorTintColor = Theme.currentTheme.gameLibraryText
        #endif
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

    func setCellObject(_: SelectionObject, cell _: CellClass) {
        fatalError("Override me")
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

// TODO: This is so similiar to the save states versoin that they can probably be combined by generalziing
// 1) Cell class to use for sub items
// 2) Query and return type

class RecentlyPlayedCollectionCell: CollectionViewInCollectionViewCell<PVGameLibraryCollectionViewCell, PVRecentGame> {
    typealias SelectionObject = PVRecentGame
    typealias CellClass = PVGameLibraryCollectionViewCell

    @objc init(frame: CGRect) {
        super.init(frame: frame, cellId: PVGameLibraryCollectionViewCellIdentifier)
    }

    override func registerSubCellClass() {
        // TODO: Use nib for cell once we drop iOS 8 and can use layouts
        #if os(iOS)
            internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #else
            internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #endif
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setCellObject(_ object: PVRecentGame, cell: PVGameLibraryCollectionViewCell) {
        cell.game = object.game
    }
}

class FavoritesPlayedCollectionCell: CollectionViewInCollectionViewCell<PVGameLibraryCollectionViewCell, PVGame> {
    typealias SelectionObject = PVGame
    typealias CellClass = PVGameLibraryCollectionViewCell

    @objc init(frame: CGRect) {
        super.init(frame: frame, cellId: PVGameLibraryCollectionViewCellIdentifier)
    }

    override func registerSubCellClass() {
        // TODO: Use nib for cell once we drop iOS 8 and can use layouts
        #if os(iOS)
            internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #else
            internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #endif
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setCellObject(_ object: PVGame, cell: PVGameLibraryCollectionViewCell) {
        cell.game = object
    }
}

class SaveStatesCollectionCell: CollectionViewInCollectionViewCell<PVSaveStateCollectionViewCell, PVSaveState> {
    typealias SelectionObject = PVSaveState
    typealias CellClass = PVSaveStateCollectionViewCell

    @objc init(frame: CGRect) {
        super.init(frame: frame, cellId: "SaveStateView")
    }

    override func registerSubCellClass() {
        #if os(tvOS)
            internalCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
        #else
            internalCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
        #endif
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setCellObject(_ object: SelectionObject, cell: PVSaveStateCollectionViewCell) {
        cell.saveState = object
    }
}
