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
import GameController
import QuartzCore
import UIKit
// import RealmSwift
import CoreSpotlight

let PVGameLibraryHeaderViewIdentifier = "PVGameLibraryHeaderView"
let PVGameLibraryFooterViewIdentifier = "PVGameLibraryFooterView"

let PVGameLibraryCollectionViewCellIdentifier = "PVGameLibraryCollectionViewCell"
let PVRequiresMigrationKey = "PVRequiresMigration"

// For Obj-C
public extension NSNotification {
    @objc
    public static var PVRefreshLibraryNotification: NSString {
        return "kRefreshLibraryNotification"
    }
}

public extension Notification.Name {
    static let PVRefreshLibrary = Notification.Name("kRefreshLibraryNotification")
    static let PVInterfaceDidChangeNotification = Notification.Name("kInterfaceDidChangeNotification")
}

enum SortOptions: String {
    case title = "Title"
    case importDate = "Imported"
    case lastPlayed = "Last Played"

    var row: UInt {
        switch self {
        case .title:
            return 0
        case .importDate:
            return 1
        case .lastPlayed:
            return 2
        }
    }

    static func optionForRow(_ row: UInt) -> SortOptions {
        switch row {
        case 0:
            return .title
        case 1:
            return .importDate
        case 2:
            return .lastPlayed
        default:
            ELOG("Bad row \(row)")
            return .title
        }
    }
}

#if os(tvOS)
private let CellWidth: CGFloat = 308.0
#else
let USE_IOS_11_SEARCHBAR = true
#endif

#if os(iOS)
class PVDocumentPickerViewController: UIDocumentPickerViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.barStyle = Theme.currentTheme.navigationBarStyle
    }
}
#endif

class PVGameLibraryViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate, GameLaunchingViewController {

    var watcher: PVDirectoryWatcher?
    var gameImporter: PVGameImporter!
    var collectionView: UICollectionView?

    #if os(iOS)
    var renameToolbar: UIToolbar?
    var assetsLibrary: ALAssetsLibrary?
    #endif
    var renameOverlay: UIView?
    var renameTextField: UITextField?
    var gameToRename: PVGame?
    var gameForCustomArt: PVGame?

    var sectionTitles: [String] {
        var sectionsTitles = [String]()
        if !favoritesIsHidden {
            sectionsTitles.append("Favorites")
        }
        if !recentGamesIsHidden {
            sectionsTitles.append("Recently Played")
        }

        if let systems = systems {
            sectionsTitles.append(contentsOf: systems.map {$0.name})
        }
        return sectionsTitles
    }

    var searchResults: Results<PVGame>?
    @IBOutlet weak var searchField: UITextField?
    var isInitialAppearance = false
    var mustRefreshDataSource = false

    @IBOutlet weak var sortButtonItem: UIBarButtonItem!
    var needToShowConflictsAlert = false

    @IBOutlet var sortOptionsTableView: UITableView!
    var currentSort: SortOptions = .title {
        didSet {
            if isViewLoaded {
                fetchGames()
                collectionView?.reloadData()
            }
        }
    }

// MARK: - Lifecycle
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // A hack to make sure the main thread instance lives first
        _ = RomDatabase.sharedInstance

        initSystemPlists()
        UserDefaults.standard.register(defaults: [PVRequiresMigrationKey: true])
    }

    func initSystemPlists() {

        // Scane all subclasses of  PVEmulator core, and get their metadata
        // like their subclass name and the bundle the belong to
        let coreClasses = PVEmulatorConfiguration.coreClasses
        let corePlists = coreClasses.flatMap { (classInfo) -> URL? in
            return classInfo.bundle.url(forResource: "Core", withExtension: "plist")
        }

        PVEmulatorConfiguration.updateSystems(fromPlists: [Bundle.main.url(forResource: "Systems", withExtension: "plist")!])
        PVEmulatorConfiguration.updateCores(fromPlists: corePlists)
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

    @objc func handleAppDidBecomeActive(_ note: Notification) {
        loadGameFromShortcut()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isInitialAppearance = true
        definesPresentationContext = true

        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.databaseMigrationStarted(_:)), name: NSNotification.Name.DatabaseMigrationStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.databaseMigrationFinished(_:)), name: NSNotification.Name.DatabaseMigrationFinished, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleCacheEmptied(_:)), name: NSNotification.Name.PVMediaCacheWasEmptied, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleArchiveInflationFailed(_:)), name: NSNotification.Name.PVArchiveInflationFailed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleRefreshLibrary(_:)), name: NSNotification.Name.PVRefreshLibrary, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleTextFieldDidChange(_:)), name: .UITextFieldTextDidChange, object: searchField)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.handleAppDidBecomeActive(_:)), name: .UIApplicationDidBecomeActive, object: nil)

        #if os(iOS)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.PVInterfaceDidChangeNotification, object: nil, queue: nil, using: {(_ note: Notification) -> Void in
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
        setUpGameLibrary()

        #if os(iOS)
            if #available(iOS 11.0, *), USE_IOS_11_SEARCHBAR {

                // Hide the pre iOS 11 search bar
                searchField?.removeFromSuperview()
                navigationItem.titleView = nil

                // Navigation bar large titles
                navigationController?.navigationBar.prefersLargeTitles = false
                navigationItem.title = "Library"

                // Create a search contorller
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

        //load the config file
        title = "Library"

        let layout = UICollectionViewFlowLayout()

        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        self.collectionView = collectionView
        collectionView.collectionViewLayout = PVGameLibraryCollectionFlowLayout()
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.bounces = true
        collectionView.alwaysBounceVertical = true
        collectionView.delaysContentTouches = false
        collectionView.keyboardDismissMode = .interactive
        collectionView.register(PVGameLibrarySectionHeaderView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier)
        collectionView.register(PVGameLibrarySectionFooterView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: PVGameLibraryFooterViewIdentifier)

