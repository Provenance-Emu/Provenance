//
//  ORSAvailableDevicesTableViewController.h
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Open Reel Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ORSAvailableDevicesTableViewControllerDelegate;

@class MIKMIDIDevice;

@interface ORSAvailableDevicesTableViewController : UITableViewController

@property (nonatomic, weak) id<ORSAvailableDevicesTableViewControllerDelegate>delegate;

@end

@protocol ORSAvailableDevicesTableViewControllerDelegate <NSObject>

@optional
- (void)availableDevicesTableViewController:(ORSAvailableDevicesTableViewController *)controller midiDeviceWasSelected:(MIKMIDIDevice *)device;

@end