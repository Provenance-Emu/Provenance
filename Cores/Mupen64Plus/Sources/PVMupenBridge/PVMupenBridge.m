/*
 Copyright (c) 2010, OpenEmu Team
 Modified by: Joseph Mattiello 2018-2025

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// We need to mess with core internals
#define M64P_CORE_PROTOTYPES 1

#define GET_FUNC(type, field, name) \
    ((field = (type)osal_dynlib_getproc(plugin_handle, name)) != NULL)

#import "PVMupenBridge.h"
#import "PVMupen64PlusBridge/PVMupen64PlusBridge-Swift.h"
@import PVSupport;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVEmulatorCore;
@import PVLoggingObjC;
@import PVSettings;

//#import "MupenGameCore+Resources.h"
#import "PVMupenBridge+Controls.h"
#import "PVMupenBridge+Cheats.h"
#import "PVMupenBridge+Mupen.h"
#import "PVMupenBridge+Resources.h"
#import "PVMupenBridge+Saves.h"

#import "api/config.h"
#import "main/rom.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/m64p_types.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "../Plugins/Core/Core/src/main/version.h"
#import "../Plugins/Core/Core/src/plugin/plugin.h"
#if defined(VIDEXT_VULKAN)
//#include <SDL_vulkan.h>
#include <MoltenVK/mvk_vulkan.h>
//#include <vulkan/vulkan.h>
//#include <vulkan/vulkan_beta.h>
//#include <vulkan/vulkan_ios.h>
//#include <vulkan/vulkan_core.h>
//#include <vulkan/vulkan_metal.h>
#endif
//#import "rom.h"
//#import "savestates.h"
//#import "memory.h"
//#import "mupen64plus-core/src/main/main.h"
@import Dispatch;
@import PVSupport;
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
@import OpenGL.GL3;
@import GLUT;
#else
@import OpenGLES.ES3;
@import GLKit;
#endif

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

/// PVMupenBridge
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
@interface PVMupenBridge () <PVN64SystemResponderClient>
#else
@interface PVMupenBridge () <PVN64SystemResponderClient, GLKViewDelegate>
#endif

/// Handles a state change for a parameter
/// @param paramType The parameter type
/// @param newValue The new value of the parameter
- (void)OE_didReceiveStateChangeForParamType:(m64p_core_param)paramType value:(int)newValue;
@end

/// Pointer to the current PVMupenBridge instance
__weak PVMupenBridge *_current = nil;

/// Pointer to the PV_ForceUpdateWindowSize function
static void (*ptr_PV_ForceUpdateWindowSize)(int width, int height);
/// Pointer to the SetOSDCallback function
static void (*ptr_SetOSDCallback)(void (*inPV_OSD_Callback)(const char *_pText, float _x, float _y));

/// Draws the OSD
/// @param _pText The text to draw
/// @param _x The x coordinate
/// @param _y The y coordinate
EXPORT static void PV_DrawOSD(const char *_pText, float _x, float _y)
{
// TODO: This should print on the screen
    NSLog(@"%s", _pText);
}

/// Mupen debug callback
/// @param context The context
/// @param level The level
/// @param message The message
static void MupenDebugCallback(void *context, int level, const char *message)
{
    NSString *messageStr = [NSString stringWithUTF8String:message];

    switch (level) {
        case M64MSG_ERROR:
            ELOG(@"[Mupen Core] %@", messageStr);
            break;
        case M64MSG_WARNING:
            WLOG(@"[Mupen Core] %@", messageStr);
            break;
        case M64MSG_INFO:
            ILOG(@"[Mupen Core] %@", messageStr);
            break;
        case M64MSG_STATUS:
            DLOG(@"[Mupen Core] Status: %@", messageStr);
            break;
        case M64MSG_VERBOSE:
            #if DEBUG
            VLOG(@"[Mupen Core] %@", messageStr);
            #endif
            break;
        default:
            DLOG(@"[Mupen Core] (%d): %@", level, messageStr);
            break;
    }
}

/// Mupen frame callback
/// @param FrameIndex The frame index
static void MupenFrameCallback(unsigned int FrameIndex) {
    if (_current == nil) {
        return;
    }

    [_current videoInterrupt];
}

/// Mupen state callback
/// @param context The context
/// @param paramType The parameter type
/// @param newValue The new value of the parameter
static void MupenStateCallback(void *context, m64p_core_param paramType, int newValue)
{
    NSString *paramName;
    switch (paramType) {
        case M64CORE_EMU_STATE:
            paramName = @"EMU_STATE";
            switch (newValue) {
                case M64EMU_STOPPED: ILOG(@"[Mupen State] Emulator state changed to STOPPED"); break;
                case M64EMU_RUNNING: ILOG(@"[Mupen State] Emulator state changed to RUNNING"); break;
                case M64EMU_PAUSED: ILOG(@"[Mupen State] Emulator state changed to PAUSED"); break;
                default: ILOG(@"[Mupen State] Emulator state changed to UNKNOWN (%d)", newValue); break;
            }
            break;
        case M64CORE_VIDEO_MODE:
            paramName = @"VIDEO_MODE";
            switch (newValue) {
                case M64VIDEO_NONE: ILOG(@"[Mupen State] Video mode changed to NONE"); break;
                case M64VIDEO_WINDOWED: ILOG(@"[Mupen State] Video mode changed to WINDOWED"); break;
                case M64VIDEO_FULLSCREEN: ILOG(@"[Mupen State] Video mode changed to FULLSCREEN"); break;
                default: ILOG(@"[Mupen State] Video mode changed to UNKNOWN (%d)", newValue); break;
            }
            break;
        case M64CORE_SAVESTATE_SLOT:
            paramName = @"SAVESTATE_SLOT";
            ILOG(@"[Mupen State] Savestate slot changed to %d", newValue);
            break;
        case M64CORE_SPEED_FACTOR:
            paramName = @"SPEED_FACTOR";
            ILOG(@"[Mupen State] Speed factor changed to %d", newValue);
            break;
        case M64CORE_SPEED_LIMITER:
            paramName = @"SPEED_LIMITER";
            ILOG(@"[Mupen State] Speed limiter %s", newValue ? "enabled" : "disabled");
            break;
        case M64CORE_VIDEO_SIZE:
            paramName = @"VIDEO_SIZE";
            ILOG(@"[Mupen State] Video size changed (value: %d)", newValue);
            break;
        case M64CORE_AUDIO_VOLUME:
            paramName = @"AUDIO_VOLUME";
            ILOG(@"[Mupen State] Audio volume changed to %d", newValue);
            break;
        case M64CORE_AUDIO_MUTE:
            paramName = @"AUDIO_MUTE";
            ILOG(@"[Mupen State] Audio %s", newValue ? "muted" : "unmuted");
            break;
        case M64CORE_INPUT_GAMESHARK:
            paramName = @"INPUT_GAMESHARK";
            ILOG(@"[Mupen State] Gameshark button %s", newValue ? "pressed" : "released");
            break;
        case M64CORE_STATE_LOADCOMPLETE:
            paramName = @"STATE_LOADCOMPLETE";
            ILOG(@"[Mupen State] State load complete");
            break;
        case M64CORE_STATE_SAVECOMPLETE:
            paramName = @"STATE_SAVECOMPLETE";
            ILOG(@"[Mupen State] State save complete");
            break;
        case M64CORE_SCREENSHOT_CAPTURED:
            paramName = @"M64CORE_SCREENSHOT_CAPTURED";
            ILOG(@"[Mupen State] Screenshot captured");
            break;
        default:
            paramName = [NSString stringWithFormat:@"UNKNOWN(%d)", paramType];
            ILOG(@"[Mupen State] Parameter %d changed to %d", paramType, newValue);
            break;
    }

    // Forward to the instance method
    [((__bridge PVMupenBridge *)context) OE_didReceiveStateChangeForParamType:paramType value:newValue];
}

/// PVMupenBridge
@implementation PVMupenBridge {
    NSData *romData;

    dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
    dispatch_semaphore_t coreWaitToEndFrameSemaphore;

    m64p_emu_state _emulatorState;

    dispatch_queue_t _callbackQueue;
    NSMutableDictionary *_callbackHandlers;

    m64p_dynlib_handle core_handle;

    m64p_dynlib_handle plugins[4];

    // OpenGL context reference (not owned by this class)
    EAGLContext *_externalGLContext;

    // Framebuffer info
    GLuint _defaultFramebuffer;
    BOOL _framebufferInitialized;

    // Refresh rate preference
    int _preferredRefreshRate;

    // Vulkan extension names
    const char **_vulkanExtensionNames;
}

/// Initializes the PVMupenBridge
/// @return The initialized PVMupenBridge
- (instancetype)init {
    if (self = [super init]) {
        mupenWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
        coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);

        [self calculateSize];
//        controllerMode = {PLUGIN_MEMPAK, PLUGIN_MEMPAK, PLUGIN_MEMPAK, PLUGIN_MEMPAK};

        _videoBitDepth = 32; // ignored
        _videoDepthBitDepth = 0; // TODO

        _mupenSampleRate = 44100;

        _isNTSC = YES;

        _callbackQueue = dispatch_queue_create("org.openemu.MupenGameCore.CallbackHandlerQueue", DISPATCH_QUEUE_SERIAL);
        _callbackHandlers = [[NSMutableDictionary alloc] init];

        _inputQueue = [[NSOperationQueue alloc] init];
        _inputQueue.name = @"mupen.input";
        _inputQueue.qualityOfService = NSOperationQueuePriorityHigh;
        _inputQueue.maxConcurrentOperationCount = 4;
    }
    _current = self;
    return self;
}

/// Deallocates the PVMupenBridge
- (void)dealloc {
    CoreShutdown();
    romdatabase_close();
    SetStateCallback(NULL, NULL);
    SetDebugCallback(NULL, NULL);

    [_inputQueue cancelAllOperations];

    [self pluginsUnload];
    [self detachCoreLib];

#if !__has_feature(objc_arc)
    dispatch_release(mupenWaitToBeginFrameSemaphore);
    dispatch_release(coreWaitToEndFrameSemaphore);
#endif
}

/// Calculates the size of the video
-(void)calculateSize {
#if !TARGET_OS_OSX
    if(RESIZE_TO_FULLSCREEN) {
        CGSize size = UIApplication.sharedApplication.keyWindow.bounds.size;
        float widthScale = size.width / WIDTHf;
        float heightScale = size.height / HEIGHTf;
        if (PVSettingsWrapper.integerScaleEnabled) {
            widthScale = floor(widthScale);
            heightScale = floor(heightScale);
        }
        float scale = MAX(MIN(widthScale, heightScale), 1);
        _videoWidth =  scale * WIDTHf;
        _videoHeight = scale * HEIGHTf;
        DLOG(@"Upscaling on: scale rounded to (%f)",scale);
    } else {
        _videoWidth  = WIDTH;
        _videoHeight = HEIGHT;
    }
#else
    _videoWidth  = WIDTH;
    _videoHeight = HEIGHT;
#endif
}

/// Detaches the core library
-(void)detachCoreLib {
    if (core_handle != NULL) {
        // Note: DL close doesn't really work as expected on iOS. The framework will still essentially be loaded
        // take care to reset static variables that are expected to have cleared memory between uses.
        const char* dlError = NULL;
        if(dlclose(core_handle) != 0) {
            dlError = dlerror();
            ELOG(@"Failed to dlclose core framework: %s", dlError ? dlError : "Unknown error");
        } else {
            ILOG(@"dlclosed core framework.");
        }
        core_handle = NULL;
    }
}

// Pass 0 as paramType to receive all state changes.
// Return YES from the block to keep watching the changes.
// Return NO to remove the block after the first received callback.
- (void)OE_addHandlerForType:(m64p_core_param)paramType usingBlock:(BOOL(^)(m64p_core_param paramType, int newValue))block
{
    // If we already have an emulator state, check if the block is satisfied with it or just add it to the queues.
    if(paramType == M64CORE_EMU_STATE && _emulatorState != 0 && !block(M64CORE_EMU_STATE, _emulatorState))
        return;

    dispatch_async(_callbackQueue, ^{
        NSMutableSet *callbacks = _callbackHandlers[@(paramType)];
        if(callbacks == nil)
        {
            callbacks = [[NSMutableSet alloc] init];
            _callbackHandlers[@(paramType)] = callbacks;
        }

        [callbacks addObject:block];
    });
}

/// Handles a state change for a parameter
/// @param paramType The parameter type
/// @param newValue The new value of the parameter
- (oneway void)OE_didReceiveStateChangeForParamType:(m64p_core_param)paramType value:(int)newValue
{
    if(paramType == M64CORE_EMU_STATE) _emulatorState = newValue;

    void(^runCallbacksForType)(m64p_core_param) =
    ^(m64p_core_param type){
        NSMutableSet *callbacks = _callbackHandlers[@(type)];
        [callbacks filterUsingPredicate:
         [NSPredicate predicateWithBlock:
          ^ BOOL (BOOL(^evaluatedObject)(m64p_core_param, int), NSDictionary *bindings)
          {
              return evaluatedObject(paramType, newValue);
          }]];
    };

    dispatch_async(_callbackQueue, ^{
        runCallbacksForType(paramType);
        runCallbacksForType(0);
    });
}

/// Opens the core library
/// @return The handle to the core library
static void *dlopen_myself()
{
    // Clear any previous dlerror
    dlerror();

    Dl_info info;
    if (!dladdr(dlopen_myself, &info)) {
        const char* dlError = dlerror();
        ELOG(@"dladdr failed: %s", dlError ? dlError : "Unknown error");
        return NULL;
    }

    // Clear any previous dlerror again
    dlerror();

    void* handle = dlopen(info.dli_fname, RTLD_LAZY | RTLD_GLOBAL);
    if (handle == NULL) {
        const char* dlError = dlerror();
        ELOG(@"dlopen_myself failed: %s", dlError ? dlError : "Unknown error");
    }

    return handle;
}

/// Loads a ROM file
/// @param path The path to the ROM file
/// @param error Pointer to NSError that will be set if loading fails
/// @return YES if ROM loaded successfully, NO otherwise with error set
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    DLOG(@"[Mupen] Starting loadFileAtPath: %@", path);
    NSBundle *coreBundle = [NSBundle mainBundle];

    NSString *batterySavesDirectory = self.batterySavesPath;
    [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    DLOG(@"[Mupen] Battery saves directory: %@", batterySavesDirectory);

    NSString *romFolder = [path stringByDeletingLastPathComponent];
    NSString *configPath = [romFolder stringByAppendingPathComponent:@"/config/"];
    NSString *dataPath = [romFolder stringByAppendingPathComponent:@"/data/"];
    DLOG(@"[Mupen] ROM folder: %@", romFolder);
    DLOG(@"[Mupen] Config path: %@", configPath);
    DLOG(@"[Mupen] Data path: %@", dataPath);

    // Create config and data paths
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in @[configPath, dataPath]) {
        if (![fileManager fileExistsAtPath:path]) {
            DLOG(@"[Mupen] Creating directory: %@", path);
            NSError *fmError;
            if(![fileManager createDirectoryAtPath:path
                       withIntermediateDirectories:true
                                        attributes:nil
                                             error:&fmError]) {
                ELOG(@"[Mupen] Failed to create path %@: %@", path, fmError.localizedDescription);
                if(error != NULL) { *error = fmError; }
                return false;
            }
        }
    }

    // Create hires folder placement
    DLOG(@"[Mupen] Creating HiRes folder");
    BOOL hiResSuccess = [self createHiResFolder:romFolder];
    if (!hiResSuccess) {
        DLOG(@"[Mupen] Warning: HiRes folder creation may have failed");
    }

    // Copy default ini files to the config path
    DLOG(@"[Mupen] Copying INI files to config path");
    BOOL iniSuccess = [self copyIniFiles:configPath];
    if (!iniSuccess) {
        DLOG(@"[Mupen] Warning: INI file copying to config path may have failed");
    }

    // Rice looks in the data path for some reason
    DLOG(@"[Mupen] Copying INI files to data path");
    BOOL iniDataSuccess = [self copyIniFiles:dataPath];
    if (!iniDataSuccess) {
        DLOG(@"[Mupen] Warning: INI file copying to data path may have failed");
    }

    // 1. FIRST: Initialize the core
    DLOG(@"[Mupen] Initializing Mupen64Plus core");
    NSError *coreError = nil;
    if (![self LoadMupen64PlusCore:configPath dataPath:dataPath error:&coreError]) {
        ELOG(@"[Mupen] Failed to load Mupen64Plus core: %@", coreError);
        if(error != NULL) { *error = coreError; }
        return NO;
    }
    DLOG(@"[Mupen] Core initialized successfully");

    // Disable the built-in speed limiter
    DLOG(@"[Mupen] Disabling built-in speed limiter");
    m64p_error speedLimiterError = CoreDoCommand(M64CMD_CORE_STATE_SET, M64CORE_SPEED_LIMITER, 0);
    if (speedLimiterError != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Failed to disable speed limiter: Error code %d", speedLimiterError);
        // Non-fatal, continue
    }

    // 2. SECOND: Load and open the ROM
    DLOG(@"[Mupen] Loading ROM data from: %@", path);
    romData = [NSData dataWithContentsOfMappedFile:path];
    if (romData == nil || romData.length == 0) {
        ELOG(@"[Mupen] Error loading ROM at path: %@\n File does not exist or is empty.", path);

        if(error != NULL) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Failed to load game.",
                NSLocalizedFailureReasonErrorKey: @"Mupen64Plus could not find the game file.",
                NSLocalizedRecoverySuggestionErrorKey: @"Check the file hasn't been moved or deleted."
            };

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                                userInfo:userInfo];
            *error = newError;
        }
        return NO;
    }
    DLOG(@"[Mupen] ROM data loaded successfully, size: %lu bytes", (unsigned long)[romData length]);

    DLOG(@"[Mupen] Opening ROM with CoreDoCommand");
    m64p_error openStatus = CoreDoCommand(M64CMD_ROM_OPEN, [romData length], (void *)[romData bytes]);
    if (openStatus != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Error opening ROM: Error code %d", openStatus);

        if(error != NULL) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Failed to load game.",
                NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load game.",
                NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:@"Error code: %d - Check the file isn't corrupt and is a supported Mupen64Plus ROM format.", openStatus]
            };

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                                userInfo:userInfo];
            *error = newError;
        }
        return NO;
    }
    DLOG(@"[Mupen] ROM opened successfully");

    DLOG(@"[Mupen] Getting core handle with dlopen_myself");
    core_handle = dlopen_myself();
    if (core_handle == NULL) {
        const char* dlError = dlerror();
        ELOG(@"[Mupen] Error getting core handle: %s", dlError ? dlError : "Unknown error");

        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Failed to load Mupen.",
            NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load itself.",
            NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:@"dlopen error: %s", dlError ? dlError : "Unknown error"]
        };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotStart
                                            userInfo:userInfo];
        *error = newError;
        return NO;
    }
    DLOG(@"[Mupen] Core handle obtained successfully");

    // 3. THIRD: Configure all settings
    DLOG(@"[Mupen] Configuring settings");
    ConfigureAll(romFolder);
    DLOG(@"[Mupen] Settings configured successfully");

    // 4. FOURTH: Load and attach plugins
    DLOG(@"[Mupen] Beginning plugin loading and attachment");

    // Check ROM state before loading plugins
    int romState = 0;
    m64p_error stateQueryError = CoreDoCommand(M64CMD_CORE_STATE_QUERY, M64CMD_ROM_OPEN, &romState);
    if (stateQueryError != M64ERR_SUCCESS || romState == 0) {
        ELOG(@"[Mupen] ROM is not open before loading plugins! State query error: %d (%@), ROM state: %d",
             stateQueryError, [self errorCodeToString:stateQueryError], romState);

        // Try to open the ROM if we have ROM data
        if (romData != nil) {
            ELOG(@"[Mupen] Attempting to open ROM before loading plugins");
            m64p_error openError = CoreDoCommand(M64CMD_ROM_OPEN, (int)[romData length], (void *)[romData bytes]);
            if (openError != M64ERR_SUCCESS) {
                ELOG(@"[Mupen] Failed to open ROM: %d (%@)", openError, [self errorCodeToString:openError]);
                if (error != NULL) {
                    *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                 code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:@{
                                                NSLocalizedDescriptionKey: @"Failed to load game.",
                                                NSLocalizedFailureReasonErrorKey: @"Mupen64Plus could not open the ROM.",
                                                NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:@"ROM open error: %d (%@)",
                                                                                       openError, [self errorCodeToString:openError]]
                                            }];
                }
                return NO;
            }

            // Check ROM state again
            CoreDoCommand(M64CMD_CORE_STATE_QUERY, M64CMD_ROM_OPEN, &romState);
            if (romState == 0) {
                ELOG(@"[Mupen] ROM still not open after explicit open attempt");
                if (error != NULL) {
                    *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                 code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:@{
                                                NSLocalizedDescriptionKey: @"Failed to load game.",
                                                NSLocalizedFailureReasonErrorKey: @"Mupen64Plus could not open the ROM.",
                                                NSLocalizedRecoverySuggestionErrorKey: @"ROM state is still 0 after explicit open attempt"
                                            }];
                }
                return NO;
            }
            DLOG(@"[Mupen] ROM opened successfully before loading plugins");
        } else {
            ELOG(@"[Mupen] No ROM data available to open");
            if (error != NULL) {
                *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                             code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"Failed to load game.",
                                            NSLocalizedFailureReasonErrorKey: @"No ROM data available.",
                                            NSLocalizedRecoverySuggestionErrorKey: @"ROM data is nil"
                                        }];
            }
            return NO;
        }
    } else {
        DLOG(@"[Mupen] ROM is confirmed open before loading plugins");
    }

    // Check emulator state - it should not be running
    int emuState = 0;
    m64p_error emuStateError = CoreDoCommand(M64CMD_CORE_STATE_QUERY, M64CORE_EMU_STATE, &emuState);
    if (emuStateError != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Failed to query emulator state: %d (%@)",
             emuStateError, [self errorCodeToString:emuStateError]);
    } else if (emuState == M64EMU_RUNNING) {
        ELOG(@"[Mupen] Emulator is running before loading plugins, which is not allowed");
        // Try to pause the emulator
        m64p_error pauseError = CoreDoCommand(M64CMD_PAUSE, 0, NULL);
        if (pauseError != M64ERR_SUCCESS) {
            ELOG(@"[Mupen] Failed to pause emulator: %d (%@)",
                 pauseError, [self errorCodeToString:pauseError]);
        }
    }

    // Assistant block to load frameworks
    NSError* (^LoadPlugin)(m64p_plugin_type, NSString *) = ^(m64p_plugin_type pluginType, NSString *pluginName) {
        DLOG(@"[Mupen] Loading plugin: %@ (type: %d)", pluginName, pluginType);

        // Validate plugin type
        if (pluginType != M64PLUGIN_GFX &&
            pluginType != M64PLUGIN_AUDIO &&
            pluginType != M64PLUGIN_INPUT &&
            pluginType != M64PLUGIN_RSP) {
            NSString *errorMessage = [NSString stringWithFormat:@"Invalid plugin type: %d", pluginType];
            ELOG(@"[Mupen] %@", errorMessage);
            return [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                       code:PVEmulatorCoreErrorCodeCouldNotLoadPlugin
                                   userInfo:@{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Invalid plugin type for %@", pluginName],
                                       NSLocalizedRecoverySuggestionErrorKey: errorMessage
                                   }];
        }

        m64p_dynlib_handle plugin_handle;
        NSString *frameworkPath = [NSString stringWithFormat:@"%@.framework/%@", pluginName, pluginName];
        NSBundle *frameworkBundle = [NSBundle mainBundle];
        NSString *pluginPath = [frameworkBundle.privateFrameworksPath stringByAppendingPathComponent:frameworkPath];
        DLOG(@"[Mupen] Plugin path: %@", pluginPath);

        // Check if the plugin path exists
        if (![[NSFileManager defaultManager] fileExistsAtPath:pluginPath]) {
            NSString *errorMessage = [NSString stringWithFormat:@"Plugin file does not exist at path: %@", pluginPath];
            ELOG(@"[Mupen] %@", errorMessage);
            return [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                       code:PVEmulatorCoreErrorCodeCouldNotLoadPlugin
                                   userInfo:@{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Mupen64Plus could not find %@ Plugin.", pluginName],
                                       NSLocalizedRecoverySuggestionErrorKey: errorMessage
                                   }];
        }

        // Clear any previous dlerror
        dlerror();

        // Open the plugin library
        plugin_handle = dlopen([pluginPath fileSystemRepresentation], RTLD_LAZY | RTLD_LOCAL);
        if (plugin_handle == NULL) {
            const char* dlError = dlerror();
            NSString *errorMessage = [NSString stringWithFormat:@"Failed to load plugin: %s", dlError ? dlError : "Unknown error"];
            ELOG(@"[Mupen] %@", errorMessage);
            return [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                       code:PVEmulatorCoreErrorCodeCouldNotLoadPlugin
                                   userInfo:@{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Mupen64Plus failed to load %@ Plugin.", pluginName],
                                       NSLocalizedRecoverySuggestionErrorKey: errorMessage
                                   }];
        }
        DLOG(@"[Mupen] Plugin library opened successfully");

        // Clear any previous dlerror
        dlerror();

        // Get the PluginStartup function pointer directly with dlsym
        DLOG(@"[Mupen] Looking for PluginStartup symbol");
        void* pluginStartupPtr = dlsym(plugin_handle, "PluginStartup");
        const char* dlError = dlerror();
        if (dlError != NULL || pluginStartupPtr == NULL) {
            NSString *errorMessage = [NSString stringWithFormat:@"Could not find PluginStartup symbol: %s", dlError ? dlError : "Unknown error"];
            ELOG(@"[Mupen] %@", errorMessage);
            dlclose(plugin_handle);
            return [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                       code:PVEmulatorCoreErrorCodeCouldNotLoadPlugin
                                   userInfo:@{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Mupen64Plus failed to find PluginStartup in %@ Plugin.", pluginName],
                                       NSLocalizedRecoverySuggestionErrorKey: errorMessage
                                   }];
        }
        DLOG(@"[Mupen] PluginStartup symbol found");

        // Cast the function pointer to the correct type and call it
        typedef m64p_error (*PluginStartupFunc)(m64p_dynlib_handle, void*, void*);
        PluginStartupFunc PluginStartup = (PluginStartupFunc)pluginStartupPtr;

        // Call the startup function
        DLOG(@"[Mupen] Calling PluginStartup");
        m64p_error err = PluginStartup(core_handle, (__bridge void *)self, MupenDebugCallback);
        if (err != M64ERR_SUCCESS) {
            NSString *errorMessage = [NSString stringWithFormat:@"PluginStartup failed with error code: %i (%@)", err, [self errorCodeToString:err]];
            ELOG(@"[Mupen] %@", errorMessage);
            dlclose(plugin_handle);
            return [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                       code:PVEmulatorCoreErrorCodeCouldNotLoadPlugin
                                   userInfo:@{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Mupen64Plus failed to start %@ Plugin.", pluginName],
                                       NSLocalizedRecoverySuggestionErrorKey: errorMessage
                                   }];
        }
        DLOG(@"[Mupen] PluginStartup completed successfully");

        // Store the plugin handle
        plugins[pluginType] = plugin_handle;

        // Attach the plugin to the core
        DLOG(@"[Mupen] Attaching plugin to core (type: %d, handle: %p)", pluginType, plugin_handle);
        m64p_error attachError = CoreAttachPlugin(pluginType, plugin_handle);
        if (attachError != M64ERR_SUCCESS) {
            NSString *errorMessage = [NSString stringWithFormat:@"CoreAttachPlugin failed with error code: %i (%@)", attachError, [self errorCodeToString:attachError]];
            ELOG(@"[Mupen] %@", errorMessage);

            // Try to get more information about the error
            int coreInitialized = 0;
            CoreDoCommand(M64CMD_CORE_STATE_QUERY, M64CORE_EMU_STATE, &coreInitialized);
            ELOG(@"[Mupen] Core state: %d", coreInitialized);

            int romOpen = 0;
            CoreDoCommand(M64CMD_CORE_STATE_QUERY, M64CMD_ROM_OPEN, &romOpen);
            ELOG(@"[Mupen] ROM open state: %d", romOpen);

            // Check if this plugin type is already attached
            void* existingPlugin = plugins[pluginType];
            if (existingPlugin != NULL && existingPlugin != plugin_handle) {
                ELOG(@"[Mupen] A plugin of type %d is already attached (handle: %p)", pluginType, existingPlugin);
            }

            dlclose(plugin_handle);
            return [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                       code:PVEmulatorCoreErrorCodeCouldNotLoadPlugin
                                   userInfo:@{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Mupen64Plus failed to attach %@ Plugin.", pluginName],
                                       NSLocalizedRecoverySuggestionErrorKey: errorMessage
                                   }];
        }
        DLOG(@"[Mupen] Plugin attached successfully");

        return (NSError *)nil;
    };

    // Load Video
    BOOL success = NO;
    NSError *pluginError = nil;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    DLOG(@"[Mupen] Getting best OpenGL context");
    EAGLContext* context = [self bestContext];
    DLOG(@"[Mupen] GLES Version: %d", self.glesVersion);
#endif

    // Video plugin loading
    if(MupenGameCoreOptions.useRice) {
        DLOG(@"[Mupen] Loading Rice video plugin (user preference)");
        pluginError = LoadPlugin(M64PLUGIN_GFX, @"PVMupen64PlusVideoRice");
        success = (pluginError == nil);
        if (success) {
            DLOG(@"[Mupen] Rice video plugin loaded successfully");
            ptr_PV_ForceUpdateWindowSize = dlsym(RTLD_DEFAULT, "_PV_ForceUpdateWindowSize");
            if (ptr_PV_ForceUpdateWindowSize == NULL) {
                DLOG(@"[Mupen] Warning: Could not find _PV_ForceUpdateWindowSize symbol");
            }
        } else {
            ELOG(@"[Mupen] Failed to load Rice video plugin: %@", pluginError);
        }
    } else {
        if(self.glesVersion < GLESVersion3 || sizeof(void*) == 4) {
            DLOG(@"[Mupen] Loading Rice video plugin (fallback due to hardware limitations)");
            pluginError = LoadPlugin(M64PLUGIN_GFX, @"PVMupen64PlusVideoRice");
            success = (pluginError == nil);
            if (success) {
                DLOG(@"[Mupen] Rice video plugin loaded successfully");
                ptr_SetOSDCallback = dlsym(RTLD_DEFAULT, "SetOSDCallback");
                if (ptr_SetOSDCallback == NULL) {
                    DLOG(@"[Mupen] Warning: Could not find SetOSDCallback symbol");
                } else {
                    ptr_SetOSDCallback(PV_DrawOSD);
                }
            } else {
                ELOG(@"[Mupen] Failed to load Rice video plugin: %@", pluginError);
            }
        } else {
            DLOG(@"[Mupen] Loading GLideN64 video plugin");
            pluginError = LoadPlugin(M64PLUGIN_GFX, @"PVMupen64PlusVideoGlideN64");
            success = (pluginError == nil);
            if (success) {
                DLOG(@"[Mupen] GLideN64 video plugin loaded successfully");
                ptr_SetOSDCallback = dlsym(RTLD_DEFAULT, "SetOSDCallback");
                if (ptr_SetOSDCallback == NULL) {
                    DLOG(@"[Mupen] Warning: Could not find SetOSDCallback symbol");
                } else {
                    ptr_SetOSDCallback(PV_DrawOSD);
                }
            } else {
                ELOG(@"[Mupen] Failed to load GLideN64 video plugin: %@", pluginError);
            }
        }
    }

    if (!success) {
        ELOG(@"[Mupen] Video plugin loading failed");
        if(error != NULL) {
            *error = pluginError;
        }
        return NO;
    }

    // Load Audio
    DLOG(@"[Mupen] Setting up audio plugin");
    audio.aiDacrateChanged = MupenAudioSampleRateChanged;
    audio.aiLenChanged = MupenAudioLenChanged;
    audio.initiateAudio = MupenOpenAudio;
    audio.setSpeedFactor = MupenSetAudioSpeed;
    audio.romOpen = (int (*)(void))MupenAudioRomOpen;
    audio.romClosed = MupenAudioRomClosed;

    DLOG(@"[Mupen] Starting audio plugin");
    m64p_error audioStartError = plugin_start(M64PLUGIN_AUDIO);
    if (audioStartError != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Failed to start audio plugin: Error code %d", audioStartError);
        // Non-fatal, continue
    } else {
        DLOG(@"[Mupen] Audio plugin started successfully");
    }

    // Load Input
    DLOG(@"[Mupen] Setting up input plugin");
    input.getKeys = MupenGetKeys;
    input.initiateControllers = MupenInitiateControllers;
    input.controllerCommand = MupenControllerCommand;

    DLOG(@"[Mupen] Starting input plugin");
    m64p_error inputStartError = plugin_start(M64PLUGIN_INPUT);
    if (inputStartError != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Failed to start input plugin: Error code %d", inputStartError);
        // Non-fatal, continue
    } else {
        DLOG(@"[Mupen] Input plugin started successfully");
    }

    // Load RSP
    if(MupenGameCoreOptions.useCXD4) {
        DLOG(@"[Mupen] Configuring CXD4 RSP plugin");
        // Configure if using rsp-cxd4 plugin
        m64p_handle configRSP;
        m64p_error configOpenError = ConfigOpenSection("rsp-cxd4", &configRSP);
        if (configOpenError != M64ERR_SUCCESS) {
            ELOG(@"[Mupen] Failed to open rsp-cxd4 config section: Error code %d", configOpenError);
        }

        int usingHLE = 1; // Set to 0 if using LLE GPU plugin/software rasterizer
        m64p_error configSetError = ConfigSetParameter(configRSP, "DisplayListToGraphicsPlugin", M64TYPE_BOOL, &usingHLE);
        if (configSetError != M64ERR_SUCCESS) {
            ELOG(@"[Mupen] Failed to set rsp-cxd4 parameter: Error code %d", configSetError);
        }

        m64p_error configSaveError = ConfigSaveSection("rsp-cxd4");
        if (configSaveError != M64ERR_SUCCESS) {
            ELOG(@"[Mupen] Failed to save rsp-cxd4 config: Error code %d", configSaveError);
        }

        DLOG(@"[Mupen] Loading CXD4 RSP plugin");
        pluginError = LoadPlugin(M64PLUGIN_RSP, @"PVRSPCXD4");
        success = (pluginError == nil);
        if (success) {
            DLOG(@"[Mupen] CXD4 RSP plugin loaded successfully");
        } else {
            ELOG(@"[Mupen] Failed to load CXD4 RSP plugin: %@", pluginError);
        }
    } else {
        DLOG(@"[Mupen] Loading HLE RSP plugin");
        pluginError = LoadPlugin(M64PLUGIN_RSP, @"PVMupen64PlusRspHLE");
        success = (pluginError == nil);
        if (success) {
            DLOG(@"[Mupen] HLE RSP plugin loaded successfully");
        } else {
            ELOG(@"[Mupen] Failed to load HLE RSP plugin: %@", pluginError);
        }
    }

    if (!success) {
        ELOG(@"[Mupen] RSP plugin loading failed");
        if(error != NULL) {
            *error = pluginError;
        }
        return NO;
    }

#if !TARGET_OS_OSX
    if(RESIZE_TO_FULLSCREEN) {
        DLOG(@"[Mupen] Attempting to resize video to fullscreen");
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        if(keyWindow != nil) {
            CGSize fullScreenSize = keyWindow.bounds.size;
            float widthScale = floor(fullScreenSize.width / WIDTHf);
            float heightScale = floor(fullScreenSize.height / HEIGHTf);
            float scale = MAX(MIN(widthScale, heightScale), 1);
            float widthScaled = scale * WIDTHf;
            float heightScaled = scale * HEIGHTf;

            DLOG(@"[Mupen] Resizing to: %.0f x %.0f", widthScaled, heightScaled);
            [self tryToResizeVideoTo:CGSizeMake(widthScaled, heightScaled)];
        } else {
            DLOG(@"[Mupen] Could not get key window for resizing");
        }
    }
#endif

    // Set up video extension functions
    [self setupVideoExtensionFunctions];

    DLOG(@"[Mupen] ROM loading completed successfully");
    return YES;
}

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
-(EAGLContext*)bestContext {
    EAGLContext* context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    self.glesVersion = GLESVersion3;
    if (context == nil)
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.glesVersion = GLESVersion2;
    }

    return context;
}
#endif

/// Starts the emulation
- (void)startEmulation {
    if(!self.isRunning) {
        void romdatabase_open();
        [super startEmulation];
        [NSThread detachNewThreadSelector:@selector(runMupenEmuThread) toTarget:self withObject:nil];
    }
}

/// Runs the Mupen emulator thread
- (void)runMupenEmuThread {
    @autoreleasepool
    {
        [self.renderDelegate startRenderingOnAlternateThread];
        if(CoreDoCommand(M64CMD_EXECUTE, 0, NULL) != M64ERR_SUCCESS) {
            ELOG(@"Core execture did not exit correctly");
        } else {
            ILOG(@"Core finished executing main");
        }

        if(CoreDetachPlugin(M64PLUGIN_GFX) != M64ERR_SUCCESS) {
            ELOG(@"Failed to detach GFX plugin");
        } else {
            ILOG(@"Detached GFX plugin");
        }

        if(CoreDetachPlugin(M64PLUGIN_RSP) != M64ERR_SUCCESS) {
            ELOG(@"Failed to detach RSP plugin");
        } else {
            ILOG(@"Detached RSP plugin");
        }

        [self pluginsUnload];

        if(CoreDoCommand(M64CMD_ROM_CLOSE, 0, NULL) != M64ERR_SUCCESS) {
            ELOG(@"Failed to close ROM");
        } else {
            ILOG(@"ROM closed");
        }

        // Unlock rendering thread
        dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        [super stopEmulation];

//        if(CoreShutdown() != M64ERR_SUCCESS) {
//            ELOG(@"Core shutdown failed");
//        }else {
//            ILOG(@"Core shutdown successfully");
//        }
    }
}

/// Unloads the plugins
/// @return The final status of the plugins
- (m64p_error)pluginsUnload {
    // shutdown and unload frameworks for plugins

    typedef m64p_error (*ptr_PluginShutdown)(void);
    ptr_PluginShutdown PluginShutdown;
    int i;
    m64p_error finalStatus = M64ERR_SUCCESS;

    /* shutdown each type of plugin */
    for (i = 0; i < 4; i++)
    {
        if (plugins[i] == NULL)
            continue;
        /* call the destructor function for the plugin and release the library */
        PluginShutdown = (ptr_PluginShutdown) osal_dynlib_getproc(plugins[i], "PluginShutdown");
        if (PluginShutdown != NULL) {
            m64p_error status = (*PluginShutdown)();
            if (status == M64ERR_SUCCESS) {
                ILOG(@"Shutdown plugin type %i", i);
            } else {
                ELOG(@"Shutdown plugin type %i failed: %i", i, status);
                finalStatus = status; // Remember the error but continue cleanup
            }
        } else {
            ELOG(@"Could not find PluginShutdown function for plugin type %i", i);
        }

        const char* dlError = NULL;
        if(dlclose(plugins[i]) != 0) {
            dlError = dlerror();
            ELOG(@"Failed to dlclose plugin type %i: %s", i, dlError ? dlError : "Unknown error");
        } else {
            ILOG(@"dlclosed plugin type %i", i);
        }
        plugins[i] = NULL;
    }

    return finalStatus;
}

