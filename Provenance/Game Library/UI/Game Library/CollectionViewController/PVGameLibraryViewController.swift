//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVGameLibraryViewController.swift
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#if os(iOS)
    import AssetsLibrary
    import SafariServices
#endif
import CoreSpotlight
import GameController
import PVLibrary
import PVSupport
import QuartzCore
import Reachability
import RealmSwift
import RxCocoa
import RxSwift
import UIKit

let PVGameLibraryHeaderViewIdentifier = "PVGameLibraryHeaderView"
let PVGameLibraryFooterViewIdentifier = "PVGameLibraryFooterView"

let PVGameLibraryCollectionViewCellIdentifier = "PVGameLibraryCollectionViewCell"
let PVGameLibraryCollectionViewFavoritesCellIdentifier = "FavoritesColletionCell"
let PVGameLibraryCollectionViewSaveStatesCellIdentifier = "SaveStateColletionCell"
let PVGameLibraryCollectionViewRecentlyPlayedCellIdentifier = "RecentlyPlayedColletionCell"

let PVRequiresMigrationKey = "PVRequiresMigration"

// For Obj-C
public extension NSNotification {
    @objc
    static var PVRefreshLibraryNotification: NSString {
        return "kRefreshLibraryNotification"
    }
}

public extension Notification.Name {
    static let PVRefreshLibrary = Notification.Name("kRefreshLibraryNotification")
    static let PVInterfaceDidChangeNotification = Notification.Name("kInterfaceDidChangeNotification")
}

#if os(iOS)
    let USE_IOS_11_SEARCHBAR = true
#endif

#if os(iOS)
    final class PVDocumentPickerViewController: UIDocumentPickerViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            navigationController?.navigationBar.barStyle = Theme.currentTheme.navigationBarStyle
        }
    }
#endif

final class PVGameLibraryViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate, GameLaunchingViewController, GameSharingViewController, WebServerActivatorController {
    lazy var collectionViewZoom: CGFloat = CGFloat(PVSettingsModel.shared.gameLibraryScale)

    let disposeBag = DisposeBag()
    var watcher: DirectoryWatcher?
    var gameImporter: GameImporter!
    var filePathsToImport = [URL]()

    var collectionView: UICollectionView?
    let maxForSpecialSection = 6

    #if os(iOS)
        var assetsLibrary: ALAssetsLibrary?
    #endif
    var gameForCustomArt: PVGame?

    @IBOutlet var getMoreRomsBarButtonItem: UIBarButtonItem!
    @IBOutlet var sortOptionBarButtonItem: UIBarButtonItem!
    @IBOutlet var conflictsBarButtonItem: UIBarButtonItem!

    #if os(iOS)
        @IBOutlet var libraryInfoContainerView: UIStackView!
        @IBOutlet var libraryInfoLabel: UILabel!
    #endif

    var sectionTitles: [String] {
        var sectionsTitles = [String]()
        if !favoritesIsHidden {
            sectionsTitles.append("Favorites")
        }

        if !saveStatesIsHidden {
            sectionsTitles.append("Recently Saved")
        }

        if !recentGamesIsHidden {
            sectionsTitles.append("Recently Played")
        }

        if let filteredSystems = filteredSystems {
            sectionsTitles.append(contentsOf: filteredSystems.map {
                var title = "\($0.manufacturer) : \($0.shortName)"
                let betaIDs: [SystemIdentifier] = [.AtariJaguar, .Saturn, .Dreamcast]
                let id = $0.enumValue
                if betaIDs.contains(id) {
                    title += " Beta"
                }
                return title
            })
        }
        return sectionsTitles
    }

    var searchResults: Results<PVGame>?
    @IBOutlet var searchField: UITextField?
    var isInitialAppearance = false

    var needToShowConflictsAlert = false {
        didSet {
            updateConflictsButton()
        }
    }

    func updateConflictsButton() {
        guard let gameImporter = gameImporter else {
            return
        }

        #if os(tvOS)
            let enabled = !(gameImporter.conflictedFiles?.isEmpty ?? true)
            var items = [sortOptionBarButtonItem!, getMoreRomsBarButtonItem!]
            if enabled, let conflictsBarButtonItem = conflictsBarButtonItem {
                items.append(conflictsBarButtonItem)
            }
            navigationItem.leftBarButtonItems = items
        #endif
    }

    @IBOutlet var sortOptionsTableView: UITableView!
    lazy var sortOptionsTableViewController: UIViewController = {
        let optionsTableView = sortOptionsTableView
        let avc = UIViewController()
        avc.view = optionsTableView

        #if os(iOS)
            avc.modalPresentationStyle = .popover
            //        avc.popoverPresentationController?.delegate = self
            avc.popoverPresentationController?.barButtonItem = sortOptionBarButtonItem
            avc.popoverPresentationController?.sourceView = collectionView
            avc.preferredContentSize = CGSize(width: 300, height: 500)
            avc.title = "Library Options"
        #else
            //		providesPresentationContextTransitionStyle = true
            //		definesPresentationContext = true
            if #available(tvOS 11.0, *) {
                avc.modalPresentationStyle = .blurOverFullScreen
            } else {
                avc.modalPresentationStyle = .currentContext
            }
            avc.modalTransitionStyle = .coverVertical
        #endif
        return avc
    }()

    var currentSort: SortOptions = PVSettingsModel.shared.sort {
        didSet {
            if currentSort != oldValue {
                PVSettingsModel.shared.sort = currentSort
                systemSectionsTokens.forEach {
                    $1.viewModel.sortOrder = currentSort
                }

                if isViewLoaded {
                    collectionView?.reloadData()
                }
            }
        }
    }

    // MARK: - Lifecycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        do {
            try RomDatabase.initDefaultDatabase()
            UserDefaults.standard.register(defaults: [PVRequiresMigrationKey: true])
        } catch {
            let alert = UIAlertController(title: "Database Error", message: error.localizedDescription, preferredStyle: .alert)
            ELOG(error.localizedDescription)
            alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: { _ in
                fatalError(error.localizedDescription)
            }))
            present(alert, animated: true, completion: nil)
        }
    }

    #if os(iOS)
        override var preferredStatusBarStyle: UIStatusBarStyle {
            return .lightContent
        }
    #endif

    deinit {
        NotificationCenter.default.removeObserver(self)

        unregisterForChange()
    }

    @objc func handleAppDidBecomeActive(_: Notification) {
        loadGameFromShortcut()
    }

    /// Cell to focus on if we update focus
    var manualFocusCell: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()
        isInitialAppearance = true
        definesPresentationContext = true

        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.databaseMigrationStarted(_:)), name: NSNotification.Name.DatabaseMigrationStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.databaseMigrationFinished(_:)), name: NSNotification.Name.DatabaseMigrationFinished, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleCacheEmptied(_:)), name: NSNotification.Name.PVMediaCacheWasEmptied, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleArchiveInflationFailed(_:)), name: NSNotification.Name.PVArchiveInflationFailed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleRefreshLibrary(_:)), name: NSNotification.Name.PVRefreshLibrary, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleTextFieldDidChange(_:)), name: UITextField.textDidChangeNotification, object: searchField)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleAppDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        #if os(iOS)
            navigationController?.navigationBar.tintColor = Theme.currentTheme.barButtonItemTint
            navigationItem.leftBarButtonItem?.tintColor = Theme.currentTheme.barButtonItemTint

            NotificationCenter.default.addObserver(forName: NSNotification.Name.PVInterfaceDidChangeNotification, object: nil, queue: nil, using: { (_: Notification) -> Void in
                DispatchQueue.main.async {
                    self.collectionView?.collectionViewLayout.invalidateLayout()
                    self.collectionView?.reloadData()
                }
            })
        #endif

        if UserDefaults.standard.bool(forKey: PVRequiresMigrationKey) {
            migrateLibrary()
        }
        initRealmResultsStorage()
