//
//  PVCloudSavesViewController.m
//  Provenance
//
//  Created by Joshua Delman on 2/24/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVCloudSavesViewController.h"
#import "PVCloudBatterySaves.h"
#import "PVGame.h"


@interface PVCloudSavesViewController ()
@property (strong, nonatomic) PVCloudBatterySaves *saves;
@property (strong, nonatomic) NSArray *localSaveDicts;
@property (strong, nonatomic) NSArray *saveRecordDicts;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation PVCloudSavesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _saves = [[PVCloudBatterySaves alloc] init];
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    
#if !TARGET_OS_TV
    UIRefreshControl *refresher = [UIRefreshControl new];
    [refresher addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresher;
#endif
}

- (void)viewWillAppear:(BOOL)animated {
#if !TARGET_OS_TV
    [self refresh:self.refreshControl];
#else
    [self refresh:nil];
#endif
}

- (NSArray *)getLocalSaves {
    
    // have to run this on the main queue because of realm/PVGame?
    NSLog(@"running on main thread? %i", [NSThread isMainThread]);
    
    NSMutableArray *localSaves = [NSMutableArray new];
    [self.gamesInSections enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSArray *games = (NSArray *)obj;
        [games enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PVGame *game = (PVGame *)obj;
            NSLog(@"ROM path: %@", game.romPath);
            NSString *savePath = [self.gameLibraryVC batterySavesPathForROM:game.romPath];
            NSArray *saveFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:savePath error:nil];
            if ([saveFiles count] == 0) return;
            
            NSString *batterySaveLocal = [NSString pathWithComponents:@[savePath, [saveFiles firstObject]]];
            NSString *batterySaveLocalExt = [[batterySaveLocal componentsSeparatedByString:@"."] lastObject];
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:batterySaveLocal error:nil];
            NSDate *localSaveDate = [attributes fileModificationDate];
            NSString *gamePathName = [[savePath componentsSeparatedByString:@"/"] lastObject];
            
            NSDictionary *doc = @{
                                  @"game": gamePathName,
                                  @"date": localSaveDate,
                                  @"url": [NSURL fileURLWithPath:batterySaveLocal],
                                  @"ext": batterySaveLocalExt
                                  };
            [localSaves addObject:doc];
        }];
    }];
    
    NSLog(@"localSaves: %@", localSaves);
    
    return [NSArray arrayWithArray:localSaves];
}

- (void)refresh:(id)refresher {
#if !TARGET_OS_TV
    refresher = (UIRefreshControl *)refresher;
#endif
    
    if (refresher) {
        [refresher beginRefreshing];
    }
    
    _localSaveDicts = [self getLocalSaves];
    
    [_saves fetchAllRecordsWithCompletion:^(NSArray<CKRecord *> *records) {
        if (refresher) {
            [refresher endRefreshing];
        }
        
        __block NSMutableArray *dicts = [NSMutableArray new];
        [records enumerateObjectsUsingBlock:^(CKRecord * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            CKAsset *saveBinary = [obj objectForKey:@"saveBinary"];
            NSURL *saveBinaryLocalURL = saveBinary.fileURL;
            
            NSDictionary *doc = @{
                                  @"game": [obj objectForKey:@"game"],
                                  @"date": [obj objectForKey:@"dateSave"],
                                  @"ext": [obj objectForKey:@"fileExtension"],
                                  @"url": saveBinaryLocalURL
                                  };
            [dicts addObject:doc];
        }];
        
        _saveRecordDicts = [NSArray arrayWithArray:dicts];
        
        NSLog(@"_saveRecordDicts: %@", _saveRecordDicts);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Remote Records: %@", _saveRecordDicts);
            [self.tableView reloadData];
        });
    }];
}