/// Returns the frame time
/// @return The frame time in seconds
- (dispatch_time_t)frameTime {
    float frameTime = 1.0/[self frameInterval];
    __block BOOL expired = NO;
    dispatch_time_t killTime = dispatch_time(DISPATCH_TIME_NOW, frameTime * NSEC_PER_SEC);
    return killTime;
}

/// Video interrupt
- (void)videoInterrupt {
    dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

    dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, [self frameTime]);
}

/// Swaps the buffers
- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

// Make sure we're properly handling the buffer swapping
//- (void)swapBuffers {
//    // This is handled by VidExt_GL_SwapBuffers in vidext.m
//    // We just need to make sure we're properly signaling that the front buffer is ready
//    [self.frontBufferCondition lock];
//    self.isFrontBufferReady = YES;
//    [self.frontBufferCondition signal];
//    [self.frontBufferCondition unlock];
//}

/// Executes a frame skipping frame
/// @param skip YES to skip frame, NO to execute frame
- (void)executeFrameSkippingFrame:(BOOL)skip {
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
}

/// Executes a frame skipping frame
- (void)executeFrame {
    if (self.isRunning) {
        // Make sure we have the video extension functions set up
        static BOOL videoExtensionSetup = NO;
        if (!videoExtensionSetup) {
            [self setupVideoExtensionFunctions];
            videoExtensionSetup = YES;
        }

        // Make sure the GL context is current before executing the frame
        #if TARGET_OS_TV || TARGET_OS_IOS
        if (self.externalGLContext && [EAGLContext currentContext] != self.externalGLContext) {
            if (![EAGLContext setCurrentContext:self.externalGLContext]) {
                ELOG(@"[Mupen] Failed to set current GL context before executing frame");
            }
        }
        #endif

        // Execute the frame
        m64p_error result = CoreDoCommand(M64CMD_ADVANCE_FRAME, 0, NULL);
        if (result != M64ERR_SUCCESS) {
            ELOG(@"[Mupen] Error executing frame: %@ (%d)",
                 [self errorCodeToString:result], result);
        }
    }
}

