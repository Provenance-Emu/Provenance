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
    
#if TARGET_OS_TV
    [self.splitViewController setTitle:@"Supported iCade Controllers"];
    [self.tableView setBackgroundColor:[UIColor clearColor]];
    [self.tableView setBackgroundView:nil];
#else
    self.title = @"Supported iCade Controllers";
#endif
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return kICadeControllerSetting_Count;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @"Your controller must be paired with your device in order to work";
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
    [self.navigationController popViewControllerAnimated:YES];
}

@end