//        setUpGameLibrary()

        #if os(iOS)
            if #available(iOS 11.0, *), USE_IOS_11_SEARCHBAR {
                // Hide the pre-iOS 11 search bar
                searchField?.removeFromSuperview()
                navigationItem.titleView = nil

                // Navigation bar large titles
                navigationController?.navigationBar.prefersLargeTitles = false
                navigationItem.title = nil

                // Create a search controller
                let searchController = UISearchController(searchResultsController: nil)
                searchController.searchBar.placeholder = "Search"
                searchController.searchResultsUpdater = self
                searchController.obscuresBackgroundDuringPresentation = false
                searchController.hidesNavigationBarDuringPresentation = true

                searchController.delegate = self
                navigationItem.hidesSearchBarWhenScrolling = true
                navigationItem.searchController = searchController
            }

            // TODO: For below iOS 11, can make searchController.searchbar. the navigationItem.titleView and get a similiar effect
        #endif

        // load the config file
        title = nil

        let layout = PVGameLibraryCollectionFlowLayout()
        layout.scrollDirection = .vertical

        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        self.collectionView = collectionView
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.bounces = true
        collectionView.alwaysBounceVertical = true
        collectionView.delaysContentTouches = false
        collectionView.keyboardDismissMode = .interactive
        collectionView.register(PVGameLibrarySectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier)
        collectionView.register(PVGameLibrarySectionFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: PVGameLibraryFooterViewIdentifier)

        #if os(tvOS)
            collectionView.contentInset = UIEdgeInsets(top: 40, left: 80, bottom: 40, right: 80)
            collectionView.remembersLastFocusedIndexPath = false
            collectionView.clipsToBounds = false
        #else
            collectionView.backgroundColor = Theme.currentTheme.gameLibraryBackground
            searchField?.keyboardAppearance = Theme.currentTheme.keyboardAppearance

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(PVGameLibraryViewController.didReceivePinchGesture(gesture:)))
            pinchGesture.cancelsTouchesInView = true
            collectionView.addGestureRecognizer(pinchGesture)
        #endif

        view.addSubview(collectionView)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(PVGameLibraryViewController.longPressRecognized(_:)))
        collectionView.addGestureRecognizer(longPressRecognizer)

        // Cells that are a collection view themsevles
        collectionView.register(FavoritesPlayedCollectionCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewFavoritesCellIdentifier)
        collectionView.register(SaveStatesCollectionCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewSaveStatesCellIdentifier)
        collectionView.register(RecentlyPlayedCollectionCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewRecentlyPlayedCellIdentifier)

        // TODO: Use nib for cell once we drop iOS 8 and can use layouts
        if #available(iOS 9.0, tvOS 9.0, *) {
            #if os(iOS)
                collectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
            #else
                collectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
            #endif
        } else {
            collectionView.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        }
        // Adjust collection view layout for iPhone X Safe areas
        // Can remove this when we go iOS 9+ and just use safe areas
        // in the story board directly - jm
        #if os(iOS)
            if #available(iOS 11.0, *) {
                collectionView.translatesAutoresizingMaskIntoConstraints = false
                let guide = view.safeAreaLayoutGuide
                NSLayoutConstraint.activate([
                    collectionView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                    collectionView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
                    collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                    collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])
                layout.sectionInsetReference = .fromSafeArea
            } else {
                layout.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
            }
        #endif
        // Force touch
        #if os(iOS)
            if #available(iOS 9.0, *) {
                registerForPreviewing(with: self, sourceView: collectionView)
            }
        #endif

        #if os(iOS)
            view.bringSubviewToFront(libraryInfoContainerView)
        #endif

        setUpGameLibrary()

        loadGameFromShortcut()
        becomeFirstResponder()
    }

    var unsortedSystems: Results<PVSystem>? {
        didSet {
            filteredSystemClear()
        }
    }

    internal func filteredSystemClear() { filteredSystemsCached = nil }
    private var filteredSystemsCached: [PVSystem]?
    var filteredSystems: [PVSystem]? {
        if let filteredSystemsCached = filteredSystemsCached {
            return filteredSystemsCached
        }
        let sorted = systemsByCurrentSort()
        filteredSystemsCached = sorted
        return sorted
    }

    var saveStates: Results<PVSaveState>?
    var favoriteGames: Results<PVGame>?
    var recentGames: Results<PVRecentGame>?

    var systemsToken: NotificationToken?
    var savesStatesToken: NotificationToken?
    var favoritesToken: NotificationToken?
    var recentGamesToken: NotificationToken?

    var searchResultsToken: NotificationToken?

    var favoritesIsHidden = true
    var saveStatesIsEmpty = true
    var saveStatesIsHidden: Bool {
        return saveStatesIsEmpty || !PVSettingsModel.shared.showRecentSaveStates
    }

    let semaphore = DispatchSemaphore(value: 1)

    var recentGamesIsEmpty = true
    var recentGamesIsHidden: Bool {
        return recentGamesIsEmpty || !PVSettingsModel.shared.showRecentGames
    }

    var favoritesSection: Int {
        return favoritesIsHidden ? -1 : 0
    }

    var saveStateSection: Int {
        if saveStatesIsHidden {
            return -1
        } else {
            return favoritesIsHidden ? 0 : 1
        }
    }

    var recentGamesSection: Int {
        if recentGamesIsHidden {
            return -1
        } else {
            return (favoritesIsHidden ? 0 : 1) + (saveStatesIsHidden ? 0 : 1)
        }
    }

    #if os(tvOS)
        var focusedGame: PVGame?
    #endif

    #if os(iOS)
        @objc
        func didReceivePinchGesture(gesture: UIPinchGestureRecognizer) {
            guard let collectionView = collectionView else {
                return
            }

            let minScale: CGFloat = 0.4
            let maxScale: CGFloat = traitCollection.horizontalSizeClass == .compact ? 1.5 : 2.0

            struct Holder {
                static var scaleStart: CGFloat = 1.0
                static var normalisedY: CGFloat = 0.0
            }

            switch gesture.state {
            case .began:
                Holder.scaleStart = collectionViewZoom
                collectionView.isScrollEnabled = false

                Holder.normalisedY = gesture.location(in: collectionView).y / collectionView.collectionViewLayout.collectionViewContentSize.height
            case .changed:
                var newScale = Holder.scaleStart * gesture.scale
                if newScale < minScale {
                    newScale = minScale
                } else if newScale > maxScale {
                    newScale = maxScale
                }

                if newScale != collectionViewZoom {
                    collectionViewZoom = newScale
                    collectionView.collectionViewLayout.invalidateLayout()

                    let dragCenter = gesture.location(in: collectionView.superview ?? collectionView)
                    let currentY = Holder.normalisedY * collectionView.collectionViewLayout.collectionViewContentSize.height
                    collectionView.setContentOffset(CGPoint(x: 0, y: currentY - dragCenter.y), animated: false)
                }
            case .ended, .cancelled:
                collectionView.isScrollEnabled = true
                PVSettingsModel.shared.gameLibraryScale = Double(collectionViewZoom)
            default:
                break
            }
        }
    #endif

    final class SystemSection: Equatable {
        struct ViewModel {
            var collapsed = false
            var sortOrder: SortOptions = .title
        }

        let id: String
        let system: PVSystem

        var viewModel = ViewModel() {
            didSet {
                if viewModel.sortOrder != oldValue.sortOrder {
                    storedQuery = generateQuery()
                    notificationToken = generateToken()
                }
            }
        }

        var itemsCount: Int {
            return viewModel.collapsed ? 0 : system.games.count
        }

        weak var gameLibraryGameController: PVGameLibraryViewController?

        init(system: PVSystem, gameLibraryViewController: PVGameLibraryViewController, sortOrder: SortOptions = .title) {
            self.system = system
            id = system.identifier
            viewModel.sortOrder = sortOrder
            viewModel.collapsed = PVSettingsModel.shared.collapsedSystems.contains(system.identifier)
            gameLibraryGameController = gameLibraryViewController
            storedQuery = generateQuery()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.notificationToken = self.generateToken()
            }
        }

        var notificationToken: NotificationToken? {
            didSet {
                oldValue?.invalidate()
            }
        }

        private var storedQuery: Results<PVGame>?
        var query: Results<PVGame> {
            if let storedQuery = storedQuery {
                return storedQuery
            } else {
                let newQuery = generateQuery()
                storedQuery = newQuery
                notificationToken = generateToken()
                return newQuery
            }
        }

        private func generateQuery() -> Results<PVGame> {
            var sortDescriptors = [SortDescriptor(keyPath: #keyPath(PVGame.isFavorite), ascending: false)]
            switch viewModel.sortOrder {
            case .title:
                break
            case .importDate:
                sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.importDate), ascending: false))
            case .lastPlayed:
                sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.lastPlayed), ascending: false))
            }

            sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: true))

            return system.games.sorted(by: sortDescriptors)
        }

        private func generateToken() -> NotificationToken {
            let newToken = query.observe { [weak self] (changes: RealmCollectionChange<Results<PVGame>>) in
                guard let `self` = self else { return }
                guard let gameLibraryGameController = self.gameLibraryGameController else { return }

                switch changes {
                case .initial:
                    if gameLibraryGameController.isInSearch {
                        return
                    }
                    // New additions already handled by systems token
                    //                guard let collectionView = self.collectionView else {
                    //                    return
                    //                }
                    //                let systemsCount = self.systems.count
                    //                if systemsCount > 0 {
                    //                    let indexes = self.systemsSectionOffset..<(systemsCount + self.systemsSectionOffset)
                    //                    let indexSet = IndexSet(indexes)
                    //                    collectionView.insertSections(indexSet)
                    //                }
                    // Query results have changed, so apply them to the UICollectionView

                    gameLibraryGameController.semaphore.wait()
                    defer {
                        gameLibraryGameController.semaphore.signal()
                    }
                    guard let systems = gameLibraryGameController.filteredSystems, let indexOfSystem = systems.index(of: self.system) else {
                        WLOG("Index of system changed.")
                        return
                    }

                    let section = indexOfSystem + gameLibraryGameController.systemsSectionOffset
//                    gameLibraryGameController.collectionView?.reloadSections(IndexSet(integer: section))
                    gameLibraryGameController.collectionView?.reloadData()
                case let .update(_, deletions, insertions, modifications):
                    if gameLibraryGameController.isInSearch {
                        return
                    }

                    gameLibraryGameController.semaphore.wait()
                    defer {
                        gameLibraryGameController.semaphore.signal()
                    }

                    // Query results have changed, so apply them to the UICollectionView
                    guard let indexOfSystem = gameLibraryGameController.filteredSystems?.index(of: self.system) else {
                        WLOG("Index of system changed.")
                        return
                    }

                    let section = indexOfSystem + gameLibraryGameController.systemsSectionOffset
                    gameLibraryGameController.handleUpdate(forSection: section, deletions: deletions, insertions: insertions, modifications: modifications, needsInsert: false)
                case let .error(error):
                    // An error occurred while opening the Realm file on the background worker thread
                    fatalError("\(error)")
                }
            }
            return newToken
        }

        deinit {
            notificationToken?.invalidate()
        }

        public static func == (lhs: SystemSection, rhs: SystemSection) -> Bool {
            return lhs.id == rhs.id
        }
    }

    var systemSectionsTokens = [String: SystemSection]()
    var systemsSectionOffset: Int {
        var section = favoritesIsHidden ? 0 : 1
        section += saveStatesIsHidden ? 0 : 1
        section += recentGamesIsHidden ? 0 : 1
        return section
    }

    var isInSearch: Bool {
        return searchResults != nil
    }

    func addSectionToken(forSystem system: PVSystem) {
        let newSystemSection = SystemSection(system: system, gameLibraryViewController: self, sortOrder: currentSort)
        if let existingToken = systemSectionsTokens[newSystemSection.id] {
            existingToken.notificationToken?.invalidate()
        }
        systemSectionsTokens[newSystemSection.id] = newSystemSection
    }

    func initRealmResultsStorage() {
        guard RomDatabase.databaseInitilized else {
            return
        }

        unsortedSystems = PVSystem.all.filter("games.@count > 0")
        saveStates = PVSaveState.all.filter("game != nil && game.system != nil").sorted(byKeyPath: #keyPath(PVSaveState.lastOpened), ascending: false).sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)
        recentGames = PVRecentGame.all.filter("game != nil").sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
        favoriteGames = PVGame.all.filter("isFavorite == YES").sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
    }

    func systemsByCurrentSort() -> [PVSystem]? {
        guard let systems = unsortedSystems else {
            return nil
        }

        let nameSort: [SortDescriptor] = [SortDescriptor(keyPath: #keyPath(PVSystem.manufacturer), ascending: true),
                                          SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: true)]

        let titleSort: (PVSystem, PVSystem) -> Bool = { (s1, s2) -> Bool in
            let mc = s1.manufacturer.compare(s2.manufacturer)
            if mc == .orderedSame {
                return s1.name.compare(s2.name) == .orderedAscending
            } else {
                return mc == .orderedAscending
            }
        }

        switch currentSort {
        case .title:
            return systems.sorted(by: titleSort)
        case .lastPlayed:
            return systems.sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.games.sorted(byKeyPath: "lastPlayed", ascending: false).first?.lastPlayed
                let l2 = s2.games.sorted(byKeyPath: "lastPlayed", ascending: false).first?.lastPlayed

                if let l1 = l1, let l2 = l2 {
                    return l1.compare(l2) == .orderedDescending
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        case .importDate:
            return systems.sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.games.sorted(byKeyPath: "importDate", ascending: false).first?.importDate
                let l2 = s2.games.sorted(byKeyPath: "importDate", ascending: false).first?.importDate

                if let l1 = l1, let l2 = l2 {
                    return l1.compare(l2) == .orderedDescending
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        }
    }

    func deinitRealmResultsStorage() {
        unsortedSystems = nil
        saveStates = nil
        recentGames = nil
        favoriteGames = nil
    }

    func registerForChange() {
        systemsToken?.invalidate()
        systemsToken = unsortedSystems!.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case let .initial(result):
                self.filteredSystemClear()

                result.forEach { system in
                    self.addSectionToken(forSystem: system)
                }

                // Results are now populated and can be accessed without blocking the UI
                self.semaphore.wait()
                self.setUpGameLibrary()
                self.semaphore.signal()
                #if os(iOS)
                    self.libraryInfoContainerView.isHidden = !result.isEmpty
                #endif
            case .update(let systems, let deletions, let insertions, _):
                self.filteredSystemClear()

                if self.isInSearch {
                    return
                }

                guard let collectionView = self.collectionView else { return }

                #if os(iOS)
                    self.libraryInfoContainerView.isHidden = !systems.isEmpty
                #endif

                self.semaphore.wait()
                collectionView.reloadData()
                self.semaphore.signal()
            //                collectionView.performBatchUpdates({
            //                    self.semaphore.wait()
            //
            //                    let insertIndexes = insertions.map { $0 + self.systemsSectionOffset }
            //                    collectionView.insertSections(IndexSet(insertIndexes))
            //
            //                    let delectIndexes = deletions.map { $0 + self.systemsSectionOffset }
            //                    collectionView.deleteSections(IndexSet(delectIndexes))
            //
            //                    deletions.forEach {
            //                        guard let systems = self.systems else {
            //                            return
            //                        }
            //                        let identifier = systems[$0].identifier
            //                        self.systemSectionsTokens.removeValue(forKey: identifier)
            //                    }
            //                    // Not needed since we have watchers per section
            //                    // collectionView.reloadSection(modifications.map{ return IndexPath(row: 0, section: $0 + systemsSectionOffset) })
            //                    self.semaphore.signal()
            //                }, completion: { (success) in
            //                    self.semaphore.wait()
            //                    systems.filter({self.systemSectionsTokens[$0.identifier] == nil}).forEach { self.addSectionToken(forSystem: $0) }
            //                    self.semaphore.signal()
            //                })
            case let .error(error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }

            #if os(iOS)
                self.libraryInfoContainerView.isHidden = (self.unsortedSystems != nil && !self.unsortedSystems!.isEmpty)
            #endif
        }

        savesStatesToken?.invalidate()
        savesStatesToken = saveStates!.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case let .initial(result):
                if !result.isEmpty {
                    self.saveStatesIsEmpty = false
                }

                self.semaphore.wait()
                self.collectionView?.reloadData()
                self.semaphore.signal()
            case let .update(_, deletions, insertions, modifications):
                ILOG("Save states update: \(deletions.count) \(insertions.count) \(modifications.count)")
                if self.isInSearch {
                    return
                }

                self.semaphore.signal()
                defer {
                    self.semaphore.signal()
                }

                self.collectionView?.reloadData()
            //                let needsInsert = self.saveStatesIsHidden && !insertions.isEmpty
            //                let needsDelete = (self.saveStates?.isEmpty ?? true) && !deletions.isEmpty
            //
            //                if self.saveStatesIsHidden {
            //                    self.saveStatesIsEmpty = needsDelete
            //                    return
            //                }
            //
            //                let section = self.saveStateSection > -1 ? self.saveStateSection : 0
            //
            //                if needsInsert {
            //                    ILOG("Needs insert, saveStatesIsHidden - false")
            //                    self.saveStatesIsEmpty = false
            //                }
            //
            //                if needsDelete {
            //                    ILOG("Needs delete, saveStatesIsHidden - true")
            //                    self.saveStatesIsEmpty = true
            //                }
            //
            //                if needsInsert {
            //                    ILOG("Inserting section \(section)")
            //                    self.collectionView?.insertSections([section])
            //                }
            //
            //                if needsDelete {
            //                    ILOG("Deleting section \(section)")
            //                    self.collectionView?.deleteSections([section])
            //                }
            //
            //                self.saveStatesIsEmpty = needsDelete
            case let .error(error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }

        recentGamesToken?.invalidate()
        recentGamesToken = recentGames!.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case let .initial(result):
                if !result.isEmpty {
                    self.recentGamesIsEmpty = false

                    self.semaphore.wait()
                    self.collectionView?.reloadData()
                    self.semaphore.signal()
                }
            case .update(_, let deletions, let insertions, _ /* modifications */ ):
                if self.isInSearch {
                    return
                }

                self.semaphore.wait()
                defer {
                    self.semaphore.signal()
                }

                self.collectionView?.reloadData()
//                let needsInsert = self.recentGamesIsHidden && !insertions.isEmpty
//                let needsDelete = (self.recentGames?.isEmpty ?? true) && !deletions.isEmpty
//
//                if self.recentGamesIsHidden {
//                    self.recentGamesIsEmpty = needsDelete
//                    return
//                }
//
                ////                let section = self.recentGamesSection > -1 ? self.recentGamesSection : 0
//
//                    if needsInsert {
//                        ILOG("Needs insert, recentGamesHidden - false")
//                        self.recentGamesIsEmpty = false
//                        self.collectionView?.insertSections([self.recentGamesSection])
//                    }
//
//                    if needsDelete {
//                        ILOG("Needs delete, recentGamesHidden - true")
//                        self.recentGamesIsEmpty = true
//                        self.collectionView?.deleteSections([self.recentGamesSection])
//                    }
//                    // Query results have changed, so apply them to the UICollectionView
//                self.recentGamesIsEmpty = needsDelete

            case let .error(error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }

        favoritesToken?.invalidate()
        favoritesToken = favoriteGames!.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case let .initial(result):
                if !result.isEmpty {
                    self.favoritesIsHidden = false
                    self.semaphore.wait()
                    self.collectionView?.reloadData()
                    self.semaphore.signal()
                }
            case .update(_, let deletions, let insertions, _):
                if self.isInSearch {
                    return
                }

                self.semaphore.wait()
                defer {
                    self.semaphore.signal()
                }

                let needsInsert = self.favoritesIsHidden && !insertions.isEmpty
                var needsDelete: Bool = false
                if let favoriteGames = self.favoriteGames {
                    let totalDeletions = deletions.count - insertions.count
                    needsDelete = (favoriteGames.isEmpty && insertions.isEmpty) || (favoriteGames.count < totalDeletions)
                }
                let existingFavoritesSection = self.favoritesSection
                self.favoritesIsHidden = needsDelete

                if needsInsert {
                    self.collectionView?.insertSections([self.favoritesSection])
                }

                if needsDelete, existingFavoritesSection >= 0 {
                    self.collectionView?.deleteSections([existingFavoritesSection])
                }
            case let .error(error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }
    }

    func filterRecents(_ changes: [Int]) -> [Int] {
        return changes.filter { $0 < self.maxForSpecialSection }
    }

    func handleUpdate(forSection section: Int, deletions: [Int], insertions: [Int], modifications: [Int], needsInsert: Bool = false, needsDelete: Bool = false) {
        guard let collectionView = collectionView else { return }
        #if false
            collectionView.performBatchUpdates({
                // 1. Delete
                if needsDelete {
                    ILOG("Deleting section \(section)")
                    collectionView.deleteSections([section])
                }

                // 2. Update
                ILOG("Section \(section) updated with Insertions<\(insertions.count)> Mods<\(modifications.count)> Deletions<\(deletions.count)>")
                collectionView.deleteItems(at: deletions.map({ IndexPath(row: $0, section: section) }))
                collectionView.reloadItems(at: modifications.map({ IndexPath(row: $0, section: section) }))
                collectionView.insertItems(at: insertions.map({ IndexPath(row: $0, section: section) }))

                // 3. Insert
                if needsInsert {
                    ILOG("Inserting section \(section)")
                    collectionView.insertSections([section])
                }
            }, completion: { _ in
                DLOG("Library collection view update completed")
            })
        #else
//        if section < collectionView.numberOfSections {
//            collectionView.reloadSections([section])
//        } else {
            collectionView.reloadData()
//        }
        #endif
    }

    func unregisterForChange() {
        systemsToken?.invalidate()
        savesStatesToken?.invalidate()
        recentGamesToken?.invalidate()
        favoritesToken?.invalidate()
        searchResultsToken?.invalidate()

        systemsToken = nil
        savesStatesToken = nil
        recentGamesToken = nil
        favoritesToken = nil
        searchResultsToken = nil
        systemSectionsTokens.removeAll()
    }

    func loadGameFromShortcut() {
        let appDelegate = UIApplication.shared.delegate as! PVAppDelegate

        if let shortcutItemGame = appDelegate.shortcutItemGame {
            load(shortcutItemGame, sender: collectionView, core: nil)
            appDelegate.shortcutItemGame = nil
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let indexPaths = collectionView?.indexPathsForSelectedItems

        indexPaths?.forEach({ indexPath in
            (self.collectionView?.deselectItem(at: indexPath, animated: true))!
        })

        guard RomDatabase.databaseInitilized else {
            return
        }

        registerForChange()

        if isViewLoaded {
            updateConflictsButton()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForChange()
        watcher?.stopMonitoring()
        watcherQueue.isSuspended = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = PVControllerManager.shared
        if isInitialAppearance {
            isInitialAppearance = false
            #if os(tvOS)
                let cell: UICollectionViewCell? = collectionView?.cellForItem(at: IndexPath(item: 0, section: 0))
                cell?.setNeedsFocusUpdate()
                cell?.updateFocusIfNeeded()
            #endif
        }

        guard RomDatabase.databaseInitilized else {
            return
        }

        if isViewLoaded {
            updateConflictsButton()
        }

        watcher?.startMonitoring()
        watcherQueue.isSuspended = false

        // Warn non core dev users if they're running in debug mode
        #if DEBUG && !targetEnvironment(simulator)
            if !PVSettingsModel.shared.haveWarnedAboutDebug, !officialBundleID {
                #if os(tvOS)
                    let releaseScheme = "ProvenanceTV-Release"
                #else
                    let releaseScheme = "Provenance-Release"
                #endif
                let alert = UIAlertController(title: "Debug Mode Detected",
                                              message: "⚠️ Detected app built in 'Debug' mode. Build with the " + releaseScheme + " scheme in XCode for best performance. This alert will only be presented this one time.",
                                              preferredStyle: .alert)
                let ok = UIAlertAction(title: "OK", style: .default) { _ in
                    PVSettingsModel.shared.haveWarnedAboutDebug = true
                }
                alert.addAction(ok)
                present(alert, animated: true)
            }
        #endif
    }

    fileprivate lazy var officialBundleID: Bool = Bundle.main.bundleIdentifier!.contains("com.provenance-emu.")

    var transitioningToSize: CGSize?
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        transitioningToSize = size
        collectionView?.collectionViewLayout.invalidateLayout()
        coordinator.notifyWhenInteractionEnds { [weak self] _ in
            self?.transitioningToSize = nil
        }
    }

    #if os(iOS)
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            return .all
        }
    #endif

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SettingsSegue" {} else if segue.identifier == "gameMoreInfoSegue" {
            let game = sender as! PVGame
            let moreInfoVC = segue.destination as! PVGameMoreInfoViewController
            moreInfoVC.game = game
        } else if segue.identifier == "gameMoreInfoPageVCSegue" {
            let game = sender as! PVGame

            let firstVC = UIStoryboard(name: "Provenance", bundle: nil).instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController
            firstVC.game = game

            let moreInfoCollectionVC = segue.destination as! GameMoreInfoPageViewController
            moreInfoCollectionVC.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
        }
    }

    #if os(iOS)
        // Show web server (stays on)
        @available(iOS 9.0, *)
        func showServer() {
            let ipURL = URL(string: PVWebServer.shared.urlString)
            let safariVC = SFSafariViewController(url: ipURL!, entersReaderIfAvailable: false)
            safariVC.delegate = self
            present(safariVC, animated: true) { () -> Void in }
        }

        @available(iOS 9.0, *)
        func safariViewController(_: SFSafariViewController, didCompleteInitialLoad _: Bool) {
            // Load finished
        }

        // Dismiss and shut down web server
        @available(iOS 9.0, *)
        func safariViewControllerDidFinish(_: SFSafariViewController) {
            // Done button pressed
            navigationController?.popViewController(animated: true)
            PVWebServer.shared.stopServers()
        }

    #endif

    @IBAction func conflictsButtonTapped(_: Any) {
        displayConflictVC()
    }

    @IBAction func sortButtonTapped(_: Any) {
        #if os(iOS)
            // Add done button to iPhone
            // iPad is a popover do no done button needed
            if traitCollection.horizontalSizeClass == .compact {
                let navController = UINavigationController(rootViewController: sortOptionsTableViewController)
                sortOptionsTableViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(PVGameLibraryViewController.dismissVC))
                sortOptionsTableView.reloadData()
                present(navController, animated: true, completion: nil)
                return
            } else {
                sortOptionsTableViewController.popoverPresentationController?.barButtonItem = sortOptionBarButtonItem
                sortOptionsTableViewController.popoverPresentationController?.sourceView = collectionView
                sortOptionsTableView.reloadData()
                present(sortOptionsTableViewController, animated: true, completion: nil)
            }
        #else
            sortOptionsTableView.reloadData()
            present(sortOptionsTableViewController, animated: true, completion: nil)
        #endif
    }

    @objc func dismissVC() {
        dismiss(animated: true, completion: nil)
    }

    lazy var reachability = Reachability()!

    // MARK: - Filesystem Helpers

    @IBAction func getMoreROMs(_ sender: Any) {
        do {
            try reachability.startNotifier()
        } catch {
            ELOG("Unable to start notifier")
        }

        #if os(iOS)
            // connected via wifi, let's continue

            let actionSheet = UIAlertController(title: "Select Import Source", message: nil, preferredStyle: .actionSheet)

            actionSheet.addAction(UIAlertAction(title: "Cloud & Local Files", style: .default, handler: { _ in
                let extensions = [UTI.rom, UTI.artwork, UTI.savestate, UTI.zipArchive, UTI.sevenZipArchive, UTI.gnuZipArchive, UTI.image, UTI.jpeg, UTI.png, UTI.bios, UTI.data].map { $0.rawValue }

                //        let documentMenu = UIDocumentMenuViewController(documentTypes: extensions, in: .import)
                //        documentMenu.delegate = self
                //        present(documentMenu, animated: true, completion: nil)
                if #available(iOS 11.0, *) {
                    // iOS 8 need iCloud entitlements, check
                } else {
                    if FileManager.default.ubiquityIdentityToken == nil {
                        self.presentMessage("Your version reqires iCloud entitlements to use this feature. Please rebuild with iCloud entitlements enabled.", title: "iCloud Error")
                        return
                    }
                }

                let documentPicker = PVDocumentPickerViewController(documentTypes: extensions, in: .import)
                if #available(iOS 11.0, *) {
                    documentPicker.allowsMultipleSelection = true
                }
                documentPicker.delegate = self
                self.present(documentPicker, animated: true, completion: nil)
            }))

            let webServerAction = UIAlertAction(title: "Web Server", style: .default, handler: { _ in
                self.startWebServer()
            })

            actionSheet.addAction(webServerAction)

            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

            reachability.whenReachable = { reachability in
                if reachability.connection == .wifi {
                    webServerAction.isEnabled = true
                } else {
                    webServerAction.isEnabled = false
                }
            }

            reachability.whenUnreachable = { _ in
                webServerAction.isEnabled = false
            }

            if let barButtonItem = sender as? UIBarButtonItem {
                actionSheet.popoverPresentationController?.barButtonItem = barButtonItem
                actionSheet.popoverPresentationController?.sourceView = collectionView
            } else if let button = sender as? UIButton {
                actionSheet.popoverPresentationController?.sourceView = collectionView
                actionSheet.popoverPresentationController?.sourceRect = view.convert(libraryInfoContainerView.convert(button.frame, to: view), to: collectionView)
            }

            actionSheet.preferredContentSize = CGSize(width: 300, height: 150)

            present(actionSheet, animated: true, completion: nil)

            actionSheet.rx.deallocating.asObservable().bind { [weak self] in
                self?.reachability.stopNotifier()
            }.disposed(by: disposeBag)
        #else // tvOS
            defer {
                reachability.stopNotifier()
            }
            if reachability.connection != .wifi {
                let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a network to continue!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
                }))
                present(alert, animated: true) { () -> Void in }
            } else {
                startWebServer()
            }
        #endif
    }

    func startWebServer() {
        // start web transfer service
        if PVWebServer.shared.startServers() {
            // show alert view
            showServerActiveAlert()
        } else {
            let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or settings and free up ports: 80, 81", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }

    // MARK: - Game Library Management

    // This method is probably outdated
    func migrateLibrary() {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)!
        hud.isUserInteractionEnabled = false
        hud.mode = .indeterminate
        hud.labelText = "Migrating Game Library"
        hud.detailsLabelText = "Please be patient, this may take a while..."

        let libraryPath: String = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!

        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: libraryPath).appendingPathComponent("PVGame.sqlite")) } catch {
            ILOG("Unable to delete PVGame.sqlite because \(error.localizedDescription)")
        }

        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: libraryPath).appendingPathComponent("PVGame.sqlite-shm")) } catch {
            ILOG("Unable to delete PVGame.sqlite-shm because \(error.localizedDescription)")
        }

        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: libraryPath).appendingPathComponent("PVGame.sqlite-wal")) } catch {
            ILOG("Unable to delete PVGame.sqlite-wal because \(error.localizedDescription)")
        }

        do {
            try FileManager.default.createDirectory(at: PVEmulatorConfiguration.Paths.romsImportPath, withIntermediateDirectories: true, attributes: nil) } catch {
            ELOG("Unable to create roms directory because \(error.localizedDescription)")
            // dunno what else can be done if this fails
            return
        }

        // Move everything that isn't a realm file, into the the import folder so it wil be re-imported
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: PVEmulatorConfiguration.documentsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        } catch {
            ELOG("Unable to get contents of documents because \(error.localizedDescription)")
            return
        }

        // TODO: Use the known ROM and BIOS extensions to skip those
        // Skip the battery and saves folder
        // Don't move the Imge cache files, or delete them

        let ignoredExtensions = ["jpg", "png", "gif", "jpeg"]
        let filteredContents = contents.filter { (url) -> Bool in
            let dbFile = url.path.lowercased().contains("realm")
            let ignoredExtension = ignoredExtensions.contains(url.pathExtension)
            return !dbFile && !ignoredExtension
        }

        filteredContents.forEach { path in
            var isDir: ObjCBool = false
            let exists: Bool = FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir)

            if exists, !isDir.boolValue, !path.path.lowercased().contains("realm") {
                let toPath = PVEmulatorConfiguration.Paths.romsImportPath.appendingPathComponent(path.lastPathComponent)

                do {
                    try FileManager.default.moveItem(at: path, to: toPath)
                } catch {
                    ELOG("Unable to move \(path.path) to \(toPath.path) because \(error.localizedDescription)")
                }
            }
        }

        hud.hide(true)
        UserDefaults.standard.set(false, forKey: PVRequiresMigrationKey)

        do {
            let paths = try FileManager.default.contentsOfDirectory(at: PVEmulatorConfiguration.Paths.romsImportPath, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
            gameImporter?.startImport(forPaths: paths)
        } catch {
            ELOG("Couldn't get rom paths")
        }
    }

    fileprivate func showConflictsAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Oops!", message: "There was a conflict while importing your game.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Let's go fix it!", style: .default, handler: { [unowned self] (_: UIAlertAction) -> Void in
                self.needToShowConflictsAlert = false
                self.displayConflictVC()
            }))

            alert.addAction(UIAlertAction(title: "Nah, I'll do it later...", style: .cancel, handler: { [unowned self] (_: UIAlertAction) -> Void in self.needToShowConflictsAlert = false }))
            self.present(alert, animated: true) { () -> Void in }

            ILOG("Encountered conflicts, should be showing message")
        }
    }

    fileprivate func displayConflictVC() {
        let conflictViewController = PVConflictViewController(gameImporter: gameImporter!)
        let navController = UINavigationController(rootViewController: conflictViewController)
        present(navController, animated: true) { () -> Void in }
    }

    func setUpGameLibrary() {
        setupGameImporter()
        setupDirectoryWatcher()
    }

    lazy var watcherQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "WatcherQueue"
        q.qualityOfService = .background
        q.maxConcurrentOperationCount = 1
        return q
    }()

    func setupDirectoryWatcher() {
        let labelMaker: (URL) -> String = { path in
            #if os(tvOS)
                return "Extracting Archive: \(path.lastPathComponent)"
            #else
                return "Extracting Archive..."
            #endif
        }

        watcher = DirectoryWatcher(directory: PVEmulatorConfiguration.Paths.romsImportPath, extractionStartedHandler: { (_ path: URL) -> Void in
            DispatchQueue.main.async {
                guard let hud = MBProgressHUD(for: self.view) ?? MBProgressHUD.showAdded(to: self.view, animated: true) else {
                    WLOG("No hud")
                    return
                }

                hud.show(true)
                hud.isUserInteractionEnabled = false
                hud.mode = .annularDeterminate
                hud.progress = 0
                hud.labelText = labelMaker(path)
            }
        }, extractionUpdatedHandler: { (_ path: URL, _: Int, _: Int, _ progress: Float) -> Void in

            DispatchQueue.main.async {
                guard let hud = MBProgressHUD(for: self.view) ?? MBProgressHUD.showAdded(to: self.view, animated: false) else {
                    WLOG("No hud")
                    return
                }
                hud.isUserInteractionEnabled = false
                hud.mode = .annularDeterminate
                hud.progress = progress
                hud.labelText = labelMaker(path)
            }
        }, extractionCompleteHandler: { (_ paths: [URL]?) -> Void in
            DispatchQueue.main.async {
                if let hud = MBProgressHUD(for: self.view) ?? MBProgressHUD.showAdded(to: self.view, animated: false) {
                    hud.isUserInteractionEnabled = false
                    hud.mode = .annularDeterminate
                    hud.progress = 1
                    hud.labelText = paths != nil ? "Extraction Complete!" : "Extraction Failed."
                    hud.hide(true, afterDelay: 0.5)
                } else {
                    WLOG("No hud")
                }
            }

            if let paths = paths {
                self.watcherQueue.addOperation({
                    self.filePathsToImport.append(contentsOf: paths)
                    do {
                        let contents = try FileManager.default.contentsOfDirectory(at: PVEmulatorConfiguration.Paths.romsImportPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                        let archives = contents.filter {
                            let exts = PVEmulatorConfiguration.archiveExtensions
                            let ext = $0.pathExtension.lowercased()
                            return exts.contains(ext)
                        }
                        if archives.isEmpty {
                            self.gameImporter?.startImport(forPaths: self.filePathsToImport)
                        }
                    } catch {
                        ELOG("\(error.localizedDescription)")
                    }
                })
            }
        })
    }

    func setupGameImporter() {
        gameImporter = GameImporter.shared
        gameImporter.completionHandler = { [unowned self] (_ encounteredConflicts: Bool) -> Void in
            self.updateConflictsButton()
            if encounteredConflicts {
                self.needToShowConflictsAlert = true
                self.showConflictsAlert()
            }
        }

        gameImporter.importStartedHandler = { (_ path: String) -> Void in
            DispatchQueue.main.async {
                if let hud = MBProgressHUD(for: self.view) ?? MBProgressHUD.showAdded(to: self.view, animated: true) {
                    hud.isUserInteractionEnabled = false
                    hud.mode = .indeterminate
                    let filename = URL(fileURLWithPath: path).lastPathComponent
                    hud.labelText = "Importing \(filename)"
                }
            }
        }

        gameImporter.finishedImportHandler = { (_ md5: String, _ modified: Bool) -> Void in
            // This callback is always called,
            // even if the started handler was not called because it didn't require a refresh.
            self.finishedImportingGame(withMD5: md5, modified: modified)
        }

        gameImporter.finishedArtworkHandler = { (_: String) -> Void in
        }

        // Wait for the importer to finish setting up it's data from Realm
        gameImporter.initialized.notify(queue: DispatchQueue.global(qos: .background)) {
            self.initialROMScan()
        }

        updateConflictsButton()
    }

    private func initialROMScan() {
        do {
            let existingFiles = try FileManager.default.contentsOfDirectory(at: PVEmulatorConfiguration.Paths.romsImportPath, includingPropertiesForKeys: nil, options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants])
            if !existingFiles.isEmpty {
                gameImporter.startImport(forPaths: existingFiles)
            }
        } catch {
            ELOG("No existing ROM path at \(PVEmulatorConfiguration.Paths.romsImportPath.path)")
        }

        importerScanSystemsDirs()
    }

    private func importerScanSystemsDirs() {
        // Scan each Core direxctory and looks for ROMs in them
        let allSystems = PVSystem.all.map { $0.asDomain() }

        let importOperation = BlockOperation()

        allSystems.forEach { system in
            let systemDir = system.romsDirectory
            // URL(fileURLWithPath: config.documentsPath).appendingPathComponent(systemID).path

            // Check if a folder actually exists, nothing to do if it doesn't
            guard FileManager.default.fileExists(atPath: systemDir.path) else {
                VLOG("Nothing found at \(systemDir.path)")
                return
            }

            guard let contents = try? FileManager.default.contentsOfDirectory(at: systemDir,
                                                                              includingPropertiesForKeys: nil,
                                                                              options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
                !contents.isEmpty else {
                return
            }

            let acceptedExtensions = system.extensions
            let filtered = contents.filter {
                acceptedExtensions.contains($0.pathExtension)
            }

            importOperation.addExecutionBlock {
                self.gameImporter.getRomInfoForFiles(atPaths: filtered, userChosenSystem: system)
            }
        }

        let completionOperation = BlockOperation {
            if let completionHandler = self.gameImporter.completionHandler {
                DispatchQueue.main.async {
                    self.updateConflictsButton()
                    completionHandler(self.gameImporter.encounteredConflicts)
                }
            }
        }

        completionOperation.addDependency(importOperation)
        gameImporter.serialImportQueue.addOperation(importOperation)
        gameImporter.serialImportQueue.addOperation(completionOperation)
    }

    func finishedImportingGame(withMD5 md5: String, modified _: Bool) {
        DispatchQueue.main.async {
            if let hud = MBProgressHUD(for: self.view) {
                hud.hide(true)
            }
        }

        #if os(iOS)
            // Add to spotlight database
            if #available(iOS 9.0, *) {
                // TODO: Would be better to pass the PVGame direclty using threads.
                // https://realm.io/blog/obj-c-swift-2-2-thread-safe-reference-sort-properties-relationships/
                // let realm = try! Realm()
                // if let game = realm.resolve(gameRef) { }

                // Have to do the import here so the images are ready
                if let game = RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: md5) {
                    let gameRef = ThreadSafeReference(to: game)

                    DispatchQueue.global(qos: .background).async {
                        let realm = try! Realm()
                        guard let game = realm.resolve(gameRef) else {
                            return // game was deleted
                        }

                        let spotlightUniqueIdentifier = game.spotlightUniqueIdentifier
                        let spotlightContentSet = game.spotlightContentSet

                        let spotlightItem = CSSearchableItem(uniqueIdentifier: spotlightUniqueIdentifier, domainIdentifier: "com.provenance-emu.game", attributeSet: spotlightContentSet)
                        CSSearchableIndex.default().indexSearchableItems([spotlightItem]) { error in
                            if let error = error {
                                ELOG("indexing error: \(error)")
                            }
                        }
                    }
                }
            }
        #endif

        // code below is simply to animate updates... currently crashy
        //    NSArray *oldSectionInfo = [self.sectionInfo copy];
        //    NSIndexPath *indexPath = [self indexPathForGameWithMD5Hash:md5];
        //    [self fetchGames];
        //    if (indexPath)
        //    {
        //        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        //    }
        //    else
        //    {
        //        indexPath = [self indexPathForGameWithMD5Hash:md5];
        //        PVGame *game = [[PVGame objectsInRealm:self.realm where:@"md5Hash == %@", md5] firstObject];
        //        NSString *systemID = [game systemIdentifier];
        //        __block BOOL needToInsertSection = YES;
        //        [self.sectionInfo enumerateObjectsUsingBlock:^(NSString *section, NSUInteger sectionIndex, BOOL *stop) {
        //            if ([systemID isEqualToString:section])
        //            {
        //                needToInsertSection = NO;
        //                *stop = YES;
        //            }
        //        }];
        //
        //        [self.collectionView performBatchUpdates:^{
        //            if (needToInsertSection)
        //            {
        //                [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[indexPath section]]];
        //            }
        //            [self.collectionView insertItemsAtIndexPaths:@[indexPath]];
        //        } completion:^(BOOL finished) {
        //        }];
        //    }
    }

    @objc func handleCacheEmptied(_: NotificationCenter) {
        DispatchQueue.global(qos: .default).async(execute: { () -> Void in
            let database = RomDatabase.sharedInstance
            database.refresh()

            do {
                try database.writeTransaction {
                    for game: PVGame in database.allGames {
                        game.customArtworkURL = ""

                        self.gameImporter?.getArtwork(forGame: game)
                    }
                }
            } catch {
                ELOG("Failed to empty cache \(error.localizedDescription)")
            }

            DispatchQueue.main.async(execute: { () -> Void in
                RomDatabase.sharedInstance.refresh()
            })
        })
    }

    @objc func handleArchiveInflationFailed(_: Notification) {
        let alert = UIAlertController(title: "Failed to extract archive", message: "There was a problem extracting the archive. Perhaps the download was corrupt? Try downloading it again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    @objc func handleRefreshLibrary(_: Notification) {
//        let config = PVEmulatorConfiguration.
//        let documentsPath: String = config.documentsPath
//        let romPaths = database.all(PVGame.self).map { (game) -> String in
//            let path: String = URL(fileURLWithPath: documentsPath).appendingPathComponent(game.romPath).path
//            return path
//        }

        let database = RomDatabase.sharedInstance
        do {
            try database.deleteAll()
        } catch {
            ELOG("Failed to delete all objects. \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }

        initialROMScan()
//        setUpGameLibrary()
        //    dispatch_async([self.gameImporter serialImportQueue], ^{
        //        [self.gameImporter getRomInfoForFilesAtPaths:romPaths userChosenSystem:nil];
        //        if ([self.gameImporter completionHandler])
        //        {
        //            [self.gameImporter completionHandler]([self.gameImporter encounteredConflicts]);
        //        }
        //    });
    }

    func loadGame(fromMD5 md5: String) {
        let database = RomDatabase.sharedInstance
        let recentGames = database.all(PVGame.self, where: #keyPath(PVGame.md5Hash), value: md5)

        if let mostRecentGame = recentGames.first {
            load(mostRecentGame, sender: collectionView, core: nil)
        } else {
            ELOG("No game found for MD5 \(md5)")
        }
    }

    @objc func longPressRecognized(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            let point: CGPoint = recognizer.location(in: collectionView)
            var maybeIndexPath: IndexPath? = collectionView?.indexPathForItem(at: point)

            #if os(tvOS)
                if maybeIndexPath == nil, let focusedView = UIScreen.main.focusedView as? UICollectionViewCell {
                    maybeIndexPath = collectionView?.indexPath(for: focusedView)
                }
            #endif
            guard let indexPath = maybeIndexPath else {
                ELOG("no index path, we're buggered.")
                return
            }

            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

            if searchResults == nil, indexPath.section == saveStateSection {
                let saveStatesCell = collectionView!.cellForItem(at: IndexPath(row: 0, section: saveStateSection)) as! SaveStatesCollectionCell
                let location2 = saveStatesCell.internalCollectionView.convert(point, from: collectionView)
                let indexPath2 = saveStatesCell.internalCollectionView.indexPathForItem(at: location2)!

                let saveState = saveStates![indexPath2.row]

                actionSheet.title = "Delete this save state?"

                actionSheet.addAction(UIAlertAction(title: "Yes", style: .destructive) { [unowned self] _ in
                    do {
                        try PVSaveState.delete(saveState)
                    } catch {
                        self.presentError("Error deleting save state: \(error.localizedDescription)")
                    }
                })
                actionSheet.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                var cell: UICollectionViewCell?

                if traitCollection.userInterfaceIdiom == .pad {
                    cell = collectionView?.cellForItem(at: indexPath)
                    actionSheet.popoverPresentationController?.sourceView = cell
                    actionSheet.popoverPresentationController?.sourceRect = (collectionView?.layoutAttributesForItem(at: indexPath)?.bounds ?? CGRect.zero)
                }
                present(actionSheet, animated: true)

                return
            }

            var recentGameMaybe: PVGame?
            if searchResults == nil, indexPath.section == recentGamesSection, let recentGames = recentGames {
                let recentGamesCell = collectionView!.cellForItem(at: IndexPath(row: 0, section: recentGamesSection)) as! RecentlyPlayedCollectionCell
                let location2 = recentGamesCell.internalCollectionView.convert(point, from: collectionView)
                let indexPath2 = recentGamesCell.internalCollectionView.indexPathForItem(at: location2)!

                if indexPath2.row < recentGames.count {
                    recentGameMaybe = recentGames[indexPath2.row].game
                }
            }

            if searchResults == nil, indexPath.section == favoritesSection, let favoriteGames = favoriteGames {
                let favoritesCell = collectionView!.cellForItem(at: IndexPath(row: 0, section: favoritesSection)) as! FavoritesPlayedCollectionCell
                let location2 = favoritesCell.internalCollectionView.convert(point, from: collectionView)
                let indexPath2 = favoritesCell.internalCollectionView.indexPathForItem(at: location2)!

                if indexPath2.row < favoriteGames.count {
                    recentGameMaybe = favoriteGames[indexPath2.row]
                }
            }

            guard let game: PVGame = recentGameMaybe ?? self.game(at: indexPath, location: point) else {
                ELOG("No game at inde path \(indexPath)")
                return
            }

            var cell: UICollectionViewCell?

            if traitCollection.userInterfaceIdiom == .pad {
                cell = collectionView?.cellForItem(at: indexPath)
                actionSheet.popoverPresentationController?.sourceView = cell
                actionSheet.popoverPresentationController?.sourceRect = (collectionView?.layoutAttributesForItem(at: indexPath)?.bounds ?? CGRect.zero)
            }

            // If game.system has multiple cores, add actions to manage
            if let system = game.system, system.cores.count > 1 {
                // If user has select a core for this game, actio to reset
                if let userPreferredCoreID = game.userPreferredCoreID {
                    // Find the core for the current id
                    let userSelectedCore = RomDatabase.sharedInstance.object(ofType: PVCore.self, wherePrimaryKeyEquals: userPreferredCoreID)
                    let coreName = userSelectedCore?.projectName ?? "nil"
                    // Add reset action
                    actionSheet.addAction(UIAlertAction(title: "Reset default core selection (\(coreName))", style: .default, handler: { [unowned self] _ in

                        let resetAlert = UIAlertController(title: "Reset core?", message: "Are you sure you want to reset \(game.title) to no longer default to use \(coreName)?", preferredStyle: .alert)
                        resetAlert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
                        resetAlert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
                            try! RomDatabase.sharedInstance.writeTransaction {
                                game.userPreferredCoreID = nil
                            }
                        }))
                        self.present(resetAlert, animated: true, completion: nil)
                    }))
                }

                // Action to Open with...
                actionSheet.addAction(UIAlertAction(title: "Open with...", style: .default, handler: { [unowned self] _ in
                    self.presentCoreSelection(forGame: game, sender: cell)
                }))
            }

            actionSheet.addAction(UIAlertAction(title: "Game Info", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.moreInfo(for: game)
            }))

            var favoriteTitle = "Favorite"
            if game.isFavorite {
                favoriteTitle = "Unfavorite"
            }
            actionSheet.addAction(UIAlertAction(title: favoriteTitle, style: .default, handler: { (_: UIAlertAction) -> Void in
                self.toggleFavorite(for: game)
            }))

            actionSheet.addAction(UIAlertAction(title: "Rename", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.renameGame(game)
            }))
            #if os(iOS)

                actionSheet.addAction(UIAlertAction(title: "Copy MD5 URL", style: .default, handler: { (_: UIAlertAction) -> Void in
                    let md5URL = "provenance://open?md5=\(game.md5Hash)"
                    UIPasteboard.general.string = md5URL
                    let alert = UIAlertController(title: nil, message: "URL copied to clipboard", preferredStyle: .alert)
                    self.present(alert, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                        alert.dismiss(animated: true, completion: nil)
                    })
                }))

                actionSheet.addAction(UIAlertAction(title: "Choose Cover", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.chooseCustomArtwork(for: game)
                }))

                actionSheet.addAction(UIAlertAction(title: "Paste Cover", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.pasteCustomArtwork(for: game)
                }))

                if !game.saveStates.isEmpty {
                    actionSheet.addAction(UIAlertAction(title: "View Save States", style: .default, handler: { (_: UIAlertAction) -> Void in
                        guard let saveStatesNavController = UIStoryboard(name: "SaveStates", bundle: nil).instantiateViewController(withIdentifier: "PVSaveStatesViewControllerNav") as? UINavigationController else {
                            return
                        }

                        if let saveStatesViewController = saveStatesNavController.viewControllers.first as? PVSaveStatesViewController {
                            saveStatesViewController.saveStates = game.saveStates
                            saveStatesViewController.delegate = self
                        }

                        saveStatesNavController.modalPresentationStyle = .overCurrentContext

                        #if os(iOS)
                            if self.traitCollection.userInterfaceIdiom == .pad {
                                saveStatesNavController.modalPresentationStyle = .formSheet
                            }
                        #endif
                        #if os(tvOS)
                            if #available(tvOS 11, *) {
                                saveStatesNavController.modalPresentationStyle = .blurOverFullScreen
                            }
                        #endif
                        self.present(saveStatesNavController, animated: true)
                    }))
                }

                // conditionally show Restore Original Artwork
                if !game.originalArtworkURL.isEmpty, !game.customArtworkURL.isEmpty, game.originalArtworkURL != game.customArtworkURL {
                    actionSheet.addAction(UIAlertAction(title: "Restore Cover", style: .default, handler: { (_: UIAlertAction) -> Void in
                        try! PVMediaCache.deleteImage(forKey: game.customArtworkURL)

                        try! RomDatabase.sharedInstance.writeTransaction {
                            game.customArtworkURL = ""
                        }

                        let gameRef = ThreadSafeReference(to: game)

                        DispatchQueue.global(qos: .default).async {
                            let realm = try! Realm()
                            guard let game = realm.resolve(gameRef) else {
                                return // person was deleted
                            }

                            self.gameImporter?.getArtwork(forGame: game)
                        }
                    }))
                }
            #endif
            #if os(tvOS)
                actionSheet.message = "Options for \(game.title)"
            #endif
            #if os(iOS)
                actionSheet.addAction(UIAlertAction(title: "Share", style: .default, handler: { (_: UIAlertAction) -> Void in
                    self.share(for: game, sender: self.collectionView?.cellForItem(at: indexPath))
                }))
            #endif

            actionSheet.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_: UIAlertAction) -> Void in
                let alert = UIAlertController(title: "Delete \(game.title)", message: "Any save states and battery saves will also be deleted, are you sure?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_: UIAlertAction) -> Void in
                    // Delete from Realm
                    do {
                        try self.delete(game: game)
                    } catch {
                        self.presentError(error.localizedDescription)
                    }
                }))
                alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                self.present(alert, animated: true) { () -> Void in }
            }))

            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(actionSheet, animated: true) { () -> Void in }
        }
    }

    func toggleFavorite(for game: PVGame) {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.isFavorite = !game.isFavorite
            }

            register3DTouchShortcuts()

            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        } catch {
            ELOG("Failed to toggle Favourite for game \(game.title)")
        }
    }

    func moreInfo(for game: PVGame) {
        #if os(iOS)
            performSegue(withIdentifier: "gameMoreInfoPageVCSegue", sender: game)
        #else
            performSegue(withIdentifier: "gameMoreInfoSegue", sender: game)
        #endif
    }

    func renameGame(_ game: PVGame) {
        let alert = UIAlertController(title: "Rename", message: "Enter a new name for \(game.title)", preferredStyle: .alert)
        alert.addTextField(configurationHandler: { (_ textField: UITextField) -> Void in
            textField.placeholder = game.title
            textField.text = game.title
        })

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            if let title = alert.textFields?.first?.text {
                guard !title.isEmpty else {
                    self.presentError("Cannot set a blank title.")
                    return
                }

                RomDatabase.sharedInstance.renameGame(game, toTitle: title)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    func delete(game: PVGame) throws {
        try RomDatabase.sharedInstance.delete(game: game)
    }

    #if os(iOS)
        func chooseCustomArtwork(for game: PVGame) {
            weak var weakSelf: PVGameLibraryViewController? = self
            let imagePickerActionSheet = UIActionSheet()
            let cameraIsAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)
            let photoLibraryIsAvaialble: Bool = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
            let cameraAction: PVUIActionSheetAction = { () -> Void in
                self.gameForCustomArt = game
                let pickerController = UIImagePickerController()
                pickerController.delegate = weakSelf
                pickerController.allowsEditing = false
                pickerController.sourceType = .camera
                self.present(pickerController, animated: true) { () -> Void in }
            }
            let libraryAction: PVUIActionSheetAction = { () -> Void in
                self.gameForCustomArt = game
                let pickerController = UIImagePickerController()
                pickerController.delegate = weakSelf
                pickerController.allowsEditing = false
                pickerController.sourceType = .photoLibrary
                self.present(pickerController, animated: true) { () -> Void in }
            }
            assetsLibrary = ALAssetsLibrary()
            assetsLibrary?.enumerateGroups(withTypes: ALAssetsGroupType(ALAssetsGroupSavedPhotos), using: { group, _ in
                guard let group = group else {
                    return
                }

                group.setAssetsFilter(ALAssetsFilter.allPhotos())
                let index: Int = group.numberOfAssets() - 1
                VLOG("Group: \(group)")
                if index >= 0 {
//                var indexPathsToUpdate = [IndexPath]()

                    group.enumerateAssets(at: IndexSet(integer: index), options: [], using: { result, _, _ in
                        if let rep: ALAssetRepresentation = result?.defaultRepresentation() {
                            imagePickerActionSheet.pv_addButton(withTitle: "Use Last Photo Taken", action: { () -> Void in
                                let orientation: UIImage.Orientation = UIImage.Orientation(rawValue: rep.orientation().rawValue)!

                                let lastPhoto = UIImage(cgImage: rep.fullScreenImage().takeUnretainedValue(), scale: CGFloat(rep.scale()), orientation: orientation)

                                do {
                                    try PVMediaCache.writeImage(toDisk: lastPhoto, withKey: rep.url().path)
                                    try RomDatabase.sharedInstance.writeTransaction {
                                        game.customArtworkURL = rep.url().path
                                    }
                                } catch {
                                    ELOG("Failed to set custom artwork URL for game \(game.title) \n \(error.localizedDescription)")
                                }
                            })
                            if cameraIsAvailable || photoLibraryIsAvaialble {
                                if cameraIsAvailable {
                                    imagePickerActionSheet.pv_addButton(withTitle: "Take Photo...", action: cameraAction)
                                }
                                if photoLibraryIsAvaialble {
                                    imagePickerActionSheet.pv_addButton(withTitle: "Choose from Library...", action: libraryAction)
                                }
                            }
                            imagePickerActionSheet.pv_addCancelButton(withTitle: "Cancel", action: nil)
                            imagePickerActionSheet.show(in: self.view)
                        }
                    })

//                DispatchQueue.main.async {
//                    self.collectionView?.reloadItems(at: indexPathsToUpdate)
//                }
                } else {
                    let alert = UIAlertController(title: "No Photos", message: "There are no photos in your library to choose from", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true) { () -> Void in }
                }
            }, failureBlock: { _ in
                if cameraIsAvailable || photoLibraryIsAvaialble {
                    if cameraIsAvailable {
                        imagePickerActionSheet.pv_addButton(withTitle: "Take Photo...", action: cameraAction)
                    }
                    if photoLibraryIsAvaialble {
                        imagePickerActionSheet.pv_addButton(withTitle: "Choose from Library...", action: libraryAction)
                    }
                }
                imagePickerActionSheet.pv_addCancelButton(withTitle: "Cancel", action: nil)
                imagePickerActionSheet.show(in: self.view)
                self.assetsLibrary = nil
            })
        }

        func pasteCustomArtwork(for game: PVGame) {
            let pb = UIPasteboard.general
            var pastedImageMaybe: UIImage? = pb.image

            let pastedURL: URL? = pb.url

            if pastedImageMaybe == nil {
                if let pastedURL = pastedURL {
                    do {
                        let data = try Data(contentsOf: pastedURL)
                        pastedImageMaybe = UIImage(data: data)
                    } catch {
                        ELOG("Failed to read pasteboard URL: \(error.localizedDescription)")
                    }
                } else {
                    ELOG("No image or image url in pasteboard")
                    return
                }
            }

            if let pastedImage = pastedImageMaybe {
                var key: String
                if let pastedURL = pastedURL {
                    key = pastedURL.lastPathComponent
                } else {
                    key = UUID().uuidString
                }

                do {
                    try PVMediaCache.writeImage(toDisk: pastedImage, withKey: key)
                    try RomDatabase.sharedInstance.writeTransaction {
                        game.customArtworkURL = key
                    }
                } catch {
                    ELOG("Failed to set custom artwork URL for game \(game.title).\n\(error.localizedDescription)")
                }
            } else {
                ELOG("No pasted image")
            }
        }

    #endif

    // MARK: - Searching

    func searchLibrary(_ searchText: String) {
        let predicate = NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText])
        let titleSearchResults = RomDatabase.sharedInstance.all(PVGame.self, filter: predicate).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)

        if !titleSearchResults.isEmpty {
            searchResults = titleSearchResults
        } else {
            let predicate = NSPredicate(format: "genres LIKE[c] %@ OR gameDescription CONTAINS[c] %@ OR regionName LIKE[c] %@ OR developer LIKE[c] %@ or publisher LIKE[c] %@", argumentArray: [searchText, searchText, searchText, searchText, searchText])
            searchResults = RomDatabase.sharedInstance.all(PVGame.self, filter: predicate).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        }

        searchResultsToken?.invalidate()
        searchResultsToken = searchResults!.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                self.collectionView?.reloadData()
            case .update:
                self.collectionView?.reloadData()
            case let .error(error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }
    }

    func clearSearch() {
        searchField?.text = nil
        searchResults = nil
        searchResultsToken?.invalidate()
        searchResultsToken = nil
        collectionView?.reloadData()
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, referenceSizeForHeaderInSection _: Int) -> CGSize {
        #if os(tvOS)
            return CGSize(width: view.bounds.size.width, height: 90)
        #else
            return CGSize(width: view.bounds.size.width, height: 40)
        #endif
    }

    // MARK: - Text Field and Keyboard Delegate

    @objc func handleTextFieldDidChange(_: Notification) {
        if let text = searchField?.text, !text.isEmpty {
            searchLibrary(text)
        } else {
            clearSearch()
        }
    }

    // MARK: - Image Picker Delegate

    #if os(iOS)
        func imagePickerController(_: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Local variable inserted by Swift 4.2 migrator.
            let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

            guard let gameForCustomArt = self.gameForCustomArt else {
                ELOG("gameForCustomArt pointer was null.")
                return
            }

            dismiss(animated: true) { () -> Void in }
            let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage
            if let image = image, let scaledImage = image.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)), let imageData = scaledImage.jpegData(compressionQuality: 0.5) {
                let hash = (imageData as NSData).md5Hash

                do {
                    try PVMediaCache.writeData(toDisk: imageData, withKey: hash)
                    try RomDatabase.sharedInstance.writeTransaction {
                        gameForCustomArt.customArtworkURL = hash
                    }
                } catch {
                    ELOG("Failed to set custom artwork for game \(gameForCustomArt.title)\n\(error.localizedDescription)")
                }
            }
            self.gameForCustomArt = nil
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            dismiss(animated: true) { () -> Void in }
            gameForCustomArt = nil
        }

    #endif
}

