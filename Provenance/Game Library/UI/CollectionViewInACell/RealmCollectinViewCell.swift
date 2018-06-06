//
//  RecentlyPlayedCollectionCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/15/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import RealmSwift

protocol RealmCollectinViewCellDelegate : class {
	func didSelectObject(_ : Object, indexPath: IndexPath)
}

protocol RealmCollectionViewCellBase {
	var minimumInteritemSpacing : CGFloat { get}
//	var additionalFilter : Bool { get }
//	func isIncluded(_ object : Object) -> Bool
}

extension RealmCollectionViewCellBase {
//	func isIncluded(_ object : Object) -> Bool {
//		return true
//	}

//	var additionalFilter : Bool {
//		return false
//	}

	var minimumInteritemSpacing : CGFloat {
		#if os(tvOS)
		return 50
		#else
		return 8.0
		#endif
	}
}

public let PageIndicatorHeight : CGFloat = 2.5

class RealmCollectinViewCell<CellClass:UICollectionViewCell, SelectionObject:Object> : UICollectionViewCell, RealmCollectionViewCellBase, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, UICollectionViewDataSource {
	var additionalFilter : Bool {
		return false
	}

	func isIncluded(_ object : SelectionObject) -> Bool {
		return true
	}

	var queryUpdateToken: NotificationToken? {
		willSet {
			queryUpdateToken?.invalidate()
		}
	}

	weak var selectionDelegate : RealmCollectinViewCellDelegate?

	let query: Results<SelectionObject>
	var count : Int {
		if additionalFilter {
			return query.filter({return self.isIncluded($0)}).count
		} else {
			return query.count
		}
	}

	func itemForIndex(_ index : Int) -> SelectionObject {
		if additionalFilter {
			return query.filter({return self.isIncluded($0)})[index]
		} else {
			return query[index]
		}
	}

	let cellId : String

	var numberOfRows = 1

	var subCellSize : CGSize {
		#if os(tvOS)
		return CGSize(width: 350, height: 280)
		#else
		return CGSize(width: 124, height: 130)
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

	func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
		return false
	}
	#endif

	lazy var layout : CenterViewFlowLayout = {
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
		// TODO : Fix me, hard coded these cause the maths are weird with CenterViewFlowLayout and margins - Joe M
		layout.itemSize = subCellSize
		return layout
	}()

	lazy var internalCollectionView: UICollectionView = {
		let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.showsHorizontalScrollIndicator = false
		collectionView.showsVerticalScrollIndicator = false
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.clipsToBounds = false // allows tvOS magnifcations to overflow the borders

		if #available(iOS 9.0, tvOS 9.0, *) {
			collectionView.remembersLastFocusedIndexPath = false
		}

