//
//  ORSSoundboardViewController.h
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Open Reel Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ORSAvailableDevicesTableViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ORSSoundboardViewController : UIViewController <ORSAvailableDevicesTableViewControllerDelegate>

- (IBAction)pianoKeyDown:(id)sender;

@property (weak, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (weak, nonatomic) IBOutlet UITextView *textView;

@end
