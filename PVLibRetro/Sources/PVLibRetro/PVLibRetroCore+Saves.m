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
-(BOOL) supportsSaveStates {
    retro_ctx_size_info_t size;
    core_serialize_size(&size);
    
    retro_ctx_memory_info_t memory;
    core_get_memory(&memory);
    return size.size > 0 || memory.data != nil;
}

#pragma mark Methods

- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        retro_ctx_size_info_t size;
        core_serialize_size(&size);

        retro_ctx_serialize_info_t info;
        core_serialize(&info);

        NSError *error = nil;
        NSData *saveStateData = [NSData dataWithBytes:info.data_const length:size.size];
        BOOL success = [saveStateData writeToFile:path
                                          options:NSDataWritingAtomic
                                            error:&error];
        if (!success) {
            ELOG(@"Error saving state: %@", [error localizedDescription]);
            return NO;
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        NSData *saveStateData = [NSData dataWithContentsOfFile:path];
        if (!saveStateData)
        {
            if(error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Failed to load save state.",
                    NSLocalizedFailureReasonErrorKey: @"Genesis failed to read savestate data.",
                    NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                };
                
                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            ELOG(@"Unable to load save state from path: %@", path);
            return NO;
        }
        
        retro_ctx_serialize_info_t info;
        info.size =  [saveStateData length];
        info.data = [saveStateData bytes];
        if (!core_unserialize(&info))
        {
            if(error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Failed to load save state.",
                    NSLocalizedFailureReasonErrorKey: @"Genesis failed to load savestate data.",
                    NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                };
                
                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            DLOG(@"Unable to load save state");
            return NO;
        }
        
        return YES;
    }
}
@end