#if os(tvOS)
        collectionView.contentInset = UIEdgeInsets(top: 40, left: 80, bottom: 40, right: 80)
#else
    collectionView.backgroundColor = Theme.currentTheme.gameLibraryBackground
    searchField?.keyboardAppearance = Theme.currentTheme.keyboardAppearance
#endif
        view.addSubview(collectionView)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(PVGameLibraryViewController.longPressRecognized(_:)))
        collectionView.addGestureRecognizer(longPressRecognizer)
        collectionView.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)

        // Adjust collection view layout for iPhone X Safe areas
        // Can remove this when we go iOS 9+ and just use safe areas
        // in the story board directly - jm
        if #available(tvOS 11.0, iOS 11.0, *) {
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            let guide = view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                collectionView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                collectionView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
                collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                collectionView.bottomAnchor.constraintEqualToSystemSpacingBelow(guide.bottomAnchor, multiplier: 1.0)
                ])
            layout.sectionInsetReference = .fromSafeArea
        } else {
            layout.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        }

        // Force touch
        #if os(iOS)
        if #available(iOS 9.0, *) {
            registerForPreviewing(with: self, sourceView: collectionView)
        }
        #endif

        loadGameFromShortcut()
        becomeFirstResponder()
    }

    var systems: Results<PVSystem>?
    var favoriteGames: Results<PVGame>?
    var recentGames: Results<PVRecentGame>?

    var systemsToken: NotificationToken?
    var favoritesToken: NotificationToken?
    var recentGamesToken: NotificationToken?

    var favoritesIsHidden = true
    var recentGamesIsEmpty = true
    var recentGamesIsHidden : Bool {
        return recentGamesIsEmpty || !PVSettingsModel.shared.showRecentGames
    }

    var favoritesSection: Int {
        return favoritesIsHidden ? -1 : 0
    }

    var recentGamesSection: Int {
        if recentGamesIsHidden {
            return -1
        } else {
            return favoritesIsHidden ? 0 : 1
        }
    }

    var systemSectionsTokens = [String : NotificationToken]()
    var systemsSectionOffset: Int {
        var section = favoritesIsHidden ? 0 : 1
        section += recentGamesIsHidden ? 0 : 1
        return section
    }

    func addSectionToken(forSystem system: PVSystem) {
        let newToken = system.games.sorted(byKeyPath: #keyPath(PVGame.title), ascending: true).observe {[unowned self] (changes: RealmCollectionChange<Results<PVGame>>) in
            switch changes {
            case .initial:
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
                break
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UICollectionView
                guard let indexOfSystem = self.systems?.index(of: system) else {
                    return
                }
                let section = indexOfSystem + self.systemsSectionOffset
                self.handleUpdate(forSection: section, deletions: deletions, insertions: insertions, modifications: modifications, needsInsert: false)
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }

        systemSectionsTokens[system.identifier]?.invalidate()
        systemSectionsTokens[system.identifier] = newToken
    }

    func initRealmResultsStorage() {
        systems = PVSystem.all.sorted(byKeyPath: #keyPath(PVSystem.identifier)).filter("games.@count > 0")
        recentGames = PVRecentGame.all.filter("game != nil").sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
        favoriteGames = RomDatabase.sharedInstance.all(PVGame.self, where: "isFavorite", value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
    }

    func deinitRealmResultsStorage() {
        systems = nil
        recentGames = nil
        favoriteGames = nil
    }

    func registerForChange() {
        systemsToken = systems!.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let result):
                result.forEach { system in
                    self.addSectionToken(forSystem: system)
                }

                // Results are now populated and can be accessed without blocking the UI
                self.setUpGameLibrary()
            case .update(_, let deletions, let insertions, _):
                guard let collectionView = self.collectionView else {return}
                collectionView.performBatchUpdates({
                    let insertIndexes = insertions.map { $0 + self.systemsSectionOffset }
                    collectionView.insertSections(IndexSet(insertIndexes))

                    let delectIndexes = deletions.map { $0 + self.systemsSectionOffset }
                    collectionView.deleteSections(IndexSet(delectIndexes))
                    // Not needed since we have watchers per section
                    // collectionView.reloadSection(modifications.map{ return IndexPath(row: 0, section: $0 + systemsSectionOffset) })

                }, completion: { (success) in

                })
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }

        recentGamesToken = recentGames!.observe { [unowned self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial(let result):
                if !result.isEmpty {
                    self.recentGamesIsEmpty = false

//                    if !self.recentGamesIsHidden {
//                        let section = self.recentGamesSection
//                        collectionView.insertSections([section])
//                    }
                }

                self.collectionView?.reloadData()
            case .update(_, let deletions, let insertions, let modifications):
                let needsInsert = self.recentGamesIsHidden && !insertions.isEmpty
                let needsDelete = (self.recentGames?.isEmpty ?? true) && !deletions.isEmpty

                if self.recentGamesIsHidden {
                    self.recentGamesIsEmpty = needsDelete
                    return
                }

                let section = self.recentGamesSection > -1 ? self.recentGamesSection : 0

                if needsInsert {
                    ILOG("Needs insert, recentGamesHidden - false")
                    self.recentGamesIsEmpty = false
                }

                if needsDelete {
                    ILOG("Needs delete, recentGamesHidden - true")
                    self.recentGamesIsEmpty = true
                }

                // Query results have changed, so apply them to the UICollectionView
                self.handleUpdate(forSection: section, deletions: deletions, insertions: insertions, modifications: modifications, needsInsert: needsInsert, needsDelete: needsDelete)
                self.recentGamesIsEmpty = needsDelete
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }

        favoritesToken = favoriteGames!.observe { [unowned self] (changes: RealmCollectionChange) in
            let section = 0

            switch changes {
            case .initial(let result):
                if !result.isEmpty {
                    self.favoritesIsHidden = false
//                    collectionView.insertSections([section])
                }

                self.collectionView?.reloadData()
            case .update(_, let deletions, let insertions, let modifications):
                let needsInsert = self.favoritesIsHidden
                let needsDelete = self.favoriteGames?.isEmpty ?? false
                self.favoritesIsHidden = needsDelete

                // Query results have changed, so apply them to the UICollectionView
                self.handleUpdate(forSection: section, deletions: deletions, insertions: insertions, modifications: modifications, needsInsert: needsInsert, needsDelete: needsDelete)
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }
    }

    func handleUpdate(forSection section: Int, deletions: [Int], insertions: [Int], modifications: [Int], needsInsert: Bool = false, needsDelete: Bool = false) {
        guard let collectionView = collectionView else { return }
        collectionView.performBatchUpdates({
            if needsInsert {
                ILOG("Inserting section \(section)")
                collectionView.insertSections([section])
            }

            ILOG("Section \(section) updated with Insertions<\(insertions.count)> Mods<\(modifications.count)> Deletions<\(deletions.count)>")
            collectionView.insertItems(at: insertions.map({ return IndexPath(row: $0, section: section) }))
            collectionView.deleteItems(at: deletions.map({  return IndexPath(row: $0, section: section) }))
            collectionView.reloadItems(at: modifications.map({  return IndexPath(row: $0, section: section) }))

            if needsDelete {
                ILOG("Deleting section \(section)")
                collectionView.deleteSections([section])
            }
        }, completion: { (completed) in

        })
    }

    func unregisterForChange() {
        systemsToken?.invalidate()
        recentGamesToken?.invalidate()
        favoritesToken?.invalidate()
        systemSectionsTokens.values.forEach {$0.invalidate()}

        systemsToken = nil
        recentGamesToken = nil
        favoritesToken = nil
        systemSectionsTokens.removeAll()
    }

    func loadGameFromShortcut() {
        let appDelegate = UIApplication.shared.delegate as! PVAppDelegate

        if let shortcutMD5 = appDelegate.shortcutItemMD5 {
            loadGame(fromMD5: shortcutMD5)
            appDelegate.shortcutItemMD5 = nil
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let indexPaths = collectionView?.indexPathsForSelectedItems

        indexPaths?.forEach({ (indexPath) in
            (self.collectionView?.deselectItem(at: indexPath, animated: true))!
        })

        if (self.mustRefreshDataSource) {
            fetchGames()
            collectionView?.reloadData()
        }

        registerForChange()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForChange()
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
    }

    #if os(iOS)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    #endif

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "SettingsSegue") {
            #if os(iOS)
            if let settingsVC = (segue.destination as! UINavigationController).topViewController as? PVSettingsViewController {
                settingsVC.gameImporter = gameImporter
            }
            #endif
            // Refresh table view data source when back from settings
            mustRefreshDataSource = true
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
    @available(iOS 9.0, *)
    func showServer() {
        let ipURL = URL(string: PVWebServer.shared.urlString)
        let safariVC = SFSafariViewController(url: ipURL!, entersReaderIfAvailable: false)
        safariVC.delegate = self
        present(safariVC, animated: true) {() -> Void in }
    }

    @available(iOS 9.0, *)
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        // Load finished
    }

    // Dismiss and shut down web server
    @available(iOS 9.0, *)
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // Done button pressed
        navigationController?.popViewController(animated: true)
        PVWebServer.shared.stopServers()
    }

#endif
    // Show "Web Server Active" alert view
    func showServerActiveAlert() {
        let message = """
            Read Importing ROMs wiki…
            Upload/Download files at:


            """
        let alert = UIAlertController(title: "Web Server Active", message: message, preferredStyle: .alert)
        let ipField = UITextView(frame: CGRect(x: 20, y: 75, width: 231, height: 70))
        ipField.backgroundColor = UIColor.clear
        ipField.textAlignment = .center
        ipField.font = UIFont.systemFont(ofSize: 13)
        ipField.textColor = UIColor.gray
        let ipFieldText = """
            WebUI:  \(PVWebServer.shared.urlString)
            WebDav: \(PVWebServer.shared.webDavURLString)
            """
        ipField.text = ipFieldText
        ipField.isUserInteractionEnabled = false
        alert.view.addSubview(ipField)
        alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: {(_ action: UIAlertAction) -> Void in
            PVWebServer.shared.stopServers()
            if self.needToShowConflictsAlert {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    self.showConflictsAlert()
                })
            }
        }))

        if #available(iOS 9.0, *) {
            #if os(iOS)
                let viewAction = UIAlertAction(title: "View", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    self.showServer()
                })
                alert.addAction(viewAction)
            #endif
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {() -> Void in }
    }

    @IBAction func sortButtonTapped(_ sender: Any) {
        let optionsTableView = sortOptionsTableView
        let avc = UIViewController()
        avc.view = optionsTableView
        #if os(iOS)
        avc.modalPresentationStyle = .popover
//        avc.popoverPresentationController?.delegate = self
        avc.popoverPresentationController?.barButtonItem = sortButtonItem
        #endif
        avc.preferredContentSize = CGSize(width: 200, height: 200)

        present(avc, animated: true, completion: nil)

    }
    // MARK: - Filesystem Helpers
	@IBAction func getMoreROMs(_ sender: Any) {
        let reachability = Reachability.forLocalWiFi()
        reachability.startNotifier()
        let status: NetworkStatus = reachability.currentReachabilityStatus()
        if status != ReachableViaWiFi {
            let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a network to continue!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) {() -> Void in }
        } else {

            #if os(iOS)
            // connected via wifi, let's continue

            let actionSheet = UIAlertController(title: "Select Import Source", message: nil, preferredStyle: .actionSheet)

            actionSheet.addAction(UIAlertAction(title: "Cloud & Local Files", style: .default, handler: { (alert) in
                let extensions = ["com.provenance.rom", "com.pkware.zip-archive"]

                //        let documentMenu = UIDocumentMenuViewController(documentTypes: extensions, in: .import)
                //        documentMenu.delegate = self
                //        present(documentMenu, animated: true, completion: nil)

                let documentPicker = PVDocumentPickerViewController(documentTypes: extensions, in: .import)
                if #available(iOS 11.0, *) {
                    documentPicker.allowsMultipleSelection = true
                }
                documentPicker.delegate = self
                self.present(documentPicker, animated: true, completion: nil)
            }))

            actionSheet.addAction(UIAlertAction(title: "Web Server", style: .default, handler: { (alert) in
                self.startWebServer()
            }))

            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

			if let barButtonItem = sender as? UIBarButtonItem {
				actionSheet.popoverPresentationController?.barButtonItem = barButtonItem
			}
            present(actionSheet, animated: true, completion: nil)
            #else
                startWebServer()
            #endif
        }
    }

    func startWebServer() {
        // start web transfer service
        if PVWebServer.shared.startServers() {
            //show alert view
            self.showServerActiveAlert()
        } else {
            let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or that something isn't already running on required ports 80 & 81", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            }))
            self.present(alert, animated: true) {() -> Void in }
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
            try FileManager.default.createDirectory(at: PVEmulatorConfiguration.romsImportPath, withIntermediateDirectories: true, attributes: nil)} catch {
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

        let ignoredExtensions = ["jpg", "png", "gif"]
        let filteredContents = contents.filter { (url) -> Bool in
            let dbFile = url.path.lowercased().contains("realm")
            let ignoredExtension = ignoredExtensions.contains(url.pathExtension)
            return !dbFile && !ignoredExtension
        }

        filteredContents.forEach { path in
            var isDir: ObjCBool = false
            let exists: Bool = FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir)

            if exists && !isDir.boolValue && !path.path.lowercased().contains("realm") {
                let toPath = PVEmulatorConfiguration.romsImportPath.appendingPathComponent(path.lastPathComponent)

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
            let paths = try FileManager.default.contentsOfDirectory(at: PVEmulatorConfiguration.romsImportPath, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
            gameImporter?.startImport(forPaths: paths)
        } catch {
            ELOG("Couldn't get rom paths")
        }
    }

    fileprivate func showConflictsAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Oops!", message: "There was a conflict while importing your game.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Let's go fix it!", style: .default, handler: {[unowned self] (_ action: UIAlertAction) -> Void in
                self.needToShowConflictsAlert = false
                let conflictViewController = PVConflictViewController(gameImporter: self.gameImporter!)
                let navController = UINavigationController(rootViewController: conflictViewController)
                self.present(navController, animated: true) {() -> Void in }
            }))

            alert.addAction(UIAlertAction(title: "Nah, I'll do it later...", style: .cancel, handler: {[unowned self] (_ action: UIAlertAction) -> Void in self.needToShowConflictsAlert = false }))
            self.present(alert, animated: true) {() -> Void in }

            ILOG("Encountered conflicts, should be showing message")
        }
    }

    func setUpGameLibrary() {
        fetchGames()

        gameImporter = PVGameImporter(completionHandler: {[unowned self] (_ encounteredConflicts: Bool) -> Void in
            if encounteredConflicts {
                self.needToShowConflictsAlert = true
                self.showConflictsAlert()
            }
        })

        gameImporter.importStartedHandler = {(_ path: String) -> Void in
            DispatchQueue.main.async {
                if let hud = MBProgressHUD(for: self.view) ?? MBProgressHUD.showAdded(to: self.view, animated: true) {
                    hud.isUserInteractionEnabled = false
                    hud.mode = .indeterminate
                    let filename = URL(fileURLWithPath: path).lastPathComponent
                    hud.labelText = "Importing \(filename)"
                }
            }
        }

        gameImporter.finishedImportHandler = {(_ md5: String, _ modified: Bool) -> Void in
            // This callback is always called,
            // even if the started handler was not called because it didn't require a refresh.
            self.finishedImportingGame(withMD5: md5, modified: modified)
        }
        gameImporter.finishedArtworkHandler = {(_ url: String) -> Void in
        }

        do {
            let existingFiles = try FileManager.default.contentsOfDirectory(at: PVEmulatorConfiguration.romsImportPath, includingPropertiesForKeys: nil, options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants])
            if !existingFiles.isEmpty {
                gameImporter.startImport(forPaths: existingFiles)
            }
        } catch {
            ELOG("No existing ROM path at \(PVEmulatorConfiguration.romsImportPath.path)")
        }

        let labelMaker: (URL) -> String = { path in
            #if os(tvOS)
            return "Extracting Archive: \(path.lastPathComponent)"
            #else
            return "Extracting Archive..."
            #endif
        }

        watcher = PVDirectoryWatcher(directory: PVEmulatorConfiguration.romsImportPath, extractionStartedHandler: {(_ path: URL) -> Void in

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
        }, extractionUpdatedHandler: {(_ path: URL, _ entryNumber: Int, _ total: Int, _ progress: Float) -> Void in

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
        }, extractionCompleteHandler: {(_ paths: [URL]?) -> Void in
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
                self.gameImporter?.startImport(forPaths: paths)
            }
        })

        watcher?.startMonitoring()

        // Scan each Core direxctory and looks for ROMs in them
        let allSystems = PVSystem.all

        allSystems.forEach { system in
            let systemDir = system.romsDirectory
            //URL(fileURLWithPath: config.documentsPath).appendingPathComponent(systemID).path

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

            let systemRef = ThreadSafeReference(to: system)

            gameImporter.serialImportQueue.async {
                let realm = try! Realm()
                guard let system = realm.resolve(systemRef) else {
                    return // person was deleted
                }

                self.gameImporter.getRomInfoForFiles(atPaths: contents, userChosenSystem: system)
                if let completionHandler = self.gameImporter.completionHandler {
                    DispatchQueue.main.async {
                        completionHandler(self.gameImporter.encounteredConflicts)
                    }
                }
            }
        }
    }

    func fetchGames() {
        let database = RomDatabase.sharedInstance
        database.refresh()
        mustRefreshDataSource = false
    }

    func finishedImportingGame(withMD5 md5: String, modified: Bool) {

        DispatchQueue.main.async {
            if let hud = MBProgressHUD(for: self.view) {
                hud.hide(true)
            }
        }

        // Only refresh the whole collection if game was modified.
        if modified {
            fetchGames()
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        }

        #if os(iOS)
            // Add to split database
            if #available(iOS 9.0, *) {
                // TODO: Would be better to pass the PVGame direclty using threads.
                // https://realm.io/blog/obj-c-swift-2-2-thread-safe-reference-sort-properties-relationships/
                // let realm = try! Realm()
                // if let game = realm.resolve(gameRef) { }

                // Have to do the import here so the images are ready
                if let game = RomDatabase.sharedInstance.all(PVGame.self, where: #keyPath(PVGame.md5Hash), value: md5).first {
                    let spotlightItem = CSSearchableItem(uniqueIdentifier: game.spotlightUniqueIdentifier, domainIdentifier: "com.provenance-emu.game", attributeSet: game.spotlightContentSet)
                    CSSearchableIndex.default().indexSearchableItems([spotlightItem]) { error in
                        if let error = error {
                            ELOG("indexing error: \(error)")
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

    @objc func handleCacheEmptied(_ notification: NotificationCenter) {

        DispatchQueue.global(qos: .default).async(execute: {() -> Void in
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

            DispatchQueue.main.async(execute: {() -> Void in
                RomDatabase.sharedInstance.refresh()
                self.fetchGames()
            })
        })
    }

    @objc func handleArchiveInflationFailed(_ note: Notification) {
        let alert = UIAlertController(title: "Failed to extract archive", message: "There was a problem extracting the archive. Perhaps the download was corrupt? Try downloading it again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true) {() -> Void in }
    }

    @objc func handleRefreshLibrary(_ note: Notification) {
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

        fetchGames()
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
        setUpGameLibrary()
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
            load(mostRecentGame)
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

            guard let game: PVGame = self.game(at: indexPath) else {
                ELOG("No game at inde path \(indexPath)")
                return
            }

            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if traitCollection.userInterfaceIdiom == .pad {
                let cell: UICollectionViewCell? = collectionView?.cellForItem(at: indexPath)
                actionSheet.popoverPresentationController?.sourceView = cell
                actionSheet.popoverPresentationController?.sourceRect = (collectionView?.layoutAttributesForItem(at: indexPath)?.bounds ?? CGRect.zero)
            }

            actionSheet.addAction(UIAlertAction(title: "Game Info", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.moreInfo(for: game)
            }))

            actionSheet.addAction(UIAlertAction(title: "Toggle Favorite", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.toggleFavorite(for: game)
            }))

            actionSheet.addAction(UIAlertAction(title: "Rename", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.renameGame(game)
            }))
#if os(iOS)

    #if DEBUG
            actionSheet.addAction(UIAlertAction(title: "Copy MD5 URL", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                let md5URL = "provenance://open?md5=\(game.md5Hash)"
                UIPasteboard.general.string = md5URL
            }))
    #endif
            actionSheet.addAction(UIAlertAction(title: "Choose Custom Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.chooseCustomArtwork(for: game)
            }))

            actionSheet.addAction(UIAlertAction(title: "Paste Custom Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.pasteCustomArtwork(for: game)
            }))

            if !game.originalArtworkURL.isEmpty && game.originalArtworkURL != game.customArtworkURL {
                actionSheet.addAction(UIAlertAction(title: "Restore Original Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
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
            actionSheet.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: {(_ action: UIAlertAction) -> Void in
                let alert = UIAlertController(title: "Delete \(game.title)", message: "Any save states and battery saves will also be deleted, are you sure?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: {(_ action: UIAlertAction) -> Void in
                    // Delete from Realm
                    self.delete(game: game)
                }))
                alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                self.present(alert, animated: true) {() -> Void in }
            }))
            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(actionSheet, animated: true) {() -> Void in }
        }
    }

    func toggleFavorite(for game: PVGame) {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.isFavorite = !game.isFavorite
            }

            register3DTouchShortcuts()

            fetchGames()

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
#if os(tvOS)
        let alert = UIAlertController(title: "Rename", message: "Enter a new name for \(game.title)", preferredStyle: .alert)
        alert.addTextField(configurationHandler: {(_ textField: UITextField) -> Void in
            textField.placeholder = game.title
        })

    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            if let title = alert.textFields?.first?.text {
                self.renameGame(game, toTitle: title)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true) {() -> Void in }