// MARK: Database Migration

extension PVGameLibraryViewController {
    @objc public func databaseMigrationStarted(_: Notification) {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)!
        hud.isUserInteractionEnabled = false
        hud.mode = .indeterminate
        hud.labelText = "Migrating Game Library"
        hud.detailsLabelText = "Please be patient, this may take a while..."
    }

    @objc public func databaseMigrationFinished(_: Notification) {
        MBProgressHUD.hide(for: view!, animated: true)
    }
}

extension PVGameLibraryViewController: RealmCollectinViewCellDelegate {
    func didSelectObject(_ object: Object, indexPath _: IndexPath) {
        if let game = object as? PVGame {
            let cell = collectionView?.cellForItem(at: IndexPath(row: 0, section: favoritesSection))
            load(game, sender: cell, core: nil, saveState: nil)
        } else if let recentGame = object as? PVRecentGame {
            let cell = collectionView?.cellForItem(at: IndexPath(row: 0, section: recentGamesSection))
            load(recentGame.game, sender: cell, core: recentGame.core, saveState: nil)
        } else if let saveState = object as? PVSaveState {
            let cell = collectionView?.cellForItem(at: IndexPath(row: 0, section: saveStateSection))
            load(saveState.game, sender: cell, core: saveState.core, saveState: saveState)
        }
    }
}

