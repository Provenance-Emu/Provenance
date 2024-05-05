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
    static let PVResetLibrary = Notification.Name("kResetLibraryNotification")
    static let PVReimportLibrary = Notification.Name("kReimportLibraryNotification")
    static let PVRefreshLibrary = Notification.Name("kRefreshLibraryNotification")
    static let PVInterfaceDidChangeNotification = Notification.Name("kInterfaceDidChangeNotification")
}

final class PVGameLibraryViewController: GCEventViewController, UITextFieldDelegate, UINavigationControllerDelegate, GameLaunchingViewController, GameSharingViewController, WebServerActivatorController {
    lazy var collectionViewZoom: CGFloat = CGFloat(PVSettingsModel.shared.gameLibraryScale)

    let disposeBag = DisposeBag()
    var updatesController: PVGameLibraryUpdatesController!
    var gameLibrary: PVGameLibrary!
    var gameImporter: GameImporter!
    var filePathsToImport = [URL]()

    // selected (aka hilighted) item selected via game controller UX
    #if os(iOS)
        // NOTE this may not be a *real* indexPath, if it is for a section with a nexted collection view
        var _selectedIndexPath:IndexPath?
        var _selectedIndexPathView:UIView!
    #endif

    var collectionView: UICollectionView? {
        didSet {
            guard let collectionView = collectionView else { return }
            #if os(iOS)
                if #available(iOS 14.0, *) {
                    collectionView.selectionFollowsFocus = true
                }
            #endif
            collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }

    #if os(iOS)
        var photoLibrary: PHPhotoLibrary?
    #endif
    var gameForCustomArt: PVGame?

    @IBOutlet var settingsBarButtonItem: UIBarButtonItem!
    @IBOutlet var getMoreRomsBarButtonItem: UIBarButtonItem!
    @IBOutlet var sortOptionBarButtonItem: UIBarButtonItem!
    @IBOutlet var conflictsBarButtonItem: UIBarButtonItem!
    @IBOutlet var refreshOptionBarButtonItem: UIBarButtonItem!

    #if os(iOS)
        @IBOutlet var libraryInfoContainerView: UIStackView!
        @IBOutlet var libraryInfoLabel: UILabel!
    #endif

    var isInitialAppearance = false
    var isLoaded = false

    // add or remove the conflict button (iff it is in the storyboard)
    func updateConflictsButton(_ hasConflicts: Bool) {
        if let conflictsBarButtonItem = conflictsBarButtonItem {
            conflictsBarButtonItem.isEnabled = hasConflicts
            #if os(tvOS)
            let items: [UIBarButtonItem] = hasConflicts ? [ getMoreRomsBarButtonItem, refreshOptionBarButtonItem, conflictsBarButtonItem ] : [getMoreRomsBarButtonItem, refreshOptionBarButtonItem]
            #else
            let items: [UIBarButtonItem] = hasConflicts ? [ settingsBarButtonItem, sortOptionBarButtonItem, conflictsBarButtonItem ] : [settingsBarButtonItem, sortOptionBarButtonItem]
            #endif
            navigationItem.leftBarButtonItems = items
        }
    }

    @IBOutlet var sortOptionsTableView: UITableView!
    lazy var sortOptionsTableViewController: SortOptionsTableViewController = {
        let avc = SortOptionsTableViewController(withTableView: sortOptionsTableView)
        avc.title = "Library Options"
        return avc
    }()

    let currentSort = BehaviorSubject(value: PVSettingsModel.shared.sort)
    let collapsedSystems = BehaviorSubject(value: PVSettingsModel.shared.collapsedSystems)
    let showSaveStates = BehaviorSubject(value: PVSettingsModel.shared.showRecentSaveStates)
    let showRecentGames = BehaviorSubject(value: PVSettingsModel.shared.showRecentGames)

    // MARK: - Lifecycle

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func handleAppDidBecomeActive(_: Notification) {
        loadGameFromShortcut()
    }

    struct Section: SectionModelType {
        let header: String
        let items: [Item]
        let collapsible: Collapsible?

        enum Item {
            case game(PVGame)
            case favorites([PVGame])
            case saves([PVSaveState])
            case recents([PVRecentGame])
        }

        enum Collapsible {
            case collapsed(systemToken: String)
            case notCollapsed(systemToken: String)
        }

        init(header: String, items: [Item], collapsible: Collapsible?) {
            self.header = header
            self.items = items
            self.collapsible = collapsible
        }

        init(original: PVGameLibraryViewController.Section, items: [Item]) {
            self.init(header: original.header, items: items, collapsible: original.collapsible)
        }
    }

    #if os(iOS)
    var searchController: UISearchController!
    #endif

    var hud: MBProgressHUD!
    
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
            navigationController?.navigationBar.backgroundColor = Theme.currentTheme.navigationBarBackgroundColor
            navigationController?.navigationBar.tintColor = Theme.currentTheme.barButtonItemTint