#else
        // TODO: There's a bug here that you'll never see the text input if a hardware keyboard is attached.
        // Maybe just use the same code as atV - jm
        gameToRename = game
        renameOverlay = UIView(frame: UIScreen.main.bounds)
        renameOverlay?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        renameOverlay?.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
        renameOverlay?.alpha = 0.0
        view.addSubview(renameOverlay!)

        UIView.animate(withDuration: 0.3, delay: 0.0, options: .beginFromCurrentState, animations: {
            self.renameOverlay?.alpha = 1.0
        }, completion: nil)

        renameToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: 44))
        renameToolbar?.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        renameToolbar?.barStyle = .black
        renameTextField = UITextField(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width - 24, height: 30))
        renameTextField?.autoresizingMask = .flexibleWidth
        renameTextField?.borderStyle = .roundedRect
        renameTextField?.placeholder = game.title
        renameTextField?.text = game.title
        renameTextField?.keyboardAppearance = .alert
        renameTextField?.returnKeyType = .done
        renameTextField?.delegate = self
        let textFieldItem = UIBarButtonItem(customView: renameTextField!)
        renameToolbar?.items = [textFieldItem]
        renameToolbar?.setOriginY(view.bounds.size.height)
        renameOverlay?.addSubview(renameToolbar!)
        navigationController?.view.addSubview(renameOverlay!)
        NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.keyboardWillShow(_:)), name: .UIKeyboardWillShow, object: nil)
        renameTextField?.becomeFirstResponder()
        renameTextField?.selectAll(nil)
