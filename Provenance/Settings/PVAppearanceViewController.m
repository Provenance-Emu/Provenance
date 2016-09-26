//
//  PVAppearanceViewController.m
//  Provenance
//
//  Created by Marcel Voß on 22.09.16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVAppearanceViewController.h"
#import "PVSettingsModel.h"
#import "PVAppConstants.h"

@interface PVAppearanceViewController ()

#if !TARGET_OS_TV
@property (nonatomic) UISwitch *hideTitlesSwitch;
@property (nonatomic) UISwitch *recentlyPlayedSwitch;
#endif

@end

@implementation PVAppearanceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Appearance";

#if !TARGET_OS_TV
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    
    _hideTitlesSwitch = [UISwitch new];
    _hideTitlesSwitch.onTintColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.99 alpha:1.00];
    [_hideTitlesSwitch setOn:[settings showGameTitles]];
    [_hideTitlesSwitch addTarget:self action:@selector(switchChangedValue:) forControlEvents:UIControlEventValueChanged];
    
    _recentlyPlayedSwitch = [UISwitch new];
    _recentlyPlayedSwitch.onTintColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.99 alpha:1.00];
    [_recentlyPlayedSwitch setOn:[settings showRecentGames]];
    [_recentlyPlayedSwitch addTarget:self action:@selector(switchChangedValue:) forControlEvents:UIControlEventValueChanged];
#endif

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#if !TARGET_OS_TV
- (void)switchChangedValue:(UISwitch *)switchItem
{
    if ([switchItem isEqual:_hideTitlesSwitch]) {
        [[PVSettingsModel sharedInstance] setShowGameTitles:[switchItem isOn]];
    } else if ([switchItem isEqual:_recentlyPlayedSwitch]) {
        [[PVSettingsModel sharedInstance] setShowRecentGames:[switchItem isOn]];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kInterfaceDidChangeNotification object:nil];
}
#endif

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 2;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"appearanceCell"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"appearanceCell"];
    }
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Show Game Titles";
#if TARGET_OS_TV
            cell.detailTextLabel.text = ([[PVSettingsModel sharedInstance] showGameTitles]) ? @"On" : @"Off";
#else
            cell.accessoryView = _hideTitlesSwitch;
#endif
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Show recently played games";
#if TARGET_OS_TV
            cell.detailTextLabel.text = ([[PVSettingsModel sharedInstance] showRecentGames]) ? @"On" : @"Off";
#else
            cell.accessoryView = _recentlyPlayedSwitch;
#endif
        }
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
#if TARGET_OS_TV
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    PVSettingsModel *settings =  [PVSettingsModel sharedInstance];
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [settings setShowGameTitles:![settings showGameTitles]];
            cell.detailTextLabel.text = ([settings showGameTitles]) ? @"On" : @"Off";
        } else if (indexPath.row == 1) {
            [settings setShowRecentGames:![settings showRecentGames]];
            cell.detailTextLabel.text = ([settings showRecentGames]) ? @"On" : @"Off";
        }
    }
#endif
}

@end
