//
//  PVTVSettingsViewController.m
//  Provenance
//
//  Created by James Addyman on 18/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVTVSettingsViewController.h"
#import "PVSettingsModel.h"
#import "PVGameLibraryViewController.h"
#import "PVGameImporter.h"
#import "PVMediaCache.h"
#import "PVConflictViewController.h"
#import "PVControllerSelectionViewController.h"

@interface PVTVSettingsViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) PVGameImporter *gameImporter;

@end

@implementation PVTVSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Settings";
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            // Emu Settings
            return 3;
            break;
        case 1:
            // Library Settings
            return 3;
            break;
        case 2:
            // Info
            return 2;
        default:
            return 0;
            break;
    }

    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];

    switch ([indexPath section]) {
        case 0:
            // Emu settings
            switch ([indexPath row]) {
                case 0:
                    // Auto Save
                    cell = [tableView dequeueReusableCellWithIdentifier:@"rightDetail"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
                    [[cell textLabel] setText:@"Auto Save"];
                    [[cell detailTextLabel] setText:([settings autoSave]) ? @"On" : @"Off"];
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    return cell;
                    break;
                case 1:
                    // Auto Load Saves
                    cell = [tableView dequeueReusableCellWithIdentifier:@"rightDetail"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
                    [[cell textLabel] setText:@"Automatically Load Saves"];
                    [[cell detailTextLabel] setText:([settings autoLoadAutoSaves]) ? @"On" : @"Off"];
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    return cell;
                    break;
                case 2:
                    // Controllers
                    cell = [tableView dequeueReusableCellWithIdentifier:@"subtitle"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
                    [[cell textLabel] setText:@"Controller Settings"];
                    [[cell detailTextLabel] setText:@"Choose which controller players use"];
                    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                    return cell;
                    break;
                default:
                    break;
            }
            break;
        case 1:
            // Library Settings
            switch ([indexPath row]) {
                case 0:
                    // Refresh
                    cell = [tableView dequeueReusableCellWithIdentifier:@"subtitle"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
                    [[cell textLabel] setText:@"Refresh Game Library"];
                    [[cell detailTextLabel] setText:@"Reimport ROMs (warning: slow)"];
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    return cell;
                    break;
                case 1:
                    // Empty Cache
                    cell = [tableView dequeueReusableCellWithIdentifier:@"subtitle"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
                    [[cell textLabel] setText:@"Empty Image Cache"];
                    [[cell detailTextLabel] setText:@"Images will redownload on demand"];
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    return cell;
                    break;
                case 2:
                    // Conflicts
                    cell = [tableView dequeueReusableCellWithIdentifier:@"subtitle"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
                    [[cell textLabel] setText:@"Manage Conflicts"];
                    [[cell detailTextLabel] setText:@"Manually solve import conflicts"];
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    return cell;
                    break;
                default:
                    break;
            }
            break;
        case 2:
            // Info
            switch ([indexPath row]) {
                case 0:
                    // Version
                    cell = [tableView dequeueReusableCellWithIdentifier:@"rightDetail"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                    [[cell textLabel] setText:@"Version"];
                    [[cell detailTextLabel] setText:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    return cell;
                    break;
                case 1:
                    // Mode
                    cell = [tableView dequeueReusableCellWithIdentifier:@"rightDetail"];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                    [[cell textLabel] setText:@"Mode"];
#if DEBUG
                    [[cell detailTextLabel] setText:@"DEBUG"];
#else
                    [[cell detailTextLabel] setText:@"RELEASE"];
#endif
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    return cell;
                    break;
                default:
                    break;
            }
        default:
            break;
    }

    return nil;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 92;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"EMULATOR SETTINGS";
            break;
        case 1:
            return @"GAME LIBRARY SETTINGS";
            break;
        case 2:
            return @"INFORMATION";
            break;
        default:
            break;
    }

    return @"";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];

    switch ([indexPath section]) {
        case 0:
            // emu settings
            switch ([indexPath row]) {
                case 0:
                    // Auto save
                    [settings setAutoSave:![settings autoSave]];
                    [tableView reloadData];
                    break;
                case 1:
                    // auto load
                    [settings setAutoLoadAutoSaves:![settings autoLoadAutoSaves]];
                    [tableView reloadData];
                    break;
                case 2:
                {
                    // controllers
                    PVControllerSelectionViewController *controllerSelectionViewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:NSStringFromClass([PVControllerSelectionViewController class])];
                    [self.navigationController pushViewController:controllerSelectionViewController animated:YES];
                }
                    break;
                default:
                    break;
            }
            break;
        case 1:
            // library settings
            switch ([indexPath row]) {
                case 0: {
                    // refresh
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Refresh Game Library?"
                                                                                   message:@"Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes."
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshLibraryNotification
                                                                            object:nil];
                    }]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:NULL]];
                    [self presentViewController:alert animated:YES completion:NULL];
                    break;
                }
                case 1: {
                    // empty cache
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Empty Image Cache?"
                                                                                   message:@"Empty the image cache to free up disk space. Images will be redownload on demand."
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [PVMediaCache emptyCache];
                    }]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:NULL]];
                    [self presentViewController:alert animated:YES completion:NULL];
                    break;
                }
                case 2: {
                    PVConflictViewController *conflictViewController = [[PVConflictViewController alloc] initWithGameImporter:self.gameImporter];
                    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:conflictViewController];
                    [self presentViewController:navController animated:YES completion:NULL];
                    break;
                }
                    
                default:
                    break;
            }
            break;
        default:
            break;
    }
}

@end
