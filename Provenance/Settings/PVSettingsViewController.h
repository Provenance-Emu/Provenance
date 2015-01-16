//
//  PVSettingsViewController.h
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PVSettingsViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UISwitch *autoSaveSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *autoLoadSwitch;
@property (weak, nonatomic) IBOutlet UISlider *opacitySlider;
@property (weak, nonatomic) IBOutlet UISwitch *autoLockSwitch;
@property (weak, nonatomic) IBOutlet UILabel *opacityValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;


- (IBAction)done:(id)sender;

@end