		#if os(iOS)
		collectionView.isPagingEnabled = true
		#else
//		collectoinView.isScrollEnabled = false
		#endif
		collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 2, left: 2, bottom: 0, right: 2)
		collectionView.indicatorStyle = .white
		return collectionView
	}()

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	init(frame: CGRect, query : Results<SelectionObject>, cellId : String) {
		self.cellId = cellId
		self.query = query
		super.init(frame: frame)
		setupViews()
		setupToken()
	}

	@objc
	func rotated() {
		refreshCollectionView()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	func setupViews() {
		#if os(iOS)
		backgroundColor = Theme.currentTheme.gameLibraryBackground
		#endif

		addSubview(internalCollectionView)

		registerSubCellClass()
		internalCollectionView.frame = self.bounds

		#if os(iOS)
		NotificationCenter.default.addObserver(self, selector: #selector(RealmCollectinViewCell.rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
		#endif

		if #available(iOS 9.0, tvOS 9.0, *) {
			let margins = self.layoutMarginsGuide

			internalCollectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
			internalCollectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0).isActive = true
			internalCollectionView.heightAnchor.constraint(equalTo: margins.heightAnchor, constant: 0).isActive = true
		} else {
			NSLayoutConstraint(item: internalCollectionView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leadingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: internalCollectionView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: internalCollectionView, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant:0.0).isActive = true
		}
		#if os(iOS)
		internalCollectionView.backgroundColor = Theme.currentTheme.gameLibraryBackground
		#endif

		// setup page indicator layout
		self.addSubview(pageIndicator)
		if #available(iOS 9.0, tvOS 9.0, *) {
			let margins = self.layoutMarginsGuide

//			pageIndicator.leadingAnchor.constraint(lessThanOrEqualTo: margins.leadingAnchor, constant: 8).isActive = true
//			pageIndicator.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor, constant: 8).isActive = true
			pageIndicator.centerXAnchor.constraint(equalTo: margins.centerXAnchor).isActive = true
			pageIndicator.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 0).isActive = true
			pageIndicator.heightAnchor.constraint(equalToConstant: PageIndicatorHeight).isActive = true
			pageIndicator.pageCount = layout.numberOfPages
		} else {
			NSLayoutConstraint(item: pageIndicator, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerXWithinMargins, multiplier: 1.0, constant: 0).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant:0.0).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: PageIndicatorHeight).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .leading, relatedBy: .lessThanOrEqual, toItem: self, attribute: .leadingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .trailing, relatedBy: .lessThanOrEqual, toItem: self, attribute: .trailingMargin, multiplier: 1.0, constant: 8.0).isActive = true
		}
		//internalCollectionView
	}

	func registerSubCellClass() {
		internalCollectionView.register(CellClass.self, forCellWithReuseIdentifier: cellId)
	}

	override func layoutMarginsDidChange() {
		super.layoutMarginsDidChange()
		internalCollectionView.flashScrollIndicators()
		self.pageIndicator.pageCount = self.layout.numberOfPages
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		selectionDelegate = nil
//		queryUpdateToken?.invalidate()
//		queryUpdateToken = nil
	}

	lazy var pageIndicator : PillPageControl = {
		let pageIndicator = PillPageControl(frame: CGRect(origin: CGPoint(x: bounds.midX - 38.2, y: bounds.maxY-18), size: CGSize(width:38, height:PageIndicatorHeight)))
		pageIndicator.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		pageIndicator.translatesAutoresizingMaskIntoConstraints = false
		pageIndicator.activeTint = UIColor.init(white: 1.0, alpha: 0.9)
		pageIndicator.activeTint = UIColor.init(white: 1.0, alpha: 0.3)

		#if os(iOS)
//		pageIndicator.currentPageIndicatorTintColor = Theme.currentTheme.defaultTintColor
//		pageIndicator.pageIndicatorTintColor = Theme.currentTheme.gameLibraryText
		#endif
		return pageIndicator
	}()

	// ----
	private func setupToken() {
		queryUpdateToken = query.observe { [unowned self] (changes: RealmCollectionChange) in
			switch changes {
			case .initial(let result):
				DLOG("Initial query result: \(result.count)")
				DispatchQueue.main.async {
					self.refreshCollectionView()
				}
			case .update(_, let deletions, let insertions, let modifications):
				// Query results have changed, so apply them to the UICollectionView
				self.handleUpdate(deletions: deletions, insertions: insertions, modifications: modifications)
			case .error(let error):
				// An error occurred while opening the Realm file on the background worker thread
				fatalError("\(error)")
			}
		}
	}

	func refreshCollectionView() {
		self.internalCollectionView.invalidateIntrinsicContentSize()
		self.internalCollectionView.collectionViewLayout.invalidateLayout()
		self.internalCollectionView.reloadData()
		self.pageIndicator.pageCount = self.layout.numberOfPages
	}

	func handleUpdate( deletions: [Int], insertions: [Int], modifications: [Int]) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			ILOG("Update for collection view cell for class \(self.cellId)")
			self.refreshCollectionView()
		}
		//		internalCollectionView.performBatchUpdates({
		//			ILOG("Section SaveStates updated with Insertions<\(insertions.count)> Mods<\(modifications.count)> Deletions<\(deletions.count)>")
		//			internalCollectionView.insertItems(at: insertions.map({ return IndexPath(row: $0, section: 0) }))
		//			internalCollectionView.deleteItems(at: deletions.map({  return IndexPath(row: $0, section: 0) }))
		//			internalCollectionView.reloadItems(at: modifications.map({  return IndexPath(row: $0, section: 0) }))
		//		}, completion: { (completed) in
		//
		//		})
	}

//	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//		let spacing : CGFloat = numberOfRows > 1 ? minimumInteritemSpacing + PageIndicatorHeight : PageIndicatorHeight
//		let height = max(0, (collectionView.frame.size.height / CGFloat(numberOfRows)) - spacing)
//
//		let viewWidth = internalCollectionView.bounds.size.width
//
//		let itemsPerRow :CGFloat = viewWidth > 800 ? 6 : 3
//		let width :CGFloat = max(0, (viewWidth / itemsPerRow) - (minimumInteritemSpacing * itemsPerRow))
//
//		return CGSize(width: width, height: height)
//	}

