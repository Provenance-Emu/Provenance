//
//  PVGameLibraryViewController.m
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import <Realm/Realm.h>
#import "PVAppDelegate.h"
#import "PVGameImporter.h"
#import "PVGameLibraryViewController.h"
#import "PVGameLibraryCollectionViewCell.h"
#import "PVEmulatorViewController.h"
#import "UIView+FrameAdditions.h"
#import "PVDirectoryWatcher.h"
#import "PVGame.h"
#import "PVRecentGame.h"
#import "PVMediaCache.h"
#import "UIAlertView+BlockAdditions.h"
#import "UIActionSheet+BlockAdditions.h"
#import "PVEmulatorConfiguration.h"
#if !TARGET_OS_TV
    #import <AssetsLibrary/AssetsLibrary.h>
    #import "PVSettingsViewController.h"
#endif
#import "UIImage+Scaling.h"
#import "PVGameLibrarySectionHeaderView.h"
#import "MBProgressHUD.h"
#import "NSData+Hashing.h"
#import "PVSettingsModel.h"
#import "PVConflictViewController.h"
#import "PVWebServer.h"
#import "Reachability.h"
#import "PVControllerManager.h"

NSString * const PVGameLibraryHeaderView = @"PVGameLibraryHeaderView";
NSString * const kRefreshLibraryNotification = @"kRefreshLibraryNotification";

NSString * const PVRequiresMigrationKey = @"PVRequiresMigration";

NSInteger const PVMaxRecentsCount = 4;

@interface PVGameLibraryViewController ()

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) PVDirectoryWatcher *watcher;
@property (nonatomic, strong) PVGameImporter *gameImporter;
@property (nonatomic, strong) UICollectionView *collectionView;
#if !TARGET_OS_TV
@property (nonatomic, strong) UIToolbar *renameToolbar;
#endif
@property (nonatomic, strong) UIView *renameOverlay;
@property (nonatomic, strong) UITextField *renameTextField;
@property (nonatomic, strong) PVGame *gameToRename;
@property (nonatomic, strong) PVGame *gameForCustomArt;
#if !TARGET_OS_TV
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
#endif

@property (nonatomic, strong) NSDictionary *gamesInSections;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) RLMResults *searchResults;

@property (nonatomic, assign) IBOutlet UITextField *searchField;

@property (nonatomic, assign) BOOL initialAppearance;

@end

@implementation PVGameLibraryViewController

static NSString *_reuseIdentifier = @"PVGameLibraryCollectionViewCell";

#pragma mark - Lifecycle

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{PVRequiresMigrationKey : @(YES)}];
        RLMRealmConfiguration *config = [[RLMRealmConfiguration alloc] init];
#if TARGET_OS_TV
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
        [config setPath:[[paths firstObject] stringByAppendingPathComponent:@"default.realm"]];
        [RLMRealmConfiguration setDefaultConfiguration:config];
        self.realm = [RLMRealm defaultRealm];
    }
    
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.renameOverlay = nil;
	self.renameTextField = nil;
#if !TARGET_OS_TV
    self.renameToolbar = nil;
#endif
	self.gameToRename = nil;
	self.gamesInSections = nil;
	
	self.watcher = nil;
	self.collectionView = nil;
    self.realm = nil;
}

- (void)handleAppDidBecomeActive:(NSNotification *)note
{
#if !TARGET_OS_TV
    PVAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if ([appDelegate shortcutItem])
    {
        [self loadRecentGameFromShortcut:[appDelegate shortcutItem]];
        [appDelegate setShortcutItem:nil];
    }
#endif
}

- (void)viewDidLoad
{
	[super viewDidLoad];

    self.initialAppearance = YES;

    [self setDefinesPresentationContext:YES];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleCacheEmptied:)
												 name:PVMediaCacheWasEmptiedNotification
											   object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleArchiveInflationFailed:)
                                                 name:PVArchiveInflationFailedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRefreshLibrary:)
                                                 name:kRefreshLibraryNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTextFieldDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.searchField];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
	
	[PVEmulatorConfiguration sharedInstance]; //load the config file
		
	[self setTitle:@"Library"];
    
	UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
	[layout setSectionInset:UIEdgeInsetsMake(20, 0, 20, 0)];
    
	self.collectionView = [[UICollectionView alloc] initWithFrame:[self.view bounds] collectionViewLayout:layout];
	[self.collectionView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self.collectionView setDataSource:self];
	[self.collectionView setDelegate:self];
	[self.collectionView setBounces:YES];
	[self.collectionView setAlwaysBounceVertical:YES];
	[self.collectionView setDelaysContentTouches:NO];
    [self.collectionView setKeyboardDismissMode:UIScrollViewKeyboardDismissModeInteractive];
    [self.collectionView registerClass:[PVGameLibrarySectionHeaderView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:PVGameLibraryHeaderView];
#if TARGET_OS_TV
    [self.collectionView setContentInset:UIEdgeInsetsMake(40, 20, 40, 20)];
#endif
	[[self view] addSubview:self.collectionView];
    
	UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressRecognized:)];
	[self.collectionView addGestureRecognizer:longPressRecognizer];
	
	[self.collectionView registerClass:[PVGameLibraryCollectionViewCell class] forCellWithReuseIdentifier:_reuseIdentifier];
	[self.collectionView setBackgroundColor:[UIColor clearColor]];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:PVRequiresMigrationKey])
    {
        [self migrateLibrary];
    }
    else
    {
        [self setUpGameLibrary];
    }

#if !TARGET_OS_TV
    PVAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if ([appDelegate shortcutItem])
    {
        [self loadRecentGameFromShortcut:[appDelegate shortcutItem]];
        [appDelegate setShortcutItem:nil];
    }