// MARK: - Spotlight

#if os(iOS)
    @available(iOS 9.0, *)
    extension PVGameLibraryViewController {
        private func deleteFromSpotlight(game: PVGame) {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [game.spotlightUniqueIdentifier], completionHandler: { error in
                if let error = error {
                    print("Error deleting game spotlight item: \(error)")
                } else {
                    print("Game indexing deleted.")
                }
            })
        }

        private func deleteAllGamesFromSpotlight() {
            CSSearchableIndex.default().deleteAllSearchableItems { error in
                if let error = error {
                    print("Error deleting all games spotlight index: \(error)")
                } else {
                    print("Game indexing deleted.")
                }
            }
        }
    }
#endif

// MARK: UIDocumentMenuDelegate

#if os(iOS)
    extension PVGameLibraryViewController: UIDocumentMenuDelegate {
        func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
            documentPicker.delegate = self
            documentPicker.popoverPresentationController?.sourceView = view
            present(documentMenu, animated: true, completion: nil)
        }

        func documentMenuWasCancelled(_: UIDocumentMenuViewController) {
            ILOG("DocumentMenu was cancelled")
        }
    }

    // MARK: UIDocumentPickerDelegate

    extension PVGameLibraryViewController: UIDocumentPickerDelegate {
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // If directory, map out sub directories if folder
            let urls: [URL] = urls.compactMap { (url) -> [URL]? in
                if #available(iOS 9.0, *) {
                    if url.hasDirectoryPath {
                        ILOG("Trying to import directory \(url.path). Scanning subcontents")
                        do {
                            _ = url.startAccessingSecurityScopedResource()
                            let subFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey, URLResourceKey.parentDirectoryURLKey, URLResourceKey.fileSecurityKey], options: .skipsHiddenFiles)
                            url.stopAccessingSecurityScopedResource()
                            return subFiles
                        } catch {
                            ELOG("Subdir scan failed. \(error)")
                            return [url]
                        }
                    } else {
                        return [url]
                    }
                } else {
                    // Fallback on earlier versions
                    return [url]
                }
            }.joined().map { $0 }

            let sortedUrls = PVEmulatorConfiguration.sortImportURLs(urls: urls)

            let importPath = PVEmulatorConfiguration.Paths.romsImportPath

            sortedUrls.forEach { url in
                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                // Doesn't seem we need access in dev builds?
                _ = url.startAccessingSecurityScopedResource()

                //            if access {
                let fileName = url.lastPathComponent
                let destination: URL
                if #available(iOS 9.0, *) {
                    destination = importPath.appendingPathComponent(fileName, isDirectory: url.hasDirectoryPath)
                } else {
                    destination = importPath.appendingPathComponent(fileName, isDirectory: false)
                }
                do {
                    // Since we're in UIDocumentPickerModeImport, these URLs are temporary URLs so a move is what we want
                    try FileManager.default.moveItem(at: url, to: destination)
                    ILOG("Document picker to moved file from \(url.path) to \(destination.path)")
                } catch {
                    ELOG("Failed to move file from \(url.path) to \(destination.path)")
                }
            }

            // Test for moving directory subcontents
            //					if #available(iOS 9.0, *) {
            //						if url.hasDirectoryPath {
            //							ILOG("Tryingn to import directory \(url.path)")
            //							let subFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            //							for subFile in subFiles {
            //								_ = subFile.startAccessingSecurityScopedResource()
            //								try FileManager.default.moveItem(at: subFile, to: destination)
            //								subFile.stopAccessingSecurityScopedResource()
            //								ILOG("Moved \(subFile.path) to \(destination.path)")
            //							}
            //						} else {
            //							try FileManager.default.moveItem(at: url, to: destination)
            //						}
            //					} else {
            //						try FileManager.default.moveItem(at: url, to: destination)
            //					}
