//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibretro.h"

#import <PVSupport/PVSupport-Swift.h>

#include "libretro.h"
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include <dynamic/dylib.h>
#include <string/stdstring.h>

#include "command.h"
#include "core_info.h"

#include "managers/state_manager.h"
//#include "audio/audio_driver.h"
//#include "camera/camera_driver.h"
//#include "location/location_driver.h"
//#include "record/record_driver.h"
#include "core.h"
#include "runloop.h"
#include "performance_counters.h"
#include "system.h"
#include "record/record_driver.h"
//#include "queues/message_queue.h"
#include "gfx/video_driver.h"
#include "gfx/video_context_driver.h"
#include "gfx/scaler/scaler.h"
//#include "gfx/video_frame.h"

#include <retro_assert.h>

#include "cores/internal_cores.h"
#include "frontend/frontend_driver.h"
#include "content.h"
#ifdef HAVE_CHEEVOS
#include "cheevos.h"
#endif
#include "retroarch.h"
#include "configuration.h"
#include "general.h"
#include "msg_hash.h"
#include "verbosity.h"

# pragma mark - Save States
@implementation PVLibRetroCore (Saves)

#pragma mark Properties
-(BOOL)supportsSaveStates {
    return core->retro_get_memory_size(0) != 0 && core->retro_get_memory_data(0) != NULL;
}

#pragma mark Methods
- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        // Save
        //  bool retro_serialize_all(DBPArchive& ar, bool unlock_thread)
        return YES;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        BOOL success = NO; // bool retro_unserialize(const void *data, size_t size)
        if (!success) {
            if(error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Failed to save state.",
                    NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
                    NSLocalizedRecoverySuggestionErrorKey: @""
                };
                
                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                
                *error = newError;
            }
        }
        return success;
    }
}
//
//- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
//    return NO;
//}
//
//- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//    block(NO, nil);
//}
//
//- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
//    return NO;
//}
//
//- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//    block(NO, nil);
//}
//
@end
