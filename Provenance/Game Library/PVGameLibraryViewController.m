//
//  PVGameLibraryViewController.m
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import "PVGameLibraryViewController.h"
#import "PVGameLibraryCollectionViewCell.h"
#import "PVEmulatorViewController.h"
#import "UIView+FrameAdditions.h"
#import "PVDirectoryWatcher.h"
#import "NSFileManager+OEHashingAdditions.h"
#import <CoreData/CoreData.h>
#import "PVGame.h"
#import "PVMediaCache.h"
#import "UIAlertView+BlockAdditions.h"
#import "UIActionSheet+BlockAdditions.h"
#import "PVEmulatorConfiguration.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "NSData+Hashing.h"
#import "UIImage+Scaling.h"
#import "PVGameLibrarySectionHeaderView.h"
#import "OESQLiteDatabase.h"

NSString *PVGameLibraryHeaderView = @"PVGameLibraryHeaderView";
NSString *kRefreshLibraryNotification = @"kRefreshLibraryNotification";

@interface PVGameLibraryViewController () {
	
	PVDirectoryWatcher *_watcher;
	
	UICollectionView *_collectionView;
	
	NSManagedObjectContext *_managedObjectContext;
	NSManagedObjectModel *_managedObjectModel;
	NSPersistentStoreCoordinator *_persistentStoreCoordinator;
	
	NSOperationQueue *_artworkDownloadQueue;
}

@property (nonatomic, strong) UIToolbar *renameToolbar;
@property (nonatomic, strong) UIView *renameOverlay;
@property (nonatomic, strong) UITextField *renameTextField;
@property (nonatomic, strong) PVGame *gameToRename;
@property (nonatomic, strong) PVGame *gameForCustomArt;
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;

@property (nonatomic, strong) NSDictionary *gamesInSections;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) OESQLiteDatabase *gameDatabase;

@end

@implementation PVGameLibraryViewController

static NSString *_reuseIdentifier = @"PVGameLibraryCollectionViewCell";

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        
    }
    
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.renameOverlay = nil;
	self.renameTextField = nil;
	self.renameToolbar = nil;
	self.gameToRename = nil;
	self.gamesInSections = nil;
	
	_watcher = nil;
	_collectionView = nil;
	_managedObjectContext = nil;
	_managedObjectModel = nil;
	_persistentStoreCoordinator = nil;

	_artworkDownloadQueue = nil;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    
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
	
	[PVEmulatorConfiguration sharedInstance]; //load the config file
	
	_artworkDownloadQueue = [[NSOperationQueue alloc] init];
	[_artworkDownloadQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	[_artworkDownloadQueue setName:@"Artwork Download Queue"];
	
	_managedObjectModel = nil;
	_persistentStoreCoordinator = nil;
	_managedObjectContext = [self managedObjectContext];
	
	[self setTitle:@"Library"];
    
	UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
	[layout setSectionInset:UIEdgeInsetsMake(20, 0, 20, 0)];
    
	_collectionView = [[UICollectionView alloc] initWithFrame:[self.view bounds] collectionViewLayout:layout];
	[_collectionView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[_collectionView setDataSource:self];
	[_collectionView setDelegate:self];
	[_collectionView setBounces:YES];
	[_collectionView setAlwaysBounceVertical:YES];
	[_collectionView setDelaysContentTouches:NO];
	[_collectionView registerClass:[PVGameLibrarySectionHeaderView class]
		forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
			   withReuseIdentifier:PVGameLibraryHeaderView];
	
	[[self view] addSubview:_collectionView];
    
	UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressRecognized:)];
	[_collectionView addGestureRecognizer:longPressRecognizer];
	
	[_collectionView registerClass:[PVGameLibraryCollectionViewCell class] forCellWithReuseIdentifier:_reuseIdentifier];
	[_collectionView setBackgroundColor:[UIColor clearColor]];
    
    NSString *romsPath = [self romsPath];
    
    _watcher = [[PVDirectoryWatcher alloc] initWithPath:romsPath directoryChangedHandler:^{
        [self reloadData];
    }];
    [_watcher findAndExtractArchives];
    [_watcher startMonitoring];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	NSArray *indexPaths = [_collectionView indexPathsForSelectedItems];
	[indexPaths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[_collectionView deselectItemAtIndexPath:obj animated:YES];
	}];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (NSString *)romsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
	
	return documentsDirectoryPath;
}