//                } catch {
//                    ELOG("Failed to move file from \(url.path) to \(destination.path)")
//                }
//            } else {
//                ELOG("Wasn't granded access to \(url.path)")
//            }
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            ILOG("Document picker was cancelled")
        }
    }
#endif

#if os(iOS)
    extension PVGameLibraryViewController: UIImagePickerControllerDelegate, SFSafariViewControllerDelegate {}
#endif

extension PVGameLibraryViewController: UISearchControllerDelegate {
    func didDismissSearchController(_: UISearchController) {
        clearSearch()
    }
}

// MARK: - UISearchResultsUpdating

extension PVGameLibraryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text, !text.isEmpty {
            searchLibrary(searchController.searchBar.text ?? "")
        } else {
            clearSearch()
        }
    }
}

extension PVGameLibraryViewController: UITableViewDataSource {
    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Sort By"
        case 1:
            return "View Options"
        default:
            return nil
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        return 2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? SortOptions.count : 4
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "sortCell", for: indexPath)

            let sortOption = SortOptions.allCases[indexPath.row]

            cell.textLabel?.text = sortOption.description
            cell.accessoryType = indexPath.row == currentSort.row ? .checkmark : .none
            return cell
        } else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "viewOptionsCell", for: indexPath)

            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Show Game Titles"
                cell.accessoryType = PVSettingsModel.shared.showGameTitles ? .checkmark : .none
            case 1:
                cell.textLabel?.text = "Show Recently Played Games"
                cell.accessoryType = PVSettingsModel.shared.showRecentGames ? .checkmark : .none
            case 2:
                cell.textLabel?.text = "Show Recent Save States"
                cell.accessoryType = PVSettingsModel.shared.showRecentSaveStates ? .checkmark : .none
            case 3:
                cell.textLabel?.text = "Show Game Badges"
                cell.accessoryType = PVSettingsModel.shared.showGameBadges ? .checkmark : .none
            default:
                fatalError("Invalid row")
            }

            return cell
        }
        fatalError("Invalid section")
    }
}

