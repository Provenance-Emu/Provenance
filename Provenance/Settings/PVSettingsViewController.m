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

@interface PVSettingsViewController ()

@end

@implementation PVSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    if ((self = [super initWithStyle:style]))
	{
    }
	
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = @"Settings";
	
	if ([UIFont respondsToSelector:NSSelectorFromString(@"preferredFontForTextStyle:")] == NO)
	{
		[[self.navigationController navigationBar] setBarStyle:UIBarStyleBlack];
	}
	
	PVSettingsModel *settings = [PVSettingsModel sharedInstance];
	
	[self.autoSaveSwitch setOn:[settings autoSave]];
	[self.autoLoadSwitch setOn:[settings autoLoadAutoSaves]];
	[self.opacitySlider setValue:[settings controllerOpacity]];
	[self.autoLockSwitch setOn:[settings disableAutoLock]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}

- (IBAction)done:(id)sender
{
	[[self presentingViewController] dismissViewControllerAnimated:YES completion:NULL];
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
	[[PVSettingsModel sharedInstance] setControllerOpacity:[self.opacitySlider value]];
}

- (IBAction)toggleAutoLock:(id)sender
{
	[[PVSettingsModel sharedInstance] setDisableAutoLock:[self.autoLockSwitch isOn]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 2 && indexPath.row == 0)
	{
		[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Empty Image Cache?"
														message:@"Empty the image cache to free up disk space. Images will be redownload on demand."
													   delegate:nil
											  cancelButtonTitle:@"No"
											  otherButtonTitles:@"Yes", nil];
		[alert PV_setCompletionHandler:^(NSUInteger buttonIndex) {
			if (buttonIndex != [alert cancelButtonIndex])
			{
				[PVMediaCache emptyCache];
			}
		}];
		[alert show];
	}
}

@end
