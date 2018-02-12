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
import RealmSwift

let PVGameLibraryHeaderViewIdentifier = "PVGameLibraryHeaderView"
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

#if os(tvOS)
private let CellWidth: CGFloat = 308.0
#else
let USE_IOS_11_SEARCHBAR = 0
#endif

class PVGameLibraryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, UINavigationControllerDelegate {

    var watcher: PVDirectoryWatcher?
    var coverArtWatcher: PVDirectoryWatcher?
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
    var gamesInSections = [String: [PVLibraryEntry]]()
    var sectionInfo = [String]()
    var searchResults: Results<PVGame>?
    @IBOutlet weak var searchField: UITextField!
    var isInitialAppearance = false
    var isMustRefreshDataSource = false

    
    typealias BiosDictionary = [String: String]

// MARK: - Lifecycle
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // A hack to make sure the main thread instance lives first
        let _ = RomDatabase.sharedInstance

        UserDefaults.standard.register(defaults: [PVRequiresMigrationKey: true])
#if USE_IOS_11_SEARCHBAR
#if os(iOS)
        if #available(iOS 11.0, *) {
            // Hide the pre iOS 11 search bar
            navigationItem.titleView = nil
            // Navigation bar large titles
            navigationController?.navigationBar.prefersLargeTitles = false
            navigationItem.title = nil
                // Create a search contorller
            let searchController = UISearchController(searchResultsController: nil)
            searchController.searchBar.placeholder = "Search"
            searchController.searchResultsUpdater = self
            navigationItem.hidesSearchBarWhenScrolling = true
            navigationItem.searchController = searchController
        }
#endif
#endif
    
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func handleAppDidBecomeActive(_ note: Notification) {
        loadGameFromShortcut()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isInitialAppearance = true
        definesPresentationContext = true
        
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
        
        PVEmulatorConfiguration.sharedInstance()
        //load the config file
        title = "Library"
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsetsMake(20, 0, 20, 0)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView?.dataSource = self
        collectionView?.delegate = self
        collectionView?.bounces = true
        collectionView?.alwaysBounceVertical = true
        collectionView?.delaysContentTouches = false
        collectionView?.keyboardDismissMode = .interactive
        collectionView?.register(PVGameLibrarySectionHeaderView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier)
#if os(tvOS)
        collectionView?.contentInset = UIEdgeInsetsMake(40, 80, 40, 80)
#endif
        view.addSubview(collectionView!)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(PVGameLibraryViewController.longPressRecognized(_:)))
        collectionView?.addGestureRecognizer(longPressRecognizer)
        collectionView?.register(PVGameLibraryCollectionViewCell.self, forCellWithReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier)
        if UserDefaults.standard.bool(forKey: PVRequiresMigrationKey) {
            migrateLibrary()
        }
        else {
            setUpGameLibrary()
        }
        loadGameFromShortcut()
        becomeFirstResponder()
    }

    func loadGameFromShortcut() {
        let appDelegate = UIApplication.shared.delegate as! PVAppDelegate
        
        if let shortcutMD5 = appDelegate.shortcutItemMD5 {
            loadRecentGame(fromShortcut: shortcutMD5)
            appDelegate.shortcutItemMD5 = nil
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let indexPaths = collectionView?.indexPathsForSelectedItems
        
        indexPaths?.forEach({ (indexPath) in
            (self.collectionView?.deselectItem(at: indexPath, animated: true))!
        })

        //    if (self.mustRefreshDataSource) {
        fetchGames()
        collectionView?.reloadData()
        //    }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PVControllerManager.shared()
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
            isMustRefreshDataSource = true
        }
    }

#if os(iOS)
    // Show web server (stays on)
    @available(iOS 9.0, *)
    func showServer() {
        let ipURL = URL(string: PVWebServer.sharedInstance().urlString)
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
        PVWebServer.sharedInstance().stopServers()
    }

