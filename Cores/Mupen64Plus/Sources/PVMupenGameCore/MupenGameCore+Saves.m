
//#import "MupenGameCore.h"
#import <PVMupen64Plus/PVMupen64Plus-Swift.h>
#import "MupenGameCore+Mupen.h"

#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "Plugins/Core/src/main/version.h"
#import "Plugins/Core/src/plugin/plugin.h"

@implementation MupenGameCore (Saves)

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error   {
    NSAssert(NO, @"Shouldn't be here since we overwrite the async call");
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
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
                     block(YES, nil);
                 });

             }
             return NO;
         }

         if (block) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 block(YES, nil);
             });
         }
         return NO;
     }];

    BOOL (^scheduleSaveState)(void) =
    ^ BOOL {
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

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    __block BOOL wasPaused = [self isEmulationPaused];
    [self OE_addHandlerForType:M64CORE_STATE_LOADCOMPLETE usingBlock:
     ^ BOOL (m64p_core_param paramType, int newValue)
     {
         NSAssert(paramType == M64CORE_STATE_LOADCOMPLETE, @"This block should only be called for load completion!");

         [self setPauseEmulation:wasPaused];
         if(newValue == 0)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 NSError *error = [NSError errorWithDomain:@"org.openemu.GameCore.ErrorDomain"
                                                      code:-3
                                                  userInfo:@{
                                                             NSLocalizedDescriptionKey : @"Mupen Could not load the save state",
                                                             NSLocalizedRecoverySuggestionErrorKey : @"The loaded file is probably corrupted.",
                                                             NSFilePathErrorKey : fileName
                                                             }];
                 block(NO, error);
             });
             return NO;
         }

         dispatch_async(dispatch_get_main_queue(), ^{
             block(YES, nil);
         });

         return NO;
     }];

    BOOL (^scheduleLoadState)(void) =
    ^ BOOL {
        if(CoreDoCommand(M64CMD_STATE_LOAD, 1, (void *)[fileName fileSystemRepresentation]) == M64ERR_SUCCESS)
        {
            // Mupen needs to run for a bit for the state loading to take place.
            [self setPauseEmulation:NO];
            return YES;
        }

        return NO;
    };

    if(scheduleLoadState()) return;

    [self OE_addHandlerForType:M64CORE_EMU_STATE usingBlock:
     ^ BOOL (m64p_core_param paramType, int newValue)
     {
         NSAssert(paramType == M64CORE_EMU_STATE, @"This block should only be called for load completion!");
         if(newValue != M64EMU_RUNNING && newValue != M64EMU_PAUSED)
             return YES;

         return !scheduleLoadState();
     }];
}


@end
