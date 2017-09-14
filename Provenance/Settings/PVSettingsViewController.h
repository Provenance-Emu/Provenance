//
//  PVSettingsViewController.h
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Reachability.h"
#import "PVWebServer.h"


@class PVGameImporter;

@interface PVSettingsViewController : UITableViewController {


}

@property (weak, nonatomic) IBOutlet UISwitch *autoSaveSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *autoLoadSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *autoLockSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *vibrateSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *imageSmoothing;
@property (weak, nonatomic) IBOutlet UISlider *opacitySlider;
@property (weak, nonatomic) IBOutlet UILabel *opacityValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UILabel *revisionLabel;
@property (weak, nonatomic) IBOutlet UILabel *modeLabel;
@property (weak, nonatomic) IBOutlet UILabel *iCadeControllerSetting;
@property (weak, nonatomic) IBOutlet UISlider *volumeSlider;
@property (weak, nonatomic) IBOutlet UILabel *volumeValueLabel;
@property (weak, nonatomic) IBOutlet UISwitch *fpsCountSwitch;

@property (nonatomic, strong) PVGameImporter *gameImporter;

- (IBAction)done:(id)sender;

@end
