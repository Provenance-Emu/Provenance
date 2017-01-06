//
//  PVSearchViewController.m
//  Provenance
//
//  Created by James Addyman on 12/06/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVSearchViewController.h"
#import <Realm/Realm.h>
#import "PVGame.h"
#import "PVGameLibraryCollectionViewCell.h"
#import "PVMediaCache.h"
#import "PVEmulatorViewController.h"
#import "PVAppConstants.h"
#import "PVEmulatorConstants.h"
#import "PVEmulatorConfiguration.h"
#import "PVRecentGame.h"
#import "PVControllerManager.h"

@interface PVSearchViewController ()

@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) RLMResults *searchResults;

@end

@implementation PVSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];

	self.realm = [RLMRealm defaultRealm];
	[self.realm refresh];

	[(UICollectionViewFlowLayout *)self.collectionViewLayout setSectionInset:UIEdgeInsetsMake(20, 0, 20, 0)];
	[self.collectionView registerClass:[PVGameLibraryCollectionViewCell class] forCellWithReuseIdentifier:@"SearchResultCell"];
	[self.collectionView setContentInset:UIEdgeInsetsMake(40, 80, 40, 80)];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
	self.searchResults = [[PVGame objectsWhere:@"title CONTAINS[c] %@", [[searchController searchBar] text]] sortedResultsUsingProperty:@"title" ascending:YES];
	[self.collectionView reloadData];
}

- (NSString *)documentsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	return [paths firstObject];
}

- (NSString *)BIOSPathForSystemID:(NSString *)systemID
{
	return [[[self documentsPath] stringByAppendingPathComponent:@"BIOS"] stringByAppendingPathComponent:systemID];
}

- (NSString *)romsPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectoryPath = [paths objectAtIndex:0];

	return [documentsDirectoryPath stringByAppendingPathComponent:@"roms"];
}

- (NSString *)batterySavesPathForROM:(NSString *)romPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
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
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
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

- (void)updateRecentGames:(PVGame *)game
{
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
			[[[PVControllerManager sharedManager] iCadeController] refreshListener];
			[self updateRecentGames:game];
		}
	};

	if (![[self presentedViewController] isKindOfClass:[PVEmulatorViewController class]])
	{
		loadGame();
	}
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return self.searchResults.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	PVGameLibraryCollectionViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"SearchResultCell" forIndexPath:indexPath];
	PVGame *game = [self.searchResults objectAtIndex:[indexPath item]];

    [cell setupWithGame:game];

	[cell setNeedsLayout];

	return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	PVGame *game = [self.searchResults objectAtIndex:[indexPath item]];
	[self loadGame:game];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	return CGSizeMake(250, 360);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
	return 88;
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
	return 30;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(40, 40, 120, 40);
}


@end