#endif
    }

    #if os(iOS)
    func doneRenaming(_ sender: Any) {
        defer {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .beginFromCurrentState, animations: {() -> Void in
                self.renameOverlay?.alpha = 0.0
            }, completion: {(_ finished: Bool) -> Void in
                self.renameOverlay?.removeFromSuperview()
                self.renameOverlay = nil
            })
            NotificationCenter.default.addObserver(self, selector: #selector(PVGameLibraryViewController.keyboardWillHide(_:)), name: .UIKeyboardWillHide, object: nil)
            renameTextField?.resignFirstResponder()
        }

        guard let newTitle = renameTextField?.text, let gameToRename = gameToRename else {
            ELOG("No rename textor game")
            return
        }

        renameGame(gameToRename, toTitle: newTitle)
        self.gameToRename = nil
    }

    #endif
    func renameGame(_ game: PVGame, toTitle title: String) {
        if title.count != 0 {
            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    game.title = title
                }

                fetchGames()
                collectionView?.reloadData()
            } catch {
                ELOG("Failed to rename game \(game.title)\n\(error.localizedDescription)")
            }
        }
    }

    func delete(game: PVGame) {
        let romURL = PVEmulatorConfiguration.path(forGame: game)

        if !game.customArtworkURL.isEmpty {
            do {
                try PVMediaCache.deleteImage(forKey: game.customArtworkURL)
            } catch {
                ELOG("Failed to delete image \(game.customArtworkURL)")
            }
        }

        let savesPath = PVEmulatorConfiguration.saveStatePath(forGame: game)
        do {
            try FileManager.default.removeItem(at: savesPath)
        } catch {
            WLOG("Unable to delete save states at path: \(savesPath.path) because: \(error.localizedDescription)")
        }

        let batteryPath = PVEmulatorConfiguration.batterySavesPath(forGame: game)
        do {
            try FileManager.default.removeItem(at: batteryPath)
        } catch {
            WLOG("Unable to delete battery states at path: \(batteryPath.path) because: \(error.localizedDescription)")
        }

        do {
            try FileManager.default.removeItem(at: romURL)
        } catch {
            WLOG("Unable to delete rom at path: \(romURL.path) because: \(error.localizedDescription)")
        }

        // Delete from Spotlight search
        #if os(iOS)
        if #available(iOS 9.0, *) {
           deleteFromSpotlight(game: game)
        }
        #endif

        game.saveStates.forEach { try! $0.delete() }
        game.recentPlays.forEach { try! $0.delete() }

        deleteRelatedFilesGame(game)
        try? game.delete()
    }

    func deleteRelatedFilesGame(_ game: PVGame) {

        guard let system = game.system else {
            ELOG("Game \(game.title) belongs to an unknown system \(game.systemIdentifier)")
            return
        }

        let romDirectory = system.romsDirectory
        let relatedFileName: String = game.url.deletingPathExtension().lastPathComponent

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: romDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        } catch {
            ELOG("scanning \(romDirectory) \(error.localizedDescription)")
            return
        }

        let matchingFiles = contents.filter {
            let filename = $0.deletingPathExtension().lastPathComponent
            return filename.contains(relatedFileName)
        }

        matchingFiles.forEach {
            let file = romDirectory.appendingPathComponent( $0.lastPathComponent, isDirectory: false)
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                ELOG("Failed to remove item \(file.path).\n \(error.localizedDescription)")
            }
        }
    }

    #if os(iOS)
    func chooseCustomArtwork(for game: PVGame) {
        weak var weakSelf: PVGameLibraryViewController? = self
        let imagePickerActionSheet = UIActionSheet()
        let cameraIsAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)
        let photoLibraryIsAvaialble: Bool = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
        let cameraAction: PVUIActionSheetAction = {() -> Void in
                self.gameForCustomArt = game
                let pickerController = UIImagePickerController()
                pickerController.delegate = weakSelf
                pickerController.allowsEditing = false
                pickerController.sourceType = .camera
                self.present(pickerController, animated: true) {() -> Void in }
            }
        let libraryAction: PVUIActionSheetAction = {() -> Void in
                self.gameForCustomArt = game
                let pickerController = UIImagePickerController()
                pickerController.delegate = weakSelf
                pickerController.allowsEditing = false
                pickerController.sourceType = .photoLibrary
                self.present(pickerController, animated: true) {() -> Void in }
            }
        assetsLibrary = ALAssetsLibrary()
        assetsLibrary?.enumerateGroups(withTypes: ALAssetsGroupType(ALAssetsGroupSavedPhotos), using: { (group, stop) in
            guard let group = group else {
                return
            }

            group.setAssetsFilter(ALAssetsFilter.allPhotos())
            let index: Int = group.numberOfAssets() - 1
            VLOG("Group: \(group)")
            if index >= 0 {
//                var indexPathsToUpdate = [IndexPath]()

                group.enumerateAssets(at: IndexSet(integer: index), options: [], using: { (result, index, stop) in
                    if let rep: ALAssetRepresentation = result?.defaultRepresentation() {
                        imagePickerActionSheet.pv_addButton(withTitle: "Use Last Photo Taken", action: {() -> Void in
                            let orientation : UIImageOrientation = UIImageOrientation(rawValue: rep.orientation().rawValue)!

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
                self.present(alert, animated: true) {() -> Void in }
            }
        }, failureBlock: { (error) in
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
            self.searchResults = RomDatabase.sharedInstance.all(PVGame.self, filter: predicate).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        }

        collectionView?.reloadData()
    }

    func clearSearch() {
        searchField?.text = nil
        searchResults = nil
        collectionView?.reloadData()
    }

// MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if searchResults != nil {
            return 1
        } else {
            let count = systemsSectionOffset + (systems?.count ?? 0)
            ILOG("Sections : \(count)")
            return count
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let searchResults = searchResults {
            return Int(searchResults.count)
        } else {
            if section >= systemsSectionOffset {
                let sectionNumber = section - systemsSectionOffset
                return systems?[sectionNumber].games.count ?? 0
            } else if section == favoritesSection {
                return favoriteGames?.count ?? 0
            } else if section == recentGamesSection {
                return recentGames?.count ?? 0
            } else {
                fatalError("Shouldn't be here")
            }
        }
    }

    func indexTitles(for collectionView: UICollectionView) -> [String]? {
        if searchResults != nil {
            return nil
        } else {
            return sectionTitles
        }
    }

    func collectionView(_ collectionView: UICollectionView, indexPathForIndexTitle title: String, at index: Int) -> IndexPath {
        return IndexPath(row: 0, section: index)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = self.collectionView?.dequeueReusableCell(withReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier, for: indexPath) as? PVGameLibraryCollectionViewCell else {
            fatalError("Couldn't create cell of type PVGameLibraryCollectionViewCellIdentifier")
        }

        var game: PVGame? = nil
        if let searchResults = searchResults {
            game = searchResults[indexPath.item]
        } else {
            game = self.game(at: indexPath)
        }

        cell.game = game

        return cell
    }

    func game(at indexPath: IndexPath) -> PVGame? {
        var game: PVGame? = nil
        if let searchResults = searchResults {
            game = Array(searchResults)[indexPath.item]
        } else {
            let section = indexPath.section
            let row = indexPath.row

            if section == favoritesSection {
                game = favoriteGames?[row]
            } else if section == recentGamesSection {
                game = recentGames?[row].game
            } else if let system = systems?[section - systemsSectionOffset] {
                game = system.games.sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)[row]
            }
        }

        return game
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if (kind == UICollectionElementKindSectionHeader) {
            var headerView: PVGameLibrarySectionHeaderView? = nil
            let title = searchResults != nil ? "Search Results" : sectionTitles[indexPath.section]

            headerView = self.collectionView?.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier, for: indexPath) as? PVGameLibrarySectionHeaderView
            headerView?.titleLabel.text = title

            if let headerView = headerView {
                return headerView
            } else {
                fatalError("Couldn't create header view")
            }
        } else if kind == UICollectionElementKindSectionFooter {
            let footerView = self.collectionView!.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PVGameLibraryFooterViewIdentifier, for: indexPath) as! PVGameLibrarySectionFooterView
            return footerView
        }

        fatalError("Don't support type \(kind)")
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
#if os(tvOS)
        return CGSize(width: view.bounds.size.width, height: 90)
#else
        return CGSize(width: view.bounds.size.width, height: 40)
#endif
    }

// MARK: - Text Field and Keyboard Delegate
#if os(iOS)
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField != searchField {
            doneRenaming(self)
        } else {
            textField.resignFirstResponder()
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField == searchField {
            textField.perform(#selector(self.resignFirstResponder), with: nil, afterDelay: 0.0)
        }
        return true
    }

#endif
    @objc func handleTextFieldDidChange(_ notification: Notification) {
        if let text = searchField?.text, !text.isEmpty {
            searchLibrary(text)
        } else {
            clearSearch()
        }
    }

#if os(iOS)
    @objc func keyboardWillShow(_ note: Notification) {
        guard let userInfo = note.userInfo else {
            return
        }

        var keyboardEndFrame: CGRect = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        keyboardEndFrame = view.window!.convert(keyboardEndFrame, to: navigationController!.view)
        let animationDuration = CGFloat((userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).floatValue)
        let animationCurve = (userInfo[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).uintValue

        UIView.animate(withDuration: TimeInterval(animationDuration), delay: 0.0, options: [.beginFromCurrentState, UIViewAnimationOptions(rawValue: animationCurve)], animations: {() -> Void in
            self.renameToolbar?.setOriginY(keyboardEndFrame.origin.y - (self.renameToolbar?.frame.size.height ?? 0))
        }, completion: {(_ finished: Bool) -> Void in
        })
    }

#endif
#if os(iOS)
    @objc func keyboardWillHide(_ note: Notification) {
        guard let userInfo = note.userInfo else {
            return
        }

        let animationDuration = CGFloat((userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).floatValue)
        let animationCurve = (userInfo[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).uintValue

        UIView.animate(withDuration: TimeInterval(animationDuration), delay: 0.0, options: [.beginFromCurrentState, UIViewAnimationOptions(rawValue: animationCurve)], animations: {() -> Void in
            self.renameToolbar?.setOriginY(UIScreen.main.bounds.size.height)
        }, completion: {(_ finished: Bool) -> Void in
            self.renameToolbar?.removeFromSuperview()
            self.renameToolbar = nil
            self.renameTextField = nil
        })
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
    }
#endif
// MARK: - Image Picker Delegate
#if os(iOS)
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        guard let gameForCustomArt = self.gameForCustomArt else {
            ELOG("gameForCustomArt pointer was null.")
            return
        }

        dismiss(animated: true) {() -> Void in }
        let image = info[UIImagePickerControllerOriginalImage] as? UIImage
        if let image = image, let scaledImage = image.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)), let imageData = UIImagePNGRepresentation(scaledImage) {

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

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true) {() -> Void in }
        gameForCustomArt = nil
    }

#endif
// MARK: - Keyboard actions
    public override var keyCommands: [UIKeyCommand]? {
        if #available(iOS 9.0, *) {
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
            let findCommand = UIKeyCommand(input: "f", modifierFlags: [.command, .alternate], action: #selector(PVGameLibraryViewController.selectSearch(_:)), discoverabilityTitle: "Find…")
            sectionCommands.append(findCommand)
            return sectionCommands
        } else {
            return nil
        }
    }

    @objc func selectSearch(_ sender: UIKeyCommand) {
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
}

// MARK: Database Migration
extension PVGameLibraryViewController {
    @objc public func databaseMigrationStarted(_ notification: Notification) {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)!
        hud.isUserInteractionEnabled = false
        hud.mode = .indeterminate
        hud.labelText = "Migrating Game Library"
        hud.detailsLabelText = "Please be patient, this may take a while..."
    }

    @objc public func databaseMigrationFinished(_ notification: Notification) {
        MBProgressHUD.hide(for: view!, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension PVGameLibraryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        #if os(tvOS)
            let game = self.game(at: indexPath)!
            let boxartSize = CGSize(width: CellWidth, height: CellWidth / game.boxartAspectRatio.rawValue)
            return PVGameLibraryCollectionViewCell.cellSize(forImageSize: boxartSize)
        #else
            if PVSettingsModel.shared.showGameTitles {
                return CGSize(width: 100, height: 144)
            }
            return CGSize(width: 100, height: 100)
        #endif
    }

    #if os(tvOS)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 88
    }
    #endif

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        #if os(tvOS)
            return 50
        #else
            return 5.0
        #endif
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        #if os(tvOS)
            return UIEdgeInsets(top: 40, left: 0, bottom: 120, right: 0)
        #else
            return UIEdgeInsets(top: section == 0 ? 5 : 15, left: 10, bottom: 5, right: 10)
        #endif
    }
}