/// Sets the pause state of the emulation
/// @param flag YES to pause, NO to resume
- (void)setPauseEmulation:(BOOL)flag
{
    [super setPauseEmulation:flag];
//    [self parseOptions];
// TODO: Fix pause
    CoreDoCommand(M64CMD_PAUSE, flag, NULL);

    if (flag)
    {
        dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
        [self.frontBufferCondition lock];
        [self.frontBufferCondition signal];
        [self.frontBufferCondition unlock];
    }
}

/// Stops the emulation
- (void)stopEmulation {
    [_inputQueue cancelAllOperations];

    CoreDoCommand(M64CMD_STOP, 0, NULL);
    romdatabase_close();

    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];

    [super stopEmulation];
}

/// Resets the emulation
- (void)resetEmulation {
    // FIXME: do we want/need soft reset? It doesn't seem to work well with sending M64CMD_RESET alone
    // FIXME: (astrange) should this method worry about this instance's dispatch semaphores?
    CoreDoCommand(M64CMD_RESET, 1 /* hard reset */, NULL);
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
}

/// Tries to resize the video to the given size
/// @param size The size to resize the video to
- (void)tryToResizeVideoTo:(CGSize)size {
    #if TARGET_OS_IOS || TARGET_OS_TV
    CGFloat screenScale = UIScreen.mainScreen.scale;

    CGSize finalSize;
    if (RESIZE_TO_FULLSCREEN) {
        /// Keep original resolution (native scale)
        finalSize = CGSizeMake(size.width * screenScale, size.height * screenScale);
    } else {
        /// Scale to fill screen
        finalSize = size;
    }

    DLOG(@"Setting video mode size to (%f,%f) with screen scale %f, fullscreen: %d",
         finalSize.width, finalSize.height, screenScale, RESIZE_TO_FULLSCREEN);

    VidExt_SetVideoMode(finalSize.width, finalSize.height, 32, M64VIDEO_FULLSCREEN, 0);
    if (ptr_PV_ForceUpdateWindowSize != nil) {
        ptr_PV_ForceUpdateWindowSize(finalSize.width, finalSize.height);
    }
    #endif
}