- (NSString *)batterySavesPathForROM:(NSString *)romPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
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
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
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

- (void)reloadData
{
    [self refreshLibrary:^{
       	NSFetchRequest *request = [[NSFetchRequest alloc] init];
        [request setEntity:[NSEntityDescription entityForName:NSStringFromClass([PVGame class]) inManagedObjectContext:_managedObjectContext]];
        
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
        [request setSortDescriptors:@[sortDescriptor]];
        
        NSError *error = nil;
        NSArray *tempGames = [_managedObjectContext executeFetchRequest:request error:&error];
        NSMutableDictionary *tempGamesInSections = [[NSMutableDictionary alloc] init];
        
        for (PVGame *game in tempGames)
        {
            NSString *fileExtension = [[[[self romsPath] stringByAppendingPathComponent:[game romPath]] pathExtension] lowercaseString];
            NSString *systemID = [[PVEmulatorConfiguration sharedInstance] systemIdentifierForFileExtension:fileExtension];
            NSMutableArray *games = [[tempGamesInSections objectForKey:systemID] mutableCopy];
            if (!games)
            {
                games = [NSMutableArray array];
            }
            
            [games addObject:game];
            [tempGamesInSections setObject:[games copy] forKey:systemID];
        }
        
        self.gamesInSections = [tempGamesInSections copy];
        self.sectionInfo = [[self.gamesInSections allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        
        [_collectionView reloadData];
    }];
}

- (void)refreshLibrary:(void (^)())completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *romsPath = [self romsPath];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:romsPath error:NULL];
        
        NSArray *supportedFileExtensions = [[PVEmulatorConfiguration sharedInstance] supportedFileExtensions];
        
        for (NSString *fileName in contents)
        {
            DLog(@"\n\nFILE: %@\n\n", fileName);
            
            BOOL isDirectory = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&isDirectory])
            {
                if (isDirectory)
                {
                    continue;
                }
            }
            
            
            NSString *fileExtension = [[fileName pathExtension] lowercaseString];
            
            if ([supportedFileExtensions containsObject:fileExtension])
            {
                NSString *currentPath = [romsPath stringByAppendingPathComponent:fileName];
                NSString *title = [[currentPath lastPathComponent] stringByDeletingPathExtension];
                NSString *systemID = [[PVEmulatorConfiguration sharedInstance] systemIdentifierForFileExtension:fileExtension];
                
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"romPath == %@", fileName];
                NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass([PVGame class])];
                [request setPredicate:predicate];
                [request setFetchLimit:1];
                
                PVGame *game = nil;
                
                NSArray *results = [_managedObjectContext executeFetchRequest:request error:NULL];
                if ([results count])
                {
                    game = results[0];
                    [game setSystemIdentifier:systemID];
                }
                else
                {
                    NSString *md5Hash = [[NSFileManager defaultManager] md5HashForFile:currentPath];
                    NSPredicate *hashPredicate = [NSPredicate predicateWithFormat:@"md5 == %@", md5Hash];
                    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([PVGame class])];
                    [request setPredicate:hashPredicate];
                    [request setFetchLimit:1];
                    NSArray *hashResults = [_managedObjectContext executeFetchRequest:request error:NULL];
                    if ([hashResults count])
                    {
                        game = hashResults[0];
                        [game setRomPath:fileName];
                        [game setTitle:title];
                        [game setSystemIdentifier:systemID];
                    }
                }
                
                if (!game)
                {
                    //creating
                    game = (PVGame *)[NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([PVGame class])
                                                                   inManagedObjectContext:_managedObjectContext];
                    [game setRomPath:fileName];
                    [game setTitle:title];
                    [game setSystemIdentifier:systemID];
                }
                
                if (![[game md5] length] && ![[game crc32] length])
                {
                    NSURL *fileURL = [NSURL fileURLWithPath:currentPath];
                    NSString *md5 = nil;
                    NSString *crc32 = nil;
                    [[NSFileManager defaultManager] hashFileAtURL:fileURL
                                                              md5:&md5
                                                            crc32:&crc32
                                                            error:NULL];
                    DLog(@"Got hash for %@", [game title]);
                    [game setMd5:md5];
                    [game setCrc32:crc32];
                    
                    if ([[game requiresSync] boolValue])
                    {
                        DLog(@"about to look up for %@ after getting hash", [game title]);
                        [self lookUpInfoForGame:game];
                    }
                }
                else
                {
                    if ([[game requiresSync] boolValue])
                    {
                        DLog(@"about to look up for %@ ", [game title]);
                        [self lookUpInfoForGame:game];
                    }
                }
            }
        }
        
        [self removeOrphans];
        [self save:NULL];
        if (completionHandler != NULL)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler();
            });
        }
    });
}