// MARK: - UICollectionViewDataSource
extension PVGameLibraryViewController: UICollectionViewDataSource {

}

// MARK: - UICollectionViewDelegate
extension PVGameLibraryViewController: UICollectionViewDelegate {
    #if os(tvOS)
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
    return true
    }

    func collectionView(_ collectionView: UICollectionView, shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
    return true
    }

    #endif

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let game = self.game(at: indexPath) {
            load(game)
        } else {
            let alert = UIAlertController(title: "Failed to find game", message: "No game found for selected cell", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
}

// MARK: - Spotlight
#if os(iOS)
@available(iOS 9.0, *)
extension PVGameLibraryViewController {
    private func deleteFromSpotlight(game: PVGame) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [game.spotlightUniqueIdentifier], completionHandler: { (error) in
            if let error = error {
                print("Error deleting game spotlight item: \(error)")
            } else {
                print("Game indexing deleted.")
            }
        })
    }

    private func deleteAllGamesFromSpotlight() {
        CSSearchableIndex.default().deleteAllSearchableItems { (error) in
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
        documentPicker.popoverPresentationController?.sourceView = self.view
        present(documentMenu, animated: true, completion: nil)
    }

    func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController) {
        ILOG("DocumentMenu was cancelled")
    }
}

// MARK: UIDocumentPickerDelegate
extension PVGameLibraryViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let sortedUrls = PVEmulatorConfiguration.sortImportUURLs(urls: urls)

        let importPath = PVEmulatorConfiguration.romsImportPath

        sortedUrls.forEach { (url) in
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Doesn't seem we need access in dev builds?
            _ = url.startAccessingSecurityScopedResource()

//            if access {
                let fileName = url.lastPathComponent
                let destination = importPath.appendingPathComponent(fileName, isDirectory: false)
                do {
                    // Since we're in UIDocumentPickerModeImport, these URLs are temporary URLs so a move is what we want
                    try FileManager.default.moveItem(at: url, to: destination)
                } catch {
                    ELOG("Failed to move file from \(url.path) to \(destination.path)")
                }
//            } else {
//                ELOG("Wasn't granded access to \(url.path)")
//            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        ILOG("Document picker was cancelled")
    }
}
#endif