/// Returns the audio sample rate
/// @return The audio sample rate in Hz
- (double)audioSampleRate {
    DLOG("Audio Sample Rate: %d", _mupenSampleRate);
    return _mupenSampleRate;
}

/// Returns the number of audio channels
/// @return 2 for stereo, 1 for mono
- (NSUInteger)channelCount {
    return 2;
}

/// Loads the Mupen64Plus core and returns success/failure with error details
/// @param configPath Path to the configuration directory
/// @param dataPath Path to the data directory
/// @param error Pointer to NSError that will be set if loading fails
/// @return YES if core loaded successfully, NO otherwise with error set
- (BOOL)LoadMupen64PlusCore:(NSString *)configPath dataPath:(NSString *)dataPath error:(NSError **)error {
    DLOG(@"[Mupen] LoadMupen64PlusCore: configPath: %@, dataPath: %@", configPath, dataPath);

    // Load the Mupen64Plus core
    m64p_error loaderror = CoreStartup(FRONTEND_API_VERSION,
                                      configPath.fileSystemRepresentation,
                                      dataPath.fileSystemRepresentation,
                                      (__bridge void *)self,
                                      MupenDebugCallback,
                                      (__bridge void *)self,
                                      MupenStateCallback);

    // Check for errors and set NSError if needed
    if (loaderror != M64ERR_SUCCESS) {
        if (error != NULL) {
            NSString *errorMessage = [NSString stringWithFormat:@"CoreStartup failed with error code: %i (%@)",
                                     loaderror, [self errorCodeToString:loaderror]];
            *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                         code:PVEmulatorCoreErrorCodeCouldNotLoadPlugin
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Failed to load Mupen64Plus core.",
                                         NSLocalizedFailureReasonErrorKey: @"The emulator core could not be initialized.",
                                         NSLocalizedRecoverySuggestionErrorKey: errorMessage
                                     }];
        }
        return NO;
    }

    // Set up debug and state callbacks explicitly
    DLOG(@"[Mupen] Setting up debug and state callbacks");
    m64p_error debugCallbackError = SetDebugCallback(MupenDebugCallback, (__bridge void *)self);
    if (debugCallbackError != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Failed to set debug callback: %d (%@)",
             debugCallbackError, [self errorCodeToString:debugCallbackError]);
    } else {
        DLOG(@"[Mupen] Debug callback set successfully");
    }

    m64p_error stateCallbackError = SetStateCallback(MupenStateCallback, (__bridge void *)self);
    if (stateCallbackError != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Failed to set state callback: %d (%@)",
             stateCallbackError, [self errorCodeToString:stateCallbackError]);
    } else {
        DLOG(@"[Mupen] State callback set successfully");
    }

    // Set up video extension functions
    [self setupVideoExtensionFunctions];

    // Set debug level to verbose in debug builds
    #if DEBUG
    DLOG(@"[Mupen] Setting debug level to verbose");
    int debugLevel = M64MSG_VERBOSE;
    m64p_error debugLevelError = CoreDoCommand(M64CMD_CORE_STATE_SET, M64CORE_EMU_STATE, &debugLevel);
    if (debugLevelError != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Failed to set debug level: %d (%@)",
            debugLevelError, [self errorCodeToString:debugLevelError]);
    }
    #endif

    return YES;
}

