//
//  PViCadeControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 17/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PViCadeControllerViewController.h"
#import "kICadeControllerSetting.h"
#import "PVSettingsModel.h"

@implementation PViCadeControllerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Supported iCade Controllers";
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    [self.navigationItem setLeftBarButtonItem:cancelButton];
}

- (void)cancel:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return kICadeControllerSetting_Count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    if ([indexPath row] == [[PVSettingsModel sharedInstance] iCadeControllerSetting]) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    [[cell textLabel] setText:kIcadeControllerSettingToString((kICadeControllerSetting)[indexPath row])];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[self.tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    [settings setICadeControllerSetting:[indexPath row]];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

@end
