//
//  PVGameLibraryViewController.m
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import <Realm/Realm.h>
#import "PVGameImporter.h"
#import "PVGameLibraryViewController.h"
#import "PVGameLibraryCollectionViewCell.h"
#import "PVEmulatorViewController.h"
#import "UIView+FrameAdditions.h"
#import "PVDirectoryWatcher.h"
#import "PVGame.h"
#import "PVMediaCache.h"
#import "UIAlertView+BlockAdditions.h"
#import "UIActionSheet+BlockAdditions.h"
#import "PVEmulatorConfiguration.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIImage+Scaling.h"
#import "PVGameLibrarySectionHeaderView.h"
#import "MBProgressHUD.h"
#import "NSData+Hashing.h"
#import "PVSettingsModel.h"
#import "PVConflictViewController.h"

NSString *PVGameLibraryHeaderView = @"PVGameLibraryHeaderView";
NSString *kRefreshLibraryNotification = @"kRefreshLibraryNotification";

@interface PVGameLibraryViewController ()

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) PVDirectoryWatcher *watcher;
@property (nonatomic, strong) PVGameImporter *gameImporter;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIToolbar *renameToolbar;
@property (nonatomic, strong) UIView *renameOverlay;
@property (nonatomic, strong) UITextField *renameTextField;
@property (nonatomic, strong) PVGame *gameToRename;
@property (nonatomic, strong) PVGame *gameForCustomArt;
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;

@property (nonatomic, strong) NSDictionary *gamesInSections;
@property (nonatomic, strong) NSArray *sectionInfo;

@property (nonatomic, assign, getter=isRefreshing) BOOL refreshing;

@end

@implementation PVGameLibraryViewController

static NSString *_reuseIdentifier = @"PVGameLibraryCollectionViewCell";

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        self.realm = [RLMRealm defaultRealm];
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
	
	self.watcher = nil;
	self.collectionView = nil;
    self.realm = nil;
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
    [self.collectionView registerClass:[PVGameLibrarySectionHeaderView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:PVGameLibraryHeaderView];
	
	[[self view] addSubview:self.collectionView];
    
	UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressRecognized:)];
	[self.collectionView addGestureRecognizer:longPressRecognizer];
	
	[self.collectionView registerClass:[PVGameLibraryCollectionViewCell class] forCellWithReuseIdentifier:_reuseIdentifier];
	[self.collectionView setBackgroundColor:[UIColor clearColor]];
    
    [self fetchGames];
    
    __weak typeof(self) weakSelf = self;
    
    self.gameImporter = [[PVGameImporter alloc] initWithCompletionHandler:^(BOOL encounteredConflicts) {
        if (encounteredConflicts)
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Oops!"
                                                                           message:@"There was a conflict while importing your game."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Let's go fix them!"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *action) {
                                                        
                                                    }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Nah, I'll do it later..."
                                                      style:UIAlertActionStyleCancel
                                                    handler:^(UIAlertAction *action) {
                                                    }]];
            [self presentViewController:alert animated:YES completion:NULL];
        }
    }];
    [self.gameImporter setFinishedImportHandler:^(NSString *md5) {
        [weakSelf finishedImportingGameWithMD5:md5];
    }];
    [self.gameImporter setFinishedArtworkHandler:^(NSString *url) {
        [weakSelf finishedDownloadingArtworkForURL:url];
    }];
    
    self.watcher = [[PVDirectoryWatcher alloc] initWithPath:[self romsPath]
                                   extractionStartedHandler:^(NSString *path) {
                                       MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
                                       if (!hud)
                                       {
                                           hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                                       }
                                       [hud setUserInteractionEnabled:NO];
                                       [hud setMode:MBProgressHUDModeAnnularDeterminate];
                                       [hud setProgress:0];
                                       [hud setLabelText:@"Extracting Archive..."];
                                   }
                                   extractionUpdatedHandler:^(NSString *path, NSInteger entryNumber, NSInteger total, unsigned long long fileSize, unsigned long long bytesRead) {
                                       MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
                                       [hud setUserInteractionEnabled:NO];
                                       [hud setMode:MBProgressHUDModeAnnularDeterminate];
                                       [hud setProgress:(float)bytesRead / (float)fileSize];
                                       [hud setLabelText:@"Extracting Archive..."];
                                   }
                                  extractionCompleteHandler:^(NSArray *paths) {
                                      MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
                                      [hud setUserInteractionEnabled:NO];
                                      [hud setMode:MBProgressHUDModeAnnularDeterminate];
                                      [hud setProgress:1];
                                      [hud setLabelText:@"Extraction Complete!"];
                                      [hud hide:YES afterDelay:0.5];
                                      [weakSelf.gameImporter startImportForPaths:paths];
                                  }];
    
    [self.watcher startMonitoring];
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
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (NSString *)documentsPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return documentsDirectoryPath;
}

