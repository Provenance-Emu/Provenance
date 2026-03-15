/*
 Copyright (c) 2010, OpenEmu Team

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

#import "PVMupenBridge.h"
#import "PVMupen64PlusBridge/PVMupen64PlusBridge-Swift.h"
@import PVSupport;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVEmulatorCore;
@import PVLogging;
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
#import "api/m64p_types.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "../Plugins/Core/Core/src/main/version.h"
#import "../Plugins/Core/Core/src/plugin/plugin.h"
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
#endif

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
@interface PVMupenBridge () <PVN64SystemResponderClient>
#else
@interface PVMupenBridge () <PVN64SystemResponderClient, GLKViewDelegate>
#endif
- (void)OE_didReceiveStateChangeForParamType:(m64p_core_param)paramType value:(int)newValue;
@end

__weak PVMupenBridge *_current = nil;

static void (*ptr_PV_ForceUpdateWindowSize)(int width, int height);
static void (*ptr_SetOSDCallback)(void (*inPV_OSD_Callback)(const char *_pText, float _x, float _y));

EXPORT static void PV_DrawOSD(const char *_pText, float _x, float _y)
{
    NSLog(@"%s", _pText);
    NSString *msg = [NSString stringWithUTF8String:_pText ?: ""];
    if (msg.length > 0) {
        [PVOSDNotification postMessage:msg type:PVOSDTypeInfo duration:3.0];
    }
}

static void MupenDebugCallback(void *context, int level, const char *message)
{
#if DEBUG
    DLOG(@"Mupen (%d): %s", level, message);
#endif
}

static void MupenFrameCallback(unsigned int FrameIndex) {
	if (_current == nil) {
		return;
	}

	[_current videoInterrupt];
}

static void MupenStateCallback(void *context, m64p_core_param paramType, int newValue)
{
    ILOG(@"Mupen: param %d -> %d", paramType, newValue);
    [((__bridge PVMupenBridge *)context) OE_didReceiveStateChangeForParamType:paramType value:newValue];
}

// ---------------------------------------------------------------------------
// Transfer Pak / GB-cart media loader callbacks
// ---------------------------------------------------------------------------
/// Called by the core to ask which GB ROM file should be inserted into
/// controller port `controller_num` (0-based).  Returns a C string owned
/// by the bridge (valid for the duration of the session) or NULL/empty to
/// leave the slot empty.
static char *MupenGetGBCartROM(void *cb_data, int controller_num) {
    if (controller_num < 0 || controller_num >= 4) return NULL;
    PVMupenBridge *bridge = (__bridge PVMupenBridge *)cb_data;
    @synchronized (bridge) {
        return bridge->_gbCartROMCStr[controller_num];
    }
}

/// Called by the core to ask where GB cart RAM (save) data should be
/// persisted.  Returns a C string owned by the bridge or NULL/empty to let
/// the core auto-generate a default save location.
static char *MupenGetGBCartRAM(void *cb_data, int controller_num) {
    if (controller_num < 0 || controller_num >= 4) return NULL;
    PVMupenBridge *bridge = (__bridge PVMupenBridge *)cb_data;
    @synchronized (bridge) {
        return bridge->_gbCartSaveCStr[controller_num];
    }
}

@implementation PVMupenBridge {
    NSData *romData;

    dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
    dispatch_semaphore_t coreWaitToEndFrameSemaphore;

    m64p_emu_state _emulatorState;

    dispatch_queue_t _callbackQueue;
    NSMutableDictionary *_callbackHandlers;

    m64p_dynlib_handle core_handle;

    m64p_dynlib_handle plugins[4];
}

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

- (void)dealloc {
    CoreShutdown();
    romdatabase_close();
    SetStateCallback(NULL, NULL);
    SetDebugCallback(NULL, NULL);

    [_inputQueue cancelAllOperations];

    [self pluginsUnload];
    [self detachCoreLib];

    // Free strdup-allocated Transfer Pak C-string caches.
    for (int i = 0; i < 4; i++) {
        if (_gbCartROMCStr[i])  { free(_gbCartROMCStr[i]);  _gbCartROMCStr[i]  = NULL; }
        if (_gbCartSaveCStr[i]) { free(_gbCartSaveCStr[i]); _gbCartSaveCStr[i] = NULL; }
    }

#if !__has_feature(objc_arc)
    dispatch_release(mupenWaitToBeginFrameSemaphore);
    dispatch_release(coreWaitToEndFrameSemaphore);
#endif
}

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

-(void)detachCoreLib {
    if (core_handle != NULL) {
        // Note: DL close doesn't really work as expected on iOS. The framework will still essentially be loaded
        // take care to reset static variables that are expected to have cleared memory between uses.
        if(dlclose(core_handle) != 0) {
            ELOG(@"Failed to dlclose core framework.");
        } else {
            ILOG(@"dlclosed core framework.");
        }
        core_handle = NULL;

//        [_callbackHandlers removeAllObjects];
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

static void *dlopen_myself()
{
    Dl_info info;

    dladdr(dlopen_myself, &info);

    return dlopen(info.dli_fname, RTLD_LAZY | RTLD_GLOBAL);
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    NSBundle *coreBundle = [NSBundle mainBundle];

    NSString *batterySavesDirectory = self.batterySavesPath;
    [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];

	NSString *romFolder = [path stringByDeletingLastPathComponent];
	NSString *configPath = [romFolder stringByAppendingPathComponent:@"/config/"];
	NSString *dataPath = [romFolder stringByAppendingPathComponent:@"/data/"];

	// Create config and data paths
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for (NSString *path in @[configPath, dataPath]) {
		if (![fileManager fileExistsAtPath:configPath]) {
			NSError *fmError;
			if(![fileManager createDirectoryAtPath:configPath
					   withIntermediateDirectories:true
										attributes:nil
											 error:&fmError]) {
				ELOG(@"Filed to create path. %@", fmError.localizedDescription);
                if(error != NULL) { *error = fmError; }
                return false;
			}
		}
	}

    [self parseOptions];

    NSError *copyError = nil;
	// Create hires folder placement
//	BOOL err =
    [self createHiResFolder:romFolder];
//    if (!err) {
//        ELOG(@"%@", [copyError localizedDescription]);
//        if(error != NULL) { *error = copyError; }
//        return false;
//    }

	// Copy default ini files to the config path
//    BOOL err2 =
    [self copyIniFiles:configPath];
//    if (!err2) {
//        ELOG(@"%@", [copyError localizedDescription]);
//        if(error != NULL) { *error = copyError; }
//        return false;
//    }

	// Rice looks in the data path for some reason, fuck it copy it there too - joe m
//    BOOL err3 =
    [self copyIniFiles:dataPath];
//    if (!err3) {
//        ELOG(@"%@", [copyError localizedDescription]);
//        if(error != NULL) { *error = copyError; }
//        return false;
//    }

	// Setup configs
	ConfigureAll(romFolder);

	// open core here
	CoreStartup(FRONTEND_API_VERSION, configPath.fileSystemRepresentation, dataPath.fileSystemRepresentation, (__bridge void *)self, MupenDebugCallback, (__bridge void *)self, MupenStateCallback);

    // Register Transfer Pak media loader so the core can request GB cart ROM/RAM paths.
    // Slots without a cart return NULL, which the core treats as "no cartridge inserted".
    m64p_media_loader mediaLoader;
    mediaLoader.cb_data      = (__bridge void *)self;
    mediaLoader.get_gb_cart_rom = MupenGetGBCartROM;
    mediaLoader.get_gb_cart_ram = MupenGetGBCartRAM;
    m64p_error mediaLoaderStatus = CoreDoCommand(M64CMD_SET_MEDIA_LOADER, sizeof(m64p_media_loader), &mediaLoader);
    if (mediaLoaderStatus != M64ERR_SUCCESS) {
        WLOG(@"Failed to register Transfer Pak media loader (error %d) — Transfer Pak support will be unavailable", mediaLoaderStatus);
    } else {
        ILOG(@"Transfer Pak media loader registered successfully");
    }

	// Setup configs
	ConfigureAll(romFolder);

	// Disable the built in speed limiter
	CoreDoCommand(M64CMD_CORE_STATE_SET, M64CORE_SPEED_LIMITER, 0);

    // Load ROM
    romData = [NSData dataWithContentsOfMappedFile:path];
	if (romData == nil || romData.length == 0) {
		ELOG(@"Error loading ROM at path: %@\n File does not exist.", path);

		if(error != NULL) {
		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to load game.",
								   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus find the game file.",
								   NSLocalizedRecoverySuggestionErrorKey: @"Check the file hasn't been moved or deleted."
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotLoadRom
											userInfo:userInfo];

		*error = newError;
		}
		return NO;
	}

    m64p_error openStatus = CoreDoCommand(M64CMD_ROM_OPEN, [romData length], (void *)[romData bytes]);
    if ( openStatus != M64ERR_SUCCESS) {
        ELOG(@"Error loading ROM at path: %@\n Error code was: %i", path, openStatus);

		if(error != NULL) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load game.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported Mupen64Plus ROM format."
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];

        *error = newError;
		}
        return NO;
    }

	core_handle = dlopen_myself();

//	m64p_error callbackStatus = CoreDoCommand(M64CMD_SET_FRAME_CALLBACK, 0, (void *)MupenFrameCallback);
//	if ( callbackStatus != M64ERR_SUCCESS) {
//		ELOG(@"Error setting video callback: %@\n Error code was: %i", path, openStatus);
//
//		NSDictionary *userInfo = @{
//								   NSLocalizedDescriptionKey: @"Failed to load game.",
//								   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load game.",
//								   NSLocalizedRecoverySuggestionErrorKey: @"The video system is invalid. Developer error. Kill the developer."
//								   };
//
//		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
//												code:PVEmulatorCoreErrorCodeCouldNotStart
//											userInfo:userInfo];
//
//		*error = newError;
//
//		return NO;
//	}

    // Assistane block to load frameworks
    BOOL (^LoadPlugin)(m64p_plugin_type, NSString *) = ^(m64p_plugin_type pluginType, NSString *pluginName){
        m64p_dynlib_handle rsp_handle;
        NSString *frameworkPath = [NSString stringWithFormat:@"%@.framework/%@", pluginName,pluginName];
        NSBundle *frameworkBundle = [NSBundle mainBundle]; //[NSBundle bundleWithIdentifier:@"org.provenance-emu.Cores"];
        NSString *rspPath = [frameworkBundle.privateFrameworksPath stringByAppendingPathComponent:frameworkPath];

        rsp_handle = dlopen([rspPath fileSystemRepresentation], RTLD_LAZY | RTLD_LOCAL);
        ptr_PluginStartup rsp_start = osal_dynlib_getproc(rsp_handle, "PluginStartup");
        m64p_error err = rsp_start(core_handle, (__bridge void *)self, MupenDebugCallback);
        if (err != M64ERR_SUCCESS) {
            ELOG(@"Error code %i loading plugin of type %i, name: %@", err, pluginType, pluginType);
            return NO;
        }

        err = CoreAttachPlugin(pluginType, rsp_handle);
        if (err != M64ERR_SUCCESS) {
            ELOG(@"Error code %i attaching plugin of type %i, name: %@", err, pluginType, pluginType);
            return NO;
        }

        // Store handle for later unload
        plugins[pluginType] = rsp_handle;

        return YES;
    };

    // Load Video

	BOOL success = NO;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
	EAGLContext* context = [self bestContext];
#endif

    if(MupenGameCoreOptions.useRice) {
        success = LoadPlugin(M64PLUGIN_GFX, @"PVMupen64PlusVideoRice");
        ptr_PV_ForceUpdateWindowSize = dlsym(RTLD_DEFAULT, "_PV_ForceUpdateWindowSize");
    } else {
        if(self.glesVersion < GLESVersion3 || sizeof(void*) == 4) {
            ILOG(@"No 64bit or GLES3. Using RICE GFX plugin.");
            success = LoadPlugin(M64PLUGIN_GFX, @"PVMupen64PlusVideoRice");
            ptr_PV_ForceUpdateWindowSize = dlsym(RTLD_DEFAULT, "_PV_ForceUpdateWindowSize");
        } else {
            ILOG(@"64bit and GLES3. Using GLiden64 GFX plugin.");
            success = LoadPlugin(M64PLUGIN_GFX, @"PVMupen64PlusVideoGlideN64");

            ptr_SetOSDCallback = dlsym(RTLD_DEFAULT, "SetOSDCallback");
            ptr_SetOSDCallback(PV_DrawOSD);

        }
    }

    if (!success) {
		if(error != NULL) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load GFX Plugin.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Provenance may not be compiled correctly."
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];

        *error = newError;
		}
        return NO;
    }


    // Load Audio
    audio.aiDacrateChanged = MupenAudioSampleRateChanged;
    audio.aiLenChanged = MupenAudioLenChanged;
    audio.initiateAudio = MupenOpenAudio;
    audio.setSpeedFactor = MupenSetAudioSpeed;
    audio.romOpen = (int (*)(void))MupenAudioRomOpen;
    audio.romClosed = MupenAudioRomClosed;

    plugin_start(M64PLUGIN_AUDIO);

    // Load Input
    input.getKeys = MupenGetKeys;
    input.initiateControllers = MupenInitiateControllers;
    input.controllerCommand = MupenControllerCommand;
    plugin_start(M64PLUGIN_INPUT);


    if(MupenGameCoreOptions.useCXD4) {
            // Load RSP
            // Configure if using rsp-cxd4 plugin
        m64p_handle configRSP;
        ConfigOpenSection("rsp-cxd4", &configRSP);
        int usingHLE = 1; // Set to 0 if using LLE GPU plugin/software rasterizer such as Angry Lion
        ConfigSetParameter(configRSP, "DisplayListToGraphicsPlugin", M64TYPE_BOOL, &usingHLE);
        /** End Core Config **/
        ConfigSaveSection("rsp-cxd4");

        success = LoadPlugin(M64PLUGIN_RSP, @"PVRSPCXD4");
    } else {
        success = LoadPlugin(M64PLUGIN_RSP, @"PVMupen64PlusRspHLE");
    }

    if (!success) {
		if(error != NULL) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load RSP Plugin.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Provenance may not be compiled correctly."
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];

        *error = newError;
		}
        return NO;
    }

