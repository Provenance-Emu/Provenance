//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVGameLibraryViewController.swift
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#if os(iOS)
    import Photos
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
import RxDataSources
import RxSwift
import UIKit

let PVGameLibraryHeaderViewIdentifier = "PVGameLibraryHeaderView"
let PVGameLibraryFooterViewIdentifier = "PVGameLibraryFooterView"

let PVGameLibraryCollectionViewCellIdentifier = "PVGameLibraryCollectionViewCell"
let PVGameLibraryCollectionViewSaveStatesCellIdentifier = "SaveStateCollectionCell"
let PVGameLibraryCollectionViewGamesCellIdentifier = "RecentlyPlayedCollectionCell"

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
    var updatesController: PVGameLibraryUpdatesController!
    var gameLibrary: PVGameLibrary!
    var gameImporter: GameImporter!
    var filePathsToImport = [URL]()

    var collectionView: UICollectionView?

    #if os(iOS)
        var photoLibrary: PHPhotoLibrary?
    #endif
    var gameForCustomArt: PVGame?

    @IBOutlet var getMoreRomsBarButtonItem: UIBarButtonItem!
    @IBOutlet var sortOptionBarButtonItem: UIBarButtonItem!
    @IBOutlet var conflictsBarButtonItem: UIBarButtonItem!

    #if os(iOS)
        @IBOutlet var libraryInfoContainerView: UIStackView!
        @IBOutlet var libraryInfoLabel: UILabel!
    #endif

    @IBOutlet var searchField: UITextField?
    var isInitialAppearance = false

    func updateConflictsButton(_ hasConflicts: Bool) {
        #if os(tvOS)
            var items = [sortOptionBarButtonItem!, getMoreRomsBarButtonItem!]
            if hasConflicts, let conflictsBarButtonItem = conflictsBarButtonItem {
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

    let currentSort = BehaviorSubject(value: PVSettingsModel.shared.sort)
    let collapsedSystems = BehaviorSubject(value: PVSettingsModel.shared.collapsedSystems)
    let showSaveStates = BehaviorSubject(value: PVSettingsModel.shared.showRecentSaveStates)
    let showRecentGames = BehaviorSubject(value: PVSettingsModel.shared.showRecentGames)

    // MARK: - Lifecycle

    #if os(iOS)
        override var preferredStatusBarStyle: UIStatusBarStyle {
            return .lightContent
        }
    #endif

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func handleAppDidBecomeActive(_: Notification) {
        loadGameFromShortcut()
    }

    struct Section: SectionModelType {
        let header: String
        let items: [Item]
        let collapsable: Collapsable?

        enum Item {
            case game(PVGame)
            case favorites([PVGame])
            case saves([PVSaveState])
            case recents([PVRecentGame])
        }

        enum Collapsable {
            case collapsed(systemToken: String)
            case notCollapsed(systemToken: String)
        }

        init(header: String, items: [Item], collapsable: Collapsable?) {
            self.header = header
            self.items = items
            self.collapsable = collapsable
        }

        init(original: PVGameLibraryViewController.Section, items: [Item]) {
            self.init(header: original.header, items: items, collapsable: original.collapsable)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isInitialAppearance = true
        definesPresentationContext = true

        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.databaseMigrationStarted(_:)), name: NSNotification.Name.DatabaseMigrationStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.databaseMigrationFinished(_:)), name: NSNotification.Name.DatabaseMigrationFinished, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleCacheEmptied(_:)), name: NSNotification.Name.PVMediaCacheWasEmptied, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleArchiveInflationFailed(_:)), name: NSNotification.Name.PVArchiveInflationFailed, object: nil)
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

        // Handle migrating library
        handleLibraryMigration()

        let searchText: Observable<String?>
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
                searchController.obscuresBackgroundDuringPresentation = false
                searchController.hidesNavigationBarDuringPresentation = true
                navigationItem.hidesSearchBarWhenScrolling = true
                navigationItem.searchController = searchController

                searchText = Observable.merge(searchController.rx.searchText, searchController.rx.didDismiss.map { _ in nil })
            } else {
                searchText = searchField!.rx.text.asObservable()
            }

            // TODO: For below iOS 11, can make searchController.searchbar. the navigationItem.titleView and get a similiar effect
        #else
            searchText = .never()
        #endif

        // load the config file
        title = nil

        // Persist some settings, could probably be done in a better way
        collapsedSystems.bind(onNext: { PVSettingsModel.shared.collapsedSystems = $0 }).disposed(by: disposeBag)
        currentSort.bind(onNext: { PVSettingsModel.shared.sort = $0 }).disposed(by: disposeBag)
        showSaveStates.bind(onNext: { PVSettingsModel.shared.showRecentSaveStates = $0 }).disposed(by: disposeBag)
        showRecentGames.bind(onNext: { PVSettingsModel.shared.showRecentGames = $0 }).disposed(by: disposeBag)

        let layout = PVGameLibraryCollectionFlowLayout()
        layout.scrollDirection = .vertical

        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        self.collectionView = collectionView
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        typealias Playable = (PVGame, UICollectionViewCell?, PVCore?, PVSaveState?)
        let selectedPlayable = PublishSubject<Playable>()

        let dataSource = RxCollectionViewSectionedReloadDataSource<Section>(configureCell: { _, collectionView, indexPath, item in
            switch item {
            case .game(let game):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier, for: indexPath) as! PVGameLibraryCollectionViewCell
                cell.game = game
                return cell
            case .favorites(let games):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionViewInCollectionViewCell<PVGame>.identifier, for: indexPath) as! CollectionViewInCollectionViewCell<PVGame>
                cell.items.onNext(games)
                cell.internalCollectionView.rx.itemSelected
                    .map { indexPath in (try cell.internalCollectionView.rx.model(at: indexPath), cell.internalCollectionView.cellForItem(at: indexPath)) }
                    .map { ($0, $1, nil, nil) }
                    .bind(to: selectedPlayable)
                    .disposed(by: cell.disposeBag)
                return cell
            case .saves(let saves):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionViewInCollectionViewCell<PVSaveState>.identifier, for: indexPath) as! CollectionViewInCollectionViewCell<PVSaveState>
                cell.items.onNext(saves)
                cell.internalCollectionView.rx.itemSelected
                    .map { indexPath in (try cell.internalCollectionView.rx.model(at: indexPath), cell.internalCollectionView.cellForItem(at: indexPath)) }
                    .map { ($0.game, $1, $0.core, $0) }
                    .bind(to: selectedPlayable)
                    .disposed(by: cell.disposeBag)
                return cell
            case .recents(let games):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionViewInCollectionViewCell<PVRecentGame>.identifier, for: indexPath) as! CollectionViewInCollectionViewCell<PVRecentGame>
                cell.items.onNext(games)
                cell.internalCollectionView.rx.itemSelected
                    .map { indexPath -> (PVRecentGame, UICollectionViewCell?) in (try cell.internalCollectionView.rx.model(at: indexPath), cell.internalCollectionView.cellForItem(at: indexPath)) }
                    .map { ($0.game, $1, $0.core, nil) }
                    .bind(to: selectedPlayable)
                    .disposed(by: cell.disposeBag)
                return cell
            }
        })

        collectionView.rx.itemSelected
            .map { indexPath in (try! collectionView.rx.model(at: indexPath) as Section.Item, collectionView.cellForItem(at: indexPath)) }
            .compactMap({ item, cell -> Playable? in
                switch item {
                case .game(let game):
                    return (game, cell, nil, nil)
                case .saves, .favorites, .recents:
                    // Handled in another place
                    return nil
                }
            })
            .bind(to: selectedPlayable)
            .disposed(by: disposeBag)

        selectedPlayable.bind(onNext: self.load).disposed(by: disposeBag)

        dataSource.configureSupplementaryView = { dataSource, collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier, for: indexPath) as! PVGameLibrarySectionHeaderView
                let section = dataSource.sectionModels[indexPath.section]
                let collapsed: Bool = {
                    if case .collapsed = section.collapsable {
                        return true
                    }
                    return false
                }()
                header.viewModel = .init(title: section.header, collapsable: section.collapsable != nil, collapsed: collapsed)
                #if os(iOS)
                header.collapseButton.rx.tap
                    .withLatestFrom(self.collapsedSystems)
                    .map({ (collapsedSystems: Set<String>) in
                        switch section.collapsable {
                        case .collapsed(let token):
                            return collapsedSystems.subtracting([token])
                        case .notCollapsed(let token):
                            return collapsedSystems.union([token])
                        case nil:
                            return collapsedSystems
                        }
                    })
                    .bind(to: self.collapsedSystems)
                    .disposed(by: header.disposeBag)
                #endif
                return header
            case UICollectionView.elementKindSectionFooter:
                return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PVGameLibraryFooterViewIdentifier, for: indexPath)
            default:
                fatalError("Don't support type \(kind)")
            }
        }

        let favoritesSection = gameLibrary.favorites
            .map { favorites in favorites.isEmpty ? nil : Section(header: "Favorites", items: [.favorites(favorites)], collapsable: nil)}

        let saveStateSection = Observable.combineLatest(showSaveStates, gameLibrary.saveStates) { $0 ? $1 : [] }
            .map { saveStates in saveStates.isEmpty ? nil : Section(header: "Recently Saved", items: [.saves(saveStates)], collapsable: nil) }

        let recentsSection = Observable.combineLatest(showRecentGames, gameLibrary.recents) { $0 ? $1 : [] }
            .map { recentGames in recentGames.isEmpty ? nil : Section(header: "Recently Played", items: [.recents(recentGames)], collapsable: nil) }

        let topSections = Observable.combineLatest(favoritesSection, saveStateSection, recentsSection) { [$0, $1, $2] }

        // MARK: DataSource sections

        let searchSection = searchText
            .flatMap({ text -> Observable<[PVGame]?> in
                guard let text = text else { return .just(nil) }
                return self.gameLibrary.search(for: text).map(Optional.init)
            })
            .map({ games -> Section? in
                guard let games = games else { return nil }
                return Section(header: "Search Results", items: games.map { .game($0) }, collapsable: nil)
            })
            .startWith(nil)

        let systemSections = currentSort
            .flatMapLatest { Observable.combineLatest(self.gameLibrary.systems(sortedBy: $0), self.collapsedSystems) }
            .map({ systems, collapsedSystems in
                systems.map { system in (system: system, isCollapsed: collapsedSystems.contains(system.identifier) )}
            })
            .mapMany({ system, isCollapsed -> Section? in
                guard !system.sortedGames.isEmpty else { return nil }
                let header = "\(system.manufacturer) : \(system.shortName)" + (system.isBeta ? " Beta" : "")
                let items = isCollapsed ? [] : system.sortedGames.map { Section.Item.game($0) }

                return Section(header: header, items: items,
                               collapsable: isCollapsed ? .collapsed(systemToken: system.identifier) : .notCollapsed(systemToken: system.identifier))
            })
        let nonSearchSections = Observable.combineLatest(topSections, systemSections) { $0 + $1 }
            // Remove empty sections
            .map { sections in sections.compactMap { $0 }}

        let sections: Observable<[Section]> = Observable
            .combineLatest(searchSection, nonSearchSections) { searchSection, nonSearchSections in
                if let searchSection = searchSection {
                    return [searchSection]
                } else {
                    return nonSearchSections
                }
        }
        sections.bind(to: collectionView.rx.items(dataSource: dataSource)).disposed(by: disposeBag)
        #if os(iOS)
        sections.map { !$0.isEmpty }.bind(to: libraryInfoContainerView.rx.isHidden).disposed(by: disposeBag)
        #endif

        collectionView.rx.longPressed(Section.Item.self)
            .bind(onNext: self.longPressed)
            .disposed(by: disposeBag)

        collectionView.rx.setDelegate(self).disposed(by: disposeBag)
        collectionView.bounces = true
        collectionView.alwaysBounceVertical = true
        collectionView.delaysContentTouches = false
        collectionView.keyboardDismissMode = .interactive
        collectionView.register(PVGameLibrarySectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier)
        collectionView.register(PVGameLibrarySectionFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: PVGameLibraryFooterViewIdentifier)

        #if os(tvOS)
            collectionView.contentInset = UIEdgeInsets(top: 0, left: 80, bottom: 40, right: 80)
            collectionView.remembersLastFocusedIndexPath = false
            collectionView.clipsToBounds = false
            collectionView.backgroundColor = .black 
        #else
            collectionView.backgroundColor = Theme.currentTheme.gameLibraryBackground
            searchField?.keyboardAppearance = Theme.currentTheme.keyboardAppearance

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(PVGameLibraryViewController.didReceivePinchGesture(gesture:)))
            pinchGesture.cancelsTouchesInView = true
            collectionView.addGestureRecognizer(pinchGesture)
        #endif

        view.addSubview(collectionView)

        // Cells that are a collection view themsevles
        collectionView.register(CollectionViewInCollectionViewCell<PVGame>.self, forCellWithReuseIdentifier: CollectionViewInCollectionViewCell<PVGame>.identifier)
        collectionView.register(CollectionViewInCollectionViewCell<PVSaveState>.self, forCellWithReuseIdentifier: CollectionViewInCollectionViewCell<PVSaveState>.identifier)
        collectionView.register(CollectionViewInCollectionViewCell<PVRecentGame>.self, forCellWithReuseIdentifier: CollectionViewInCollectionViewCell<PVRecentGame>.identifier)

        // TODO: Use nib for cell once we drop iOS 8 and can use layouts
        #if os(iOS)
            collectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #else
            collectionView.register(UINib(nibName: "PVGameLibraryCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        #endif
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
                    collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
                layout.sectionInsetReference = .fromSafeArea
            } else {
                layout.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
            }
        #endif
        // Force touch
        #if os(iOS)
            registerForPreviewing(with: self, sourceView: collectionView)
        #endif

        #if os(iOS)
            view.bringSubviewToFront(libraryInfoContainerView)
        #endif

        let hud = MBProgressHUD(view: view)!
        hud.isUserInteractionEnabled = false
        view.addSubview(hud)
        updatesController.hudState
            .subscribe(onNext: { state in
                switch state {
                case .hidden:
                    hud.hide(true)
                case .title(let title):
                    hud.show(true)
                    hud.mode = .indeterminate
                    hud.labelText = title
                case .titleAndProgress(let title, let progress):
                    hud.show(true)
                    hud.mode = .annularDeterminate
                    hud.progress = progress
                    hud.labelText = title
                }
            })
            .disposed(by: disposeBag)

        updatesController.conflicts
            .map { !$0.isEmpty }
            .subscribe(onNext: { hasConflicts in
                self.updateConflictsButton(hasConflicts)
                if hasConflicts {
                    self.showConflictsAlert()
                }
            })
            .disposed(by: disposeBag)

        loadGameFromShortcut()
        becomeFirstResponder()
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
        coordinator.notifyWhenInteractionChanges { [weak self] _ in
            self?.transitioningToSize = nil
        }
    }

    #if os(iOS)
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            return .all
        }
    #endif

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SettingsSegue" {
            let settingsVC = (segue.destination as! UINavigationController).topViewController as! PVSettingsViewController
            settingsVC.conflictsController = updatesController
        } else if segue.identifier == "gameMoreInfoSegue" {
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
        func showServer() {
            let ipURL = URL(string: PVWebServer.shared.urlString)
            let safariVC = SFSafariViewController(url: ipURL!, entersReaderIfAvailable: false)
            safariVC.delegate = self
            present(safariVC, animated: true) { () -> Void in }
        }

        func safariViewController(_: SFSafariViewController, didCompleteInitialLoad _: Bool) {
            // Load finished
        }

        // Dismiss and shut down web server
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

    lazy var reachability = try! Reachability()

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
            let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or settings and free up ports: 80, 81.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }

    // MARK: - Game Library Management

    // TODO: It would be nice to move this and the importer-logic out of the ViewController at some point
    func handleLibraryMigration() {
        UserDefaults.standard.register(defaults: [PVRequiresMigrationKey: true])
        if UserDefaults.standard.bool(forKey: PVRequiresMigrationKey) {
            let hud = MBProgressHUD.showAdded(to: view, animated: true)!
            gameLibrary.migrate()
                .subscribe(onNext: { event in
                    switch event {
                    case .starting:
                        hud.isUserInteractionEnabled = false
                        hud.mode = .indeterminate
                        hud.labelText = "Migrating Game Library"
                        hud.detailsLabelText = "Please be patient, this may take a while..."
                    case .pathsToImport(let paths):
                        hud.hide(true)
                        let _ = self.gameImporter.importFiles(atPaths: paths)
                    }
                }, onError: { error in
                    ELOG(error.localizedDescription)
                }, onCompleted: {
                    hud.hide(true)
                    UserDefaults.standard.set(false, forKey: PVRequiresMigrationKey)
                })
                .disposed(by: disposeBag)
        }
    }

    fileprivate func showConflictsAlert() {
        let alert = UIAlertController(title: "Oops!", message: "There was a conflict while importing your game.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Let's go fix it!", style: .default, handler: { [unowned self] (_: UIAlertAction) -> Void in
            self.displayConflictVC()
        }))

        alert.addAction(UIAlertAction(title: "Nah, I'll do it later...", style: .cancel, handler: nil))
        self.present(alert, animated: true) { () -> Void in }

        ILOG("Encountered conflicts, should be showing message")
    }

    fileprivate func displayConflictVC() {
        let conflictViewController = PVConflictViewController(conflictsController: updatesController)
        let navController = UINavigationController(rootViewController: conflictViewController)
        present(navController, animated: true) { () -> Void in }
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

    private func longPressed(item: Section.Item, at indexPath: IndexPath, point: CGPoint) {
        let cell = collectionView!.cellForItem(at: indexPath)!
        let actionSheet = contextMenu(for: item, cell: cell, point: point)

        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = cell
            actionSheet.popoverPresentationController?.sourceRect = (collectionView?.layoutAttributesForItem(at: indexPath)?.bounds ?? CGRect.zero)
        }

        present(actionSheet, animated: true)
    }

    private func contextMenu(for item: Section.Item, cell: UICollectionViewCell, point: CGPoint) -> UIAlertController {
        switch item {
        case .game(let game):
            return contextMenu(for: game, sender: cell)
        case .favorites:
            let game: PVGame = (cell as! CollectionViewInCollectionViewCell).item(at: point)!
            return contextMenu(for: game, sender: cell)
        case .saves:
            let saveState: PVSaveState = (cell as! CollectionViewInCollectionViewCell).item(at: point)!
            return contextMenu(for: saveState)
        case .recents:
            let game: PVRecentGame = (cell as! CollectionViewInCollectionViewCell).item(at: point)!
            return contextMenu(for: game.game, sender: cell)
        }
    }

    private func contextMenu(for game: PVGame, sender: Any?) -> UIAlertController {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        #if os(tvOS)
        actionSheet.message = "Options for \(game.title)"
        #endif
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
                self.presentCoreSelection(forGame: game, sender: sender)
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
            let alert = UIAlertController(title: nil, message: "URL copied to clipboard.", preferredStyle: .alert)
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

        actionSheet.addAction(UIAlertAction(title: "Share", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.share(for: game, sender: sender)
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
        return actionSheet
    }

    private func contextMenu(for saveState: PVSaveState) -> UIAlertController {
        let actionSheet = UIAlertController(title: "Delete this save state?", message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Yes", style: .destructive) { [unowned self] _ in
            do {
                try PVSaveState.delete(saveState)
            } catch {
                self.presentError("Error deleting save state: \(error.localizedDescription)")
            }
        })
        actionSheet.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        return actionSheet
    }

    func toggleFavorite(for game: PVGame) {
        gameLibrary.toggleFavorite(for: game)
            .subscribe(onCompleted: {
                self.collectionView?.reloadData()
            }, onError: { error in
                ELOG("Failed to toggle Favorite for game \(game.title)")
            })
            .disposed(by: disposeBag)
    }

    func moreInfo(for game: PVGame) {
        #if os(iOS)
            performSegue(withIdentifier: "gameMoreInfoPageVCSegue", sender: game)
        #else
            performSegue(withIdentifier: "gameMoreInfoSegue", sender: game)
        #endif
    }

    func renameGame(_ game: PVGame) {
        let alert = UIAlertController(title: "Rename", message: "Enter a new name for \(game.title):", preferredStyle: .alert)
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
            let imagePickerActionSheet = UIAlertController(title: "Choose Artwork", message: "Choose the location of the artwork.\n\nUse Latest Photo: Use the last image in the camera roll.\nTake Photo: Use the camera to take a photo.\nChoose Photo: Use the camera roll to choose an image.", preferredStyle: .actionSheet)
            
            let cameraIsAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)
            let photoLibraryIsAvaialble: Bool = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
            
            let cameraAction = UIAlertAction(title: "Take Photo", style: .default, handler: { action in
                self.gameForCustomArt = game
                let pickerController = UIImagePickerController()
                pickerController.delegate = weakSelf
                pickerController.allowsEditing = false
                pickerController.sourceType = .camera
                self.present(pickerController, animated: true) { () -> Void in }
            })
            
            let libraryAction = UIAlertAction(title: "Choose Photo", style: .default, handler: { action in
                self.gameForCustomArt = game
                let pickerController = UIImagePickerController()
                pickerController.delegate = weakSelf
                pickerController.allowsEditing = false
                pickerController.sourceType = .photoLibrary
                self.present(pickerController, animated: true) { () -> Void in }
            })
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            if fetchResult.count > 0 {
                let lastPhoto = fetchResult.lastObject
                
                imagePickerActionSheet.addAction(UIAlertAction(title: "Use Latest Photo", style: .default, handler: { (action) in
                    PHImageManager.default().requestImage(for: lastPhoto!, targetSize: CGSize(width: lastPhoto!.pixelWidth, height: lastPhoto!.pixelHeight), contentMode: .aspectFill, options: PHImageRequestOptions(), resultHandler: { (image, _) in
                        let orientation: UIImage.Orientation = UIImage.Orientation(rawValue: (image?.imageOrientation)!.rawValue)!

                        let lastPhoto2 = UIImage(cgImage: image!.cgImage!, scale: CGFloat(image!.scale), orientation: orientation)
                        lastPhoto!.requestContentEditingInput(with: PHContentEditingInputRequestOptions()) { (input, _) in
                            do {
                                try PVMediaCache.writeImage(toDisk: lastPhoto2, withKey: (input?.fullSizeImageURL!.absoluteString)!)
                                try RomDatabase.sharedInstance.writeTransaction {
                                    game.customArtworkURL = (input?.fullSizeImageURL!.absoluteString)!
                                }
                            } catch {
                            ELOG("Failed to set custom artwork URL for game \(game.title) \n \(error.localizedDescription)")
                            }
                        }
                    })
                }))
            }
                    
            if cameraIsAvailable || photoLibraryIsAvaialble {
                if cameraIsAvailable {
                    imagePickerActionSheet.addAction(cameraAction)
                }
                if photoLibraryIsAvaialble {
                    imagePickerActionSheet.addAction(libraryAction)
                }
            }
            imagePickerActionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                imagePickerActionSheet.dismiss(animated: true, completion: nil)
            }))
            present(imagePickerActionSheet, animated: true, completion: nil)
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

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, referenceSizeForHeaderInSection _: Int) -> CGSize {
        #if os(tvOS)
            return CGSize(width: view.bounds.size.width, height: 60)
        #else
            return CGSize(width: view.bounds.size.width, height: 40)
        #endif
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
            if let image = image, let scaledImage = image.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)), let imageData = scaledImage.jpegData(compressionQuality: 0.85) {
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
                destination = importPath.appendingPathComponent(fileName, isDirectory: url.hasDirectoryPath)
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
            cell.accessoryType = indexPath.row == (try! currentSort.value()).row ? .checkmark : .none
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
            currentSort.onNext(SortOptions.optionForRow(UInt(indexPath.row)))
            dismiss(animated: true, completion: nil)
        } else if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                PVSettingsModel.shared.showGameTitles = !PVSettingsModel.shared.showGameTitles
            case 1:
                showRecentGames.onNext(!PVSettingsModel.shared.showRecentGames)
            case 2:
                showSaveStates.onNext(!PVSettingsModel.shared.showRecentSaveStates)
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

        // Simulator Command + number has shorcuts already
        #if targetEnvironment(simulator)
            let flags: UIKeyModifierFlags = [.control, .command]
        #else
            let flags: UIKeyModifierFlags = .command
        #endif

        if let dataSource = collectionView?.rx.dataSource.forwardToDelegate() as? CollectionViewSectionedDataSource<Section> {
            for (i, section) in dataSource.sectionModels.enumerated() {
                let input = "\(i)"
                let title = section.header
                let command = UIKeyCommand(input: input, modifierFlags: flags, action: #selector(PVGameLibraryViewController.selectSection(_:)), discoverabilityTitle: title)
                sectionCommands.append(command)
            }
        }

        #if os(tvOS)
            if focusedGame != nil {
                let toggleFavoriteCommand = UIKeyCommand(input: "=", modifierFlags: flags, action: #selector(PVGameLibraryViewController.toggleFavoriteCommand), discoverabilityTitle: "Toggle Favorite")
                sectionCommands.append(toggleFavoriteCommand)

                let showMoreInfo = UIKeyCommand(input: "i", modifierFlags: flags, action: #selector(PVGameLibraryViewController.showMoreInfoCommand), discoverabilityTitle: "More info…")
                sectionCommands.append(showMoreInfo)

                let renameCommand = UIKeyCommand(input: "r", modifierFlags: flags, action: #selector(PVGameLibraryViewController.renameCommand), discoverabilityTitle: "Rename…")
                sectionCommands.append(renameCommand)

                let deleteCommand = UIKeyCommand(input: "x", modifierFlags: flags, action: #selector(PVGameLibraryViewController.deleteCommand), discoverabilityTitle: "Delete…")
                sectionCommands.append(deleteCommand)

                let sortCommand = UIKeyCommand(input: "s", modifierFlags: flags, action: #selector(PVGameLibraryViewController.sortButtonTapped(_:)), discoverabilityTitle: "Sorting")
                sectionCommands.append(sortCommand)
            }
        #elseif os(iOS)
            let findCommand = UIKeyCommand(input: "f", modifierFlags: flags, action: #selector(PVGameLibraryViewController.selectSearch(_:)), discoverabilityTitle: "Find…")
            sectionCommands.append(findCommand)

            let sortCommand = UIKeyCommand(input: "s", modifierFlags: flags, action: #selector(PVGameLibraryViewController.sortButtonTapped(_:)), discoverabilityTitle: "Sorting")
            sectionCommands.append(sortCommand)

            let settingsCommand = UIKeyCommand(input: ",", modifierFlags: flags, action: #selector(PVGameLibraryViewController.settingsCommand), discoverabilityTitle: "Settings")
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

        func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with _: UIFocusAnimationCoordinator) {
            focusedGame = getFocusedGame(in: collectionView, focusContext: context)
        }

        private func getFocusedGame(in collectionView: UICollectionView, focusContext context: UICollectionViewFocusUpdateContext) -> PVGame? {
            guard let indexPath = context.nextFocusedIndexPath,
                let item: Section.Item = try? collectionView.rx.model(at: indexPath)
                else { return nil }

            switch item {
                case .game(let game):
                    return game
            case .favorites(let games):
                if let outerCell = collectionView.cellForItem(at: indexPath) as? CollectionViewInCollectionViewCell<PVGame>,
                    let innerCell = context.nextFocusedItem as? UICollectionViewCell,
                    let innerIndexPath = outerCell.internalCollectionView.indexPath(for: innerCell) {
                    return games[innerIndexPath.row]
                }
                return nil
            case .recents(let games):
                if let outerCell = collectionView.cellForItem(at: indexPath) as? CollectionViewInCollectionViewCell<PVRecentGame>,
                    let innerCell = context.nextFocusedItem as? UICollectionViewCell,
                    let innerIndexPath = outerCell.internalCollectionView.indexPath(for: innerCell) {
                    return games[innerIndexPath.row].game
                }
                return nil
            case .saves:
                return nil
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
    private func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
        return Dictionary(uniqueKeysWithValues: input.map { key, value in (key.rawValue, value) })
    }

    // Helper function inserted by Swift 4.2 migrator.
    private func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
        return input.rawValue
    }
#endif