// Add this method to convert error codes to strings
- (NSString *)errorCodeToString:(m64p_error)errorCode {
    switch (errorCode) {
        case M64ERR_SUCCESS:
            return @"Success";
        case M64ERR_NOT_INIT:
            return @"Not initialized";
        case M64ERR_ALREADY_INIT:
            return @"Already initialized";
        case M64ERR_INCOMPATIBLE:
            return @"Incompatible";
        case M64ERR_INPUT_ASSERT:
            return @"Input assertion failed";
        case M64ERR_INPUT_INVALID:
            return @"Input invalid";
        case M64ERR_INPUT_NOT_FOUND:
            return @"Input not found";
        case M64ERR_NO_MEMORY:
            return @"No memory";
        case M64ERR_FILES:
            return @"File error";
        case M64ERR_INTERNAL:
            return @"Internal error";
        case M64ERR_INVALID_STATE:
            return @"Invalid state";
        case M64ERR_PLUGIN_FAIL:
            return @"Plugin failure";
        case M64ERR_SYSTEM_FAIL:
            return @"System failure";
        case M64ERR_UNSUPPORTED:
            return @"Unsupported";
        case M64ERR_WRONG_TYPE:
            return @"Wrong type";
        default:
            return [NSString stringWithFormat:@"Unknown error code: %d", errorCode];
    }
}

