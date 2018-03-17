//
//  PVEmulatorViewController.h
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PVEmulatorCore, PVGame, PVEmulatorConfiguration;

#if TARGET_OS_TV
@interface PVEmulatorViewController : GCEventViewController
#else
@interface PVEmulatorViewController : UIViewController
#endif

@property (nonatomic, strong, nullable) PVEmulatorCore *emulatorCore;
@property (nonatomic, strong, nonnull) PVGame *game;
@property (nonatomic, strong, nullable)  NSString *systemID;
@property (nonatomic, copy, nullable) NSString *batterySavesPath;
@property (nonatomic, copy, nullable) NSString *saveStatePath;
@property (nonatomic, copy, nullable) NSString *BIOSPath;
@property (nonatomic, strong, nullable) UIButton *menuButton;

- (instancetype _Nonnull )initWithGame:(PVGame *_Nonnull)game;
- (void)quit;
- (void)quit:(void(^_Nullable)(void))completion;

@end

// Private for Swift
@interface PVEmulatorViewController()
@property (nonatomic, weak, nullable) UIAlertController *menuActionSheet;
@property (nonatomic, assign) BOOL isShowingMenu;
@end