//	#if os(tvOS)
//	func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
//		// Quick hack to fix paging on left scrolling on tvOS, not sure why the layout class is missing this, somehting to do with tvOS focus and autoscrolling
//		if var indexPath = context.nextFocusedIndexPath, context.focusHeading == .left, let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath, previouslyFocusedIndexPath.row % layout.columnCount == 0 {
//			indexPath.row = max(0, indexPath.row - layout.columnCount)
//			collectionView.scrollToItem(at: indexPath, at: [.right], animated: true)
//		}
//	}
//	#endif

	/// whether or not dragging has ended
	fileprivate var endDragging = false

	/// the current page
	var currentIndex: Int = 0 {
		didSet {
			updateAccessoryViews()
		}
	}

	// MARK: - UICollectionViewDataSource
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return count
	}

	// MARK: - UICollectionViewDelegate
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let selectedObject = itemForIndex(indexPath.row)
		selectionDelegate?.didSelectObject(selectedObject, indexPath: indexPath)
	}

	override func didTransition(from oldLayout: UICollectionViewLayout, to newLayout: UICollectionViewLayout) {
		super.didTransition(from: oldLayout, to: newLayout)
		pageIndicator.pageCount = layout.numberOfPages
	}

	// MARK: - UICollectionViewDataSource
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let cell = internalCollectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as? CellClass else {
			fatalError("Couldn't create cell of type ...")
		}

//		if indexPath.row < count {
			let objectForRow = itemForIndex(indexPath.row)
			setCellObject(objectForRow, cell: cell)
//		}

		return cell
	}

	func setCellObject(_ object : SelectionObject, cell: CellClass) {
		//
		fatalError("Override me")
	}

//}
//
//
//extension RealmCollectinViewCell : UIScrollViewDelegate {

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

class RecentlyPlayedCollectionCell: RealmCollectinViewCell<PVGameLibraryCollectionViewCell, PVRecentGame> {
	typealias SelectionObject = PVRecentGame
	typealias CellClass = PVGameLibraryCollectionViewCell

	@objc init(frame: CGRect) {
		let recentGamesQuery: Results<SelectionObject> = SelectionObject.all.filter("game != nil").sorted(byKeyPath: #keyPath(SelectionObject.lastPlayedDate), ascending: false)
		super.init(frame: frame, query: recentGamesQuery, cellId: PVGameLibraryCollectionViewCellIdentifier)
	}

	override func registerSubCellClass() {
		// TODO: Use nib for cell once we drop iOS 8 and can use layouts
		if #available(iOS 9.0, tvOS 9.0, *) {
			#if os(iOS)
			internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
			#else
			internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
			#endif
		} else {
			internalCollectionView.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
		}
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func setCellObject(_ object: PVRecentGame, cell: PVGameLibraryCollectionViewCell) {
		cell.game = object.game
	}
}

class FavoritesPlayedCollectionCell: RealmCollectinViewCell<PVGameLibraryCollectionViewCell, PVGame> {
	typealias SelectionObject = PVGame
	typealias CellClass = PVGameLibraryCollectionViewCell

	@objc init(frame: CGRect) {
		let favoriteGamesQuery: Results<SelectionObject> = RomDatabase.sharedInstance.all(PVGame.self, where: "isFavorite", value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
		super.init(frame: frame, query: favoriteGamesQuery, cellId: PVGameLibraryCollectionViewCellIdentifier)
	}

	override func registerSubCellClass() {
		// TODO: Use nib for cell once we drop iOS 8 and can use layouts
		if #available(iOS 9.0, tvOS 9.0, *) {
			#if os(iOS)
			internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
			#else
			internalCollectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
			#endif
		} else {
			internalCollectionView.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
		}
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func setCellObject(_ object: PVGame, cell: PVGameLibraryCollectionViewCell) {
		cell.game = object
	}
}

class SaveStatesCollectionCell: RealmCollectinViewCell<PVSaveStateCollectionViewCell, PVSaveState> {
	typealias SelectionObject = PVSaveState
	typealias CellClass = PVSaveStateCollectionViewCell

//	override var subCellSize : CGSize {
//		#if os(tvOS)
//		return CGSize(width: 300, height: 300)
//		#else
//		return CGSize(width: 124, height: 144)
//		#endif
//	}

	@objc init(frame: CGRect) {
//		let sortDescriptors = [SortDescriptor(keyPath: #keyPath(SelectionObject.lastOpened), ascending: false), SortDescriptor(keyPath: #keyPath(SelectionObject.date), ascending: false)]
		let sortDescriptors = [SortDescriptor(keyPath: #keyPath(SelectionObject.date), ascending: false)]

		let saveStatesQuery: Results<SelectionObject> = SelectionObject.all.filter("game != nil").sorted(by: sortDescriptors)

		super.init(frame: frame, query: saveStatesQuery, cellId: "SaveStateView")
	}

	@objc override func isIncluded(_ object : SelectionObject) -> Bool {
		return !object.isAutosave || object.isNewestAutosave
	}

	@objc override var additionalFilter : Bool {
		return true
	}

	override func registerSubCellClass() {
		#if os(tvOS)
		internalCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
		#else
		internalCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
		#endif
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func setCellObject(_ object: SelectionObject, cell: PVSaveStateCollectionViewCell) {
		cell.saveState = object
	}
}