- (void)removeOrphans
{
	NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([PVGame class])];
	NSArray *results = [_managedObjectContext executeFetchRequest:fetchRequest error:NULL];
	for (PVGame *game in results)
	{
        if (![[NSFileManager defaultManager] fileExistsAtPath:[[self romsPath] stringByAppendingPathComponent:[game romPath]]])
		{
			[_managedObjectContext deleteObject:game];
		}
	}
}

- (IBAction)getMoreROMs
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Get ROMs!"
													message:@"Download a ROM from your favourite ROM site using Safari and once the download is complete choose \"Open In...\", select Provenance and your ROM will magically appear in the Library."
												   delegate:nil
										  cancelButtonTitle:@"Cancel"
										  otherButtonTitles:@"Open Safari", nil];
	[alert PV_setCompletionHandler:^(NSUInteger buttonIndex) {
		if (buttonIndex != [alert cancelButtonIndex])
		{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://google.com"]];
		}
	}];
	[alert show];
}

- (NSArray *)searchDatabaseUsingKey:(NSString *)key value:(NSString *)value systemID:(NSString *)systemID error:(NSError **)error
{
    NSArray *results = nil;
    NSString *exactQuery = @"SELECT DISTINCT releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL' FROM ROMs rom LEFT JOIN RELEASES release USING (romID) WHERE %@ = '%@'";
    NSString *likeQuery = @"SELECT DISTINCT romFileName as 'romFileName', releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', regionName as 'region', systemShortName as 'systemShortName' FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE %@ LIKE \"%%%@%%\" AND systemID=\"%@\"";
    NSString *queryString = nil;
    
    NSString *dbSystemID = [[PVEmulatorConfiguration sharedInstance] databaseIDForSystemID:systemID];
    
    if ([key isEqualToString:@"romFileName"])
    {
        queryString = [NSString stringWithFormat:likeQuery, key, value, dbSystemID];
    }
    else
    {
        queryString = [NSString stringWithFormat:exactQuery, key, value];
    }
    
    results = [self.gameDatabase executeQuery:queryString
                                        error:error];
    return results;
}

