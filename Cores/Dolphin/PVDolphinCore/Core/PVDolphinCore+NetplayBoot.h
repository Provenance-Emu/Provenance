//
//  PVDolphinCore+NetplayBoot.h
//  PVDolphin
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Private, Objective-C++ only. Lets the netplay category reboot the running
//  core into a netplay session and back, without the full stopEmulation
//  teardown. Implemented in PVDolphinCore.mm, which owns the boot state
//  (the WindowSystemInfo the core was booted with, the loaded ROM path).
//
//  Every method that stops or boots the core runs on `netplayBootQueue`, a
//  serial queue that is neither main nor one of Dolphin's netplay threads.
//  The netplay category also tears its session down on that queue, so a
//  queued boot never outlives the session it belongs to.
//

#pragma once

#ifndef __cplusplus
#error "PVDolphinCore+NetplayBoot.h is Objective-C++ only."
#endif

#import <Foundation/Foundation.h>
#import <PVDolphin/PVDolphinCore.h>

#include <memory>
#include <string>

#include "Core/Boot/Boot.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVDolphinCoreBridge (NetplayBoot)

/// Serial queue for netplay reboots and session teardown.
@property (nonatomic, readonly) dispatch_queue_t netplayBootQueue;

/// The ROM `loadFileAtPath:` stored.
@property (nonatomic, readonly, nullable) NSString *netplayROMPath;

/// YES from the moment a netplay reboot starts stopping the running game
/// until the next game has booted (or the reboot gave up). A stop seen while
/// it is set is the reboot's own, not the player quitting.
@property (nonatomic, readonly) BOOL netplayRebootInProgress;

/// Runs `block` on `netplayBootQueue` and waits for it; runs it inline when
/// already on that queue.
- (void)performOnNetplayBootQueueAndWait:(dispatch_block_t)block;

/// Boot queue only. Stops the running game and waits until Dolphin is
/// uninitialized. Raises `netplayRebootInProgress` and leaves it up on
/// success; the boot that follows lowers it. Returns NO when the emulator is
/// shutting down, the core never booted, or the stop timed out.
- (BOOL)netplayStopRunningGame;

/// Boot queue only. Boots `path` with the netplay session data, on the
/// surface the core first booted on. Lowers `netplayRebootInProgress`.
/// Returns NO when the emulator is shutting down or Dolphin refuses the boot.
- (BOOL)netplayBootGameAtPath:(const std::string &)path
                      session:(std::unique_ptr<BootSessionData>)session;

/// Boot queue only. Ends a game `netplayBootGameAtPath:session:` started and
/// boots the loaded ROM again, without netplay. Does nothing when no netplay
/// game is running or the emulator is shutting down.
- (void)netplayEndGame;

/// Boot queue only. Stops whatever is running and boots the loaded ROM
/// without netplay. Used when a netplay start fails part way.
- (void)netplayRebootLocalGame;

@end

NS_ASSUME_NONNULL_END
