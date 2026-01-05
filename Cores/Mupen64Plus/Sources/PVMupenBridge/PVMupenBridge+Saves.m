
//#import "MupenGameCore.h"
#import "PVMupenBridge+Mupen.h"

#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "../Plugins/Core/Core/src/main/version.h"
#import "../Plugins/Core/Core/src/plugin/plugin.h"

@implementation PVMupenBridge (Saves)

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error   {
    NSAssert(NO, @"Shouldn't be here since we overwrite the async call");
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    __block BOOL wasPaused = [self isEmulationPaused];
    [self OE_addHandlerForType:M64CORE_STATE_SAVECOMPLETE usingBlock:
     ^ BOOL (m64p_core_param paramType, int newValue)
     {
         [self setPauseEmulation:wasPaused];
         NSAssert(paramType == M64CORE_STATE_SAVECOMPLETE, @"This block should only be called for save completion!");
         if(newValue == 0)
         {
             if (block) {
                 NSError *error = [NSError errorWithDomain:@"org.openemu.GameCore.ErrorDomain"
                                                      code:-5
                                                  userInfo:@{
                                                             NSLocalizedDescriptionKey : @"Mupen Could not save the current state.",
                                                             NSFilePathErrorKey : fileName
                                                             }];

                 dispatch_async(dispatch_get_main_queue(), ^{
                     block(error);
                 });
             }
             return NO;
         }

         if (block) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 block(nil);
             });
         }
         return NO;
     }];

    BOOL (^scheduleSaveState)(void) = ^ BOOL {
        if(CoreDoCommand(M64CMD_STATE_SAVE, 1, (void *)[fileName fileSystemRepresentation]) == M64ERR_SUCCESS)
        {
            // Mupen needs to run for a bit for the state saving to take place.
            [self setPauseEmulation:NO];
            return YES;
        }

        return NO;
    };

    if(scheduleSaveState()) return;

    [self OE_addHandlerForType:M64CORE_EMU_STATE usingBlock:
     ^ BOOL (m64p_core_param paramType, int newValue)
     {
         NSAssert(paramType == M64CORE_EMU_STATE, @"This block should only be called for load completion!");
         if(newValue != M64EMU_RUNNING && newValue != M64EMU_PAUSED)
             return YES;

         return !scheduleSaveState();
     }];

    [super saveStateToFileAtPath:fileName completionHandler:block];
}


- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error   {
    NSAssert(NO, @"Shouldn't be here since we overwrite the async call");
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block
{
    __block BOOL wasPaused = [self isEmulationPaused];
    __block BOOL completionHandlerCalled = NO;

    /// Register completion handler first to minimize race condition window
    [self OE_addHandlerForType:M64CORE_STATE_LOADCOMPLETE usingBlock:
     ^ BOOL (m64p_core_param paramType, int newValue)
     {
         NSAssert(paramType == M64CORE_STATE_LOADCOMPLETE, @"This block should only be called for load completion!");

         /// Prevent duplicate callbacks
         if (completionHandlerCalled) {
             return NO;
         }
         completionHandlerCalled = YES;

         if(newValue == 0)
         {
             [self setPauseEmulation:wasPaused];
             dispatch_async(dispatch_get_main_queue(), ^{
                 NSError *error = [NSError errorWithDomain:@"org.openemu.GameCore.ErrorDomain"
                                                      code:-3
                                                  userInfo:@{
                                                             NSLocalizedDescriptionKey : @"Mupen Could not load the save state",
                                                             NSLocalizedRecoverySuggestionErrorKey : @"The loaded file is probably corrupted.",
                                                             NSFilePathErrorKey : fileName
                                                             }];
                 block(error);
             });
             return NO;
         }

         /// Allow at least one frame to render before restoring pause state to prevent black screen
         /// This ensures the video buffer is populated before pausing
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             [self setPauseEmulation:wasPaused];
         });

         dispatch_async(dispatch_get_main_queue(), ^{
             block(nil);
         });

         return NO;
     }];

    BOOL (^scheduleLoadState)(void) =
    ^ BOOL {
        if(CoreDoCommand(M64CMD_STATE_LOAD, 1, (void *)[fileName fileSystemRepresentation]) == M64ERR_SUCCESS)
        {
            /// Mupen needs to run for a bit for the state loading to take place.
            [self setPauseEmulation:NO];
            return YES;
        }

        return NO;
    };

    if(scheduleLoadState()) {
        /// Load command succeeded, handler is registered, wait for completion callback
        return;
    }

    /// Load command failed, wait for emulator to be in valid state before retrying
    __block NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    [self OE_addHandlerForType:M64CORE_EMU_STATE usingBlock:
     ^ BOOL (m64p_core_param paramType, int newValue)
     {
         NSAssert(paramType == M64CORE_EMU_STATE, @"This block should only be called for emu state changes!");

         if(newValue != M64EMU_RUNNING && newValue != M64EMU_PAUSED)
             return YES;

         /// Timeout after 5 seconds to prevent hanging
         NSTimeInterval elapsed = [[NSDate date] timeIntervalSince1970] - startTime;
         if (elapsed > 5.0) {
             if (!completionHandlerCalled && block) {
                 completionHandlerCalled = YES;
                 dispatch_async(dispatch_get_main_queue(), ^{
                     NSError *error = [NSError errorWithDomain:@"org.openemu.GameCore.ErrorDomain"
                                                          code:-4
                                                      userInfo:@{
                                                                 NSLocalizedDescriptionKey : @"Mupen Could not load the save state",
                                                                 NSLocalizedRecoverySuggestionErrorKey : @"The emulator did not reach a valid state in time.",
                                                                 NSFilePathErrorKey : fileName
                                                                 }];
                     block(error);
                 });
             }
             return NO;
         }

         BOOL success = scheduleLoadState();
         return !success;
     }];
}


@end
