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
#import "ArchiveVG.h"
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

NSString *PVGameLibraryHeaderView = @"PVGameLibraryHeaderView";

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

@end

@implementation PVGameLibraryViewController

static NSString *_reuseIdentifier = @"PVGameLibraryCollectionViewCell";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
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
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleCacheEmptied:)
												 name:PVMediaCacheWasEmptiedNotification
											   object:nil];
	
	[PVEmulatorConfiguration sharedInstance]; //load the config file
	
	_artworkDownloadQueue = [[NSOperationQueue alloc] init];
	[_artworkDownloadQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	[_artworkDownloadQueue setName:@"Artwork Download Queue"];
	
	_managedObjectModel = nil;
	_persistentStoreCoordinator = nil;
	_managedObjectContext = [self managedObjectContext];
	
	[self setTitle:@"Library"];
	
	NSString *romsPath = [self romsPath];
	
	_watcher = [[PVDirectoryWatcher alloc] initWithPath:romsPath directoryChangedHandler:^{
		[self reloadData];
	}];
	[_watcher startMonitoring];
	
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
    
	[self reloadData];
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
		NSLog(@"Error creating save state directory: %@", [error localizedDescription]);
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
		NSLog(@"Error creating save state directory: %@", [error localizedDescription]);
	}
	
	return saveStateDirectory;
}

- (void)reloadData
{
	[self refreshLibrary];
	
	NSFetchRequest *request = [[NSFetchRequest alloc] init];
	[request setEntity:[NSEntityDescription entityForName:NSStringFromClass([PVGame class]) inManagedObjectContext:_managedObjectContext]];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
	[request setSortDescriptors:@[sortDescriptor]];
	
	NSError *error = nil;
	NSArray *tempGames = [_managedObjectContext executeFetchRequest:request error:&error];
	NSMutableDictionary *tempGamesInSections = [[NSMutableDictionary alloc] init];
	
	for (PVGame *game in tempGames)
	{
		NSString *fileExtension = [[game romPath] pathExtension];
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
}

- (void)refreshLibrary
{
	NSString *romsPath = [self romsPath];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *contents = [fileManager contentsOfDirectoryAtPath:romsPath error:NULL];
	
	NSArray *supportedFileExtensions = [[PVEmulatorConfiguration sharedInstance] supportedFileExtensions];
	
	for (NSString *filePath in contents)
	{
		NSString *fileExtension = [filePath pathExtension];
		
		if ([supportedFileExtensions containsObject:[fileExtension lowercaseString]])
		{
			NSString *path = [romsPath stringByAppendingPathComponent:filePath];
			NSString *title = [[path lastPathComponent] stringByDeletingPathExtension];
			NSString *systemID = [[PVEmulatorConfiguration sharedInstance] systemIdentifierForFileExtension:fileExtension];
			
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"romPath == %@", path];
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
				NSString *md5Hash = [[NSFileManager defaultManager] md5HashForFile:path];
				NSPredicate *hashPredicate = [NSPredicate predicateWithFormat:@"md5 == %@", md5Hash];
				NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([PVGame class])];
				[request setPredicate:hashPredicate];
				[request setFetchLimit:1];
				NSArray *hashResults = [_managedObjectContext executeFetchRequest:request error:NULL];
				if ([hashResults count])
				{
					game = hashResults[0];
					[game setRomPath:path];
					[game setTitle:title];
					[game setSystemIdentifier:systemID];
				}
			}

			if (!game)
			{
				//creating
				game = (PVGame *)[NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([PVGame class])
																inManagedObjectContext:_managedObjectContext];
				[game setRomPath:path];
				[game setTitle:title];
				[game setSystemIdentifier:systemID];
			}
			
			if (![[game md5] length] && ![[game crc32] length])
			{
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					NSURL *fileURL = [NSURL fileURLWithPath:path];
					NSString *md5 = nil;
					NSString *crc32 = nil;
					NSLog(@"Getting hash for %@", [game title]);
					[[NSFileManager defaultManager] hashFileAtURL:fileURL
															  md5:&md5
															crc32:&crc32
															error:NULL];
					dispatch_async(dispatch_get_main_queue(), ^{
						NSLog(@"Got hash for %@", [game title]);
						[game setMd5:md5];
						[game setCrc32:crc32];
						
						if (![[game isSyncing] boolValue] && [[game requiresSync] boolValue])
						{
							NSLog(@"about to look up for %@ after getting hash", [game title]);
							[self lookUpInfoForGame:game];
						}
					});
				});
			}
			else
			{
				if (![[game isSyncing] boolValue] && [[game requiresSync] boolValue])
				{
					NSLog(@"about to look up for %@ ", [game title]);
					[self lookUpInfoForGame:game];
				}
			}
		}
	}
	
	[self removeOrphans];
	[self save:NULL];
}

- (void)removeOrphans
{
	NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([PVGame class])];
	NSArray *results = [_managedObjectContext executeFetchRequest:fetchRequest error:NULL];
	for (PVGame *game in results)
	{
		if (![[NSFileManager defaultManager] fileExistsAtPath:[game romPath]])
		{
			[_managedObjectContext deleteObject:game];
		}
	}
}

- (IBAction)getMoreROMs
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Get ROMs!"
													message:@"Download a ROM from your favourite ROM site using Safari and once the download is complete choose \"Open In...\", select GB4iOS and your ROM will magically appear in the Library."
												   delegate:nil
										  cancelButtonTitle:@"Cancel"
										  otherButtonTitles:@"Open Safari", nil];
	[alert PV_setCompletionHandler:^(NSUInteger buttonIndex) {
		if (buttonIndex != [alert cancelButtonIndex])
		{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://coolrom.com/roms/genesis"]];
		}
	}];
	[alert show];
}