#if !TARGET_OS_OSX
    if(RESIZE_TO_FULLSCREEN) {
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        if(keyWindow != nil) {
            CGSize fullScreenSize = keyWindow.bounds.size;
            float widthScale = floor(fullScreenSize.width / WIDTHf);
            float heightScale = floor(fullScreenSize.height / HEIGHTf);
            float scale = MAX(MIN(widthScale, heightScale), 1);
            float widthScaled = scale * WIDTHf;
            float heightScaled = scale * HEIGHTf;

            [self tryToResizeVideoTo:CGSizeMake(widthScaled, heightScaled)];
        }
    }
#endif

	// Setup configs
	ConfigureAll(romFolder);

#ifdef DEBUG
    NSString *defaults = [[NSUserDefaults standardUserDefaults].dictionaryRepresentation debugDescription];
    DLOG(@"defaults: \n%@", defaults);
#endif
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

- (void)startEmulation {
    if(!self.isRunning) {
        romdatabase_init();
        [super startEmulation];
        [NSThread detachNewThreadSelector:@selector(runMupenEmuThread) toTarget:self withObject:nil];
    }
}

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

//		if(CoreShutdown() != M64ERR_SUCCESS) {
//			ELOG(@"Core shutdown failed");
//		}else {
//			ILOG(@"Core shutdown successfully");
//		}
    }
}