- (NSString *)romsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
	
	return [documentsDirectoryPath stringByAppendingPathComponent:@"roms"];
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

- (NSString *)BIOSPathForSystemID:(NSString *)systemID
{
    return [[[self documentsPath] stringByAppendingPathComponent:@"BIOS"] stringByAppendingPathComponent:systemID];
}

- (void)fetchGames
{
    [self.realm refresh];
    NSMutableDictionary *tempSections = [NSMutableDictionary dictionary];
    for (PVGame *game in [[PVGame allObjectsInRealm:self.realm] sortedResultsUsingProperty:@"title" ascending:YES])
    {
        NSString *fileExtension = [[[game romPath] pathExtension] lowercaseString];
        NSString *systemID = [[PVEmulatorConfiguration sharedInstance] systemIdentifierForFileExtension:fileExtension];
        NSMutableArray *games = [[tempSections objectForKey:systemID] mutableCopy];
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
    NSArray *oldSectionInfo = self.sectionInfo;
    NSIndexPath *indexPath = [self indexPathForGameWithMD5Hash:md5];
    [self fetchGames];
    if (indexPath)
    {
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
    }
    else
    {
        indexPath = [self indexPathForGameWithMD5Hash:md5];
        PVGame *game = [[PVGame objectsInRealm:self.realm where:@"md5Hash == %@", md5] firstObject];
        NSString *systemID = [game systemIdentifier];
        __block BOOL needToInsertSection = YES;
        [oldSectionInfo enumerateObjectsUsingBlock:^(NSString *section, NSUInteger sectionIndex, BOOL *stop) {
            if ([systemID isEqualToString:section])
            {
                needToInsertSection = NO;
                *stop = YES;
            }
        }];
        
        [self.collectionView performBatchUpdates:^{
            if (needToInsertSection)
            {
                [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[indexPath section]]];
            }
            [self.collectionView insertItemsAtIndexPaths:@[indexPath]];
        } completion:^(BOOL finished) {
        }];
    }
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
            [game setCustomArtworkURL:nil];
            [realm commitWriteTransaction];
            NSString *originalArtworkURL = [game originalArtworkURL];
            [weakSelf.gameImporter getArtworkFromURL:originalArtworkURL];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.realm refresh];
            [weakSelf fetchGames];
            [weakSelf.collectionView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self.sectionInfo count])]];
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
    for (PVGame *game in [PVGame allObjectsInRealm:self.realm])
    {   [self.realm beginWriteTransaction];
        [game setCustomArtworkURL:nil];
        [game setOriginalArtworkURL:nil];
        [game setRequiresSync:YES];
        [self.realm commitWriteTransaction];
        NSString *path = [documentsPath stringByAppendingPathComponent:[game romPath]];
        dispatch_async([self.gameImporter serialImportQueue], ^{
           [self.gameImporter getRomInfoForFilesAtPaths:@[path]];
        });
    }
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
    
    return canLoad;
}

- (void)loadGame:(PVGame *)game
{
    if ([self canLoadGame:game])
    {
        PVEmulatorViewController *emulatorViewController = [[PVEmulatorViewController alloc] initWithGame:game];
        [emulatorViewController setBatterySavesPath:[self batterySavesPathForROM:[[self romsPath] stringByAppendingPathComponent:[game romPath]]]];
        [emulatorViewController setSaveStatePath:[self saveStatePathForROM:[[self romsPath] stringByAppendingPathComponent:[game romPath]]]];
        [emulatorViewController setBIOSPath:[self BIOSPathForSystemID:[game systemIdentifier]]];
        [emulatorViewController setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
        
        [self presentViewController:emulatorViewController animated:YES completion:NULL];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return [self.sectionInfo count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:section]];
	return [games count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	PVGameLibraryCollectionViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:_reuseIdentifier forIndexPath:indexPath];
	
	NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
	
	PVGame *game = games[[indexPath item]];
	
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
    
    [self loadGame:game];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	if ([kind isEqualToString:UICollectionElementKindSectionHeader])
	{
		PVGameLibrarySectionHeaderView *headerView = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind
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
		CGPoint point = [recognizer locationInView:self.collectionView];
		NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
		
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
			[[game originalArtworkURL] isEqualToString:[game customArtworkURL]] == NO)
		{
			[actionSheet PV_addButtonWithTitle:@"Restore Original Artwork" action:^{
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

@end