#endif
    // Show "Web Server Active" alert view
    func showServerActiveAlert() {
        let message = """
            Upload/Download ROMs,
            saves and cover art at:
            
            """
        let alert = UIAlertController(title: "Web Server Active", message: message, preferredStyle: .alert)
        let ipField = UITextView(frame: CGRect(x: 20, y: 71, width: 231, height: 70))
        ipField.backgroundColor = UIColor.clear
        ipField.textAlignment = .center
        ipField.font = UIFont.systemFont(ofSize: 13)
        ipField.textColor = UIColor.gray
        let ipFieldText = """
            \(PVWebServer.sharedInstance().urlString)
            WebDav: \(PVWebServer.sharedInstance().webDavURLString)
            """
        ipField.text = ipFieldText
        ipField.isUserInteractionEnabled = false
        alert.view.addSubview(ipField)
        let importNote = UITextView(frame: CGRect(x: 2, y: 160, width: 267, height: 44))
        importNote.isUserInteractionEnabled = false
        importNote.font = UIFont.boldSystemFont(ofSize: 12)
        importNote.textColor = UIColor.white
        importNote.textAlignment = .center
        importNote.backgroundColor = UIColor(white: 0.2, alpha: 0.3)
        importNote.text = """
        Check the wiki for information
        about Importing ROMs.
        """
        importNote.layer.shadowOpacity = 0.8
        importNote.layer.shadowRadius = 3.0
        importNote.layer.cornerRadius = 8.0
        importNote.layer.shadowColor = UIColor(white: 0.2, alpha: 0.7).cgColor
        importNote.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        alert.view.addSubview(importNote)
        alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: {(_ action: UIAlertAction) -> Void in
            PVWebServer.sharedInstance().stopServers()
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

// MARK: - Filesystem Helpers
    @IBAction func getMoreROMs() {
        let reachability = Reachability.forInternetConnection()
        reachability.startNotifier()
        let status: NetworkStatus = reachability.currentReachabilityStatus()
        if status != ReachableViaWiFi {
            let alert = UIAlertController(title: "Unable to start web server!", message: "Your device needs to be connected to a network to continue!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) {() -> Void in }
        }
        else {
            // connected via wifi, let's continue
            // start web transfer service
            if PVWebServer.sharedInstance().startServers() {
                //show alert view
                showServerActiveAlert()
            }
            else {
                let alert = UIAlertController(title: "Unable to start web server!", message: "Check your network connection or that something isn't already running on required ports 80 & 81", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                }))
                present(alert, animated: true) {() -> Void in }
            }
        }
    }

// MARK: - Game Library Management
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


        let config = PVEmulatorConfiguration.sharedInstance()

        do {
            try FileManager.default.createDirectory(atPath: config.romsPath, withIntermediateDirectories: true, attributes: nil)} catch {
                ELOG("Unable to create roms directory because \(error.localizedDescription)")
                // dunno what else can be done if this fails
                return
        }

        let contents = try! FileManager.default.contentsOfDirectory(atPath: config.documentsPath)
//        if contents == nil {
//            DLOG("Unable to get contents of documents because %@", error?.localizedDescription)
//        }
        
        for path: String in contents {
            let fullPath: String = URL(fileURLWithPath: config.documentsPath).appendingPathComponent(path).path
            var isDir : ObjCBool = false
            let exists: Bool = FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)
            if exists && !isDir.boolValue && !path.lowercased().contains("realm") {
                let toPath = URL(fileURLWithPath: config.romsPath).appendingPathComponent(path).path
                do {
                    try FileManager.default.moveItem(atPath: fullPath, toPath: toPath)
                } catch {
                    ELOG("Unable to move \(fullPath) to \(toPath) because \(error.localizedDescription)")
                }
            }
        }
        hud.hide(true)
        UserDefaults.standard.set(false, forKey: PVRequiresMigrationKey)
        setUpGameLibrary()
        
        do {
            let paths = try FileManager.default.contentsOfDirectory(atPath: config.romsPath)
            gameImporter?.startImport(forPaths: paths)
        } catch {
            ELOG("Couldn't get rom paths")
        }
    }

    func setUpGameLibrary() {
        fetchGames()

        let config = PVEmulatorConfiguration.sharedInstance()
        
        gameImporter = PVGameImporter(completionHandler: {[unowned self] (_ encounteredConflicts: Bool) -> Void in
            if encounteredConflicts {
                let alert = UIAlertController(title: "Oops!", message: "There was a conflict while importing your game.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Let's go fix it!", style: .default, handler: {[unowned self] (_ action: UIAlertAction) -> Void in
                    let conflictViewController = PVConflictViewController(gameImporter: self.gameImporter!)
                    let navController = UINavigationController(rootViewController: conflictViewController)
                    self.present(navController, animated: true) {() -> Void in }
                }))
                alert.addAction(UIAlertAction(title: "Nah, I'll do it later...", style: .cancel, handler: nil))
                self.present(alert, animated: true) {() -> Void in }
                
                ILOG("Encountered conflicts, should be showing message")
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
            self.finishedDownloadingArtwork(forURL: url)
        }
        
        do {
            let existingFiles = try FileManager.default.contentsOfDirectory(atPath: config.romsPath)
            gameImporter.startImport(forPaths: existingFiles)
        } catch {
            ELOG("No existing ROM path at \(config.romsPath)")
        }
        
        watcher = PVDirectoryWatcher(path: config.romsPath, extractionStartedHandler: {(_ path: String) -> Void in
            
            DispatchQueue.main.async {
                guard let hud = MBProgressHUD(for: self.view) ?? MBProgressHUD.showAdded(to: self.view, animated: true) else {
                    WLOG("No hud")
                    return
                }
                
                hud.show(true)
                hud.isUserInteractionEnabled = false
                hud.mode = .annularDeterminate
                hud.progress = 0
                #if os(tvOS)
                    let lastPathComponent = URL(fileURLWithPath: path).lastPathComponent
                    let label = "Extracting Archive: \(lastPathComponent)"
                #else
                    let label = "Extracting Archive..."
                #endif
                hud.labelText = label
            }
        }, extractionUpdatedHandler: {(_ path: String, _ entryNumber: Int, _ total: Int, _ progress: Float) -> Void in
            
            DispatchQueue.main.async {
                guard let hud = MBProgressHUD(for: self.view) else {
                    WLOG("No hud")
                    return
                }
                hud.isUserInteractionEnabled = false
                hud.mode = .annularDeterminate
                hud.progress = progress
                #if os(tvOS)
                    let lastPathComponent = URL(fileURLWithPath: path).lastPathComponent
                    let label = "Extracting Archive: \(lastPathComponent)"
                #else
                    let label = "Extracting Archive..."
                #endif
                hud.labelText = label
            }
        }, extractionCompleteHandler: {(_ paths: [String]) -> Void in
            DispatchQueue.main.async {
                if let hud = MBProgressHUD(for: self.view) {
                    hud.isUserInteractionEnabled = false
                    hud.mode = .annularDeterminate
                    hud.progress = 1
                    hud.labelText = "Extraction Complete!"
                    hud.hide(true, afterDelay: 0.5)
                } else {
                    WLOG("No hud")
                }
            }
            
            self.gameImporter?.startImport(forPaths: paths)
        })
        watcher?.startMonitoring()
        coverArtWatcher = PVDirectoryWatcher(path: config.coverArtPath, extractionStartedHandler: {(_ path: String) -> Void in
            
            DispatchQueue.main.async {
                guard let hud = MBProgressHUD(for: self.view) ?? MBProgressHUD.showAdded(to: self.view, animated: true) else {
                    WLOG("No hud")
                    return
                }

                hud.isUserInteractionEnabled = false
                hud.mode = .annularDeterminate
                hud.progress = 0
                hud.labelText = "Extracting Archive…"
            }
        }, extractionUpdatedHandler: {(_ path: String, _ entryNumber: Int, _ total: Int, _ progress: Float) -> Void in
            DispatchQueue.main.async {
                if let hud = MBProgressHUD(for: self.view) {
                    hud.progress = progress
                } else {
                    WLOG("No hud")
                }
            }
        }, extractionCompleteHandler: {(_ paths: [String]) -> Void in
            
            DispatchQueue.main.async {
                guard let hud = MBProgressHUD(for: self.view) else {
                    WLOG("No hud")
                    return
                }
                hud.progress = 1
                hud.labelText = "Extraction Complete!"
                hud.hide(true, afterDelay: 0.5)
            }
            
            var allIndexPaths = [IndexPath]()
            
            for imageFilepath: String in paths {
                let imageFullPath: String = URL(fileURLWithPath: config.coverArtPath).appendingPathComponent(imageFilepath).path
                if let game = PVGameImporter.importArtwork(fromPath: imageFullPath) {
                    let indexPaths = self.indexPathsForGame(withMD5Hash: game.md5Hash)
                    allIndexPaths.append(contentsOf: indexPaths)
                } else {
                    DLOG("No game for artwork \(imageFullPath)")
                }
            }
            
            DispatchQueue.main.async {
                self.collectionView?.reloadItems(at: allIndexPaths)
            }
        })
        
        coverArtWatcher?.startMonitoring()
        let systems = PVEmulatorConfiguration.sharedInstance().availableSystemIdentifiers
        for systemID: String in systems {
            let systemDir: String = URL(fileURLWithPath: config.documentsPath).appendingPathComponent(systemID).path
            if FileManager.default.fileExists(atPath: systemDir) {

                if let contents = try? FileManager.default.contentsOfDirectory(atPath: systemDir) {
                    gameImporter.serialImportQueue.async {
                        self.gameImporter.getRomInfoForFiles(atPaths: contents, userChosenSystem: systemID)
                        if let completionHandler = self.gameImporter.completionHandler {
                            DispatchQueue.main.async {
                                completionHandler(self.gameImporter.encounteredConflicts)
                            }
                        }
                    }
                } else {
                    ELOG("Nothing found at \(systemDir)")
                }
            }
        }
    }

    func fetchGames() {
        let database = RomDatabase.temporaryDatabaseContext()
        database.refresh()
        
        // Favorite Games
        let allSortedGames = database.allGames(sortedByKeyPath: #keyPath(PVGame.title), ascending: true)
        let favoriteGames : [PVGame] = allSortedGames.filter { (game) -> Bool in
            return game.isFavorite
        }
        
        // Recent games
        var recentGames : [PVGame]?
        if  PVSettingsModel.sharedInstance().showRecentGames {
            let sorted: Results<PVRecentGame> = database.all(PVRecentGame.self, sorthedByKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)

            recentGames = Array(sorted).flatMap({ (recentGame) -> PVGame? in
                return recentGame.game
            })
        }

        // Games by system
        var tempSections = [String: [PVLibraryEntry]]()
        for game: PVGame in allSortedGames {
            let systemID: String = game.systemIdentifier
            var games = tempSections[systemID]
            if games == nil {
                games = [PVGame]()
            }
            games?.append(game)
            tempSections[systemID] = games
        }
        
        var sectionInfo = tempSections.keys.sorted()
        // Check if recent games should be added to menu
        if let recentGames = recentGames, !recentGames.isEmpty {
            let key = "recent"
            sectionInfo.insert(key, at: 0)
            tempSections[key] = recentGames
        }
        
        // Check if favorite games should be added to menu
        if favoriteGames.count > 0 {
            let key = "favorite"
            sectionInfo.insert(key, at: 0)
            tempSections[key] = favoriteGames
        }
        
        // Set data source
        gamesInSections = tempSections
        self.sectionInfo = sectionInfo
        isMustRefreshDataSource = false
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

    func finishedDownloadingArtwork(forURL url: String) {
        if let indexPath: IndexPath = indexPathForGame(withURL: url) {
            DispatchQueue.main.async {
                self.collectionView?.reloadItems(at: [indexPath])
            }
        }
    }

    func indexPathsForGame(withMD5Hash md5Hash: String) -> [IndexPath] {
        if let searchResults = searchResults {
            return searchResults.enumerated().flatMap({ (arg) -> IndexPath? in
                let (row, game) = arg
                return game.md5Hash == md5Hash ? IndexPath(row: row, section: 0) : nil
            })
        }
        else {
            return Array(sectionInfo.enumerated().flatMap({ (arg) -> [IndexPath]? in
                let (sectionIndex, sectionKey) = arg
                return gamesInSections[sectionKey]?.enumerated().flatMap({ (arg) -> IndexPath? in
                    let (gameIndex, game) = arg

                    if let game = game as? PVGame {
                        return game.md5Hash == md5Hash ? IndexPath(row: gameIndex, section: sectionIndex) : nil
                    } else if let recentGame = game as? PVRecentGame, let game = recentGame.game {
                        return game.md5Hash == md5Hash ? IndexPath(row: gameIndex, section: sectionIndex) : nil
                    } else {
                        return nil
                    }
                })
            }).joined())
        }
    }

    func indexPathForGame(withURL url: String) -> IndexPath? {
        var indexPath: IndexPath? = nil
        var section: Int = NSNotFound
        var item: Int = NSNotFound
        
        _ = sectionInfo.enumerated().first(where: { (arg) -> Bool in
            let (sectionIndex, sectionKey) = arg
            let games = self.gamesInSections[sectionKey]
            
            var gameIndex: Int?
            let foundGame = games?.enumerated().first(where: { (arg) -> Bool in
                    let (index, game) = arg
                    if let game = game as? PVGame, (game.originalArtworkURL == url) || (game.customArtworkURL == url) {
                        gameIndex = index
                        return true
                    } else {
                        return false
                    }
            })
                
            if foundGame != nil {
                section = sectionIndex
                item = gameIndex!
                return true
            }
            
            return false
        })
        
        if (section != NSNotFound) && (item != NSNotFound) {
            indexPath = IndexPath(item: item, section: section)
        }
        return indexPath
    }

    @objc func handleCacheEmptied(_ notification: NotificationCenter) {

        DispatchQueue.global(qos: .default).async(execute: {() -> Void in
            let database = RomDatabase.temporaryDatabaseContext()
            database.refresh()
            
            do {
                try database.writeTransaction {
                    for game: PVGame in database.allGames {
                        game.customArtworkURL = ""
                        
                        let originalArtworkURL: String = game.originalArtworkURL
                        self.gameImporter?.getArtworkFromURL(originalArtworkURL)
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
//        let config = PVEmulatorConfiguration.sharedInstance()
//        let documentsPath: String = config.documentsPath
//        let romPaths = database.all(PVGame.self).map { (game) -> String in
//            let path: String = URL(fileURLWithPath: documentsPath).appendingPathComponent(game.romPath).path
//            return path
//        }

        let database = RomDatabase.temporaryDatabaseContext()
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

    func createBiosDirectory(atPath biosPath: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: biosPath) {
            do {
                try fm.createDirectory(atPath: biosPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating BIOS dir: \(error.localizedDescription)")
            }
        }
    }

    // TODO: This should be a throw not a bool
    // with error message containting the message text
    // instead of using the handleError function
    func canLoad(_ game: PVGame) -> Bool {
        let config = PVEmulatorConfiguration.sharedInstance()

        guard let system = config.system(forIdentifier: game.systemIdentifier) else {
            ELOG("No system for id \(game.systemIdentifier)")
            return false
        }

        // Error handler
        let handleError : (String?)->Void = { [unowned self] errorMessage in
            // Create missing BIOS directory to help user out
            let biosPath: String = config.biosPath(forSystemID: game.systemIdentifier)
            self.createBiosDirectory(atPath: biosPath)
            
            let biosNames = system[PVBIOSNamesKey] as? [BiosDictionary] ?? [BiosDictionary]()
            
            var biosString = ""
            for bios: BiosDictionary in biosNames {
                let name = bios["Name"]
                biosString += "\(String(describing: name))"
                if biosNames.last! != bios {
                    biosString += """
                    ,
                    
                    """
                }
            }
            
            var message : String
            if let errorMessage = errorMessage {
                message = errorMessage
            } else {
                message = """
                \(String(describing: system[PVShortSystemNameKey])) requires BIOS files to run games. Ensure the following files are inside Documents/BIOS/\(String(describing: system[PVSystemIdentifierKey]))/
                
                \(biosString)
                """
            }
            
            let alertController = UIAlertController(title: "Missing BIOS Files", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true)
        }
        
        
        if let requiresBIOS = system[PVRequiresBIOSKey] as? Bool, requiresBIOS == true {
           
            guard  let biosNames = system[PVBIOSNamesKey] as? [BiosDictionary] else {
                ELOG("System \(game.systemIdentifier) specifies it requires BIOS files but does not provide values for \(PVBIOSNamesKey)")
                handleError("Invalid configuration for system \(game.systemIdentifier)")
                return false
            }
            
            let biosPath: String = config.biosPath(forSystemID: game.systemIdentifier)

            var contents : [String]!
            do {
                contents = try FileManager.default.contentsOfDirectory(atPath: biosPath)
            } catch {
                ELOG("Unable to get contents of \(biosPath) because \(error.localizedDescription)")
                handleError(nil)
                return false
            }
            
            for bios: BiosDictionary in biosNames {
                if let name = bios["name"], !contents.contains(name)  {
                    ELOG("Missing bios of name \(String(describing: name))")
                    handleError(nil)
                    return false
                }
            }
        }

        return true
    }

    // TODO: Make this throw
    func load(_ game: PVGame) {
        if !(presentedViewController is PVEmulatorViewController) {
            let config = PVEmulatorConfiguration.sharedInstance()
            if self.canLoad(game) {
                let emulatorViewController = PVEmulatorViewController(game: game)!
                emulatorViewController.batterySavesPath = config.batterySavesPath(forROM: URL(fileURLWithPath: config.romsPath).appendingPathComponent(game.romPath).path)
                emulatorViewController.saveStatePath = config.saveStatePath(forROM: URL(fileURLWithPath: config.romsPath).appendingPathComponent(game.romPath).path)
                emulatorViewController.biosPath = config.biosPath(forSystemID: game.systemIdentifier)
                emulatorViewController.systemID = game.systemIdentifier
                emulatorViewController.modalTransitionStyle = .crossDissolve
                self.present(emulatorViewController, animated: true) {() -> Void in }
                PVControllerManager.shared().iCadeController?.refreshListener()
                self.updateRecentGames(game)
            } else {
                ELOG("Cannot load game")
            }
        }
    }

    func updateRecentGames(_ game: PVGame) {
        let database = RomDatabase.temporaryDatabaseContext()
        database.refresh()
        
        let recents: Results<PVRecentGame> = database.all(PVRecentGame.self)
        
        let recentsMatchingGame =  database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: game.md5Hash)
        let recentToDelete = recentsMatchingGame.first
        if let recentToDelete = recentToDelete {
            do {
                try database.delete(object: recentToDelete)
            } catch {
                ELOG("Failed to delete recent: \(error.localizedDescription)")
            }
        }
        
        if recents.count >= PVMaxRecentsCount() {
            // TODO: This should delete more than just the last incase we had an overflow earlier
            if let oldestRecent: PVRecentGame = recents.sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false).last {
                do {
                    try database.delete(object: oldestRecent)
                } catch {
                    ELOG("Failed to delete recent: \(error.localizedDescription)")
                }
            }
        }

        let newRecent = PVRecentGame(withGame: game)
        do {
            try database.add(object: newRecent, update:false)
        } catch {
            ELOG("Failed to create Recent Game entry. \(error.localizedDescription)")
        }
        registerRecentGames(recents)
        isMustRefreshDataSource = true
    }

    func registerRecentGames(_ recents: Results<PVRecentGame>) {
        if #available(iOS 9.0, *) {
            #if os(iOS)
                // Add 3D touch shortcuts to recent games
                var shortcuts = [UIApplicationShortcutItem]()
                
                let sortedRecents: Results<PVRecentGame> = recents.sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
                
                for recentGame in sortedRecents {
                    if let game = recentGame.game {
                        let shortcut = UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: game.title, localizedSubtitle: PVEmulatorConfiguration.sharedInstance().name(forSystemIdentifier: game.systemIdentifier), icon: nil, userInfo: ["PVGameHash": game.md5Hash])
                        shortcuts.append(shortcut)
                    }
                }

                UIApplication.shared.shortcutItems = shortcuts
            #endif
        } else {
            // Fallback on earlier versions
        }
    }

    func loadRecentGame(fromShortcut md5: String) {
        let database = RomDatabase.temporaryDatabaseContext()
        let recentGames = database.all(PVRecentGame.self, where: #keyPath(PVRecentGame.game.md5Hash), value: md5)
        
        if let mostRecentGame = recentGames.first?.game {
            load(mostRecentGame)
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
            actionSheet.addAction(UIAlertAction(title: "Toggle Favorite", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.toggleFavorite(for: game)
            }))
            actionSheet.addAction(UIAlertAction(title: "Rename", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.renameGame(game)
            }))
#if os(iOS)
            actionSheet.addAction(UIAlertAction(title: "Choose Custom Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.chooseCustomArtwork(for: game)
            }))
            actionSheet.addAction(UIAlertAction(title: "Paste Custom Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.pasteCustomArtwork(for: game)
            }))
    
            if !game.originalArtworkURL.isEmpty && game.originalArtworkURL != game.customArtworkURL {
                actionSheet.addAction(UIAlertAction(title: "Restore Original Artwork", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                    PVMediaCache.deleteImage(forKey: game.customArtworkURL)
                    
                    try! RomDatabase.temporaryDatabaseContext().writeTransaction {
                        game.customArtworkURL = ""
                    }

                    let originalArtworkURL: String = game.originalArtworkURL
                    DispatchQueue.global(qos: .default).async {
                        self.gameImporter?.getArtworkFromURL(originalArtworkURL)
                        DispatchQueue.main.async {
                            let indexPaths = self.indexPathsForGame(withMD5Hash: game.md5Hash)
                            self.fetchGames()
                            self.collectionView?.reloadItems(at: indexPaths)
                        }
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
            try RomDatabase.temporaryDatabaseContext().writeTransaction {
                game.isFavorite = !game.isFavorite
            }
            
            fetchGames()
            
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        } catch {
            ELOG("Failed to toggle Favourite for game \(game.title)")
        }
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
                try RomDatabase.temporaryDatabaseContext().writeTransaction {
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
        let config = PVEmulatorConfiguration.sharedInstance()
        
        let romPath: String = URL(fileURLWithPath: config.documentsPath).appendingPathComponent(game.romPath).path
        let indexPaths = indexPathsForGame(withMD5Hash: game.md5Hash)
        PVMediaCache.deleteImage(forKey: game.customArtworkURL)

        let savesPath = config.saveStatePath(forROM: romPath)
        do {
            try FileManager.default.removeItem(atPath: savesPath)
        } catch {
            WLOG("Unable to delete save states at path: \(savesPath) because: \(error.localizedDescription)")
        }
        
        let batteryPath = config.batterySavesPath(forROM: romPath)
        do {
            try FileManager.default.removeItem(atPath:batteryPath)
        } catch {
            WLOG("Unable to delete battery states at path: \(batteryPath) because: \(error.localizedDescription)")
        }

        do {
            try FileManager.default.removeItem(atPath: romPath)
        } catch {
            WLOG("Unable to delete rom at path: \(romPath) because: \(error.localizedDescription)")
        }

        deleteRelatedFilesGame(game)
        try? RomDatabase.temporaryDatabaseContext().delete(object: game)
        let oldSectionInfo = sectionInfo
        let oldGamesInSections = gamesInSections
        fetchGames()
        
        DispatchQueue.main.async {
            self.collectionView?.performBatchUpdates({() -> Void in
                self.collectionView?.deleteItems(at: indexPaths)
                for indexPath: IndexPath in indexPaths {
                    let sectionID = oldSectionInfo[indexPath.section]
                    
                    let count: Int = oldGamesInSections[sectionID]?.count ?? 0
                    if count == 1 {
                        self.collectionView?.deleteSections(NSIndexSet(index: indexPath.section) as IndexSet)
                    }
                }
            }, completion: {(_ finished: Bool) -> Void in
            })
        }
    }

    func deleteRelatedFilesGame(_ game: PVGame) {
        let config = PVEmulatorConfiguration.sharedInstance()
        
        let romPath = URL.init(fileURLWithPath: game.romPath)
        let romDirectory: String = URL(fileURLWithPath: config.documentsPath).appendingPathComponent(game.systemIdentifier).path
        let romExtension = romPath.pathExtension
        let relatedFileName: String = romPath.lastPathComponent.replacingOccurrences(of: romExtension, with: "")
        
        let contents : [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: romDirectory)
        } catch {
            ELOG("scanning \(romDirectory) \(error.localizedDescription)")
            return
        }
        
        for file: String in contents {
            let fileWithoutExtension: String = file.replacingOccurrences(of: URL(fileURLWithPath: file).pathExtension, with: "")
            if fileWithoutExtension == relatedFileName {
                do {
                    try FileManager.default.removeItem(atPath: URL(fileURLWithPath: romDirectory).appendingPathComponent(file).path)
                } catch {
                    ELOG("Failed to remove item \(file).\n \(error.localizedDescription)")
                }
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
                var indexPathsToUpdate = [IndexPath]()
                
                group.enumerateAssets(at: IndexSet(integer: index), options: [], using: { (result, index, stop) in
                    if let rep: ALAssetRepresentation = result?.defaultRepresentation() {
                        imagePickerActionSheet.pv_addButton(withTitle: "Use Last Photo Taken", action: {() -> Void in
                            let orientation : UIImageOrientation = UIImageOrientation(rawValue: rep.orientation().rawValue)!

                            let lastPhoto = UIImage(cgImage: rep.fullScreenImage().takeUnretainedValue(), scale: CGFloat(rep.scale()), orientation: orientation)
                            PVMediaCache.writeImage(toDisk: lastPhoto, withKey: rep.url().path)
                            
                            do {
                                try RomDatabase.temporaryDatabaseContext().writeTransaction {
                                    game.customArtworkURL = rep.url().path
                                }
                            } catch {
                                ELOG("Failed to set custom artwork URL for game \(game.title) \n \(error.localizedDescription)")
                            }
                            
                            let indexPaths = self.indexPathsForGame(withMD5Hash: game.md5Hash)
                            indexPathsToUpdate.append(contentsOf: indexPaths)
                            self.fetchGames()
                            self.assetsLibrary = nil
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
                
                DispatchQueue.main.async {
                    self.collectionView?.reloadItems(at: indexPathsToUpdate)
                }
            }
            else {
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
            }
            else {
                key = UUID().uuidString
            }
            PVMediaCache.writeImage(toDisk: pastedImage, withKey: key)
            
            do {
                try RomDatabase.temporaryDatabaseContext().writeTransaction {
                    game.customArtworkURL = key
                }
            } catch {
                ELOG("Failed to set custom artwork URL for game \(game.title).\n\(error.localizedDescription)")
            }
            
            let indexPaths = indexPathsForGame(withMD5Hash: game.md5Hash)
            
            if !indexPaths.isEmpty {
                fetchGames()
                collectionView?.reloadItems(at: indexPaths)
            } else {
                ELOG("Couldn't find index paths for game \(game.title)")
            }
        } else {
            ELOG("No pasted image")
        }
    }

    #endif
    
    func nameForSection(at section: Int) -> String {
        let systemID = sectionInfo[section]
        if (systemID == "recent") {
            return "Recently Played"
        }
        else if (systemID == "favorite") {
            return "Favorites"
        }
        else {
            return PVEmulatorConfiguration.sharedInstance().shortName(forSystemIdentifier: systemID) ?? "Not Found"
        }

    }

// MARK: - Searching
    func searchLibrary(_ searchText: String) {
        let predicate = NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText])
        
        searchResults = RomDatabase.temporaryDatabaseContext().all(PVGame.self, filter: predicate).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        
        collectionView?.reloadData()
    }

    func clearSearch() {
        searchField.text = nil
        searchResults = nil
        collectionView?.reloadData()
    }

// MARK: - UISearchResultsUpdating
    func updateSearchResults(forSearch searchController: UISearchController) {
        searchLibrary(searchController.searchBar.text ?? "")
    }

// MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        var sections: Int = 0
        if searchResults != nil {
            sections = 1
        }
        else {
            sections = sectionInfo.count
        }
        return sections
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var items: Int = 0
        if let searchResults = searchResults {
            items = Int(searchResults.count)
        }
        else {
            let games = gamesInSections[sectionInfo[section]]
            items = games?.count ?? 0
        }
        return items
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = self.collectionView?.dequeueReusableCell(withReuseIdentifier: PVGameLibraryCollectionViewCellIdentifier, for: indexPath) as? PVGameLibraryCollectionViewCell else {
            fatalError("Couldn't create cell of type PVGameLibraryCollectionViewCellIdentifier")
        }
        
        var game: PVGame? = nil
        if let searchResults = searchResults {
            game = Array(searchResults)[indexPath.item]
        }
        else {
            let games = gamesInSections[sectionInfo[indexPath.section]]
            game = games?[indexPath.item] as? PVGame
        }
        cell.setup(with: game)
        return cell
    }

// MARK: - UICollectionViewDelegate & UICollectionViewDelegateFlowLayout
#if os(tvOS)
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
        return true
    }

#endif
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
#if os(tvOS)
        let game = self.game(at: indexPath)!
        let boxartSize = CGSize(width: CellWidth, height: CellWidth / game.boxartAspectRatio)
        return PVGameLibraryCollectionViewCell.cellSize(forImageSize: boxartSize)
#else
        if PVSettingsModel.sharedInstance().showGameTitles {
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
        return UIEdgeInsetsMake(40, 0, 120, 0)
#else
        return UIEdgeInsetsMake(5, 5, 5, 5)
#endif
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let game = self.game(at: indexPath) {
            load(game)
        } else {
            let alert = UIAlertController(title: "Failed to find game", message: "No game found for selected cell", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }

    func game(at indexPath: IndexPath) -> PVGame? {
        var game: PVGame? = nil
        if let searchResults = searchResults {
            game = Array(searchResults)[indexPath.item]
        }
        else {
            let games = gamesInSections[sectionInfo[indexPath.section]]
            game = games![indexPath.item] as? PVGame
        }
        return game
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if (kind == UICollectionElementKindSectionHeader) {
            var headerView: PVGameLibrarySectionHeaderView? = nil
            if  searchResults != nil {
                headerView = self.collectionView?.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier, for: indexPath) as? PVGameLibrarySectionHeaderView
                headerView?.titleLabel?.text = "Search Results"
            }
            else {
                headerView = self.collectionView?.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PVGameLibraryHeaderViewIdentifier, for: indexPath) as? PVGameLibrarySectionHeaderView
                let title: String = nameForSection(at: indexPath.section)
                headerView?.titleLabel?.text = title
            }
            if let headerView = headerView {
                return headerView
            } else {
                fatalError("Couldn't create header view")
            }
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
        }
        else {
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
        if let text = searchField.text, !text.isEmpty {
            searchLibrary(text)
        }
        else {
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
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let gameForCustomArt = self.gameForCustomArt else {
            ELOG("gameForCustomArt pointer was null.")
            return
        }
        
        dismiss(animated: true) {() -> Void in }
        let image = info[UIImagePickerControllerOriginalImage] as? UIImage
        if let image = image, let scaledImage = image.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)), let imageData = UIImagePNGRepresentation(scaledImage) {

            let hash = (imageData as NSData).md5Hash
            PVMediaCache.writeData(toDisk: imageData, withKey: hash)
            
            do {
                try RomDatabase.temporaryDatabaseContext().writeTransaction {
                    gameForCustomArt.customArtworkURL = hash
                }
            } catch {
                ELOG("Failed to set custom artwork for game \(gameForCustomArt.title)\n\(error.localizedDescription)")
            }

            let indexPaths = indexPathsForGame(withMD5Hash: gameForCustomArt.md5Hash)
            collectionView?.reloadItems(at: indexPaths)
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
            for i in 0..<sectionInfo.count {
                let input = "\(i)"
                let title: String = nameForSection(at: i)
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
        searchField.becomeFirstResponder()
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

#if os(iOS)
    extension PVGameLibraryViewController : UIImagePickerControllerDelegate, SFSafariViewControllerDelegate {
        
    }
#endif