- (void)lookUpInfoForGame:(PVGame *)game
{
	NSLog(@"%@ MD5: %@, CRC32: %@", [game title], [game md5], [game crc32]);
	if (![[game isSyncing] boolValue] && [[game requiresSync] boolValue])
	{
		[game setIsSyncing:@(YES)];
		[[ArchiveVG throttled] gameInfoByMD5:[game md5]
									  andCRC:[game crc32]
								withCallback:^(id result, NSError *error) {
									dispatch_async(dispatch_get_main_queue(), ^{
										NSLog(@"result = %@, error %@", result, [error localizedDescription]);
										if (result)
										{
											[game setTitle:[result objectForKey:AVGGameTitleKey]];
											[game setArtworkURL:[result objectForKey:AVGGameBoxURLStringKey]];
											[game setOriginalArtworkURL:[result objectForKey:AVGGameBoxURLStringKey]];
											[self getArtworkForGame:game];
										}
										
										[game setRequiresSync:@(NO)];
										[game setIsSyncing:@(NO)];
										[self save:NULL];
										[_collectionView reloadData];
									});
								} usingFormat:AVGOutputFormatXML];
	}
}

- (void)getArtworkForGame:(PVGame *)game
{
	NSLog(@"Starting Artwork download for %@, %@", [game title], [game artworkURL]);
	[game setIsSyncing:@(YES)];
	[self save:NULL];
	
	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[game artworkURL]]]
									   queue:_artworkDownloadQueue
						   completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
							   dispatch_async(dispatch_get_main_queue(), ^{
								   
                                   if ([data length])
								   {
									   UIImage *artwork = [UIImage imageWithData:data];
									   artwork = [artwork scaledImageWithMaxResolution:200];
									   if (artwork)
									   {
										   NSLog(@"got artwork for %@", [game title]);
										   [PVMediaCache writeImageToDisk:artwork
																  withKey:[game artworkURL]];
									   }
								   }
								   
								   [game setIsSyncing:@(NO)];
								   [self save:NULL];
								   [_collectionView reloadData];
							   });
						   }];
}

- (void)handleCacheEmptied:(NSNotificationCenter *)notification
{
	[self.sectionInfo enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
		NSArray *games = [self.gamesInSections objectForKey:key];
		PVGame *game = [games objectAtIndex:idx];
		[game setArtworkURL:[game originalArtworkURL]];
	}];
	
	[_collectionView reloadData];
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
		else if (![[game isSyncing] boolValue])
		{
			[self getArtworkForGame:game];
		}
	}
	else if ([originalArtworkURL length])
	{
		[game setArtworkURL:originalArtworkURL];
		[self save:NULL];
		UIImage *artwork = [PVMediaCache imageForKey:artworkURL];
		if (artwork)
		{
			[[cell imageView] setImage:artwork];
		}
		else if (![[game isSyncing] boolValue])
		{
			[self getArtworkForGame:game];
		}
	}
	
	[[cell titleLabel] setText:[game title]];
	[[cell missingLabel] setText:[game title]];
	
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
	return UIEdgeInsetsMake(15, 5, 5, 5);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	NSArray *games = [self.gamesInSections objectForKey:[self.sectionInfo objectAtIndex:indexPath.section]];
	
	PVGame *game = games[[indexPath item]];
	
	PVEmulatorViewController *emulatorViewController = [[PVEmulatorViewController alloc] initWithGame:game];
	[emulatorViewController setBatterySavesPath:[self batterySavesPathForROM:[game romPath]]];
	[emulatorViewController setSaveStatePath:[self saveStatePathForROM:[game romPath]]];
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
		
		if ([[game artworkURL] length] && ![[game originalArtworkURL] length])
		{
			[actionSheet PV_addButtonWithTitle:@"Remove Artwork" action:^{
				[PVMediaCache deleteImageForKey:[game artworkURL]];
				[game setArtworkURL:nil];
				[self save:NULL];
				[_collectionView reloadData];
			}];
		}
		
		if ([[game originalArtworkURL] length] &&
			[[game originalArtworkURL] isEqualToString:[game artworkURL]] == NO)
		{
			[actionSheet PV_addButtonWithTitle:@"Restore Original Artwork" action:^{
				[PVMediaCache deleteImageForKey:[game artworkURL]];
				[game setArtworkURL:[game originalArtworkURL]];
				[self save:NULL];
				[_collectionView reloadData];
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
	NSError *error = nil;
	BOOL success = [[NSFileManager defaultManager] removeItemAtPath:[game romPath] error:&error];
	if (!success)
	{
		NSLog(@"Unable to delete rom at path: %@ because: %@", [game romPath], [error localizedDescription]);
	}
	
	success = [[NSFileManager defaultManager] removeItemAtPath:[self saveStatePathForROM:[game romPath]] error:&error];
	if (!success)
	{
		NSLog(@"Unable to delete save states at path: %@ because: %@", [self saveStatePathForROM:[game romPath]], [error localizedDescription]);
	}
	
	success = [[NSFileManager defaultManager] removeItemAtPath:[self batterySavesPathForROM:[game romPath]] error:&error];
	if (!success)
	{
		NSLog(@"Unable to delete battery saves at path: %@ because: %@", [self batterySavesPathForROM:[game romPath]], [error localizedDescription]);
	}
	
	success = [PVMediaCache deleteImageForKey:[game artworkURL]];
	
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
									[group setAssetsFilter:[ALAssetsFilter allPhotos]];
									[group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:[group numberOfAssets] - 1]
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
			NSLog(@"Will delete old store and try again");
			[[NSFileManager defaultManager] removeItemAtURL:storeUrl error:&error];
			
			if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error]) {
				NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
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