            NotificationCenter.default.addObserver(forName: NSNotification.Name.PVInterfaceDidChangeNotification, object: nil, queue: nil, using: { (_: Notification) -> Void in
                DispatchQueue.main.async {
                    self.collectionView?.collectionViewLayout.invalidateLayout()
                    self.collectionView?.reloadData()
                }
            })
        #else
            navigationController?.navigationBar.isTranslucent = false
            let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            let bounds = (self.navigationController?.navigationBar.bounds)!
            blurEffectView.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height + 20)
            self.navigationController?.navigationBar.addSubview(blurEffectView)
            self.navigationController?.navigationBar.sendSubviewToBack(blurEffectView)
            navigationController?.navigationBar.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            // ironicaly BarButtonItems (unselected background) look better when forced to LightMode
            navigationController?.overrideUserInterfaceStyle = .light
            self.overrideUserInterfaceStyle = .dark
        #endif

        // Handle migrating library
        DispatchQueue.main.async {
            self.handleLibraryMigration()
        }

        let searchText: Observable<String?>
        #if os(iOS)
            // Navigation bar large titles
            navigationController?.navigationBar.prefersLargeTitles = false
            navigationItem.title = nil

            // Create a search controller
            let searchController = UISearchController(searchResultsController: nil)
            searchController.searchBar.placeholder = "Search"
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.hidesNavigationBarDuringPresentation = false
            searchController.automaticallyShowsCancelButton = true
            navigationItem.hidesSearchBarWhenScrolling = true
            navigationItem.searchController = searchController

            self.searchController = searchController
            searchText = Observable.merge(searchController.rx.searchText, searchController.rx.didDismiss.map { _ in nil })
        #else
            searchText = .never()
        #endif

        // create a Logo as the title
        #if os(iOS)
            let font = UIFont.boldSystemFont(ofSize: 20)
            let icon = "AppIcon"
			let icon_size = font.pointSize
        #else
            let font = UIFont.boldSystemFont(ofSize: 48)
            let icon = "pv_dark_logo"
            let icon_size = font.capHeight

            if let bbi = settingsBarButtonItem {
                bbi.image = UIImage(systemName:"gear", withConfiguration:UIImage.SymbolConfiguration(font:font))
            }
        #endif
        if let icon = UIImage(named:icon)?.resize(to:CGSize(width:0, height:icon_size))
        {
            let logo = UIImageView(image:icon)
            logo.layer.cornerRadius = 4.0
            logo.layer.masksToBounds = true
            let name = UILabel()
            name.text = " Provenance"
            name.font = font
            name.textColor = .white
            name.sizeToFit()
            let stack =  UIStackView(arrangedSubviews:[logo, name])
            stack.alignment = .center
            stack.frame = CGRect(origin:.zero, size:stack.systemLayoutSizeFitting(.zero))
            stack.isHidden=false;
            navigationItem.titleView = stack
            navigationItem.titleView?.isHidden=false;
        }

        // Persist some settings, could probably be done in a better way
        collapsedSystems.bind(onNext: { PVSettingsModel.shared.collapsedSystems = $0 }).disposed(by: disposeBag)
        currentSort.bind(onNext: { PVSettingsModel.shared.sort = $0 }).disposed(by: disposeBag)
        showSaveStates.bind(onNext: { PVSettingsModel.shared.showRecentSaveStates = $0 }).disposed(by: disposeBag)
        showRecentGames.bind(onNext: { PVSettingsModel.shared.showRecentGames = $0 }).disposed(by: disposeBag)

        let layout = PVGameLibraryCollectionFlowLayout()
        layout.scrollDirection = .vertical

        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        self.collectionView = collectionView

        typealias Playable = (PVGame, UICollectionViewCell?, PVCore?, PVSaveState?)
        let selectedPlayable = PublishSubject<Playable>()

        let dataSource = RxCollectionViewSectionedReloadDataSource<Section>(configureCell: { _, collectionView, indexPath, item in
            switch item {
            case .game(let game):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier, for: indexPath)
                if let cell = cell as? PVGameLibraryCollectionViewCell {
                    cell.game = game
                }
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
            .map {
                indexPath in (try! collectionView.rx.model(at: indexPath) as Section.Item, collectionView.cellForItem(at: indexPath))
            }
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
                    if case .collapsed = section.collapsible {
                        return true
                    }
                    return false
                }()
                header.viewModel = .init(title: section.header, collapsible: section.collapsible != nil, collapsed: collapsed)
                #if os(iOS)
                header.collapseButton.rx.tap
                    .withLatestFrom(self.collapsedSystems)
                    .map({ (collapsedSystems: Set<String>) in
                        switch section.collapsible {
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
                #if os(tvOS)
                header.collapseButton.rx.primaryAction
                    .withLatestFrom(self.collapsedSystems)
                    .map({ (collapsedSystems: Set<String>) in
                        switch section.collapsible {
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
                    header.updateFocusIfNeeded()
                #endif
                return header
            case UICollectionView.elementKindSectionFooter:
                return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PVGameLibraryFooterViewIdentifier, for: indexPath)
            default:
                fatalError("Don't support type \(kind)")
            }
        }
        let favoritesSection = gameLibrary.favorites
            .map { favorites in favorites.isEmpty ? nil : Section(header: "Favorites", items: [.favorites(favorites)], collapsible: nil)}

        let saveStateSection = Observable.combineLatest(showSaveStates, gameLibrary.saveStates) { $0 ? $1.filter { FileManager.default.fileExists(atPath: $0.file.url.path) } : [] }
            .map { saveStates in saveStates.isEmpty ? nil : Section(header: "Recently Saved", items: [.saves(saveStates)], collapsible: nil) }

        let recentsSection = Observable.combineLatest(showRecentGames, gameLibrary.recents) { $0 ? $1 : [] }
            .map { recentGames in recentGames.isEmpty ? nil : Section(header: "Recently Played", items: [.recents(recentGames)], collapsible: nil) }

        let topSections = Observable.combineLatest(favoritesSection, saveStateSection, recentsSection) { [$0, $1, $2] }

        // MARK: DataSource sections

        let searchSection = searchText
            .flatMap({ text -> Observable<[PVGame]?> in
                guard let text = text else { return .just(nil) }
                return self.gameLibrary.search(for: text).map(Optional.init)
            })
            .map({ games -> Section? in
                guard let games = games else { return nil }
                return Section(header: "Search Results", items: games.map { .game($0) }, collapsible: nil)
            })
            .startWith(nil)
        let hideBios:[String:Bool] = RomDatabase.sharedInstance.getBIOSCache().values.joined()
            .reduce(into: [:]){
                (hideBios, bios) in
                let biosInfo=bios.components(separatedBy: "|")
                if biosInfo.count >= 3 {
                    let (path, visibility)=(biosInfo[1], biosInfo[2])
                    hideBios[path.lowercased()] = visibility == "hide"
                } else {
                    hideBios[bios.lowercased()] = true
                }
            }
        let systemSections = currentSort
            .flatMapLatest { Observable.combineLatest(self.gameLibrary.systems(sortedBy: $0), self.collapsedSystems) }
            .map({ systems, collapsedSystems in
                systems.map { system in (system: system, isCollapsed: collapsedSystems.contains(system.identifier) )}
            })
            .mapMany({ system, isCollapsed -> Section? in
                guard !system.sortedGames.isEmpty else { return nil }
                let header = "\(system.manufacturer) : \(system.shortName)" + (system.isBeta ? " ⚠️ Beta" : "") + (system.unsupported ? " 🚫 Unsupported" : "")
                let items = isCollapsed ? [] : system.sortedGames.filter{ !$0.isInvalidated && $0.genres != "hidden" && hideBios[$0.romPath.lowercased()] != true }.map { Section.Item.game($0) }

                return Section(header: header, items: items,
                               collapsible: isCollapsed ? .collapsed(systemToken: system.identifier) : .notCollapsed(systemToken: system.identifier))
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
        sections.observe(on: MainScheduler.instance).bind(to: collectionView.rx.items(dataSource: dataSource)).disposed(by: disposeBag)
        #if os(iOS)
        sections.map { !$0.isEmpty }.bind(to: libraryInfoContainerView.rx.isHidden).disposed(by: disposeBag)
        #endif

        #if os(tvOS)
        collectionView.rx.longPressed(Section.Item.self)
            .bind(onNext: self.longPressed)
            .disposed(by: disposeBag)
        #endif

        collectionView.rx.setDelegate(self).disposed(by: disposeBag)
        collectionView.bounces = true
        collectionView.alwaysBounceVertical = true
        collectionView.delaysContentTouches = false
        collectionView.keyboardDismissMode = .interactive
        collectionView.register(PVGameLibrarySectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier)
        collectionView.register(PVGameLibrarySectionFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: PVGameLibraryFooterViewIdentifier)

        #if os(tvOS)
//          collectionView.contentInset = UIEdgeInsets(top: 0, left: 80, bottom: 0, right: 80)
            collectionView.remembersLastFocusedIndexPath = true
            collectionView.clipsToBounds = false
            collectionView.backgroundColor = .black
        #else
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
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        let guide = view.safeAreaLayoutGuide
        #if os(iOS)
            NSLayoutConstraint.activate([
                collectionView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                collectionView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
                collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        #else
            NSLayoutConstraint.activate([
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 20),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        #endif

        // Force touch
        #if os(iOS)
            registerForPreviewing(with: self, sourceView: collectionView)
        #endif

        #if os(iOS)
            view.bringSubviewToFront(libraryInfoContainerView)
            layout.sectionInsetReference = .fromSafeArea
        #endif
        
        self.hud = MBProgressHUD(view: view)!
        self.hud.isUserInteractionEnabled = true
        view.addSubview(self.hud)
        
        updatesController.hudState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { state in
                    switch state {
                    case .hidden:
                        self.hud.hide(true, afterDelay: 1.0)
                        break;
                    case .title(let title):
                        self.hud.mode = .indeterminate
                        self.hud.labelText = title
                        self.hud.show(true)
                        self.hud.hide(true, afterDelay: 1.0)
                        break;
                    case .titleAndProgress(let title, let progress):
                        self.hud.mode = .annularDeterminate
                        self.hud.progress = progress
                        self.hud.labelText = title
                        self.hud.show(true)
                        if (progress == 1.0) {
                            self.hud.hide(true, afterDelay: 1.0)
                        }
                        break;
                    }
            }, onError: { (err) in
                print("Error")
            }, onCompleted: {
                print("Completed")
            }) {
                print("Disposed")
            }
            .disposed(by: disposeBag)

        updatesController.hudStateWatcher
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { state in
                    switch state {
                    case .hidden:
                        self.hud.hide(true, afterDelay: 1.0)
                        break;  
                    case .title(let title):
                        self.hud.mode = .indeterminate
                        self.hud.labelText = title
                        self.hud.show(true)
                        self.hud.hide(true, afterDelay: 1.0)
                        break;
                    case .titleAndProgress(let title, let progress):
                        self.hud.mode = .annularDeterminate
                        self.hud.progress = progress
                        self.hud.labelText = title
                        self.hud.show(true)
                        if (progress == 1) {
                            self.hud.hide(true, afterDelay: 1.0)
                        }
                        break;
                    }
            }, onError: { (err) in
                print("Error")
            }, onCompleted: {
                print("Completed")
            }) {
                print("Disposed")
            }
            .disposed(by: disposeBag)

        updatesController.conflicts
            .map { !$0.isEmpty }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { hasConflicts in
                self.updateConflictsButton(hasConflicts)
                if hasConflicts {
                    DispatchQueue.main.async {
                        self.showConflictsAlert()
                    }
                }
            })
            .disposed(by: disposeBag)

        self.hud.mode = .indeterminate
        self.hud.labelText = "Initializing Games Library..."
        self.hud.show(true)
        self.hud.hide(true, afterDelay: TimeInterval(1))
        self.checkROMs(true)

        loadGameFromShortcut()
        becomeFirstResponder()
    }
    
    public func checkROMs(_ once:Bool) {
        self.hud.mode = .indeterminate
        self.hud.labelText = "Initializing ROM Database..."
        self.hud.show(true)
        if !once || !isLoaded {
            self.updatesController.importROMDirectories()
        }
        self.hud.hide(true)
        isLoaded = true
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
                guard collectionView.collectionViewLayout.collectionViewContentSize.height != 0 else {
                    ELOG("collectionView.collectionViewLayout.collectionViewContentSize.height is 0")
                    return
                }
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        #if os(iOS)
            PVControllerManager.shared.controllerUserInteractionEnabled = false
        #else
            self.controllerUserInteractionEnabled = false
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = PVControllerManager.shared
        #if os(iOS)
            PVControllerManager.shared.controllerUserInteractionEnabled = true
        #else
            self.controllerUserInteractionEnabled = true
        #endif
        if isInitialAppearance {
            isInitialAppearance = false
            #if os(tvOS)
                let cell: UICollectionViewCell? = collectionView?.cellForItem(at: IndexPath(item: 0, section: 0))
                cell?.setNeedsFocusUpdate()
                cell?.updateFocusIfNeeded()
            #endif
        }

        guard RomDatabase.databaseInitialized else {
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

    fileprivate lazy var officialBundleID: Bool = Bundle.main.bundleIdentifier!.contains("org.provenance-emu.")

    var transitioningToSize: CGSize?
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        Theme.currentTheme = Theme.currentTheme

        transitioningToSize = size
        collectionView?.collectionViewLayout.invalidateLayout()
        coordinator.notifyWhenInteractionChanges { [weak self] _ in
            self?.transitioningToSize = nil
        }
    }

#if os(iOS) && !targetEnvironment(macCatalyst)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
#endif

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SettingsSegue" {
            let settingsVC = (segue.destination as! UINavigationController).topViewController as! PVSettingsViewController
            settingsVC.conflictsController = updatesController
        } else if segue.identifier == "SplitSettingsSegue" {
            #if os(tvOS)
                let splitVC = segue.destination as! PVTVSplitViewController
                let navVC = splitVC.viewControllers[1] as! UINavigationController
                let settingsVC = navVC.topViewController as! PVSettingsViewController
                settingsVC.conflictsController = updatesController
            #endif
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
			let ipURL: String = PVWebServer.shared.urlString
			let url = URL(string: ipURL)!
			#if targetEnvironment(macCatalyst)
			UIApplication.shared.open(url, options: [:]) { completed in
				ILOG("Completed: \(completed ? "Yes":"No")")
			}
			#else
			let config = SFSafariViewController.Configuration()
			config.entersReaderIfAvailable = false
			let safariVC = SFSafariViewController(url: url, configuration: config)
			safariVC.delegate = self
			present(safariVC, animated: true) { () -> Void in }
			#endif // targetEnvironment(macCatalyst)
        }

		#if !targetEnvironment(macCatalyst)
        func safariViewController(_: SFSafariViewController, didCompleteInitialLoad _: Bool) {
            // Load finished
        }

        // Dismiss and shut down web server
        func safariViewControllerDidFinish(_: SFSafariViewController) {
            // Done button pressed
            navigationController?.popViewController(animated: true)
            PVWebServer.shared.stopServers()
        }
		#endif // !targetEnvironment(macCatalyst)
    #endif // os(iOS)

    @IBAction func conflictsButtonTapped(_: Any) {
        displayConflictVC()
    }

    #if os(tvOS)
    @IBAction func searchButtonTapped(_ sender: Any) {
        let searchNavigationController = PVSearchViewController.createEmbeddedInNavigationController(gameLibrary: gameLibrary)
        present(searchNavigationController, animated: true) { () -> Void in }
    }
    #endif

    @IBAction func sortButtonTapped(_ sender: Any?) {
        if self.presentedViewController != nil {
            return
        }
        sortOptionsTableView.reloadData()

        #if !os(tvOS)
            // Add done button to iPhone
            // iPad is a popover do no done button needed
            if traitCollection.userInterfaceIdiom != .pad || traitCollection.horizontalSizeClass == .compact || !(sender is UIBarButtonItem) {
                let navController = UINavigationController(rootViewController: sortOptionsTableViewController)
                sortOptionsTableViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(PVGameLibraryViewController.dismissVC))
                present(navController, animated: true, completion: nil)
            } else {
                sortOptionsTableViewController.modalPresentationStyle = .popover
                sortOptionsTableViewController.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
                sortOptionsTableViewController.popoverPresentationController?.sourceView = collectionView
                sortOptionsTableViewController.preferredContentSize = CGSize(width:300, height:sortOptionsTableView.contentSize.height)
                present(sortOptionsTableViewController, animated: true, completion: nil)
            }
        #else
            sortOptionsTableViewController.preferredContentSize = CGSize(width:675, height:sortOptionsTableView.contentSize.height)
            let pvc = TVFullscreenController(rootViewController:sortOptionsTableViewController)
            present(pvc, animated: true, completion: nil)
        #endif
    }

    @IBAction func refreshButtonTapped(_ sender: Any?) {
        self.checkROMs(false)
    }

    @objc func dismissVC() {
        dismiss(animated: true, completion: nil)
    }

    lazy var reachability = try! Reachability()

    // MARK: - Filesystem Helpers

    @IBAction func getMoreROMs(_ sender: Any?) {
        do {
            try reachability.startNotifier()
        } catch {
            ELOG("Unable to start notifier")
        }

        #if !os(tvOS)
            // connected via wifi, let's continue

            let actionSheet = UIAlertController(title: "Select Import Source", message: nil, preferredStyle: .actionSheet)
            actionSheet.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem

            actionSheet.addAction(UIAlertAction(title: "Cloud & Local Files", style: .default, handler: { _ in
                let extensions = [UTI.rom, UTI.artwork, UTI.savestate, UTI.zipArchive, UTI.sevenZipArchive, UTI.gnuZipArchive, UTI.image, UTI.jpeg, UTI.png, UTI.bios, UTI.data, UTI.rar].map { $0.rawValue }

                //        let documentMenu = UIDocumentMenuViewController(documentTypes: extensions, in: .import)
                //        documentMenu.delegate = self
                //        present(documentMenu, animated: true, completion: nil)

                let documentPicker = UIDocumentPickerViewController(documentTypes: extensions, in: .import)
                documentPicker.allowsMultipleSelection = true
                documentPicker.delegate = self
                self.present(documentPicker, animated: true, completion: nil)
            }))

            let webServerAction = UIAlertAction(title: "Web Server", style: .default, handler: { _ in
                self.startWebServer(sender: sender as? UIView)
            })

            actionSheet.addAction(webServerAction)

            actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))

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

            if traitCollection.userInterfaceIdiom == .pad, let barButtonItem = sender as? UIBarButtonItem {
                actionSheet.popoverPresentationController?.barButtonItem = barButtonItem
                actionSheet.popoverPresentationController?.sourceView = collectionView
            }

            actionSheet.preferredContentSize = CGSize(width: 300, height: 150)

            present(actionSheet, animated: true, completion: nil)

            (actionSheet as UIViewController).rx.deallocating.asObservable().bind { [weak self] in
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
                WLOG("No WiFi. Cannot start web server.")
                present(alert, animated: true) { () -> Void in }
            } else {
                startWebServer(sender: sender as? UIView)
            }
        #endif
    }

    func startWebServer(sender: UIView?) {
        // start web transfer service
        if PVWebServer.shared.startServers() {
            // show alert view
            showServerActiveAlert(sender: self.collectionView, barButtonItem: navigationItem.rightBarButtonItem)
        } else {
			#if targetEnvironment(simulator) || targetEnvironment(macCatalyst) || os(macOS)
			let message = "Check your network connection or settings and free up ports: 8080, 8081."
			#else
			let message = "Check your network connection or settings and free up ports: 80, 81."
			#endif
            let alert = UIAlertController(title: "Unable to start web server!", message: message, preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            alert.popoverPresentationController?.sourceView = self.collectionView
            alert.popoverPresentationController?.sourceRect = self.collectionView?.bounds ?? UIScreen.main.bounds
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
            if (hud == nil) {
                self.hud = MBProgressHUD.init(view: view)!
            }
            gameLibrary.migrate()
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { event in
                    switch event {
                    case .starting:
                        self.hud.isUserInteractionEnabled = true
                        self.hud.mode = .indeterminate
                        self.hud.labelText = "Migrating Game Library"
                        self.hud.detailsLabelText = "Please be patient, this could take a while…"
                        self.hud.show(true)
                        self.hud.hide(true, afterDelay: 1.0)
                        break;
                    case .pathsToImport(let paths):
                        self.hud.labelText = "Checking " + paths.description
                        self.hud.show(true)
                        self.hud.hide(true, afterDelay: 1.0)
                        _ = self.gameImporter.importFiles(atPaths: paths)
                        break;
                    }
                }, onError: { error in
                    ELOG(error.localizedDescription)
                }, onCompleted: {
                    self.hud.hide(true)
                    UserDefaults.standard.set(false, forKey: PVRequiresMigrationKey)
                })
                .disposed(by: disposeBag)
        }
    }

    fileprivate func showConflictsAlert() {
        let alert = UIAlertController(title: "Oops!", message: "There was a conflict while importing your game.", preferredStyle: .alert)
        alert.preferredContentSize = CGSize(width: 300, height: 150)
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        alert.popoverPresentationController?.sourceView = self.collectionView
        alert.popoverPresentationController?.sourceRect = self.collectionView?.bounds ?? UIScreen.main.bounds
        alert.addAction(UIAlertAction(title: "Let's go fix it!", style: .default, handler: { [unowned self] (_: UIAlertAction) -> Void in
            self.displayConflictVC()
        }))

        alert.addAction(UIAlertAction(title: "Nah, I'll do it later…", style: .cancel, handler: nil))
        self.present(alert, animated: true) { () -> Void in }

        ILOG("Encountered conflicts, should be showing message")
    }

    fileprivate func displayConflictVC() {
        let conflictViewController = PVConflictViewController(conflictsController: updatesController)
        let navController = UINavigationController(rootViewController: conflictViewController)
        present(navController, animated: true) { () -> Void in }
    }

    @objc func handleCacheEmptied(_: NotificationCenter) {
        DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
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
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        alert.popoverPresentationController?.sourceView = self.collectionView
        alert.popoverPresentationController?.sourceRect = self.collectionView?.bounds ?? UIScreen.main.bounds
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true) { () -> Void in }
    }

    private func longPressed(item: Section.Item, at indexPath: IndexPath, point: CGPoint) {
        guard let cell = collectionView?.cellForItem(at: indexPath),
              let actionSheet = contextMenu(for: item, cell: cell, point: point) else {
            ELOG("nils here")
            return
        }

        actionSheet.popoverPresentationController?.sourceView = cell
        actionSheet.popoverPresentationController?.sourceRect = cell.bounds
        present(actionSheet, animated: true)
    }

    #if !os(tvOS)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = collectionView.cellForItem(at: indexPath),
              let item: Section.Item = try? collectionView.rx.model(at: indexPath)
        else { return nil }

        if let actionSheet = contextMenu(for: item, cell: cell, point: point) as? UIAlertControllerProtocol {
            return UIContextMenuConfiguration(identifier:nil) {
                return nil      // use default
            } actionProvider: {_ in
                return actionSheet.convertToMenu()
            }
        }
        return nil
    }
    #endif

    private func contextMenu(for item: Section.Item, cell: UICollectionViewCell, point: CGPoint) -> UIViewController? {
        switch item {
        case .game(let game):
            return contextMenu(for: game, sender: cell)
        case .favorites:
            guard let game: PVGame = (cell as? CollectionViewInCollectionViewCell)?.item(at: point) else { return nil }
            return contextMenu(for: game, sender: cell)
        case .saves:
            guard let saveState: PVSaveState = (cell as? CollectionViewInCollectionViewCell)?.item(at: point) else { return nil }
            return contextMenu(for: saveState)
        case .recents:
            guard let game: PVRecentGame = (cell as? CollectionViewInCollectionViewCell)?.item(at: point) else { return nil }
            return contextMenu(for: game.game, sender: cell)
        }
    }

    private func showCoreOptions(forCore core: CoreOptional.Type, withTitle title:String) {
        let optionsVC = CoreOptionsViewController(withCore: core)
        optionsVC.title = title
        #if os(iOS)
            self.navigationController?.pushViewController(optionsVC, animated: true)
        #else
            let nav = UINavigationController(rootViewController: optionsVC)
            present(TVFullscreenController(rootViewController: nav), animated: true, completion: nil)
        #endif
    }

    private func contextMenu(for game: PVGame, sender: UIView) -> UIViewController {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.title = game.title

        // If game.system has multiple cores, add actions to manage
        if let system = game.system, system.cores.count > 1 {
            // If user has select a core for this game, actio to reset
            if let userPreferredCoreID = game.userPreferredCoreID {

                // Action to play for default core
                actionSheet.addAction(UIAlertAction(title: "Play", symbol:"gamecontroller", style: .default, handler: { [unowned self] _ in
                    self.load(game, sender: sender, core: nil, saveState: nil)
                }))
                actionSheet.preferredAction = actionSheet.actions.last

                // Find the core for the current id
                let userSelectedCore = RomDatabase.sharedInstance.object(ofType: PVCore.self, wherePrimaryKeyEquals: userPreferredCoreID)
                let coreName = userSelectedCore?.projectName ?? "nil"
                // Add reset action
                actionSheet.addAction(UIAlertAction(title: "Reset default core selection (\(coreName))", symbol:"bolt.circle", style: .default, handler: { [unowned self] _ in

                    let resetAlert = UIAlertController(title: "Reset core?", message: "Are you sure you want to reset \(game.title) to no longer default to use \(coreName)?", preferredStyle: .alert)
                    resetAlert.preferredContentSize = CGSize(width: 300, height: 150)
                    resetAlert.popoverPresentationController?.sourceView = sender
                    resetAlert.popoverPresentationController?.sourceRect = sender.bounds ?? UIScreen.main.bounds
                    resetAlert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
                    resetAlert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
                        try! RomDatabase.sharedInstance.writeTransaction {
                            game.userPreferredCoreID = nil
                        }
                    }))
                    self.present(resetAlert, animated: true, completion: nil)
                }))
            }

            // Action to Open with...
            actionSheet.addAction(UIAlertAction(title: "Play with…", symbol: "ellipsis.circle", style: .default, handler: { [unowned self] _ in
                self.presentCoreSelection(forGame: game, sender: sender)
            }))
        } else {
            // Action to play for single core games
            actionSheet.addAction(UIAlertAction(title: "Play", symbol:"gamecontroller", style: .default, handler: { [unowned self] _ in
                self.load(game, sender: sender, core: nil, saveState: nil)
            }))
            actionSheet.preferredAction = actionSheet.actions.last
        }

        if let system = game.system, system.cores.count == 1, let pvcore = system.cores.first, let coreClass = NSClassFromString(pvcore.principleClass) as? CoreOptional.Type {

            actionSheet.addAction(UIAlertAction(title: "\(pvcore.projectName) options", symbol: "slider.horizontal.3", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.showCoreOptions(forCore: coreClass, withTitle:pvcore.projectName)
            }))
        }
        if game.relatedFiles.count > 0 {
            actionSheet.addAction(UIAlertAction(title: "Choose Disc…", symbol: "opticaldiscdrive", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.discSelection(forGame: game, system: game.system, sender: sender)
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "Game Info", symbol: "info.circle", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.moreInfo(for: game)
        }))

        var favoriteTitle = "Favorite"
        var favoriteSymbol = "heart"
        if game.isFavorite {
            favoriteTitle = "Unfavorite"
            favoriteSymbol = "heart.fill"
        }
        actionSheet.addAction(UIAlertAction(title: favoriteTitle, symbol:favoriteSymbol, style: .default, handler: { (_: UIAlertAction) -> Void in
            self.toggleFavorite(for: game)
        }))
        actionSheet.addAction(UIAlertAction(title: "Rename", symbol: "rectangle.and.pencil.and.ellipsis", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.renameGame(game, sender: sender)
        }))
        actionSheet.addAction(UIAlertAction(title: "Hide", symbol: "eye.slash", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.hideGame(game, sender: sender)
        }))
        #if os(iOS)

        actionSheet.addAction(UIAlertAction(title: "Copy MD5 URL", symbol: "arrow.up.doc", style: .default, handler: { (_: UIAlertAction) -> Void in
            let md5URL = "provenance://open?md5=\(game.md5Hash)"
            UIPasteboard.general.string = md5URL
            let alert = UIAlertController(title: nil, message: "URL copied to clipboard.", preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.popoverPresentationController?.sourceView = sender
            alert.popoverPresentationController?.sourceRect = sender.bounds ?? UIScreen.main.bounds
            self.present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                alert.dismiss(animated: true, completion: nil)
            })
        }))

        actionSheet.addAction(UIAlertAction(title: "Choose Cover", symbol:"folder", style: .default) { [weak self] _ in
            self?.chooseCustomArtwork(for: game, sourceView: sender)
        })

        if UIPasteboard.general.hasImages || UIPasteboard.general.hasURLs {
            actionSheet.addAction(UIAlertAction(title: "Paste Cover", symbol:"arrow.down.doc", style: .default, handler: { (_: UIAlertAction) -> Void in
                self.pasteCustomArtwork(for: game)
            }))
        }

        if !game.saveStates.isEmpty {
            actionSheet.addAction(UIAlertAction(title: "View Save States", symbol:"archivebox", style: .default, handler: { (_: UIAlertAction) -> Void in
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
                saveStatesNavController.modalPresentationStyle = .blurOverFullScreen
                #endif
                self.present(saveStatesNavController, animated: true)
            }))
        }

        // conditionally show Restore Original Artwork
        if !game.originalArtworkURL.isEmpty, !game.customArtworkURL.isEmpty, game.originalArtworkURL != game.customArtworkURL {
            actionSheet.addAction(UIAlertAction(title: "Restore Cover", symbol:"photo", style: .default, handler: { (_: UIAlertAction) -> Void in
                try! PVMediaCache.deleteImage(forKey: game.customArtworkURL)

                try! RomDatabase.sharedInstance.writeTransaction {
                    game.customArtworkURL = ""
                }

                let gameRef = ThreadSafeReference(to: game)

                DispatchQueue.global(qos: .userInitiated).async {
                    let realm = try! Realm()
                    guard let game = realm.resolve(gameRef) else {
                        return // person was deleted
                    }

                    self.gameImporter?.getArtwork(forGame: game)
                }
            }))
        }

        actionSheet.addAction(UIAlertAction(title: "Share", symbol:"square.and.arrow.up", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.share(for: game, sender: sender)
        }))
        #endif

        actionSheet.addAction(UIAlertAction(title: "Delete", symbol:"trash", style: .destructive, handler: { (_: UIAlertAction) -> Void in
            let alert = UIAlertController(title: "Delete \(game.title)", message: "Any save states and battery saves will also be deleted, are you sure?", preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.popoverPresentationController?.sourceView = sender
            alert.popoverPresentationController?.sourceRect = sender.bounds
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_: UIAlertAction) -> Void in
                // Delete from Realm
                do {
                    try self.delete(game: game)
                } catch {
                    self.presentError(error.localizedDescription, source: self.view)
                }
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            self.present(alert, animated: true) { () -> Void in }
        }))

        if actionSheet.preferredAction == nil {
            actionSheet.preferredAction = actionSheet.actions.first
        }
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
        return actionSheet
    }

    private func contextMenu(for saveState: PVSaveState) -> UIViewController {
        let actionSheet = UIAlertController(title: "Delete this save state?", message: nil, preferredStyle: .alert)

        actionSheet.addAction(UIAlertAction(title: "Yes", style: .destructive) { [unowned self] _ in
            do {
                try PVSaveState.delete(saveState)
            } catch {
                self.presentError("Error deleting save state: \(error.localizedDescription)", source: self.view)
            }
        })
        actionSheet.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        actionSheet.preferredAction = actionSheet.actions.last
        return actionSheet
    }

    func toggleFavorite(for game: PVGame) {
        gameLibrary.toggleFavorite(for: game)
            .observe(on: MainScheduler.instance)
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
    func discSelection(forGame game: PVGame, system: PVSystem, sender: Any?) {
        var discs:[PVFile] = game.relatedFiles.toArray().filter {
            system.supportedExtensions.contains($0.pathExtension)
        }
        if discs.filter({ return $0.url.lastPathComponent == game.file.url.lastPathComponent }).count == 0 {
            discs.append(game.file)
        }
        discs = discs.sorted(by: { (obj1, obj2) in
            return obj1.url.lastPathComponent < obj2.url.lastPathComponent
        })
        let coreChoiceAlert = UIAlertController(title: "Please Select the Disc to Launch",
                                                message: "",
                                                preferredStyle: .actionSheet)
        if let senderView = sender as? UIView ?? self.view {
            coreChoiceAlert.popoverPresentationController?.sourceView = senderView
            coreChoiceAlert.popoverPresentationController?.sourceRect = senderView.bounds
        }
        for disc in discs {
            let action = UIAlertAction(title: disc.fileName, style:.default) { [unowned self] _ in
                UserDefaults.standard.set(disc.url, forKey: game.romPath)
            }
            if let url = UserDefaults.standard.url(forKey: game.romPath) {
                if url.lastPathComponent == disc.url.lastPathComponent {
                    coreChoiceAlert.preferredAction = action
                }
            } else if disc.url.lastPathComponent == game.file.url.lastPathComponent {
                coreChoiceAlert.preferredAction = action
            }
            coreChoiceAlert.addAction(action)
        }
        present(coreChoiceAlert, animated: true)
    }
    func renameGame(_ game: PVGame, sender: UIView) {
        let alert = UIAlertController(title: "Rename", message: "Enter a new name for \(game.title):", preferredStyle: .alert)
        alert.preferredContentSize = CGSize(width: 300, height: 150)
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds ?? UIScreen.main.bounds
        alert.addTextField(configurationHandler: { (_ textField: UITextField) -> Void in
            textField.placeholder = game.title
            textField.text = game.title
        })

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            if let title = alert.textFields?.first?.text {
                guard !title.isEmpty else {
                    self.presentError("Cannot set a blank title.", source: self.view)
                    return
                }

                RomDatabase.sharedInstance.renameGame(game, toTitle: title)
            }
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
#if os(iOS)
        let ui=UIViewController()
        ui.addChildViewController(alert, toContainerView: ui.view)
        present(ui, animated:true) { ()-> Void in }
#else
        present(alert, animated: true) { () -> Void in }
#endif
    }
    func hideGame(_ game: PVGame, sender: UIView) {
        RomDatabase.sharedInstance.hideGame(game)
    }
    func delete(game: PVGame) throws {
        try RomDatabase.sharedInstance.delete(game: game)
    }

    #if os(iOS)
    private func chooseCustomArtwork(for game: PVGame, sourceView: UIView) {
            weak var weakSelf: PVGameLibraryViewController? = self
            let imagePickerActionSheet = UIAlertController(title: "Choose Artwork", message: "Choose the location of the artwork.\n\nUse Latest Photo: Use the last image in the camera roll.\nTake Photo: Use the camera to take a photo.\nChoose Photo: Use the camera roll to choose an image.", preferredStyle: .actionSheet)
            imagePickerActionSheet.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
       
            let cameraIsAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)
            let photoLibraryIsAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)

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
            // swiftlint:disable:next empty_count
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

            if cameraIsAvailable || photoLibraryIsAvailable {
                if cameraIsAvailable {
                    imagePickerActionSheet.addAction(cameraAction)
                }
                if photoLibraryIsAvailable {
                    imagePickerActionSheet.addAction(libraryAction)
                }
            }
            imagePickerActionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { (action) in
                imagePickerActionSheet.dismiss(animated: true, completion: nil)
            }))

            presentActionSheetViewControllerForPopoverPresentation(imagePickerActionSheet, sourceView: sourceView)
        }

        private func presentActionSheetViewControllerForPopoverPresentation(_ alertController: UIViewController, sourceView: UIView) {

            #if os(macOS) || targetEnvironment(macCatalyst)
            alertController.popoverPresentationController?.sourceView = sourceView
            alertController.popoverPresentationController?.sourceRect = sourceView.bounds
            #else
            if traitCollection.userInterfaceIdiom == .pad {
                alertController.popoverPresentationController?.sourceView = sourceView
                alertController.popoverPresentationController?.sourceRect = sourceView.bounds
            }
            #endif
            present(alertController, animated: true)
        }

        private func pasteCustomArtwork(for game: PVGame) {
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
        return CGSize(width: view.bounds.size.width, height: 40)
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
        if (self.hud == nil) {
            self.hud = MBProgressHUD.init(view: view)!
        }
        self.hud.isUserInteractionEnabled = true
        self.hud.mode = .indeterminate
        self.hud.labelText = "Migrating Game Library..."
        self.hud.detailsLabelText = "Please be patient, this could take a while…"
        self.hud.show(true);
    }

    @objc public func databaseMigrationFinished(_: Notification) {
        self.hud.hide(true)
    }
}

