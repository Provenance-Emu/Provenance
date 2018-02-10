//
//  PVTVSettingsViewController.m
//  Provenance
//
//  Created by James Addyman on 18/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVTVSettingsViewController.h"
#import "PVSettingsModel.h"
#import "Provenance-Swift.h"
#import "PVGameImporter.h"
#import "PVMediaCache.h"
#import "PVConflictViewController.h"
#import "PVControllerSelectionViewController.h"
#import "Reachability.h"
#import "PVWebServer.h"

// Reduce code, use a macro!
#define BOOL_STRING(boolean) ((NSString*)(boolean ? @"On" : @"Off"))
#define TOGGLE_SETTING(setting, label) \
PVSettingsModel.sharedInstance.setting = !PVSettingsModel.sharedInstance.setting; \
self.label.text = BOOL_STRING(PVSettingsModel.sharedInstance.setting)

@interface PVTVSettingsViewController ()

@property (nonatomic, strong, nonnull) PVGameImporter *gameImporter;

@property (weak, nonatomic) IBOutlet UILabel *autoSaveValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *autoLoadValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *versionValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *revisionLabel;
@property (weak, nonatomic) IBOutlet UILabel *modeValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *showFPSCountValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *iCadeControllerSetting;
@property (weak, nonatomic) IBOutlet UILabel *crtFilterLabel;
@property (weak, nonatomic) IBOutlet UILabel *webDavAlwaysOnValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *webDavAlwaysOnTitleLabel;

@end

@implementation PVTVSettingsViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _gameImporter = [[PVGameImporter alloc] initWithCompletionHandler:nil];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _gameImporter = [[PVGameImporter alloc] initWithCompletionHandler:nil];
    }
    return self;
}

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
    [self.crtFilterLabel setText:([settings crtFilterEnabled]) ? @"On" : @"Off"];
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
    
    [self updateWebDavTitleLabel];
}

- (void)updateWebDavTitleLabel {
    BOOL isAlwaysOn = PVSettingsModel.sharedInstance.webDavAlwaysOn;

    // Set the status indicator text
    _webDavAlwaysOnValueLabel.text = isAlwaysOn ? @"On" : @"Off";
    
    // Use 2 lines if on to make space for the sub title
    _webDavAlwaysOnTitleLabel.numberOfLines = isAlwaysOn ? 2 : 1;
    
    
    // The main title is always present
    NSDictionary<NSAttributedStringKey, id>* firstLineAttributes = @{
                                                                     NSFontAttributeName : [UIFont systemFontOfSize:38]
                                                                     };
    NSMutableAttributedString * titleString = [[NSMutableAttributedString alloc] initWithString:@"Always on WebDav server"
                                                                                     attributes:firstLineAttributes];
    
    // Make a new line sub title with instructions to connect in lighter text
    if (isAlwaysOn) {
        NSString *subTitleText = [NSString stringWithFormat:@"\nPoint a WebDav client to %@", PVWebServer.sharedInstance.WebDavURLString];
        NSDictionary<NSAttributedStringKey, id>* subTitleAttributes = @{
                                                                         NSFontAttributeName : [UIFont systemFontOfSize:26],
                                                                         NSForegroundColorAttributeName : [UIColor grayColor]
                                                                         };
        NSAttributedString * subTitleAttrString = [[NSMutableAttributedString alloc] initWithString:subTitleText
                                                                                         attributes:subTitleAttributes];
        [titleString appendAttributedString:subTitleAttrString];
    }
    
    _webDavAlwaysOnTitleLabel.attributedText = titleString;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch ([indexPath section]) {
        case 0:
            // Emu Settings
            switch ([indexPath row]) {
                case 0:
                    // Auto save
                    TOGGLE_SETTING(autoSave, autoSaveValueLabel);
                    break;
                case 1:
                    // auto load
                    TOGGLE_SETTING(autoLoadAutoSaves, autoLoadValueLabel);
                    break;
                case 2:
                    // CRT Filter
                    TOGGLE_SETTING(crtFilterEnabled, crtFilterLabel);
                    break;
                case 3:
                    // FPS Counter
                    TOGGLE_SETTING(showFPSCount, showFPSCountValueLabel);
                default:
                    break;
            }
            break;
        case 1:
            // iCade Settings
            break;
        case 2:
            // Actions
            switch ([indexPath row]) {
                case 0: {
                    PVSettingsModel.sharedInstance.webDavAlwaysOn = !PVSettingsModel.sharedInstance.webDavAlwaysOn;
                    
                    // Always on WebDav server
                    // Currently this is only exposed on ATV since it would be a drain on battery
                    // for a mobile device to have this on and doesn't seem nearly as useful.
                    // Web dav can still be manually started alone side the web server
                    
                    if (PVSettingsModel.sharedInstance.webDavAlwaysOn && ! PVWebServer.sharedInstance.isWebDavServerRunning) {
                        [PVWebServer.sharedInstance startWebDavServer];
                    } else if (!PVSettingsModel.sharedInstance.webDavAlwaysOn && PVWebServer.sharedInstance.isWebDavServerRunning) {
                        [PVWebServer.sharedInstance stopWebDavServer];
                    }
                    
                    // Update the label to hide / show the instructions to connect
                    [self updateWebDavTitleLabel];

                    break;
                }
                case 1: {
					// Start Webserver
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
                        if([[PVWebServer sharedInstance] startServers]) {                            

                            // get the IP address of the device
                            NSString *webServerAddress = PVWebServer.sharedInstance.URLString;
                            NSString *webDavAddress = PVWebServer.sharedInstance.WebDavURLString;
                            
                            NSString *message = [NSString stringWithFormat: @"Upload/Download ROMs,\nsaves and cover art at:\n%@\n Or WebDav at:\n%@", webServerAddress, webDavAddress];
                            UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Web Server Active"
                                                                                           message: message
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                            [alert addAction:[UIAlertAction actionWithTitle:@"Stop" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                [[PVWebServer sharedInstance] stopServers];
                            }]];
                            [self presentViewController:alert animated:YES completion:NULL];
                        } else {
                            // Display error
                            UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Unable to start web server!"
                                                                                           message: @"Check your network connection or that something isn't already running on required ports 80 & 81"
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            }]];
                            [self presentViewController:alert animated:YES completion:NULL];
                        }
					}
				}
                default:
                    break;
            }
            break;
        case 3:
            // Game Library Settings
            switch ([indexPath row]) {
                case 0: {
                    // Refresh
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
                    // Empty Cache
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