- (void)copyCloudSave:(NSURL *)cloudURL forGame:(NSString *)game withFileExtension:(NSString *)extension {
    NSString *saveDir = [self.gameLibraryVC batterySavesPathForROM:game];
    NSString *gameWithExtension = [NSString stringWithFormat:@"%@.%@", game, extension];
    NSString *pathStr = [NSString pathWithComponents:@[saveDir, gameWithExtension]];
    NSURL *pathURL = [NSURL fileURLWithPath:pathStr];
    
    // check if file currently exists
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:pathStr];
    NSLog(@"saving to %@; exists already? %li", pathURL, exists);
    
    if (exists) {
        NSLog(@"Removing existing save...");
        NSError *removeError;
        [[NSFileManager defaultManager] removeItemAtURL:pathURL error:&removeError];
        if (removeError) {
            NSLog(@"Error removing file: %@", removeError);
            return;
        }
    }
    
    NSError *fileCopyError;
    [[NSFileManager defaultManager] copyItemAtURL:cloudURL toURL:pathURL error:&fileCopyError];
    if (fileCopyError) {
        NSLog(@"Error copying file: %@", fileCopyError);
    }
}

- (void)copyLocalSave:(NSURL *)localURL forGame:(NSString *)game withFileExtension:(NSString *)extension {
    if ([_saves cloudSaveExistsForGame:game]) {
        // update
        
        [_saves updateRecordForGame:game urlToSaveFile:localURL completionBlock:^(BOOL success) {
            NSLog(@"updated save!");
        }];
    }
    else {
        // create new
        
        [_saves createRecordForGame:game urlToSaveFile:localURL completionBlock:^(BOOL success) {
            NSLog(@"created save!");
        }];
    }
}

# pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Local -> Cloud"
                                                                       message:@"Would you like to copy this game save to the cloud? It will overwrite the existing save in the cloud."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  NSLog(@"Yes");
                                                                  
                                                                  NSDictionary *localDict = [_localSaveDicts objectAtIndex:indexPath.row];
                                                                  [self copyLocalSave:[localDict objectForKey:@"url"] forGame:[localDict objectForKey:@"game"] withFileExtension:[localDict objectForKey:@"ext"]];
                                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                                      [self refresh:nil];
                                                                  });
                                                                  

                                                                  
                                                              }];
        UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            NSLog(@"No");
        }];
        
        [alert addAction:defaultAction];
        [alert addAction:noAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else if (indexPath.section == 1) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Cloud -> Local"
                                                                       message:@"Would you like to copy this cloud game save to your local storage? It will overwrite the existing save."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  NSLog(@"Yes");
                                                                  
                                                                  
                                                                  NSDictionary *cloudDict = [_saveRecordDicts objectAtIndex:indexPath.row];
                                                                  [self copyCloudSave:[cloudDict objectForKey:@"url"] forGame:[cloudDict objectForKey:@"game"] withFileExtension:[cloudDict objectForKey:@"ext"]];
                                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                                      [self.tableView reloadData];
                                                                  });

                                                              }];
        UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            NSLog(@"No");
        }];
        
        [alert addAction:defaultAction];
        [alert addAction:noAction];
        [self presentViewController:alert animated:YES completion:nil];
        
    }
    
    NSLog(@"selected indexPath - %@", indexPath);
}

# pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"saveCell" forIndexPath:indexPath];
        NSDictionary *gameDict = [_localSaveDicts objectAtIndex:indexPath.row];
        
        cell.textLabel.text = [gameDict objectForKey:@"game"];
        cell.detailTextLabel.text = [_dateFormatter stringFromDate:[gameDict objectForKey:@"date"]];
        
        return cell;
    }
    else if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"saveCell" forIndexPath:indexPath];
        NSDictionary *gameDict = [_saveRecordDicts objectAtIndex:indexPath.row];
        
        cell.textLabel.text = [gameDict objectForKey:@"game"];
        cell.detailTextLabel.text = [_dateFormatter stringFromDate:[gameDict objectForKey:@"date"]];
        
        return cell;
    }
    
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [_localSaveDicts count];
    }
    else if (section == 1) {
        return [_saveRecordDicts count];
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Local Saves";
    }
    else if (section == 1) {
        return @"Cloud Saves";
    }
    return nil;
}

@end
