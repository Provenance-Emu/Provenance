//
//  PVmGBAGameCoreBridge+NetplayInternal.h
//  PVCoremGBA
//
//  Emulation-thread hooks between the bridge's frame loop and the link
//  cable. Not in the module map.
//

#pragma once

#import "PVmGBAGameCoreBridge+Netplay.h"

struct mCore;

NS_ASSUME_NONNULL_BEGIN

@interface PVmGBAGameCoreBridge (NetplayInternal)

/// Emulation thread, between frames. Installs or removes the link driver as
/// the session requires, then runs the frame through it.
///
/// Returns NO when no link is installed: the caller runs core->runFrame
/// itself. `frameAdvanced` is NO when the link made the frame stop early
/// (the next call finishes it).
- (BOOL)pvmgba_runLinkedFrame:(struct mCore *)core frameAdvanced:(BOOL *)frameAdvanced;

/// Ends the session and takes the driver out of the core. Call before the
/// core is destroyed.
- (void)pvmgba_detachLinkFromCore:(struct mCore *)core;

@end

NS_ASSUME_NONNULL_END