// Setup video extension functions
- (void)setupVideoExtensionFunctions {
    DLOG(@"[Mupen] Setting up video extension functions");

    // Create video extension functions struct
    m64p_video_extension_functions vidExtFunctions;
    memset(&vidExtFunctions, 0, sizeof(vidExtFunctions));

    // Set the number of functions we're implementing
    vidExtFunctions.Functions = 17; // All functions required by the core

    // Assign function pointers - use the existing functions from vidext.m
    vidExtFunctions.VidExtFuncInit = VidExt_Init;
    vidExtFunctions.VidExtFuncInitWithRenderMode = VidExt_InitWithRenderMode;
    vidExtFunctions.VidExtFuncQuit = VidExt_Quit;
    vidExtFunctions.VidExtFuncListModes = VidExt_ListFullscreenModes;
    vidExtFunctions.VidExtFuncListRates = VidExt_ListFullscreenRates;
    vidExtFunctions.VidExtFuncSetMode = (m64p_error (*)(int, int, int, int, int))VidExt_SetVideoMode;
    vidExtFunctions.VidExtFuncSetModeWithRate = (m64p_error (*)(int, int, int, int, int, int))VidExt_SetVideoModeWithRate;
    vidExtFunctions.VidExtFuncGLGetProc = VidExt_GL_GetProcAddress;
    vidExtFunctions.VidExtFuncGLSetAttr = VidExt_GL_SetAttribute;
    vidExtFunctions.VidExtFuncGLGetAttr = VidExt_GL_GetAttribute;
    vidExtFunctions.VidExtFuncGLSwapBuf = VidExt_GL_SwapBuffers;
    vidExtFunctions.VidExtFuncSetCaption = VidExt_SetCaption;
    vidExtFunctions.VidExtFuncToggleFS = VidExt_ToggleFullScreen;
    vidExtFunctions.VidExtFuncResizeWindow = VidExt_ResizeWindow;
    vidExtFunctions.VidExtFuncGLGetDefaultFramebuffer = VidExt_GL_GetDefaultFramebuffer;
#if defined(VIDEXT_VULKAN)
    vidExtFunctions.VidExtFuncVKGetSurface = VidExt_VK_GetSurface;
    vidExtFunctions.VidExtFuncVKGetInstanceExtensions = VidExt_VK_GetInstanceExtensions;
#else
    vidExtFunctions.VidExtFuncVKGetSurface = NULL;
    vidExtFunctions.VidExtFuncVKGetInstanceExtensions = NULL;
#endif

    // Make sure we have a valid GL context before registering the functions
    if (![self findExternalGLContext]) {
        ELOG(@"[Mupen] Failed to find external GL context before setting up video extension functions");
    }

    // Register the video extension functions with the core
    m64p_error result = CoreOverrideVidExt(&vidExtFunctions);
    if (result != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Error setting up video extension functions: %d (%@)",
             result, [self errorCodeToString:result]);
    } else {
        DLOG(@"[Mupen] Successfully set up video extension functions");
    }

    // Initialize with OpenGL render mode
    result = VidExt_InitWithRenderMode(M64P_RENDER_OPENGL);
    if (result != M64ERR_SUCCESS) {
        ELOG(@"[Mupen] Error initializing with OpenGL render mode: %d (%@)",
             result, [self errorCodeToString:result]);
    } else {
        DLOG(@"[Mupen] Successfully initialized with OpenGL render mode");
    }
}