- (m64p_error)pluginsUnload {
    // shutdown and unload frameworks for plugins

    typedef m64p_error (*ptr_PluginShutdown)(void);
    ptr_PluginShutdown PluginShutdown;
    int i;

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
                ILOG(@"Shutdown plugin");
            } else {

				ELOG(@"Shutdown plugin type %i failed: %i", i, status);
            }
        }
        if(dlclose(plugins[i]) != 0) {
            ELOG(@"Failed to dlclose plugin type %i", i);
        } else {
            ILOG(@"dlclosed plugin type %i", i);
        }
        plugins[i] = NULL;
    }

    return M64ERR_SUCCESS;
}

- (dispatch_time_t)frameTime {
    float frameTime = 1.0/[self frameInterval];
    __block BOOL expired = NO;
    dispatch_time_t killTime = dispatch_time(DISPATCH_TIME_NOW, frameTime * NSEC_PER_SEC);
    return killTime;
}

- (void)videoInterrupt {
    dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

    dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, [self frameTime]);
}

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)setPauseEmulation:(BOOL)flag
{
    [super setPauseEmulation:flag];

    if (flag)
    {
        // Unblock any pending frame-sync waits so the core thread can exit the
        // VIChangeXFB callback and process the pause state change below.
        dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
        [self.frontBufferCondition lock];
        [self.frontBufferCondition signal];
        [self.frontBufferCondition unlock];
        // Tell the Mupen64Plus core to enter its internal pause state.
        // The core run-loop checks this flag and suspends until M64CMD_RESUME.
        CoreDoCommand(M64CMD_PAUSE, 0, NULL);
    }
    else
    {
        // Wake the Mupen64Plus core run-loop back up.
        CoreDoCommand(M64CMD_RESUME, 0, NULL);
    }
}

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

