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
#import "Reachability.h"
#import "PVWebServer.h"

@interface PVTVSettingsViewController ()

@property (nonatomic, strong) PVGameImporter *gameImporter;

@property (weak, nonatomic) IBOutlet UILabel *autoSaveValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *autoLoadValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *versionValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *revisionLabel;
@property (weak, nonatomic) IBOutlet UILabel *modeValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *showFPSCountValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *iCadeControllerSetting;

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
    [self.showFPSCountValueLabel setText:([settings showFPSCount]) ? @"On" : @"Off"];
	NSString *versionText = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	versionText = [versionText stringByAppendingFormat:@" (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
	[self.versionValueLabel setText:versionText];
#if DEBUG
    [self.modeValueLabel setText:@"DEBUG"];
#else
    [self.modeValueLabel setText:@"RELEASE"];
#endif
    NSString *revisionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Revision"];
    UIColor *color = [UIColor colorWithWhite:0.0 alpha:0.1];

    if ([revisionString length] > 0) {
        [self.revisionLabel setText:revisionString];
    } else {
        [self.revisionLabel setTextColor:color];
        [self.revisionLabel setText:@"(none)"];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.splitViewController.title = @"Settings";
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    [self.iCadeControllerSetting setText:kIcadeControllerSettingToString([settings iCadeControllerSetting])];
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
                case 2:
                    [settings setShowFPSCount:![settings showFPSCount]];
                    [self.showFPSCountValueLabel setText:([settings showFPSCount]) ? @"On" : @"Off"];
                default:
                    break;
            }
            break;
        case 1:
            // icase settings
            break;
        case 2:
            // library settings
            switch ([indexPath row]) {
				case 0: {
					// start webserver
					// Check to see if we are connected to WiFi. Cannot continue otherwise.
					Reachability *reachability = [Reachability reachabilityForInternetConnection];
					[reachability startNotifier];

					NetworkStatus status = [reachability currentReachabilityStatus];

					if (status != ReachableViaWiFi)
					{
						UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Unable to start web server!"
																					   message: @"Your device needs to be connected to a WiFi network to continue!"
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
                case 1: {
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
                case 2: {
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
                case 3: {
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