- (void)lookUpInfoForGame:(PVGame *)game
{
    DLog(@"%@ MD5: %@, CRC32: %@", [game title], [game md5], [game crc32]);
    if (!self.gameDatabase)
    {
        self.gameDatabase = [[OESQLiteDatabase alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"openvgdb" withExtension:@"sqlite"]
                                                            error:NULL];
    }
    
    __block NSError *error = nil;
    __block NSArray *results = nil;
    NSString *md5 = [game md5];
    NSString *crc32 = [game crc32];
    NSString *romPath = [game romPath];
    NSString *systemID = [game systemIdentifier];
    
    results = [self searchDatabaseUsingKey:@"romHashMD5" value:md5 systemID:systemID error:&error];
    
    if (![results count])
    {
        results = [self searchDatabaseUsingKey:@"romHashCRC" value:crc32 systemID:systemID error:&error];
    }
    
    if (![results count])
    {
        NSString *extension = [@"." stringByAppendingString:[romPath pathExtension]];
        NSString *name = [romPath stringByReplacingOccurrencesOfString:extension withString:@""];
        results = [self searchDatabaseUsingKey:@"romFileName" value:name systemID:systemID error:&error];
    }
    
    if (![results count])
    {
        if (error)
        {
            DLog(@"Error looking up game info, %@", [error localizedDescription]);
        }
        else
        {
            DLog(@"Got no results for DB search for game: %@", romPath);
        }
        
        [game setRequiresSync:@(NO)];
        
        return;
    }
    
    NSDictionary *chosenResult = nil;
    for (NSDictionary *result in results)
    {
        if ([result[@"region"] isEqualToString:@"USA"])
        {
            chosenResult = result;
            break;
        }
    }
    
    if (!chosenResult)
    {
        chosenResult = [results firstObject];
    }
    
    [game setRequiresSync:@(NO)];
    [game setTitle:chosenResult[@"gameTitle"]];
    [game setOriginalArtworkURL:chosenResult[@"boxImageURL"]];
    [self save:NULL];
    [self getArtworkForGame:game];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_collectionView reloadData];
    });
}

- (void)getArtworkForGame:(PVGame *)game
{
    DLog(@"Starting Artwork download for %@, %@", [game title], [game originalArtworkURL]);
    NSString *originalArtworkURL = [game originalArtworkURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:originalArtworkURL]];
    NSHTTPURLResponse *urlResponse = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&urlResponse
                                                     error:&error];
    if (error)
    {
        DLog(@"error downloading artwork from: %@ -- %@", originalArtworkURL, [error localizedDescription]);
        return;
    }
    
    if ([urlResponse statusCode] != 200)
    {
        DLog(@"HTTP Error: %zd", [urlResponse statusCode]);
        DLog(@"Response: %@", urlResponse);
    }
    
    UIImage *artwork = [[UIImage alloc] initWithData:data];
    if (artwork)
    {
        [PVMediaCache writeImageToDisk:artwork withKey:originalArtworkURL];
    }
}

