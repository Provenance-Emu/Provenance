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

extern NSString * const PVAutoLoadSaveStateKey;
extern NSString * const PVAskToLoadSaveStateKey;


@interface PVEmulatorViewController : UIViewController <UIActionSheetDelegate, JSDPadDelegate, JSButtonDelegate>

- (instancetype)initWithROMPath:(NSString *)path;

@end
