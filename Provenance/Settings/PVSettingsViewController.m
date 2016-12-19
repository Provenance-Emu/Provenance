//
//  PVSettingsViewController.m
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVSettingsViewController.h"
#import "PVSettingsModel.h"
#import "PVMediaCache.h"
#import "UIAlertView+BlockAdditions.h"
#import "PVGameLibraryViewController.h"
#import "PVConflictViewController.h"
#import "PViCadeControllerViewController.h"
#import "PVLicensesViewController.h"

@interface PVSettingsViewController ()

@end

@implementation PVSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

	self.title = @"Settings";

    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
	[self.autoSaveSwitch setOn:[settings autoSave]];
	[self.autoLoadSwitch setOn:[settings autoLoadAutoSaves]];
	[self.opacitySlider setValue:[settings controllerOpacity]];
	[self.autoLockSwitch setOn:[settings disableAutoLock]];
    [self.vibrateSwitch setOn:[settings buttonVibration]];
    [self.imageSmoothing setOn:[settings imageSmoothing]];
	[self.fpsCountSwitch setOn:[settings showFPSCount]];
    [self.volumeSlider setValue:[settings volume]];
    [self.volumeValueLabel setText:[NSString stringWithFormat:@"%.0f%%", self.volumeSlider.value * 100]];
    [self.opacityValueLabel setText:[NSString stringWithFormat:@"%.0f%%", self.opacitySlider.value * 100]];
	NSString *versionText = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	versionText = [versionText stringByAppendingFormat:@" (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
	[self.versionLabel setText:versionText];
#if DEBUG
    [self.modeLabel setText:@"DEBUG"];
#else
    [self.modeLabel setText:@"RELEASE"];
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    [self.iCadeControllerSetting setText:kIcadeControllerSettingToString([settings iCadeControllerSetting])];
}

- (IBAction)help:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/jasarien/Provenance/wiki"]];
}

- (IBAction)done:(id)sender
{
	[[self presentingViewController] dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)toggleFPSCount:(id)sender
{
    [[PVSettingsModel sharedInstance] setShowFPSCount:[self.fpsCountSwitch isOn]];
}

- (IBAction)toggleAutoSave:(id)sender
{
	[[PVSettingsModel sharedInstance] setAutoSave:[self.autoSaveSwitch isOn]];
}

- (IBAction)toggleAutoLoadAutoSaves:(id)sender
{
	[[PVSettingsModel sharedInstance] setAutoLoadAutoSaves:[self.autoLoadSwitch isOn]];
}

- (IBAction)controllerOpacityChanged:(id)sender
{
    self.opacitySlider.value = floor(self.opacitySlider.value / 0.05) * 0.05;
    [self.opacityValueLabel setText:[NSString stringWithFormat:@"%.0f%%", self.opacitySlider.value * 100]];

	[[PVSettingsModel sharedInstance] setControllerOpacity:self.opacitySlider.value];
}

- (IBAction)toggleAutoLock:(id)sender
{
	[[PVSettingsModel sharedInstance] setDisableAutoLock:[self.autoLockSwitch isOn]];
}

- (IBAction)toggleVibration:(id)sender
{
    [[PVSettingsModel sharedInstance] setButtonVibration:[self.vibrateSwitch isOn]];
}

- (IBAction)toggleSmoothing:(id)sender
{
    [[PVSettingsModel sharedInstance] setImageSmoothing:[self.imageSmoothing isOn]];
}

- (IBAction)volumeChanged:(id)sender
{
    [[PVSettingsModel sharedInstance] setVolume:self.volumeSlider.value];
    [self.volumeValueLabel setText:[NSString stringWithFormat:@"%.0f%%", self.volumeSlider.value * 100]];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 3 && indexPath.row == 0)
    {
        PViCadeControllerViewController *iCadeControllerViewController = [[PViCadeControllerViewController alloc] init];
        [self.navigationController pushViewController:iCadeControllerViewController animated:YES];
    }
    else if(indexPath.section == 4 && indexPath. row == 0) {
        // import/export roms and game saves button
        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];

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
    else if (indexPath.section == 5 && indexPath.row == 0)
    {
        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Refresh Game Library?"
                                                                       message:@"Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshLibraryNotification
                                                                object:nil];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:NULL]];
        [self presentViewController:alert animated:YES completion:NULL];
    }
	else if (indexPath.section == 5 && indexPath.row == 1)
	{
		[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Empty Image Cache?"
                                                                       message:@"Empty the image cache to free up disk space. Images will be redownload on demand."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [PVMediaCache emptyCache];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:NULL]];
        [self presentViewController:alert animated:YES completion:NULL];
	}
    else if (indexPath.section == 5 && indexPath.row == 2)
    {
        PVConflictViewController *conflictViewController = [[PVConflictViewController alloc] initWithGameImporter:self.gameImporter];
        [self.navigationController pushViewController:conflictViewController animated:YES];
    }
    else if (indexPath.section == 7 && indexPath.row == 0) {
        PVLicensesViewController *licensesViewController = [[PVLicensesViewController alloc] init];
        [self.navigationController pushViewController:licensesViewController animated:YES];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated: YES];
    [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)] animated:NO];
}


@end
