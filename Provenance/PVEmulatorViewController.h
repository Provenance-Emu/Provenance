//
//  PVEmulatorViewController.h
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JSDPad.h"
#import "JSButton.h"

@interface PVEmulatorViewController : UIViewController <UIActionSheetDelegate, JSDPadDelegate, JSButtonDelegate>

@property (nonatomic, copy) NSString *batterySavesPath;
@property (nonatomic, copy) NSString *saveStatePath;

- (instancetype)initWithROMPath:(NSString *)path;

@end
