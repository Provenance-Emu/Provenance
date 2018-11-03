//
//  PVFCEUEmulatorCore+Controls.h
//  PVFCEU-iOS
//
//  Created by Joseph Mattiello on 11/3/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

#import <PVFCEU/PVFCEU.h>
#import <PVSupport/PVSupport-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVFCEUEmulatorCore (Controls) <PVNESSystemResponderClient>

- (void)didPushNESButton:(PVNESButton)button forPlayer:(NSInteger)player;
- (void)didReleaseNESButton:(PVNESButton)button forPlayer:(NSInteger)player;

@end

NS_ASSUME_NONNULL_END
