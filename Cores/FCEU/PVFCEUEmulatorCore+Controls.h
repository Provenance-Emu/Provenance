//
//  PVFCEUEmulatorCore+Controls.h
//  PVFCEU-iOS
//
//  Created by Joseph Mattiello on 11/3/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

#import "PVFCEUEmulatorCore.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PVNESSystemResponderClient;
typedef enum PVNESButton: NSInteger PVNESButton;

@interface PVFCEUEmulatorCoreBridge (Controls) <PVNESSystemResponderClient>

- (void)didPushNESButton:(PVNESButton)button forPlayer:(NSInteger)player;
- (void)didReleaseNESButton:(PVNESButton)button forPlayer:(NSInteger)player;

@end

NS_ASSUME_NONNULL_END