#endif
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	NSArray *indexPaths = [self.collectionView indexPathsForSelectedItems];
	[indexPaths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[self.collectionView deselectItemAtIndexPath:obj animated:YES];
	}];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [PVControllerManager sharedManager];

    if (self.initialAppearance)
    {
        self.initialAppearance = NO;
#if TARGET_OS_TV
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        [cell setNeedsFocusUpdate];
        [cell updateFocusIfNeeded];
#endif
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
#if !TARGET_OS_TV
    if ([[segue identifier] isEqualToString:@"SettingsSegue"])
    {
        [(PVSettingsViewController *)[[segue destinationViewController] topViewController] setGameImporter:self.gameImporter];
    }
#endif
}

#pragma mark - Filesystem Helpers

- (NSString *)documentsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return documentsDirectoryPath;
}

- (NSString *)romsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
	
	return [documentsDirectoryPath stringByAppendingPathComponent:@"roms"];
}

- (NSString *)batterySavesPathForROM:(NSString *)romPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
	NSString *documentsDirectoryPath = [paths objectAtIndex:0];
	NSString *batterySavesDirectory = [documentsDirectoryPath stringByAppendingPathComponent:@"Battery States"];
	
	NSString *romName = [[[romPath lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
	batterySavesDirectory = [batterySavesDirectory stringByAppendingPathComponent:romName];
	
	NSError *error = nil;
	
	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
							  withIntermediateDirectories:YES
											   attributes:nil
													error:&error];
	if (error)
	{
		DLog(@"Error creating save state directory: %@", [error localizedDescription]);
	}
	
	return batterySavesDirectory;
}

- (NSString *)saveStatePathForROM:(NSString *)romPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
	NSString *saveStateDirectory = [documentsDirectoryPath stringByAppendingPathComponent:@"Save States"];
	
	NSString *romName = [[[romPath lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
	saveStateDirectory = [saveStateDirectory stringByAppendingPathComponent:romName];
	
	NSError *error = nil;
	
	[[NSFileManager defaultManager] createDirectoryAtPath:saveStateDirectory
							  withIntermediateDirectories:YES
											   attributes:nil
													error:&error];
	if (error)
	{
		DLog(@"Error creating save state directory: %@", [error localizedDescription]);
	}
	
	return saveStateDirectory;
}

- (IBAction)getMoreROMs
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    [reachability startNotifier];

    NetworkStatus status = [reachability currentReachabilityStatus];

    if (status != ReachableViaWiFi)
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Unable to start web server!"
                                                                       message: @"Your device needs to be connected to a network to continue!"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [self presentViewController:alert animated:YES completion:NULL];
    } else {
        // connected via wifi, let's continue

        // start web transfer service
        [[PVWebServer sharedInstance] startServer];

        // get the IP address of the device
        NSString *ipAddress = [[PVWebServer sharedInstance] getIPAddress];

#if TARGET_IPHONE_SIMULATOR
        ipAddress = [ipAddress stringByAppendingString:@":8080"];
#endif

        NSString *message = [NSString stringWithFormat: @"You can now upload ROMs or download saves by visiting:\nhttp://%@/\non your computer", ipAddress];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Web server started!"
                                                                       message: message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Stop" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[PVWebServer sharedInstance] stopServer];
        }]];
        [self presentViewController:alert animated:YES completion:NULL];
    }
}

- (NSString *)BIOSPathForSystemID:(NSString *)systemID
{
    return [[[self documentsPath] stringByAppendingPathComponent:@"BIOS"] stringByAppendingPathComponent:systemID];
}

#pragma mark - Game Library Management

- (void)migrateLibrary
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [hud setUserInteractionEnabled:NO];
    [hud setMode:MBProgressHUDModeIndeterminate];
    [hud setLabelText:@"Migrating Game Library"];
    [hud setDetailsLabelText:@"Please be patient, this may take a while..."];
    
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:[libraryPath stringByAppendingPathComponent:@"PVGame.sqlite"] error:&error])
    {
        DLog(@"Unable to delete PVGame.sqlite because %@", [error localizedDescription]);
    }
    if (![[NSFileManager defaultManager] removeItemAtPath:[libraryPath stringByAppendingPathComponent:@"PVGame.sqlite-shm"] error:&error])
    {
        DLog(@"Unable to delete PVGame.sqlite-shm because %@", [error localizedDescription]);
    }
    if (![[NSFileManager defaultManager] removeItemAtPath:[libraryPath stringByAppendingPathComponent:@"PVGame.sqlite-wal"] error:&error])
    {
        DLog(@"Unable to delete PVGame.sqlite-wal because %@", [error localizedDescription]);
    }
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:[self romsPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error])
    {
        DLog(@"Unable to create roms directory because %@", [error localizedDescription]);
        return; // dunno what else can be done if this fails
    }
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self documentsPath] error:&error];
    if (!contents)
    {
        DLog(@"Unable to get contents of documents because %@", [error localizedDescription]);
    }
    
    for (NSString *path in contents)
    {
        NSString *fullPath = [[self documentsPath] stringByAppendingPathComponent:path];
        BOOL isDir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];
        if (exists && !isDir && ![[path lowercaseString] containsString:@"realm"])
        {
            if (![[NSFileManager defaultManager] moveItemAtPath:fullPath
                                                         toPath:[[self romsPath] stringByAppendingPathComponent:path]
                                                          error:&error])
            {
                DLog(@"Unable to move %@ to %@ because %@", fullPath, [[self romsPath] stringByAppendingPathComponent:path], [error localizedDescription]);
            }
        }
    }
    
    [hud hide:YES];
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PVRequiresMigrationKey];
    
    [self setUpGameLibrary];
    [self.gameImporter startImportForPaths:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self romsPath] error:&error]];
}