#if os(iOS)
    @available(iOS 9.0, *)
    extension PVGameLibraryViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {

        let moreInfoGamePageVC = UIStoryboard(name: "Provenance", bundle: nil).instantiateViewController(withIdentifier: "gameMoreInfoPageVC") as! GameMoreInfoPageViewController
        moreInfoGamePageVC.setViewControllers([viewControllerToCommit], direction: .forward, animated: false, completion: nil)
        navigationController!.show(moreInfoGamePageVC, sender: self)

//        navigationController?.show(viewControllerToCommit, sender: self)
//        (viewControllerToCommit as! PVGameMoreInfoViewController).navigationItem.leftBarButtonItem =  UIBarButtonItem(barButtonSystemItem: .done, target: self, action: nil)
//        let newNav = UINavigationController(rootViewController: viewControllerToCommit)
//        present(newNav, animated: true, completion: nil)
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        if let indexPath = collectionView!.indexPathForItem(at: location), let cellAttributes = collectionView!.layoutAttributesForItem(at: indexPath) {
            //This will show the cell clearly and blur the rest of the screen for our peek.
            previewingContext.sourceRect = cellAttributes.frame

            let storyBoard = UIStoryboard(name: "Provenance", bundle: nil)
            let moreInfoViewContrller = storyBoard.instantiateViewController(withIdentifier: "gameMoreInfoVC") as! PVGameMoreInfoViewController
            moreInfoViewContrller.game = game(at: indexPath)
            moreInfoViewContrller.showsPlayButton = true
            return moreInfoViewContrller
        }
        return nil
    }
}

extension PVGameLibraryViewController: UIImagePickerControllerDelegate, SFSafariViewControllerDelegate {

}
#endif

extension PVGameLibraryViewController: UISearchControllerDelegate {
    func didDismissSearchController(_ searchController: UISearchController) {
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

class PVGameLibraryCollectionFlowLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        #if os(iOS)
        if #available(iOS 9.0, *) {
            self.sectionHeadersPinToVisibleBounds = true
        }
        #endif
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PVGameLibraryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 3 : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sortCell", for: indexPath)

        let sortOption = SortOptions.optionForRow(UInt(indexPath.row))

        cell.textLabel?.text = sortOption.rawValue
        cell.accessoryType = sortOption == currentSort ? .checkmark : .none
        return cell
    }
}

extension PVGameLibraryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentSort = SortOptions.optionForRow(UInt(indexPath.row))
        tableView.reloadData()
        dismiss(animated: true, completion: nil)
    }
}

#if os(iOS)
extension PVGameLibraryViewController: UIPopoverControllerDelegate {

}
#endif