extension PVGameLibraryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            currentSort = SortOptions.optionForRow(UInt(indexPath.row))
            dismiss(animated: true, completion: nil)
        } else if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                PVSettingsModel.shared.showGameTitles = !PVSettingsModel.shared.showGameTitles
            case 1:
                PVSettingsModel.shared.showRecentGames = !PVSettingsModel.shared.showRecentGames
            case 2:
                PVSettingsModel.shared.showRecentSaveStates = !PVSettingsModel.shared.showRecentSaveStates
            case 3:
                PVSettingsModel.shared.showGameBadges = !PVSettingsModel.shared.showGameBadges
            default:
                fatalError("Invalid row")
            }

            tableView.reloadRows(at: [indexPath], with: .automatic)
            collectionView?.reloadData()
        }
    }
}

extension PVGameLibraryViewController: PVSaveStatesViewControllerDelegate {
    func saveStatesViewControllerDone(_: PVSaveStatesViewController) {
        dismiss(animated: true, completion: nil)
    }

    func saveStatesViewControllerCreateNewState(_: PVSaveStatesViewController, completion _: @escaping SaveCompletion) {
        // TODO: Should be a different protocol for loading / saving states then really.
        assertionFailure("Shouldn't be here. Can't create save states in game library")
    }

    func saveStatesViewControllerOverwriteState(_: PVSaveStatesViewController, state _: PVSaveState, completion _: @escaping SaveCompletion) {
        assertionFailure("Shouldn't be here. Can't create save states in game library")
    }