- (void)setUpGameLibrary
{
    [self fetchGames];
    
    __weak typeof(self) weakSelf = self;
    
    self.gameImporter = [[PVGameImporter alloc] initWithCompletionHandler:^(BOOL encounteredConflicts) {
        if (encounteredConflicts)
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Oops!"
                                                                           message:@"There was a conflict while importing your game."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Let's go fix it!"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *action) {
                                                        PVConflictViewController *conflictViewController = [[PVConflictViewController alloc] initWithGameImporter:weakSelf.gameImporter];
                                                        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:conflictViewController];
                                                        [weakSelf presentViewController:navController animated:YES completion:NULL];
                                                    }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Nah, I'll do it later..."
                                                      style:UIAlertActionStyleCancel
                                                    handler:NULL]];
            [weakSelf presentViewController:alert animated:YES completion:NULL];
        }
    }];
    [self.gameImporter setImportStartedHandler:^(NSString *path) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:weakSelf.view animated:YES];
        [hud setUserInteractionEnabled:NO];
        [hud setMode:MBProgressHUDModeIndeterminate];
        [hud setLabelText:[NSString stringWithFormat:@"Importing %@", [path lastPathComponent]]];
    }];
    [self.gameImporter setFinishedImportHandler:^(NSString *md5) {
        [weakSelf finishedImportingGameWithMD5:md5];
    }];
    [self.gameImporter setFinishedArtworkHandler:^(NSString *url) {
        [weakSelf finishedDownloadingArtworkForURL:url];
    }];
    
    self.watcher = [[PVDirectoryWatcher alloc] initWithPath:[self romsPath]
                                   extractionStartedHandler:^(NSString *path) {
                                       MBProgressHUD *hud = [MBProgressHUD HUDForView:weakSelf.view];
                                       if (!hud)
                                       {
                                           hud = [MBProgressHUD showHUDAddedTo:weakSelf.view animated:YES];
                                       }
                                       [hud setUserInteractionEnabled:NO];
                                       [hud setMode:MBProgressHUDModeAnnularDeterminate];
                                       [hud setProgress:0];
                                       [hud setLabelText:@"Extracting Archive..."];
                                   }
                                   extractionUpdatedHandler:^(NSString *path, NSInteger entryNumber, NSInteger total, unsigned long long fileSize, unsigned long long bytesRead) {
                                       MBProgressHUD *hud = [MBProgressHUD HUDForView:weakSelf.view];
                                       [hud setUserInteractionEnabled:NO];
                                       [hud setMode:MBProgressHUDModeAnnularDeterminate];
                                       [hud setProgress:(float)bytesRead / (float)fileSize];
                                       [hud setLabelText:@"Extracting Archive..."];
                                   }
                                  extractionCompleteHandler:^(NSArray *paths) {
                                      MBProgressHUD *hud = [MBProgressHUD HUDForView:weakSelf.view];
                                      [hud setUserInteractionEnabled:NO];
                                      [hud setMode:MBProgressHUDModeAnnularDeterminate];
                                      [hud setProgress:1];
                                      [hud setLabelText:@"Extraction Complete!"];
                                      [hud hide:YES afterDelay:0.5];
                                      [weakSelf.gameImporter startImportForPaths:paths];
                                  }];
    [self.watcher startMonitoring];
    
    NSArray *systems = [[PVEmulatorConfiguration sharedInstance] availableSystemIdentifiers];
    for (NSString *systemID in systems)
    {
        NSString *systemDir = [[self documentsPath] stringByAppendingPathComponent:systemID];
        if ([[NSFileManager defaultManager] fileExistsAtPath:systemDir])
        {
            NSError *error = nil;
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:systemDir error:&error];
            dispatch_async([self.gameImporter serialImportQueue], ^{
                [self.gameImporter getRomInfoForFilesAtPaths:contents userChosenSystem:systemID];
                if ([self.gameImporter completionHandler])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.gameImporter completionHandler]([self.gameImporter encounteredConflicts]);
                    });
                }
            });
        }
    }
}

- (void)fetchGames
{
    [self.realm refresh];
    NSMutableDictionary *tempSections = [NSMutableDictionary dictionary];
    for (PVGame *game in [[PVGame allObjectsInRealm:self.realm] sortedResultsUsingProperty:@"title" ascending:YES])
    {
        NSString *systemID = [game systemIdentifier];
        NSMutableArray *games = [tempSections objectForKey:systemID];
        if (!games)
        {
            games = [NSMutableArray array];
        }
        
        [games addObject:game];
        [tempSections setObject:games forKey:systemID];
    }
    
    self.gamesInSections = tempSections;
    self.sectionInfo = [[self.gamesInSections allKeys] sortedArrayUsingSelector:@selector(compare:)];
}

- (void)finishedImportingGameWithMD5:(NSString *)md5
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];

    [self fetchGames];
    [self.collectionView reloadData];

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

- (void)finishedDownloadingArtworkForURL:(NSString *)url
{
    NSIndexPath *indexPath = [self indexPathForGameWithURL:url];
    if (indexPath)
    {
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
    }
}

- (NSIndexPath *)indexPathForGameWithMD5Hash:(NSString *)md5Hash
{
    NSIndexPath *indexPath = nil;
    __block NSInteger section = NSNotFound;
    __block NSInteger item = NSNotFound;
    
    [self.sectionInfo enumerateObjectsUsingBlock:^(NSString *sectionKey, NSUInteger sectionIndex, BOOL *sectionStop) {
        NSArray *games = self.gamesInSections[sectionKey];
        [games enumerateObjectsUsingBlock:^(PVGame *game, NSUInteger gameIndex, BOOL *gameStop) {
            if ([[game md5Hash] isEqualToString:md5Hash])
            {
                section = sectionIndex;
                item = gameIndex;
                *gameStop = YES;
                *sectionStop = YES;
            }
        }];
    }];
    
    if ((section != NSNotFound) && (item != NSNotFound))
    {
        indexPath = [NSIndexPath indexPathForItem:item inSection:section];
    }
    
    return indexPath;
}