// Improve the findExternalGLContext method to ensure proper GL context setup
- (BOOL)findExternalGLContext {
    DLOG(@"[Mupen] Finding external GL context");

    #if TARGET_OS_TV || TARGET_OS_IOS
    // First check if we should be using Metal instead of OpenGL
    MTKView *mtlView = [self.renderDelegate mtlView];
    if (mtlView) {
        DLOG(@"[Mupen] Found MTKView from render delegate: %@", mtlView);

        // Get the Metal layer from the view on the main thread
        __block CAMetalLayer *metalLayer = nil;
        if ([NSThread isMainThread]) {
            metalLayer = (CAMetalLayer *)mtlView.layer;
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                metalLayer = (CAMetalLayer *)mtlView.layer;
            });
        }

        if (metalLayer) {
            self.metalLayer = metalLayer;
            DLOG(@"[Mupen] Set Metal layer from MTKView: %@", metalLayer);

            // For Metal rendering, we'll use Vulkan mode
            self.renderMode = M64P_RENDER_VULKAN;

            // We don't call startRenderingOnAlternateThread here as it's already called in runMupenEmuThread

            return YES;
        }
    }

    // If we're not using Metal, try to get the framebuffer from the render delegate
    id framebufferObj = [self.renderDelegate presentationFramebuffer];
    if (framebufferObj && [framebufferObj isKindOfClass:[NSNumber class]]) {
        GLuint framebuffer = [(NSNumber *)framebufferObj unsignedIntValue];
        if (framebuffer != 0) {
            DLOG(@"[Mupen] Found external framebuffer from render delegate: %u", framebuffer);
            self.defaultFramebuffer = framebuffer;
            self.framebufferInitialized = YES;

            // Try to get the current GL context
            EAGLContext *currentContext = [EAGLContext currentContext];
            if (currentContext) {
                DLOG(@"[Mupen] Using current GL context: %@", currentContext);
                self.externalGLContext = currentContext;

                // We don't call startRenderingOnAlternateThread here as it's already called in runMupenEmuThread

                return YES;
            } else {
                ELOG(@"[Mupen] Found framebuffer but no current GL context");
            }
        }
    }

    // If we couldn't get the framebuffer from the render delegate, try the current context
    EAGLContext *currentContext = [EAGLContext currentContext];
    if (currentContext) {
        DLOG(@"[Mupen] Using current GL context: %@", currentContext);
        self.externalGLContext = currentContext;

        // Initialize framebuffer if needed
        if (!self.framebufferInitialized) {
            GLint currentFramebuffer = 0;
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &currentFramebuffer);
            self.defaultFramebuffer = (GLuint)currentFramebuffer;

            if (self.defaultFramebuffer != 0) {
                self.framebufferInitialized = YES;
                DLOG(@"[Mupen] Initialized framebuffer: %u", self.defaultFramebuffer);

                // We don't call startRenderingOnAlternateThread here as it's already called in runMupenEmuThread

                return YES;
            } else {
                ELOG(@"[Mupen] No valid framebuffer bound in current GL context");
            }
        }
    }
    #endif

    ELOG(@"[Mupen] No GL context or Metal view found");
    return NO;
}

// Override rendersToOpenGL to return YES
- (BOOL)rendersToOpenGL {
    return YES;
}

@end
