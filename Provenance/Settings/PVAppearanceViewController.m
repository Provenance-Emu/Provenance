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

@property (nonatomic) UISwitch *hideTitlesSwitch;
@property (nonatomic) UISwitch *recentlyPlayedSwitch;

@end

@implementation PVAppearanceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Appearance";
    
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    
    _hideTitlesSwitch = [UISwitch new];
    _hideTitlesSwitch.onTintColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.99 alpha:1.00];
    [_hideTitlesSwitch setOn:[settings showGameTitles]];
    [_hideTitlesSwitch addTarget:self action:@selector(switchChangedValue:) forControlEvents:UIControlEventValueChanged];
    
    _recentlyPlayedSwitch = [UISwitch new];
    _recentlyPlayedSwitch.onTintColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.99 alpha:1.00];
    [_recentlyPlayedSwitch setOn:[settings showRecentGames]];
    [_recentlyPlayedSwitch addTarget:self action:@selector(switchChangedValue:) forControlEvents:UIControlEventValueChanged];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)switchChangedValue:(UISwitch *)switchItem
{
    if ([switchItem isEqual:_hideTitlesSwitch]) {
        [[PVSettingsModel sharedInstance] setShowGameTitles:[switchItem isOn]];
    } else if ([switchItem isEqual:_recentlyPlayedSwitch]) {
        [[PVSettingsModel sharedInstance] setShowRecentGames:[switchItem isOn]];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kInterfaceDidChangeNotification object:nil];
}

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
            cell.accessoryView = _hideTitlesSwitch;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Show recently played games";
            cell.accessoryView = _recentlyPlayedSwitch;
        }
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

@end