- (NSIndexPath *)indexPathForGameWithURL:(NSString *)url
{
    NSIndexPath *indexPath = nil;
    __block NSInteger section = NSNotFound;
    __block NSInteger item = NSNotFound;
    
    [self.sectionInfo enumerateObjectsUsingBlock:^(NSString *sectionKey, NSUInteger sectionIndex, BOOL *sectionStop) {
        NSArray *games = self.gamesInSections[sectionKey];
        [games enumerateObjectsUsingBlock:^(PVGame *game, NSUInteger gameIndex, BOOL *gameStop) {
            if ([[game originalArtworkURL] isEqualToString:url] ||
                [[game customArtworkURL] isEqualToString:url])
            {
                section = sectionIndex;
                item = gameIndex;
                *gameStop = YES;
                *sectionStop = YES;
            }
        }];
    }];
    
    if ((section != NSNotFound) && (item != NSNotFound))
    {
        indexPath = [NSIndexPath indexPathForItem:item inSection:section];
    }
    
    return indexPath;
}

- (void)handleCacheEmptied:(NSNotificationCenter *)notification
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm refresh];
        for (PVGame *game in [PVGame allObjectsInRealm:realm])
        {
            [realm beginWriteTransaction];
            [game setCustomArtworkURL:@""];
            [realm commitWriteTransaction];
            NSString *originalArtworkURL = [game originalArtworkURL];
            [weakSelf.gameImporter getArtworkFromURL:originalArtworkURL];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.realm refresh];
            [weakSelf fetchGames];
        });

    });
}

- (void)handleArchiveInflationFailed:(NSNotification *)note
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Failed to extract archive"
                                                                   message:@"There was a problem extracting the archive. Perhaps the download was corrupt? Try downloading it again."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:NULL]];
    [self presentViewController:alert animated:YES completion:NULL];
}

- (void)handleRefreshLibrary:(NSNotification *)note
{
    NSString *documentsPath = [self documentsPath];
    NSMutableArray *romPaths = [NSMutableArray array];

    for (PVGame *game in [PVGame allObjectsInRealm:self.realm])
    {
        NSString *path = [documentsPath stringByAppendingPathComponent:[game romPath]];
        [romPaths addObject:path];
    }

    [self.realm beginWriteTransaction];
    [self.realm deleteAllObjects];
    [self.realm commitWriteTransaction];
    [self fetchGames];
    [self.collectionView reloadData];

    [self setUpGameLibrary];

//    dispatch_async([self.gameImporter serialImportQueue], ^{
//        [self.gameImporter getRomInfoForFilesAtPaths:romPaths userChosenSystem:nil];
//        if ([self.gameImporter completionHandler])
//        {
//            [self.gameImporter completionHandler]([self.gameImporter encounteredConflicts]);
//        }
//    });
}

- (BOOL)canLoadGame:(PVGame *)game
{
    BOOL canLoad = YES;
    
    NSDictionary *system = [[PVEmulatorConfiguration sharedInstance] systemForIdentifier:[game systemIdentifier]];
    BOOL requiresBIOS = [system[PVRequiresBIOSKey] boolValue];
    if (requiresBIOS)
    {
        NSArray *biosNames = system[PVBIOSNamesKey];
        NSString *biosPath = [self BIOSPathForSystemID:[game systemIdentifier]];
        NSError *error = nil;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:biosPath error:&error];
        if (!contents)
        {
            DLog(@"Unable to get contents of %@ because %@", biosPath, [error localizedDescription]);
            canLoad = NO;
        }
        
        for (NSString *name in biosNames)
        {
            if (![contents containsObject:name])
            {
                canLoad = NO;
                break;
            }
        }
        
        if (canLoad == NO)
        {
            NSMutableString *biosString = [NSMutableString string];
            for (NSString *name in biosNames)
            {
                [biosString appendString:[NSString stringWithFormat:@"%@", name]];
                if ([biosNames lastObject] != name)
                {
                    [biosString appendString:@",\n"];
                }
            }
            
            NSString *message = [NSString stringWithFormat:@"%@ requires BIOS files to run games. Ensure the following files are inside Documents/BIOS/%@/\n\n%@", system[PVShortSystemNameKey], system[PVSystemIdentifierKey], biosString];
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Missing BIOS Files"
                                                                                     message:message
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:NULL]];
            [self presentViewController:alertController animated:YES completion:NULL];
        }
    }

//    if ([self.presentedViewController isKindOfClass:[PVEmulatorViewController class]])
//    {
//        canLoad = NO;
//    }

    return canLoad;
}

- (void)loadGame:(PVGame *)game
{
    void (^loadGame)(void) = ^void(void) {
        if ([self canLoadGame:game])
        {
            PVEmulatorViewController *emulatorViewController = [[PVEmulatorViewController alloc] initWithGame:game];
            [emulatorViewController setBatterySavesPath:[self batterySavesPathForROM:[[self romsPath] stringByAppendingPathComponent:[game romPath]]]];
            [emulatorViewController setSaveStatePath:[self saveStatePathForROM:[[self romsPath] stringByAppendingPathComponent:[game romPath]]]];
            [emulatorViewController setBIOSPath:[self BIOSPathForSystemID:[game systemIdentifier]]];
            [emulatorViewController setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];

            [self presentViewController:emulatorViewController animated:YES completion:NULL];

            [self updateRecentGames:game];
        }
    };

    if (![[self presentedViewController] isKindOfClass:[PVEmulatorViewController class]])
    {
        loadGame();
    }
}