- (void)handleCacheEmptied:(NSNotificationCenter *)notification
{
	[self.sectionInfo enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
		NSArray *games = [self.gamesInSections objectForKey:key];
        for (PVGame *game in games)
        {
            [game setArtworkURL:nil];
            [self getArtworkForGame:game];
        }
	}];
	
	[_collectionView reloadData];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.sectionInfo enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            NSArray *games = [self.gamesInSections objectForKey:key];
            for (PVGame *game in games)
            {
                [game setRequiresSync:@(YES)];
                [game setArtworkURL:nil];
                [game setOriginalArtworkURL:nil];
            }
        }];
        
        if ([self save:NULL])
        {
            [_collectionView reloadData];
            [self reloadData];
        }
    });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return [self.sectionInfo count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	NSArray *sortedKeys = [[self.gamesInSections allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSArray *games = [self.gamesInSections objectForKey:[sortedKeys objectAtIndex:section]];
	return [games count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	PVGameLibraryCollectionViewCell *cell = [_collectionView dequeueReusableCellWithReuseIdentifier:_reuseIdentifier forIndexPath:indexPath];
	
	NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
	
	PVGame *game = games[[indexPath item]];
	
	NSString *artworkURL = [game artworkURL];
	NSString *originalArtworkURL = [game originalArtworkURL];
		
	if ([artworkURL length])
	{
		UIImage *artwork = [PVMediaCache imageForKey:artworkURL];
		if (artwork)
		{
			[[cell imageView] setImage:artwork];
		}
	}
	else if ([originalArtworkURL length])
	{
		UIImage *artwork = [PVMediaCache imageForKey:originalArtworkURL];
		if (artwork)
		{
			[[cell imageView] setImage:artwork];
		}
	}
    
	[[cell titleLabel] setText:[game title]];
	[[cell missingLabel] setText:[game title]];
	
    [cell setNeedsLayout];
    
	return cell;
}

#pragma mark - UICollectionViewDelegate & UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	return CGSizeMake(100, 144);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
	return 5.0;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(5, 5, 5, 5);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
	
	PVGame *game = games[[indexPath item]];
    
	PVEmulatorViewController *emulatorViewController = [[PVEmulatorViewController alloc] initWithGame:game];
	[emulatorViewController setBatterySavesPath:[self batterySavesPathForROM:[[self romsPath] stringByAppendingPathComponent:[game romPath]]]];
	[emulatorViewController setSaveStatePath:[self saveStatePathForROM:[[self romsPath] stringByAppendingPathComponent:[game romPath]]]];
	[emulatorViewController setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
	
	[self presentViewController:emulatorViewController animated:YES completion:NULL];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	if ([kind isEqualToString:UICollectionElementKindSectionHeader])
	{
		PVGameLibrarySectionHeaderView *headerView = [_collectionView dequeueReusableSupplementaryViewOfKind:kind
																						 withReuseIdentifier:PVGameLibraryHeaderView
																								forIndexPath:indexPath];
		NSString *systemID = [self.sectionInfo objectAtIndex:[indexPath section]];
		NSString *title = [[PVEmulatorConfiguration sharedInstance] shortNameForSystemIdentifier:systemID];
		[[headerView titleLabel] setText:title];
		return headerView;
	}
	
	return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
	return CGSizeMake([self.view bounds].size.width, 40);
}

- (void)longPressRecognized:(UILongPressGestureRecognizer *)recognizer
{
	if ([recognizer state] == UIGestureRecognizerStateBegan)
	{
		__weak PVGameLibraryViewController *weakSelf = self;
		CGPoint point = [recognizer locationInView:_collectionView];
		NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:point];
		
		NSArray *games = [weakSelf.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
		PVGame *game = games[[indexPath item]];
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
		[actionSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
		
		[actionSheet PV_addButtonWithTitle:@"Rename" action:^{
			[weakSelf renameGame:game];
		}];
		[actionSheet PV_addButtonWithTitle:@"Choose Custom Artwork" action:^{
			[weakSelf chooseCustomArtworkForGame:game];
		}];
				
		if ([[game originalArtworkURL] length] &&
			[[game originalArtworkURL] isEqualToString:[game artworkURL]] == NO)
		{
			[actionSheet PV_addButtonWithTitle:@"Restore Original Artwork" action:^{
				[PVMediaCache deleteImageForKey:[game artworkURL]];
				[game setArtworkURL:[game originalArtworkURL]];
				[weakSelf save:NULL];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [weakSelf getArtworkForGame:game];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_collectionView reloadData];
                    });
                });
			}];
		}
		
		[actionSheet PV_addDestructiveButtonWithTitle:@"Delete" action:^{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Delete %@", [game title]]
															message:@"Any save states and battery saves will also be deleted, are you sure?"
														   delegate:nil
												  cancelButtonTitle:@"No"
												  otherButtonTitles:@"Yes", nil];
			[alert PV_setCompletionHandler:^(NSUInteger buttonIndex) {
				if (buttonIndex != [alert cancelButtonIndex])
				{
					[weakSelf deleteGame:game];
				}
			}];
			[alert show];
		}];
		[actionSheet PV_addCancelButtonWithTitle:@"Cancel" action:NULL];
		[actionSheet showInView:self.view];
	}
}

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

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self doneRenaming:self];
	return YES;
}

- (void)keyboardWillShow:(NSNotification *)note
{
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
}