    func saveStatesViewController(_: PVSaveStatesViewController, load state: PVSaveState) {
        dismiss(animated: true, completion: nil)
        load(state.game, sender: self, core: state.core, saveState: state)
    }
}

// Keyboard shortcuts
extension PVGameLibraryViewController {
    // MARK: - Keyboard actions

    public override var keyCommands: [UIKeyCommand]? {
        var sectionCommands = [UIKeyCommand]() /* TODO: .reserveCapacity(sectionInfo.count + 2) */

        for (i, title) in sectionTitles.enumerated() {
            let input = "\(i)"
            // Simulator Command + number has shorcuts already
            #if TARGET_OS_SIMULATOR
                let flags: UIKeyModifierFlags = [.control, .command]
            #else
                let flags: UIKeyModifierFlags = .command
            #endif
            let command = UIKeyCommand(input: input, modifierFlags: flags, action: #selector(PVGameLibraryViewController.selectSection(_:)), discoverabilityTitle: title)
            sectionCommands.append(command)
        }

        #if os(tvOS)
            if focusedGame != nil {
                let toggleFavoriteCommand = UIKeyCommand(input: "=", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.toggleFavoriteCommand), discoverabilityTitle: "Toggle Favorite")
                sectionCommands.append(toggleFavoriteCommand)

                let showMoreInfo = UIKeyCommand(input: "i", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.showMoreInfoCommand), discoverabilityTitle: "More info ...")
                sectionCommands.append(showMoreInfo)

                let renameCommand = UIKeyCommand(input: "r", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.renameCommand), discoverabilityTitle: "Rename ...")
                sectionCommands.append(renameCommand)