- (void)updateRecentGames:(PVGame *)game
{
#if !TARGET_OS_TV
    if (NSClassFromString(@"UIApplicationShortcutItem")) {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm refresh];

        RLMResults *recents = [PVRecentGame allObjects];

        PVRecentGame *recentToDelete = [[PVRecentGame objectsWithPredicate:[NSPredicate predicateWithFormat:@"game.md5Hash == %@", [game md5Hash]]] firstObject];
        if (recentToDelete)
        {
            [realm beginWriteTransaction];
            [realm deleteObject:recentToDelete];
            [realm commitWriteTransaction];
        }

        if ([recents count] >= PVMaxRecentsCount)
        {
            PVRecentGame *oldestRecent = [[recents sortedResultsUsingProperty:@"lastPlayedDate" ascending:NO] lastObject];
            [realm beginWriteTransaction];
            [realm deleteObject:oldestRecent];
            [realm commitWriteTransaction];
        }

        PVRecentGame *newRecent = [[PVRecentGame alloc] initWithGame:game];
        [realm beginWriteTransaction];
        [realm addObject:newRecent];
        [realm commitWriteTransaction];


        [[UIApplication sharedApplication] setShortcutItems:nil];
        NSMutableArray *shortcuts = [NSMutableArray array];
        for (PVRecentGame *recentGame in [recents sortedResultsUsingProperty:@"lastPlayedDate" ascending:NO])
        {
            if ([recentGame game])
            {
                UIApplicationShortcutItem *shortcut = [[UIApplicationShortcutItem alloc] initWithType:@"kRecentGameShortcut"
                                                                                       localizedTitle:[[recentGame game] title]
                                                                                    localizedSubtitle:[[PVEmulatorConfiguration sharedInstance] nameForSystemIdentifier:[[recentGame game] systemIdentifier]]
                                                                                                 icon:nil
                                                                                             userInfo:@{@"PVGameHash": [[recentGame game] md5Hash]}];
                [shortcuts addObject:shortcut];
            }
            else
            {
                [realm beginWriteTransaction];
                [realm deleteObject:recentGame];
                [realm commitWriteTransaction];
            }
        }
        
        [[UIApplication sharedApplication] setShortcutItems:shortcuts];
    }
#endif
}

#if !TARGET_OS_TV
- (void)loadRecentGameFromShortcut:(UIApplicationShortcutItem *)shortcut
{
    if ([[shortcut type] isEqualToString:@"kRecentGameShortcut"])
    {
        NSString *md5 = (NSString *)[shortcut userInfo][@"PVGameHash"];
        if ([md5 length])
        {
            PVRecentGame *recentGame = [[PVRecentGame objectsWithPredicate:[NSPredicate predicateWithFormat:@"game.md5Hash == %@", md5]] firstObject];
            PVGame *game = [recentGame game];
            [self loadGame:game];
        }
    }
}
#endif

- (void)longPressRecognized:(UILongPressGestureRecognizer *)recognizer
{
    if ([recognizer state] == UIGestureRecognizerStateBegan)
    {
        __weak PVGameLibraryViewController *weakSelf = self;
        CGPoint point = [recognizer locationInView:self.collectionView];
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];

#if TARGET_OS_TV
        if (!indexPath)
        {
            indexPath = [self.collectionView indexPathForCell:(UICollectionViewCell *)[[UIScreen mainScreen] focusedView]];
        }
#endif

        if (!indexPath)
        {
            // no index path, we're buggered.
            return;
        }
        
        NSArray *games = [weakSelf.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
        PVGame *game = games[[indexPath item]];
        
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@""
                                                                             message:@""
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad)
        {
            UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
            [[actionSheet popoverPresentationController] setSourceView:cell];
            [[actionSheet popoverPresentationController] setSourceRect:[[self.collectionView layoutAttributesForItemAtIndexPath:indexPath] bounds]];
        }
#if !TARGET_OS_TV
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Rename"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          [weakSelf renameGame:game];
                                                      }]];

        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Choose Custom Artwork"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          [weakSelf chooseCustomArtworkForGame:game];
                                                      }]];
        
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Paste Custom Artwork"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          [weakSelf pasteCustomArtworkForGame:game];
                                                      }]];

        if ([[game originalArtworkURL] length] &&
            [[game originalArtworkURL] isEqualToString:[game customArtworkURL]] == NO)
        {
            [actionSheet addAction:[UIAlertAction actionWithTitle:@"Restore Original Artwork"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              [PVMediaCache deleteImageForKey:[game customArtworkURL]];
                                                              [weakSelf.realm beginWriteTransaction];
                                                              [game setCustomArtworkURL:@""];
                                                              [weakSelf.realm commitWriteTransaction];
                                                              NSString *originalArtworkURL = [game originalArtworkURL];
                                                              dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                                  [weakSelf.gameImporter getArtworkFromURL:originalArtworkURL];
                                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                                      NSIndexPath *indexPath = [weakSelf indexPathForGameWithMD5Hash:[game md5Hash]];
                                                                      [weakSelf fetchGames];
                                                                      [weakSelf.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                                                                  });
                                                              });
                                                          }]];
        }
#endif

#if TARGET_OS_TV
        [actionSheet setMessage:[NSString stringWithFormat:@"Options for %@", [game title]]];
#endif

        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Delete %@", [game title]]
                                                                           message:@"Any save states and battery saves will also be deleted, are you sure?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [weakSelf deleteGame:game];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:NULL]];
            [weakSelf presentViewController:alert animated:YES completion:NULL];
        }]];

        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:NULL]];
        [weakSelf presentViewController:actionSheet animated:YES completion:NULL];
    }
}