// MARK: UIDocumentMenuDelegate

#if !os(tvOS)
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
// MARK: Sort Options
extension PVGameLibraryViewController: UITableViewDataSource {
    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Sort By:"
        case 1:
            return "Game Library Display Options:"
        default:
            return nil
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        return 2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        #if os(tvOS)
            return section == 0 ? SortOptions.count : 5
        #else
            return section == 0 ? SortOptions.count : 4
        #endif
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // NOTE: cell setup is done in willDisplayCell
        if indexPath.section == 0 {
            return tableView.dequeueReusableCell(withIdentifier: "sortCell", for: indexPath)
        } else if indexPath.section == 1 {
            return tableView.dequeueReusableCell(withIdentifier: "viewOptionsCell", for: indexPath)
        } else {
            fatalError("Invalid section")
        }
    }
}

extension PVGameLibraryViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        #if os(tvOS)
            cell.layer.cornerRadius = 12
        #endif

        if indexPath.section == 0 {
            let sortOption = SortOptions.allCases[indexPath.row]
            cell.textLabel?.text = sortOption.description
            cell.accessoryType = indexPath.row == (try! currentSort.value()).row ? .checkmark : .none
        } else if indexPath.section == 1 {
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
            #if os(tvOS)
            case 4:
                cell.textLabel?.text = "Show Large Game Artwork"
                cell.accessoryType = PVSettingsModel.shared.largeGameArt ? .checkmark : .none
            #endif
	    default:
                fatalError("Invalid row")
            }
        } else {
            fatalError("Invalid section")
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.section == 0 {
            currentSort.onNext(SortOptions.optionForRow(UInt(indexPath.row)))
            // dont call reloadSections or we will loose focus on tvOS
            // tableView.reloadSections([indexPath.section], with: .automatic)
            for row in 0..<(self.tableView(tableView, numberOfRowsInSection: indexPath.section)) {
                let indexPath = IndexPath(row:row, section:indexPath.section)
                self.tableView(tableView, willDisplay:tableView.cellForRow(at:indexPath)!, forRowAt:indexPath)
            }
            // dismiss(animated: true, completion: nil)
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
	    #if os(tvOS)
            case 4:
                PVSettingsModel.shared.largeGameArt = !PVSettingsModel.shared.largeGameArt
            #endif
	    default:
                fatalError("Invalid row")
            }
            // dont call reloadRows or we will loose focus on tvOS
            // tableView.reloadRows(at: [indexPath], with:.automatic)
            self.tableView(tableView, willDisplay:tableView.cellForRow(at:indexPath)!, forRowAt:indexPath)
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
                #if os(tvOS)
                    let command = UIKeyCommand(input: input, modifierFlags: flags, action: #selector(PVGameLibraryViewController.selectSection(_:)))
                    command.discoverabilityTitle = title
                #elseif os(iOS)
                    let command = UIKeyCommand(title: title, action: #selector(PVGameLibraryViewController.selectSection(_:)), input: input, modifierFlags: flags)
                #endif
                sectionCommands.append(command)
            }
        }

        #if os(tvOS)
            if focusedGame != nil {
                let toggleFavoriteCommand = UIKeyCommand(input: "=", modifierFlags: flags, action: #selector(PVGameLibraryViewController.toggleFavoriteCommand))
                toggleFavoriteCommand.discoverabilityTitle = "Toggle Favorite"
                sectionCommands.append(toggleFavoriteCommand)

                let showMoreInfo = UIKeyCommand(input: "i", modifierFlags: flags, action: #selector(PVGameLibraryViewController.showMoreInfoCommand))
                showMoreInfo.discoverabilityTitle = "More info…"
                sectionCommands.append(showMoreInfo)

                let renameCommand = UIKeyCommand(input: "r", modifierFlags: flags, action: #selector(PVGameLibraryViewController.renameCommand))
                renameCommand.discoverabilityTitle = "Rename…"
                sectionCommands.append(renameCommand)

                let deleteCommand = UIKeyCommand(input: "x", modifierFlags: flags, action: #selector(PVGameLibraryViewController.deleteCommand))
                deleteCommand.discoverabilityTitle = "Delete…"
                sectionCommands.append(deleteCommand)

                let sortCommand = UIKeyCommand(input: "s", modifierFlags: flags, action: #selector(PVGameLibraryViewController.sortButtonTapped(_:)))
                sortCommand.discoverabilityTitle = "Sorting"
                sectionCommands.append(sortCommand)
            }
        #elseif os(iOS)
            let findCommand = UIKeyCommand(title: "Find…", action: #selector(PVGameLibraryViewController.selectSearch(_:)), input: "f", modifierFlags: flags)
            sectionCommands.append(findCommand)

            let sortCommand = UIKeyCommand(title: "Sorting", action: #selector(PVGameLibraryViewController.sortButtonTapped(_:)), input: "s", modifierFlags: flags)
            sectionCommands.append(sortCommand)
        
            let settingsCommand = UIKeyCommand(title: "Settings", action: #selector(PVGameLibraryViewController.settingsCommand), input: ",", modifierFlags: flags)
            sectionCommands.append(settingsCommand)
        #endif

        return sectionCommands
    }

    @objc func selectSearch(_: UIKeyCommand) {
		#if os(iOS)
		navigationItem.searchController?.isActive = true
        navigationItem.searchController?.searchBar.becomeFirstResponder()
		#endif
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
            renameGame(focusedGame, sender: self.collectionView!)
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
        alert.preferredContentSize = CGSize(width: 300, height: 150)
        alert.popoverPresentationController?.sourceView = self.collectionView
        alert.popoverPresentationController?.sourceRect = self.collectionView?.bounds ?? UIScreen.main.bounds
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_: UIAlertAction) -> Void in
            // Delete from Realm
            do {
                try self.delete(game: game)
                completion?(true)
            } catch {
                completion?(false)
                self.presentError(error.localizedDescription, source: self.view)
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

private extension UIImage {
    func resize(to size:CGSize) -> UIImage {
        var size = size
        if size.height == 0 {size.height = floor(size.width  * self.size.height / self.size.width)}
        if size.width  == 0 {size.width  = floor(size.height * self.size.width  / self.size.height)}
        return UIGraphicsImageRenderer(size:size).image { (context) in
            self.draw(in: CGRect(origin:.zero, size:size))
        }
    }
}

// MARK: ControllerButtonPress

#if os(iOS)

extension PVGameLibraryViewController: ControllerButtonPress {
    func controllerButtonPress(_ type: ButtonType) {
        switch type {
        case .select:
            select()
        case .up:
            moveVert(-1)
        case .down:
            moveVert(+1)
        case .left:
            moveHorz(-1)
        case .right:
            moveHorz(+1)
        case .options:
            options()
        case .menu:
            menu()
        case .x:
            settingsCommand()
//        case .y: // Bad merge?
//            longPress()
        case .r1:
            getMoreROMs(self)
        case .l1:
            sortButtonTapped(self)
        default:
            break
        }
    }

    private func moveVert(_ dir:Int) {
        guard var indexPath = _selectedIndexPath else {
            return select(IndexPath(item:0, section:0))
        }
        indexPath.item = indexPath.item + dir * itemsPerRow(indexPath)
        if indexPath.item < 0 {
            indexPath.section = indexPath.section-1
            indexPath.item = collectionView!.numberOfItems(inSection: indexPath.section)-1
        }
        if indexPath.item >= collectionView!.numberOfItems(inSection: indexPath.section) {
            indexPath.section = indexPath.section+1
            indexPath.item = 0
        }
        if indexPath.section >= 0 && indexPath.section < collectionView!.numberOfSections {
            select(indexPath)
        }
    }

    private func moveHorz(_ dir:Int) {
        guard var indexPath = _selectedIndexPath else {
            return select(IndexPath(item:0, section:0))
        }
        indexPath.item = indexPath.item + dir
        select(indexPath)
    }

    // access cell(s) in nested collectionView
    private func getNestedCollectionView(_ indexPath:IndexPath) -> UICollectionView? {
        if let cell = collectionView?.cellForItem(at: IndexPath(item: 0, section: indexPath.section)),
           let cv = (cell as? CollectionViewInCollectionViewCell<PVGame>)?.internalCollectionView ??
                    (cell as? CollectionViewInCollectionViewCell<PVSaveState>)?.internalCollectionView ??
                    (cell as? CollectionViewInCollectionViewCell<PVRecentGame>)?.internalCollectionView {
            return cv
        }
        return nil
    }

    private func itemsPerRow(_ indexPath:IndexPath) -> Int {
        guard let rect = collectionView!.layoutAttributesForItem(at: IndexPath(item: 0, section: indexPath.section))?.frame else {
            return 1
        }

        // TODO: this math is probably wrong
        let layout = (collectionView!.collectionViewLayout as! UICollectionViewFlowLayout)
        let space = layout.minimumInteritemSpacing
        let width = collectionView!.bounds.width // + space // - (layout.sectionInset.left + layout.sectionInset.right)
        let n = width / (rect.width + space)

        return max(1, Int(n))
    }

    // just hilight (with a cheesy overlay) the item
    private func select(_ indexPath:IndexPath?) {

        guard var indexPath = indexPath, collectionView!.numberOfSections > 0 else {
            _selectedIndexPath = nil
            _selectedIndexPathView?.frame = .zero
            return
        }

        // TODO: this is a hack, a cell should be selected by setting isSelected and the cell class should handle it

        indexPath.section = max(0, min(collectionView!.numberOfSections-1, indexPath.section))
        let rect:CGRect
        if let cv = getNestedCollectionView(indexPath) {
            collectionView?.scrollToItem(at: IndexPath(item:0, section: indexPath.section), at: [], animated: false)
            indexPath.item = max(0, min(cv.numberOfItems(inSection:0)-1, indexPath.item))
            let idx = IndexPath(item:indexPath.item, section:0)
            cv.scrollToItem(at:idx, at:[], animated: false)
            rect = cv.convert(cv.layoutAttributesForItem(at:idx)?.frame ?? .zero, to: collectionView)
        } else {
            guard let collectionView = collectionView, collectionView.numberOfSections > 0 else {
                _selectedIndexPath = nil
                _selectedIndexPathView?.frame = .zero
                return
            }
            let numberOfItems = collectionView.numberOfItems(inSection:indexPath.section)
            if numberOfItems < 1 {
                return
            }
            indexPath.item = max(0, min(numberOfItems-1, indexPath.item))
            collectionView.scrollToItem(at: indexPath, at: [], animated: false)
            rect = collectionView.layoutAttributesForItem(at: indexPath)?.frame ?? .zero
        }

        _selectedIndexPath = indexPath

        // TODO: this is a hack, a cell should be selected by setting isSelected and the cell class should handle it

        if !rect.isEmpty {
            _selectedIndexPathView = _selectedIndexPathView ?? UIView()
            collectionView!.addSubview(_selectedIndexPathView)
            collectionView!.bringSubviewToFront(_selectedIndexPathView)
            _selectedIndexPathView.frame = rect.insetBy(dx: -4.0, dy: -4.0)
            _selectedIndexPathView.backgroundColor = navigationController?.view.tintColor
            _selectedIndexPathView.alpha = 0.5
            _selectedIndexPathView.layer.cornerRadius = 16.0
        }
    }

    // actually *push* the selected item
    private func select() {
        guard let indexPath = _selectedIndexPath else { return }
        if let collectionView = getNestedCollectionView(indexPath) {
            let indexPath = IndexPath(item: indexPath.item, section:0)
            collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
        } else {
            collectionView!.delegate?.collectionView?(collectionView!, didSelectItemAt: indexPath)
        }
    }
    private func contextMenu(for indexPath:IndexPath?) -> UIViewController? {
        guard var indexPath = indexPath else { return nil }

        if let _ = getNestedCollectionView(indexPath) {
            indexPath = IndexPath(item:0, section:indexPath.section)
        }
        if  let item: Section.Item = try? collectionView!.rx.model(at: indexPath),
            let cell = collectionView!.cellForItem(at: indexPath) {
            return contextMenu(for: item, cell: cell, point: _selectedIndexPathView.center)
        }
        return nil
    }
    private func menu() {
        if let menu = contextMenu(for: _selectedIndexPath) {
            present(menu, animated: true)
        }
    }
    private func options() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem

        if _selectedIndexPath != nil {
            // get the title of the game from the contextMenu!
            if let menu = contextMenu(for: _selectedIndexPath), let title = menu.title, !title.isEmpty {
                actionSheet.addAction(UIAlertAction(title: "Play \(title)", symbol:"gamecontroller", style: .default, handler: { _ in
                    self.select()
                }))
            }
        }
        actionSheet.addAction(UIAlertAction(title: "Settings", symbol:"gear", style: .default, handler: { _ in
            self.settingsCommand()
        }))
        actionSheet.addAction(UIAlertAction(title: "Sort Options", symbol:"list.bullet", style: .default, handler: { _ in
            self.sortButtonTapped(nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "Add ROMs", symbol:"plus", style: .default, handler: { _ in
            self.getMoreROMs(nil)
        }))
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
        actionSheet.preferredAction = actionSheet.actions.first

        present(actionSheet, animated: true)
    }
}
#endif