                let deleteCommand = UIKeyCommand(input: "x", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.deleteCommand), discoverabilityTitle: "Delete ...")
                sectionCommands.append(deleteCommand)

                let sortCommand = UIKeyCommand(input: "s", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.sortButtonTapped(_:)), discoverabilityTitle: "Sorting")
                sectionCommands.append(sortCommand)
            }
        #elseif os(iOS)
            let findCommand = UIKeyCommand(input: "f", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.selectSearch(_:)), discoverabilityTitle: "Find …")
            sectionCommands.append(findCommand)

            let sortCommand = UIKeyCommand(input: "s", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.sortButtonTapped(_:)), discoverabilityTitle: "Sorting")
            sectionCommands.append(sortCommand)

            let settingsCommand = UIKeyCommand(input: ",", modifierFlags: [.command], action: #selector(PVGameLibraryViewController.settingsCommand), discoverabilityTitle: "Settings")
            sectionCommands.append(settingsCommand)

        #endif

        return sectionCommands
    }

    @objc func selectSearch(_: UIKeyCommand) {
        searchField?.becomeFirstResponder()
    }

    @objc func selectSection(_ sender: UIKeyCommand) {
        if let input = sender.input, let section = Int(input) {
            collectionView?.scrollToItem(at: IndexPath(item: 0, section: section), at: .top, animated: true)
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    #if os(tvOS)
        @objc
        func showMoreInfoCommand() {
            guard let focusedGame = focusedGame else {
                return
            }
            moreInfo(for: focusedGame)
        }

        @objc
        func toggleFavoriteCommand() {
            guard let focusedGame = focusedGame else {
                return
            }
            toggleFavorite(for: focusedGame)
        }

        @objc
        func renameCommand() {
            guard let focusedGame = focusedGame else {
                return
            }
            renameGame(focusedGame)
        }

        @objc
        func deleteCommand() {
            guard let focusedGame = focusedGame else {
                return
            }
            promptToDeleteGame(focusedGame)
        }

        func collectionView(_: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with _: UIFocusAnimationCoordinator) {
            focusedGame = nil

            if let focusedIndexPath = context.nextFocusedIndexPath {
                let section = focusedIndexPath.section
                let row = focusedIndexPath.row

                if section == favoritesSection {
                    guard let favoriteGames = favoriteGames else {
                        return
                    }
                    if row < favoriteGames.count {
                        focusedGame = favoriteGames[row]
                    }
                } else if section == recentGamesSection {
                    return
                } else if section == saveStateSection {
                    return
                } else {
                    let sI = section - systemsSectionOffset
                    if sI < 0 {
                        return
                    }

                    if let systems = filteredSystems, sI < systems.count, let query = systemSectionsTokens[systems[sI].identifier]?.query, row < query.count {
                        focusedGame = query[row]
                    }
                }
            }
        }
    #endif

    #if os(iOS)
        @objc
        func settingsCommand() {
            performSegue(withIdentifier: "SettingsSegue", sender: self)
        }
    #endif
}

#if os(iOS)
    extension PVGameLibraryViewController: UIPopoverControllerDelegate {}
#endif

extension PVGameLibraryViewController: GameLibraryCollectionViewDelegate {
    func promptToDeleteGame(_ game: PVGame, completion: ((Bool) -> Void)? = nil) {
        let alert = UIAlertController(title: "Delete \(game.title)", message: "Any save states and battery saves will also be deleted, are you sure?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_: UIAlertAction) -> Void in
            // Delete from Realm
            do {
                try self.delete(game: game)
                completion?(true)
            } catch {
                completion?(false)
                self.presentError(error.localizedDescription)
            }
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (_: UIAlertAction) -> Void in
            completion?(false)
        }))
        present(alert, animated: true) { () -> Void in }
    }
}

// Helper function inserted by Swift 4.2 migrator.
#if os(iOS)
    fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
        return Dictionary(uniqueKeysWithValues: input.map { key, value in (key.rawValue, value) })
    }

    // Helper function inserted by Swift 4.2 migrator.
    fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
        return input.rawValue
    }
#endif