- (void)resetEmulation {
    // FIXME: do we want/need soft reset? It doesn’t seem to work well with sending M64CMD_RESET alone
    // FIXME: (astrange) should this method worry about this instance’s dispatch semaphores?
    CoreDoCommand(M64CMD_RESET, 1 /* hard reset */, NULL);
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
}

- (void)tryToResizeVideoTo:(CGSize)size {
    #if TARGET_OS_IOS || TARGET_OS_TV
    CGFloat screenScale = UIScreen.mainScreen.nativeScale;

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

- (double)audioSampleRate {
    DLOG("Audio Sample Rate: %d", _mupenSampleRate);
    return _mupenSampleRate;
}

- (NSUInteger)channelCount {
    return 2;
}

#pragma mark - Options

- (void)parseOptions {
    // Parse controller pak options and set controller modes
    // Values: 1=None, 2=Memory Pak, 3=Rumble Pak, 4=Transfer Pak, 5=Raw/Smart Pak
    int pak1 = [MupenGameCoreOptions controllerPak1Option];
    int pak2 = [MupenGameCoreOptions controllerPak2Option];
    int pak3 = [MupenGameCoreOptions controllerPak3Option];
    int pak4 = [MupenGameCoreOptions controllerPak4Option];

    [self setMode:pak1 forController:0];
    [self setMode:pak2 forController:1];
    [self setMode:pak3 forController:2];
    [self setMode:pak4 forController:3];

    ILOG(@"Controller paks configured: P1=%d, P2=%d, P3=%d, P4=%d", pak1, pak2, pak3, pak4);

    // Load virtual mempak data for any controller in PLUGIN_RAW (Smart Pak) mode.
    // PLUGIN_RAW = 5; only those ports use our in-memory mempak buffer.
    int paks[4] = {pak1, pak2, pak3, pak4};
    for (int i = 0; i < 4; i++) {
        if (paks[i] == 5) {
            [self loadMempakForPort:i];
        }
    }
}

#pragma mark - Virtual Mempak (PLUGIN_RAW / Smart Pak)

/// Returns the filesystem path for the mempak save file for the given port.
/// Format: <batterySavesPath>/<romName>_controller<N+1>.mpk
- (nullable NSString *)mempakPathForPort:(NSInteger)port {
    NSString *savesDir = self.batterySavesPath;
    NSString *name = self.romName;
    if (savesDir.length == 0 || name.length == 0) {
        WLOG(@"[Mempak] Cannot derive path: batterySavesPath=%@ romName=%@", savesDir, name);
        return nil;
    }
    NSString *fileName = [NSString stringWithFormat:@"%@_controller%ld.mpk", name, (long)(port + 1)];
    return [savesDir stringByAppendingPathComponent:fileName];
}

- (void)loadMempakForPort:(NSInteger)port {
    if (port < 0 || port >= 4) return;

    NSString *path = [self mempakPathForPort:port];
    if (!path) return;

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data && data.length >= 0x8000) {
        memcpy(mempakBuffer[port], data.bytes, 0x8000);
        mempakDirty[port] = NO;
        ILOG(@"[Mempak] Loaded controller %ld pak from %@", (long)(port + 1), path);
    } else if (data) {
        WLOG(@"[Mempak] File too small (%lu bytes) for controller %ld, starting fresh", (unsigned long)data.length, (long)(port + 1));
        memset(mempakBuffer[port], 0x00, 0x8000);
        mempakDirty[port] = NO;
    } else {
        // No file yet — fresh pak, all zeros (game will format it on first access)
        memset(mempakBuffer[port], 0x00, 0x8000);
        mempakDirty[port] = NO;
        ILOG(@"[Mempak] No save file for controller %ld — starting with empty pak", (long)(port + 1));
    }
}

- (void)saveMempakForPort:(NSInteger)port {
    if (port < 0 || port >= 4) return;
    if (!mempakDirty[port]) return;

    NSString *path = [self mempakPathForPort:port];
    if (!path) return;

    // Ensure the saves directory exists.
    NSString *dir = [path stringByDeletingLastPathComponent];
    NSError *err = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&err];
    if (err) {
        ELOG(@"[Mempak] Failed to create saves directory %@: %@", dir, err.localizedDescription);
        return;
    }

    NSData *data = [NSData dataWithBytes:mempakBuffer[port] length:0x8000];
    if ([data writeToFile:path atomically:YES]) {
        mempakDirty[port] = NO;
        DLOG(@"[Mempak] Saved controller %ld pak to %@", (long)(port + 1), path);
    } else {
        ELOG(@"[Mempak] Failed to write controller %ld pak to %@", (long)(port + 1), path);
    }
}

- (void)saveAllMempaks {
    for (int i = 0; i < 4; i++) {
        if (mempakDirty[i]) {
            [self saveMempakForPort:i];
        }
    }
}

@end
