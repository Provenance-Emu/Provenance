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

@property (nonatomic, strong) PVGameImporter *gameImporter;

@property (weak, nonatomic) IBOutlet UILabel *autoSaveValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *autoLoadValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *versionValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *modeValueLabel;

@end

@implementation PVTVSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.splitViewController.title = @"Settings";

    [self.tableView setBackgroundView:nil];
    [self.tableView setBackgroundColor:[UIColor clearColor]];

    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    [self.autoSaveValueLabel setText:([settings autoSave]) ? @"On" : @"Off"];
    [self.autoLoadValueLabel setText:([settings autoLoadAutoSaves]) ? @"On" : @"Off"];
    [self.versionValueLabel setText:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
#if DEBUG
    [self.modeValueLabel setText:@"DEBUG"];
#else
    [self.modeValueLabel setText:@"RELEASE"];
#endif
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.splitViewController.title = @"Settings";
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];

    switch ([indexPath section]) {
        case 0:
            // emu settings
            switch ([indexPath row]) {
                case 0:
                    // Auto save
                    [settings setAutoSave:![settings autoSave]];
                    [self.autoSaveValueLabel setText:([settings autoSave]) ? @"On" : @"Off"];
                    break;
                case 1:
                    // auto load
                    [settings setAutoLoadAutoSaves:![settings autoLoadAutoSaves]];
                    [self.autoLoadValueLabel setText:([settings autoLoadAutoSaves]) ? @"On" : @"Off"];
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
                    [self.navigationController pushViewController:conflictViewController animated:YES];
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
