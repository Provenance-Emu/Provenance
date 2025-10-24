//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVCoreBridgeRetro.h"

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
@implementation PVLibRetroCoreBridge (Saves)

#pragma mark Properties
-(BOOL)supportsSaveStates {
    return core->retro_get_memory_size(0) != 0 && core->retro_get_memory_data(0) != NULL;
}

#pragma mark Methods
- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        if (!core || !core->retro_serialize || !core->retro_serialize_size) {
            if (error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Save states not supported.",
                    NSLocalizedFailureReasonErrorKey: @"Core does not support serialization.",
                    NSLocalizedRecoverySuggestionErrorKey: @"This core does not implement save state functionality."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                    userInfo:userInfo];
                *error = newError;
            }
            return NO;
        }

        // Get the required size for the save state
        size_t serialize_size = core->retro_serialize_size();
        if (serialize_size == 0) {
            if (error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Cannot determine save state size.",
                    NSLocalizedFailureReasonErrorKey: @"Core returned zero size for serialization.",
                    NSLocalizedRecoverySuggestionErrorKey: @"The core may not be properly initialized."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                    userInfo:userInfo];
                *error = newError;
            }
            return NO;
        }

        // Allocate buffer for save state data
        void *serialize_data = malloc(serialize_size);
        if (!serialize_data) {
            if (error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Memory allocation failed.",
                    NSLocalizedFailureReasonErrorKey: @"Could not allocate memory for save state.",
                    NSLocalizedRecoverySuggestionErrorKey: @"Try freeing up memory and try again."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                    userInfo:userInfo];
                *error = newError;
            }
            return NO;
        }

        // Serialize the current state
        BOOL success = core->retro_serialize(serialize_data, serialize_size);

        if (success) {
            // Write the serialized data to file
            NSData *saveData = [NSData dataWithBytes:serialize_data length:serialize_size];
            success = [saveData writeToFile:fileName atomically:YES];

            if (!success && error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Failed to write save state file.",
                    NSLocalizedFailureReasonErrorKey: @"Could not write save state data to disk.",
                    NSLocalizedRecoverySuggestionErrorKey: @"Check file permissions and available disk space."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                    userInfo:userInfo];
                *error = newError;
            }
        } else if (error != NULL) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Core failed to serialize state.",
                NSLocalizedFailureReasonErrorKey: @"The libretro core could not create a save state.",
                NSLocalizedRecoverySuggestionErrorKey: @"The game may be in an invalid state or the core has an issue."
            };

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                userInfo:userInfo];
            *error = newError;
        }

        // Clean up allocated memory
        free(serialize_data);

        return success;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        if (!core || !core->retro_unserialize) {
            if (error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Save states not supported.",
                    NSLocalizedFailureReasonErrorKey: @"Core does not support deserialization.",
                    NSLocalizedRecoverySuggestionErrorKey: @"This core does not implement save state functionality."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            return NO;
        }

        // Check if the save state file exists
        if (![[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
            if (error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Save state file not found.",
                    NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"File does not exist: %@", fileName],
                    NSLocalizedRecoverySuggestionErrorKey: @"Make sure the save state file exists and is accessible."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            return NO;
        }

        // Read the save state data from file
        NSError *readError = nil;
        NSData *saveData = [NSData dataWithContentsOfFile:fileName options:0 error:&readError];

        if (!saveData || readError) {
            if (error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Failed to read save state file.",
                    NSLocalizedFailureReasonErrorKey: readError ? readError.localizedDescription : @"Unknown read error.",
                    NSLocalizedRecoverySuggestionErrorKey: @"Check file permissions and integrity."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            return NO;
        }

        // Validate save state size
        if (saveData.length == 0) {
            if (error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Invalid save state file.",
                    NSLocalizedFailureReasonErrorKey: @"Save state file is empty.",
                    NSLocalizedRecoverySuggestionErrorKey: @"The save state file may be corrupted."
                };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            return NO;
        }

        // Deserialize the save state
        BOOL success = core->retro_unserialize(saveData.bytes, saveData.length);

        if (!success && error != NULL) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Failed to load save state.",
                NSLocalizedFailureReasonErrorKey: @"Core failed to deserialize save state data.",
                NSLocalizedRecoverySuggestionErrorKey: @"The save state may be corrupted or incompatible with this core version."
            };

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];
            *error = newError;
        }

        return success;
    }
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    if (!block) {
        return; // No completion handler provided
    }
    
    // Dispatch save state operation to background queue to avoid blocking UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [self saveStateToFileAtPath:fileName error:&error];
        
        // Call completion handler on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            block(success, error);
        });
    });
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    if (!block) {
        return; // No completion handler provided
    }
    
    // Dispatch load state operation to background queue to avoid blocking UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [self loadStateFromFileAtPath:fileName error:&error];
        
        // Call completion handler on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            block(success, error);
        });
    });
}
//
@end