#if !TARGET_OS_TV
- (void)renameGame:(PVGame *)game
{
    self.gameToRename = game;
    
    self.renameOverlay = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.renameOverlay setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self.renameOverlay setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.3]];
    [self.renameOverlay setAlpha:0.0];
    [self.view addSubview:self.renameOverlay];
    
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         [self.renameOverlay setAlpha:1.0];
                     }
                     completion:NULL];

    self.renameToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    [self.renameToolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    [self.renameToolbar setBarStyle:UIBarStyleBlack];
    
    self.renameTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width - 24, 30)];
    [self.renameTextField setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self.renameTextField setBorderStyle:UITextBorderStyleRoundedRect];
    [self.renameTextField setPlaceholder:[game title]];
    [self.renameTextField setKeyboardAppearance:UIKeyboardAppearanceAlert];
    [self.renameTextField setReturnKeyType:UIReturnKeyDone];
    [self.renameTextField setDelegate:self];
    UIBarButtonItem *textFieldItem = [[UIBarButtonItem alloc] initWithCustomView:self.renameTextField];
    
    [self.renameToolbar setItems:@[textFieldItem]];
    
    [self.renameToolbar setOriginY:self.view.bounds.size.height];
    [self.renameOverlay addSubview:self.renameToolbar];
    
    [self.navigationController.view addSubview:self.renameOverlay];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [self.renameTextField becomeFirstResponder];
}
#endif

- (void)doneRenaming:(id)sender
{
    NSString *newTitle = [self.renameTextField text];
    
    if ([newTitle length])
    {
        [self.realm beginWriteTransaction];
        [self.gameToRename setTitle:newTitle];
        [self.realm commitWriteTransaction];
        
        NSIndexPath *indexPath = [self indexPathForGameWithMD5Hash:[self.gameToRename md5Hash]];
        [self fetchGames];
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        
        self.gameToRename = nil;
    }
    
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         [self.renameOverlay setAlpha:0.0];
                     }
                     completion:^(BOOL finished) {
                         [self.renameOverlay removeFromSuperview];
                         self.renameOverlay = nil;
                     }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [self.renameTextField resignFirstResponder];
}

- (void)deleteGame:(PVGame *)game
{
    NSString *romPath = [[self documentsPath] stringByAppendingPathComponent:[game romPath]];
    NSIndexPath *indexPath = [self indexPathForGameWithMD5Hash:[game md5Hash]];
    
    [PVMediaCache deleteImageForKey:[game originalArtworkURL]];
    [PVMediaCache deleteImageForKey:[game customArtworkURL]];
    
    NSError *error = nil;
    
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:[self saveStatePathForROM:romPath] error:&error];
    if (!success)
    {
        DLog(@"Unable to delete save states at path: %@ because: %@", [self saveStatePathForROM:romPath], [error localizedDescription]);
    }
    
    success = [[NSFileManager defaultManager] removeItemAtPath:[self batterySavesPathForROM:romPath] error:&error];
    if (!success)
    {
        DLog(@"Unable to delete battery saves at path: %@ because: %@", [self batterySavesPathForROM:romPath], [error localizedDescription]);
    }
    
    success = [[NSFileManager defaultManager] removeItemAtPath:romPath error:&error];
    if (!success)
    {
        DLog(@"Unable to delete rom at path: %@ because: %@", romPath, [error localizedDescription]);
    }
    
    [self deleteRelatedFilesGame:game];
    
    [self.realm beginWriteTransaction];
    [self.realm deleteObject:game];
    [self.realm commitWriteTransaction];
    
    NSArray *oldSectionInfo = self.sectionInfo;
    NSDictionary *oldGamesInSections = self.gamesInSections;
    [self fetchGames];
    
    NSString *sectionID = [oldSectionInfo objectAtIndex:[indexPath section]];
    NSUInteger count = [oldGamesInSections[sectionID] count];
    
    [self.collectionView performBatchUpdates:^{
        [self.collectionView deleteItemsAtIndexPaths:@[indexPath]];
        
        if (count == 1)
        {
            [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:[indexPath section]]];
        }
    } completion:^(BOOL finished) {
    }];
}

- (void)deleteRelatedFilesGame:(PVGame *)game
{
    NSString *romPath = [game romPath];
    NSString *romDirectory = [[self documentsPath] stringByAppendingPathComponent:[game systemIdentifier]];
    NSString *relatedFileName = [[romPath lastPathComponent] stringByReplacingOccurrencesOfString:[romPath pathExtension] withString:@""];
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:romDirectory error:&error];
    
    if (!contents)
    {
        DLog(@"Error scanning %@, %@", romDirectory, [error localizedDescription]);
        return;
    }
    
    for (NSString *file in contents)
    {
        NSString *fileWithoutExtension = [file stringByReplacingOccurrencesOfString:[file pathExtension] withString:@""];
        
        if ([fileWithoutExtension isEqual:relatedFileName])
        {
            if (![[NSFileManager defaultManager] removeItemAtPath:[romDirectory stringByAppendingPathComponent:file]
                                                            error:&error])
            {
                DLog(@"Unable to delete file at %@ because %@", file, [error localizedDescription]);
            }
        }
    }
}

