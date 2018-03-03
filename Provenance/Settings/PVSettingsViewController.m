//
//  PVSettingsViewController.m
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVSettingsViewController.h"
#import "PVSettingsModel.h"
#import "Provenance-Swift.h"
#import "PVConflictViewController.h"
#import "PViCadeControllerViewController.h"
#import "PVLicensesViewController.h"
#import <SafariServices/SafariServices.h>
#import "PVWebServer.h"

@interface PVSettingsViewController () <SFSafariViewControllerDelegate>

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
    [self.crtFilterSwitch setOn:[settings crtFilterEnabled]];
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

//Hide Dummy Cell Separator
-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (cell && indexPath.row == 1 && indexPath.section == 4) {
        cell.separatorInset = UIEdgeInsetsMake(0, cell.bounds.size.width, 0, 0);
    } else if (cell && indexPath.row == 2 && indexPath.section == 4) {
        cell.hidden = YES;
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

- (void)viewDidAppear:(BOOL)animated{
// placed for animation use later…
}

- (IBAction)help:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/jasarien/Provenance/wiki"]];
}

- (IBAction)wikiLinkButton:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/jasarien/Provenance/wiki/Importing-ROMs"]];
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

- (IBAction)toggleCRTFilter:(id)sender
{
    [[PVSettingsModel sharedInstance] setCrtFilterEnabled:[self.crtFilterSwitch isOn]];
}

- (IBAction)volumeChanged:(id)sender
{
    [[PVSettingsModel sharedInstance] setVolume:self.volumeSlider.value];
    [self.volumeValueLabel setText:[NSString stringWithFormat:@"%.0f%%", self.volumeSlider.value * 100]];
}

// Show web server (stays on)
- (void)showServer {
	NSString *ipURL = PVWebServer.sharedInstance.URLString;
	SFSafariViewController *safariVC = [[SFSafariViewController alloc]initWithURL:[NSURL URLWithString:ipURL]
                                                          entersReaderIfAvailable:NO];
	safariVC.delegate = self;
	[self presentViewController:safariVC animated:YES completion:nil];
}

- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
	// Load finished
}

// Dismiss and shut down web server
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
	// Done button pressed
	[self.navigationController popViewControllerAnimated:YES];
	[[PVWebServer sharedInstance] stopServers];
	_importLabel.text = @"Web server: OFF";
}

// Show "Web Server Active" alert view
- (void)showServerActiveAlert {
	NSString *message = [NSString stringWithFormat: @"Upload/Download ROMs,\nsaves and cover art at:\n"];
	UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Web Server Active"
																   message: message
															preferredStyle:UIAlertControllerStyleAlert];
	
    UITextView *ipField = [[UITextView alloc] initWithFrame:CGRectMake(20,71,231,70)];
    ipField.backgroundColor = [UIColor clearColor];
    ipField.textAlignment = NSTextAlignmentCenter;
    ipField.font = [UIFont systemFontOfSize:13];
    ipField.textColor = [UIColor grayColor];
    NSString* ipFieldText = [NSString stringWithFormat:@"%@\nWebDav: %@", PVWebServer.sharedInstance.URLString, PVWebServer.sharedInstance.WebDavURLString];
    [ipField setText:ipFieldText];
    [ipField setUserInteractionEnabled:NO];
    [alert.view addSubview:ipField];
	
    UITextView *importNote = [[UITextView alloc] initWithFrame:CGRectMake(2,160,267,44)];
    [importNote setUserInteractionEnabled:NO];
    importNote.font = [UIFont boldSystemFontOfSize:12];
    importNote.textColor = [UIColor whiteColor];
    importNote.textAlignment = NSTextAlignmentCenter;
    importNote.backgroundColor = [UIColor colorWithWhite:.2 alpha:.3];
    importNote.text = @"Check the wiki for information\nabout Importing ROMs.";
    importNote.layer.shadowOpacity = 0.8;
    importNote.layer.shadowRadius = 3.0;
    importNote.layer.cornerRadius = 8.0;
    importNote.layer.shadowColor = [UIColor colorWithWhite:.2 alpha:.7].CGColor;
    importNote.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    [alert.view addSubview:importNote];
    
	[alert addAction:[UIAlertAction actionWithTitle:@"Stop" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		[[PVWebServer sharedInstance] stopServers];
		_importLabel.text = @"Web server: OFF";
	}]];
	
	UIAlertAction *viewAction = [UIAlertAction actionWithTitle: @"View" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *action)
	{
		[self showServer];
	}];
	
	[alert addAction:viewAction];
	
	[self presentViewController:alert animated:YES completion:NULL];
	
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
            if([[PVWebServer sharedInstance] startServers]) {
                _importLabel.text = @"Web server: ON";
                
                //show alert view
                [self showServerActiveAlert];
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
    else if (indexPath.section == 5 && indexPath.row == 0)
    {
        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Refresh Game Library?"
                                                                       message:@"Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NSNotification.PVRefreshLibraryNotification
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
            [PVMediaCache emptyAndReturnError:nil];
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