- (void)doneRenaming:(id)sender
{
	NSString *newTitle = [self.renameTextField text];
	
	if ([newTitle length])
	{
		[self.gameToRename setTitle:newTitle];
		self.gameToRename = nil;
		
		[self save:NULL];
		[_collectionView reloadData];
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

- (void)keyboardWillHide:(NSNotification *)note
{
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
}

- (void)deleteGame:(PVGame *)game
{
    NSString *romPath = [[self romsPath] stringByAppendingPathComponent:[game romPath]];
    
	NSError *error = nil;
	BOOL success = [[NSFileManager defaultManager] removeItemAtPath:romPath error:&error];
	if (!success)
	{
		DLog(@"Unable to delete rom at path: %@ because: %@", romPath, [error localizedDescription]);
	}
	
	success = [[NSFileManager defaultManager] removeItemAtPath:[self saveStatePathForROM:romPath] error:&error];
	if (!success)
	{
		DLog(@"Unable to delete save states at path: %@ because: %@", [self saveStatePathForROM:romPath], [error localizedDescription]);
	}
	
	success = [[NSFileManager defaultManager] removeItemAtPath:[self batterySavesPathForROM:romPath] error:&error];
	if (!success)
	{
		DLog(@"Unable to delete battery saves at path: %@ because: %@", [self batterySavesPathForROM:romPath], [error localizedDescription]);
	}
	
	[PVMediaCache deleteImageForKey:[game originalArtworkURL]];
    [PVMediaCache deleteImageForKey:[game artworkURL]];
	
	[[self managedObjectContext] deleteObject:game];
	[self save:NULL];
}

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
                                                                         [game setArtworkURL:[[rep url] absoluteString]];
                                                                         [weakSelf save:NULL];
                                                                         //[_collectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForRow:[weakSelf.games indexOfObject:game] inSection:0]]];
                                                                         [_collectionView reloadData];
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
		[self.gameForCustomArt setArtworkURL:hash];
		[self save:NULL];
		//[_collectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForRow:[self.games indexOfObject:self.gameToRename] inSection:0]]];
		[_collectionView reloadData];
	}
	
	self.gameForCustomArt = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[self dismissViewControllerAnimated:YES completion:NULL];
	self.gameForCustomArt = nil;
}

#pragma mark -
#pragma mark Core Data stack

- (NSManagedObjectContext *) managedObjectContext {
    
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
	{
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
	
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
	
	NSString *path = [[NSBundle mainBundle] pathForResource:@"PVGame" ofType:@"momd"];
	
	NSURL *url = [NSURL fileURLWithPath:path];
	
	_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
		
	NSString *directoryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
	
	BOOL myPathIsDir = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:directoryPath
														   isDirectory:&myPathIsDir];
	if(fileExists == NO)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
								  withIntermediateDirectories:YES
												   attributes:nil
														error:NULL];
	}
	
	NSString *pathComponent = [NSString stringWithFormat:@"PVGame.sqlite"];
    
    NSURL *storeUrl = [NSURL fileURLWithPath: [directoryPath stringByAppendingPathComponent:pathComponent]];
	
    NSError *error = nil;
    NSMutableDictionary *storeOptions = [NSMutableDictionary dictionary];
	
	[storeOptions setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
    [storeOptions setObject:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
												   configuration:nil
															 URL:storeUrl
														 options:storeOptions
														   error:&error]) {
		if([error code] == 134100)
		{
			DLog(@"Will delete old store and try again");
			[[NSFileManager defaultManager] removeItemAtURL:storeUrl error:&error];
			
			if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error]) {
				DLog(@"Unresolved error %@, %@", error, [error userInfo]);
			}
		}
    }
    
    return _persistentStoreCoordinator;
}

- (BOOL)hasChanges
{
	if (_managedObjectContext != nil)
    {
		return [_managedObjectContext hasChanges];
	}
	else
	{
		return NO;
	}
}

- (BOOL)save:(NSError **)error
{
	if (_managedObjectContext != nil)
	{
		if ([_managedObjectContext hasChanges])
		{
			if (![_managedObjectContext save:error])
			{
				return NO;
			}
			else
			{
				return YES;
			}
			
		}
	}
	
	return NO;
}

@end