#if !TARGET_OS_TV
- (void)chooseCustomArtworkForGame:(PVGame *)game
{
    __weak PVGameLibraryViewController *weakSelf = self;
    
    UIActionSheet *imagePickerActionSheet = [[UIActionSheet alloc] init];
    
    BOOL cameraIsAvailable = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    BOOL photoLibraryIsAvaialble = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    
    PVUIActionSheetAction cameraAction = ^{
        weakSelf.gameForCustomArt = game;
        UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
        [pickerController setDelegate:weakSelf];
        [pickerController setAllowsEditing:NO];
        [pickerController setSourceType:UIImagePickerControllerSourceTypeCamera];
        [weakSelf presentViewController:pickerController animated:YES completion:NULL];
    };
    
    PVUIActionSheetAction libraryAction = ^{
        weakSelf.gameForCustomArt = game;
        UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
        [pickerController setDelegate:weakSelf];
        [pickerController setAllowsEditing:NO];
        [pickerController setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        [weakSelf presentViewController:pickerController animated:YES completion:NULL];
    };
    
    self.assetsLibrary = [[ALAssetsLibrary alloc] init];
    [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                      usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                          if (!group)
                                          {
                                              return;
                                          }
                                          [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                                          NSInteger index = [group numberOfAssets] - 1;
                                          DLog(@"Group: %@", group);
                                          if (index >= 0)
                                          {
                                              [group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:index]
                                                                      options:0
                                                                   usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                                                       ALAssetRepresentation *rep = [result defaultRepresentation];
                                                                       if (rep)
                                                                       {
                                                                           [imagePickerActionSheet PV_addButtonWithTitle:@"Use Last Photo Taken" action:^{
                                                                               UIImage *lastPhoto = [UIImage imageWithCGImage:[rep fullScreenImage]
                                                                                                                        scale:[rep scale]
                                                                                                                  orientation:(UIImageOrientation)[rep orientation]];
                                                                               [PVMediaCache writeImageToDisk:lastPhoto
                                                                                                      withKey:[[rep url] absoluteString]];
                                                                               [self.realm beginWriteTransaction];
                                                                               [game setCustomArtworkURL:[[rep url] absoluteString]];
                                                                               [self.realm commitWriteTransaction];
                                                                               NSIndexPath *indexPath = [self indexPathForGameWithMD5Hash:[game md5Hash]];
                                                                               [self fetchGames];
                                                                               [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                                                                               weakSelf.assetsLibrary = nil;
                                                                           }];
                                                                           
                                                                           if (cameraIsAvailable || photoLibraryIsAvaialble)
                                                                           {
                                                                               if (cameraIsAvailable)
                                                                               {
                                                                                   [imagePickerActionSheet	PV_addButtonWithTitle:@"Take Photo..." action:cameraAction];
                                                                               }
                                                                               
                                                                               if (photoLibraryIsAvaialble)
                                                                               {
                                                                                   [imagePickerActionSheet PV_addButtonWithTitle:@"Choose from Library..." action:libraryAction];
                                                                               }
                                                                           }
                                                                           
                                                                           [imagePickerActionSheet PV_addCancelButtonWithTitle:@"Cancel" action:NULL];
                                                                           [imagePickerActionSheet showInView:self.view];
                                                                       }
                                                                   }];
                                          }
                                          else
                                          {
                                              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Photos"
                                                                                              message:@"There are no photos in your library to choose from"
                                                                                             delegate:nil
                                                                                    cancelButtonTitle:nil
                                                                                    otherButtonTitles:@"OK", nil];
                                              [alert show];
                                          }
                                      } failureBlock:^(NSError *error) {
                                          if (cameraIsAvailable || photoLibraryIsAvaialble)
                                          {
                                              if (cameraIsAvailable)
                                              {
                                                  [imagePickerActionSheet	PV_addButtonWithTitle:@"Take Photo..." action:cameraAction];
                                              }
                                              
                                              if (photoLibraryIsAvaialble)
                                              {
                                                  [imagePickerActionSheet PV_addButtonWithTitle:@"Choose from Library..." action:libraryAction];
                                              }
                                          }
                                          [imagePickerActionSheet PV_addCancelButtonWithTitle:@"Cancel" action:NULL];
                                          [imagePickerActionSheet showInView:self.view];
                                          weakSelf.assetsLibrary = nil;
                                      }];
}

- (void)pasteCustomArtworkForGame:(PVGame *)game
{
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    UIImage *pastedImage = [pb image];
    NSURL *pastedURL = [pb URL];
    if (pastedURL != nil && pastedImage == nil) {
        pastedImage = [UIImage imageWithData: [NSData dataWithContentsOfURL:pastedURL]];
    }
    
    if (pastedImage != nil) {
        NSString *key;
        if (pastedURL != nil) {
            key = pastedURL.lastPathComponent;
        } else {
            key = [NSUUID UUID].UUIDString;
        }
        [PVMediaCache writeImageToDisk:pastedImage
                               withKey:key];
        [self.realm beginWriteTransaction];
        [game setCustomArtworkURL:key];
        [self.realm commitWriteTransaction];
        NSIndexPath *indexPath = [self indexPathForGameWithMD5Hash:[game md5Hash]];
        [self fetchGames];
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
    }
}
#endif

#pragma mark - Searching

- (void)searchLibrary:(NSString *)searchText
{
    self.searchResults = [[PVGame objectsWhere:@"title CONTAINS[c] %@", searchText] sortedResultsUsingProperty:@"title" ascending:YES];
    [self.collectionView reloadData];
}

