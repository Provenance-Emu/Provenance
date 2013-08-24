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
#import "KGNoise.h"
#import "UIView+FrameAdditions.h"
#import "PVDirectoryWatcher.h"
#import "ArchiveVG.h"
#import "NSFileManager+OEHashingAdditions.h"
#import <CoreData/CoreData.h>
#import "PVGame.h"
#import "PVMediaCache.h"
#import "UIAlertView+BlockAdditions.h"
#import "UIActionSheet+BlockAdditions.h"

@interface PVGameLibraryViewController () {
	
	PVDirectoryWatcher *_watcher;
	
	UICollectionView *_collectionView;
	
	NSManagedObjectContext *_managedObjectContext;
	NSManagedObjectModel *_managedObjectModel;
	NSPersistentStoreCoordinator *_persistentStoreCoordinator;
	
	NSOperationQueue *_artworkDownloadQueue;
}

@property (nonatomic, strong) NSArray *games;

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

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
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
	
	KGNoiseRadialGradientView *backgroundView = [[KGNoiseRadialGradientView alloc] initWithFrame:[[self view] bounds]];
	[backgroundView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[backgroundView setBackgroundColor:[UIColor colorWithWhite:0.05 alpha:0.7]];
	[backgroundView setAlternateBackgroundColor:[UIColor colorWithWhite:0.3 alpha:0.7]];
	[backgroundView setNoiseBlendMode:kCGBlendModeOverlay];
	[backgroundView setNoiseOpacity:0.1];
	[[self view] addSubview:backgroundView];
	
	UIImageView *barShadow = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"bar-shadow"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 0)]];
	[barShadow setWidth:[[self view] bounds].size.width];
	[barShadow setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
	[[self view] addSubview:barShadow];
	
	UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
	_collectionView = [[UICollectionView alloc] initWithFrame:[self.view bounds] collectionViewLayout:layout];
	[_collectionView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[_collectionView setDataSource:self];
	[_collectionView setDelegate:self];
	[_collectionView setBounces:YES];
	[_collectionView setAlwaysBounceVertical:YES];
	
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

- (BOOL)shouldAutorotate
{
	return NO;
}

- (NSString *)romsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
	NSString *romsDirectory = [documentsDirectoryPath stringByAppendingPathComponent:@"roms"];
	
	return romsDirectory;
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
	self.games = [_managedObjectContext executeFetchRequest:request error:&error];
	
	[_collectionView reloadData];
}

- (void)refreshLibrary
{
	NSString *romsPath = [self romsPath];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *contents = [fileManager contentsOfDirectoryAtPath:romsPath error:NULL];
	
	for (NSString *filePath in contents)
	{
		if ([filePath hasSuffix:@".smd"] ||
			[filePath hasSuffix:@".SMD"] ||
			[filePath hasSuffix:@".bin"] ||
			[filePath hasSuffix:@".BIN"])
		{
			NSString *path = [romsPath stringByAppendingPathComponent:filePath];
			NSString *title = [[path lastPathComponent] stringByDeletingPathExtension];
			
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"romPath == %@", path];
			NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass([PVGame class])];
			[request setPredicate:predicate];
			[request setFetchLimit:1];
			
			PVGame *game = nil;
			
			NSArray *results = [_managedObjectContext executeFetchRequest:request error:NULL];
			if ([results count])
			{
				game = results[0];
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
				}
			}

			if (!game)
			{
				//creating
				game = (PVGame *)[NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([PVGame class])
																inManagedObjectContext:_managedObjectContext];
				[game setRomPath:path];
				[game setTitle:title];
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
						
						if ([[game requiresSync] boolValue])
						{
							NSLog(@"about to look up for %@", [game title]);
							[self lookUpInfoForGame:game];
						}
					});
				});
			}
			else
			{
				if ([[game requiresSync] boolValue])
				{
					NSLog(@"about to look up for %@ (not hash route)", [game title]);
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
	[game setIsSyncing:@(YES)];
	[[ArchiveVG throttled] gameInfoByMD5:[game md5]
								  andCRC:[game crc32]
							withCallback:^(id result, NSError *error) {
								NSLog(@"result = %@, error %@", result, [error localizedDescription]);
								if (result)
								{
									[game setTitle:[result objectForKey:AVGGameTitleKey]];
									[game setArtworkURL:[result objectForKey:AVGGameBoxURLStringKey]];
									if ([[game artworkURL] length])
									{
										NSLog(@"About to get art for %@", [game title]);
										[self getArtworkForGame:game fromURL:[NSURL URLWithString:[game artworkURL]]];
									}
									else
									{
										NSLog(@"no art, reloading for %@", [game title]);
										[game setRequiresSync:@(NO)];
										[game setIsSyncing:@(NO)];
										[_collectionView reloadData];
									}
								}
								else
								{
									NSLog(@"no result for %@", [game title]);
									[game setRequiresSync:@(NO)];
									[game setIsSyncing:@(NO)];
									[_collectionView reloadData];
								}
								
								[self save:NULL];
							} usingFormat:AVGOutputFormatXML];
}

- (void)getArtworkForGame:(PVGame *)game fromURL:(NSURL *)url
{
	NSLog(@"Starting Artwork download for %@, %@", [game title], [url absoluteString]);
	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url]
									   queue:_artworkDownloadQueue
						   completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
							   [game setIsSyncing:@(NO)];
							   
							   if ([data length])
							   {
								   UIImage *artwork = [UIImage imageWithData:data];
								   
								   if (artwork)
								   {
									   NSLog(@"got artwork for %@", [game title]);
									   [game setRequiresSync:@(NO)];
									   [PVMediaCache writeImageToDisk:artwork
															   withKey:[url absoluteString]];
								   }
							   }
							   
							   [game setIsSyncing:@(NO)];
							   [self save:NULL];
							   [_collectionView reloadData];
						   }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return [self.games count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	PVGameLibraryCollectionViewCell *cell = [_collectionView dequeueReusableCellWithReuseIdentifier:_reuseIdentifier forIndexPath:indexPath];
	
	PVGame *game = self.games[[indexPath item]];
	
	if ([game artworkURL])
	{
		UIImage *artwork = [PVMediaCache imageForKey:[game artworkURL]];
		if (artwork)
		{
			[[cell imageView] setImage:artwork];
		}
		else
		{
			[[cell imageView] setImage:[UIImage imageNamed:@"blank"]];
		}
	}
	else
	{
		[[cell imageView] setImage:[UIImage imageNamed:@"blank"]];
	}
	
	
	[[cell titleLabel] setText:[game title]];
	
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
	PVGame *game = self.games[[indexPath item]];
	
	PVEmulatorViewController *emulatorViewController = [[PVEmulatorViewController alloc] initWithROMPath:[game romPath]];
	[emulatorViewController setBatterySavesPath:[self batterySavesPathForROM:[game romPath]]];
	[emulatorViewController setSaveStatePath:[self saveStatePathForROM:[game romPath]]];
	
	[self presentViewController:emulatorViewController animated:YES completion:NULL];
}

- (void)longPressRecognized:(UILongPressGestureRecognizer *)recognizer
{
	if ([recognizer state] == UIGestureRecognizerStateBegan)
	{
		__weak PVGameLibraryViewController *weakSelf = self;
		CGPoint point = [recognizer locationInView:_collectionView];
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
		[actionSheet PV_addButtonWithTitle:@"Rename" action:^{
			
		}];
		[actionSheet PV_addDestructiveButtonWithTitle:@"Delete" action:^{
			NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:point];
			PVGame *game = weakSelf.games[[indexPath item]];
			
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
		[actionSheet showInView:self.view];
	}
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

	[self reloadData];
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
