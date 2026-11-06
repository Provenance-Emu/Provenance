
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

// Readiness uses the same five-second startup allowance as the load path below.
// An accepted engine save has its own completion event and is not timed out here.
static const NSTimeInterval PVMupenSaveReadinessInterval = 5.0;

typedef BOOL (^PVMupenSaveStateHandler)(m64p_core_param, int);

/// All request state is confined to the bridge's serial callback queue.
@interface PVMupenSaveRequest : NSObject
@property (nonatomic, weak) PVMupenBridge *bridge;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) void (^completion)(NSError *);
@property (nonatomic, weak) PVMupenSaveStateHandler handler;
@property (nonatomic) BOOL wasPaused;
@property (nonatomic) BOOL accepted;
@property (nonatomic) BOOL ownsSlot;
@property (nonatomic) BOOL completed;
- (void)begin;
@end

@implementation PVMupenSaveRequest

- (void)finishWithError:(NSError *)error restorePause:(BOOL)restorePause {
    if (self.completed) return;
    self.completed = YES;
    if (self.ownsSlot) [self.bridge OE_releaseSaveStateRequest:self];
    if (restorePause) [self.bridge setPauseEmulation:self.wasPaused];
    [self.bridge OE_removeHandlerForType:0 usingBlock:self.handler];
    self.handler = nil;
    void (^completion)(NSError *) = self.completion;
    self.completion = nil;
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
}

- (NSError *)errorWithDescription:(NSString *)description {
    return [NSError errorWithDomain:@"org.openemu.GameCore.ErrorDomain" code:-5
                           userInfo:@{NSLocalizedDescriptionKey: description, NSFilePathErrorKey: self.fileName}];
}

- (BOOL)scheduleSave {
    if (self.completed || self.accepted) return self.accepted;
    m64p_error error = CoreDoCommand(M64CMD_STATE_SAVE, 1, (void *)self.fileName.fileSystemRepresentation);
    if (error != M64ERR_SUCCESS) return NO;
    self.accepted = YES;
    // The core must advance to write the file and emit SAVECOMPLETE.
    [self.bridge setPauseEmulation:NO];
    return YES;
}

- (void)begin {
    PVMupenSaveStateHandler handler = ^BOOL(m64p_core_param type, int value) {
        if (self.completed) return NO;
        if (!self.ownsSlot) return YES;
        if (type == M64CORE_STATE_SAVECOMPLETE && self.accepted) {
            NSError *error = value == 0 ? [self errorWithDescription:@"Mupen could not save the current state."] : nil;
            [self finishWithError:error restorePause:YES];
        } else if (type == M64CORE_EMU_STATE) {
            if (value == M64EMU_STOPPED) {
                // Restoring an unpaused state here would mark a stopped bridge running again.
                NSString *description = self.accepted
                    ? @"Mupen stopped before save completion was confirmed. The save file may still be written."
                    : @"Mupen stopped before it could accept the save request.";
                [self finishWithError:[self errorWithDescription:description] restorePause:NO];
            } else if (value == M64EMU_RUNNING || value == M64EMU_PAUSED) {
                [self scheduleSave];
            }
        }
        return !self.completed;
    };
    self.handler = handler;
    [self.bridge OE_addHandlerForType:0 usingBlock:handler];
    [self.bridge OE_performCallbackOperation:^{
        if (![self.bridge OE_claimSaveStateRequest:self]) {
            [self finishWithError:[self errorWithDescription:@"Mupen is already saving a state. Try again after that save finishes."] restorePause:NO];
            return;
        }
        self.ownsSlot = YES;
        if ([self scheduleSave]) return;
        // A ready transition may have preceded registration. Query the live engine,
        // rather than waiting for another notification or relying on cached state.
        int state = 0;
        if (CoreDoCommand(M64CMD_CORE_STATE_QUERY, M64CORE_EMU_STATE, &state) == M64ERR_SUCCESS
            && (state == M64EMU_RUNNING || state == M64EMU_PAUSED)) {
            [self scheduleSave];
        }
    } afterDelay:0];
    [self.bridge OE_performCallbackOperation:^{
        if (!self.completed && !self.accepted) {
            [self finishWithError:[self errorWithDescription:@"Mupen did not become ready to save the state."] restorePause:NO];
        }
    } afterDelay:PVMupenSaveReadinessInterval];
}

@end

@implementation PVMupenBridge (Saves)

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error   {
    NSAssert(NO, @"Shouldn't be here since we overwrite the async call");
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    PVMupenSaveRequest *request = [PVMupenSaveRequest new];
    request.bridge = self;
    request.fileName = fileName;
    request.completion = block;
    request.wasPaused = self.isEmulationPaused;
    [request begin];
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