- (void)clearSearch
{
    [self.searchField setText:nil];
    self.searchResults = nil;
    [self.collectionView reloadData];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    NSInteger sections = 0;
    
    if (self.searchResults)
    {
        sections = 1;
    }
    else
    {
        sections = [self.sectionInfo count];
    }
    
    return sections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSInteger items = 0;
    
    if (self.searchResults)
    {
        items = [self.searchResults count];
    }
    else
    {
        NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:section]];
        items = [games count];
    }
    
    return items;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	PVGameLibraryCollectionViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:_reuseIdentifier forIndexPath:indexPath];
	
    PVGame *game = nil;
    
    if (self.searchResults)
    {
        game = [self.searchResults objectAtIndex:[indexPath item]];
    }
    else
    {
        NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
        game = games[[indexPath item]];
    }
	
	NSString *artworkURL = [game customArtworkURL];
	NSString *originalArtworkURL = [game originalArtworkURL];
    __block UIImage *artwork = nil;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([artworkURL length])
        {
            artwork = [PVMediaCache imageForKey:artworkURL];
        }
        else if ([originalArtworkURL length])
        {
            artwork = [PVMediaCache imageForKey:originalArtworkURL];
        }
        
        if (artwork)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[cell imageView] setImage:artwork];
                [cell setNeedsLayout];
            });
        }
    });
    
	[[cell titleLabel] setText:[game title]];
	[[cell missingLabel] setText:[game title]];
	
    [cell setNeedsLayout];
    
	return cell;
}

#pragma mark - UICollectionViewDelegate & UICollectionViewDelegateFlowLayout

#if TARGET_OS_TV
- (BOOL)collectionView:(UICollectionView *)collectionView canFocusItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldUpdateFocusInContext:(UICollectionViewFocusUpdateContext *)context
{
    return YES;
}
#endif

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
#if TARGET_OS_TV
    return CGSizeMake(250, 360);
#else
	return CGSizeMake(100, 144);
#endif
}

#if TARGET_OS_TV
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 88;
}
#endif

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
#if TARGET_OS_TV
    return 30;
#else
	return 5.0;
#endif
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
#if TARGET_OS_TV
    	return UIEdgeInsetsMake(40, 40, 40, 40);
#else
    	return UIEdgeInsetsMake(5, 5, 5, 5);
#endif
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PVGame *game = nil;
    if (self.searchResults)
    {
        game = [self.searchResults objectAtIndex:[indexPath item]];
    }
    else
    {
        NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
        game = games[[indexPath item]];
    }
    
    [self loadGame:game];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader])
	{
        PVGameLibrarySectionHeaderView *headerView = nil;
        
        if (self.searchResults)
        {
            headerView = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                 withReuseIdentifier:PVGameLibraryHeaderView
                                                                        forIndexPath:indexPath];
            [[headerView titleLabel] setText:@"Search Results"];
        }
        else
        {
            headerView = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                 withReuseIdentifier:PVGameLibraryHeaderView
                                                                        forIndexPath:indexPath];
            NSString *systemID = [self.sectionInfo objectAtIndex:[indexPath section]];
            NSString *title = [[PVEmulatorConfiguration sharedInstance] shortNameForSystemIdentifier:systemID];
            [[headerView titleLabel] setText:title];
        }
		return headerView;
	}
	
	return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
#if TARGET_OS_TV
    return CGSizeMake([self.view bounds].size.width, 90);
#else
	return CGSizeMake([self.view bounds].size.width, 40);
#endif
}

#pragma mark - Text Field and Keyboard Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField != self.searchField)
    {
        [self doneRenaming:self];
    }
    else
    {
        [textField resignFirstResponder];
    }
    
	return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if (textField == self.searchField)
    {
        [textField performSelector:@selector(resignFirstResponder)
                        withObject:nil
                        afterDelay:0.0];
    }
    
    return YES;
}

- (void)handleTextFieldDidChange:(NSNotification *)notification
{
    if ([[self.searchField text] length])
    {
        [self searchLibrary:[self.searchField text]];
    }
    else
    {
        [self clearSearch];
    }
}

- (void)keyboardWillShow:(NSNotification *)note
{
#if !TARGET_OS_TV
	NSDictionary *userInfo = [note userInfo];
	
	CGRect keyboardEndFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardEndFrame = [self.view.window convertRect:keyboardEndFrame toView:self.navigationController.view];
	CGFloat animationDuration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	NSUInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
	
	[UIView animateWithDuration:animationDuration
						  delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState | animationCurve
					 animations:^{
						 [self.renameToolbar setOriginY:keyboardEndFrame.origin.y - self.renameToolbar.frame.size.height];
					 }
					 completion:^(BOOL finished) {
					 }];
#endif
}


- (void)keyboardWillHide:(NSNotification *)note
{
#if !TARGET_OS_TV
	NSDictionary *userInfo = [note userInfo];
	
	CGFloat animationDuration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	NSUInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
	
	[UIView animateWithDuration:animationDuration
						  delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState | animationCurve
					 animations:^{
						 [self.renameToolbar setOriginY:[[UIScreen mainScreen] bounds].size.height];
					 }
					 completion:^(BOOL finished) {
						 [self.renameToolbar removeFromSuperview];
						 self.renameToolbar = nil;
						 self.renameTextField = nil;
					 }];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillShowNotification
												  object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillHideNotification
												  object:nil];
#endif
}

#pragma mark - Image Picker Deleate

#if !TARGET_OS_TV
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	[self dismissViewControllerAnimated:YES completion:NULL];
	
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	image = [image scaledImageWithMaxResolution:200];
	
	if (image)
	{
		NSData *imageData = UIImagePNGRepresentation(image);
		NSString *hash = [imageData md5Hash];
		[PVMediaCache writeDataToDisk:imageData withKey:hash];
        [self.realm beginWriteTransaction];
		[self.gameForCustomArt setCustomArtworkURL:hash];
        [self.realm commitWriteTransaction];
        NSIndexPath *indexPath = [self indexPathForGameWithMD5Hash:[self.gameForCustomArt md5Hash]];
		[self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
	}
	
	self.gameForCustomArt = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[self dismissViewControllerAnimated:YES completion:NULL];
	self.gameForCustomArt = nil;
}
#endif

@end
