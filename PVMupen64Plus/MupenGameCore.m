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

// Change to 1 to use the CXD4 plugin for the Reality Coprocessor
// Some games will run much slower or not at all. Others may run better if you have faster hardware.
#define USE_RSP_CXD4 0

#define FORCE_RICE_VIDEO 0

#define RESIZE_TO_FULLSCREEN 0
// Experimental, set to 1 for fullscreen fill

#import "MupenGameCore.h"
#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "Plugins/mupen64plus-core/src/main/version.h"
#import "Plugins/mupen64plus-core/src/plugin/plugin.h"
//#import "rom.h"
//#import "savestates.h"
//#import "memory.h"
//#import "mupen64plus-core/src/main/main.h"
#import <dispatch/dispatch.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVLogging.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>


#import <dlfcn.h>

NSString *MupenControlNames[] = {
    @"N64_DPadU", @"N64_DPadD", @"N64_DPadL", @"N64_DPadR",
    @"N64_CU", @"N64_CD", @"N64_CL", @"N64_CR",
    @"N64_B", @"N64_A", @"N64_R", @"N64_L", @"N64_Z", @"N64_Start"
}; // FIXME: missing: joypad X, joypad Y, mempak switch, rumble switch

#define N64_ANALOG_MAX 80

@interface MupenGameCore () <PVN64SystemResponderClient, GLKViewDelegate>
- (void)OE_didReceiveStateChangeForParamType:(m64p_core_param)paramType value:(int)newValue;

@end

__weak MupenGameCore *_current = 0;

static void (*ptr_PV_ForceUpdateWindowSize)(int width, int height);
static void (*ptr_SetOSDCallback)(void (*inPV_OSD_Callback)(const char *_pText, float _x, float _y));

EXPORT static void PV_DrawOSD(const char *_pText, float _x, float _y)
{
#if DEBUG
//	DLOG(@"%s", _pText);
#endif
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
    [((__bridge MupenGameCore *)context) OE_didReceiveStateChangeForParamType:paramType value:newValue];
}

@implementation MupenGameCore
{
    NSData *romData;
    
    dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
    dispatch_semaphore_t coreWaitToEndFrameSemaphore;

    m64p_emu_state _emulatorState;

    dispatch_queue_t _callbackQueue;
    NSMutableDictionary *_callbackHandlers;
    
    m64p_dynlib_handle core_handle;
    
    m64p_dynlib_handle plugins[4];
}

- (instancetype)init
{
    if (self = [super init]) {
        mupenWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
        coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);
#if RESIZE_TO_FULLSCREEN
		CGSize size = UIApplication.sharedApplication.keyWindow.bounds.size;
		_videoWidth = size.width;
		_videoHeight = size.height;
#else
        _videoWidth  = 640;
        _videoHeight = 480;
#endif
        _videoBitDepth = 32; // ignored
        videoDepthBitDepth = 0; // TODO
        
        sampleRate = 33600;
        
        isNTSC = YES;

        _callbackQueue = dispatch_queue_create("org.openemu.MupenGameCore.CallbackHandlerQueue", DISPATCH_QUEUE_SERIAL);
        _callbackHandlers = [[NSMutableDictionary alloc] init];
    }
    _current = self;
    return self;
}

- (void)dealloc
{
    SetStateCallback(NULL, NULL);
    SetDebugCallback(NULL, NULL);
    
    [self pluginsUnload];
    [self detachCoreLib];
    
#if !__has_feature(objc_arc)
    dispatch_release(mupenWaitToBeginFrameSemaphore);
    dispatch_release(coreWaitToEndFrameSemaphore);
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

- (void)OE_didReceiveStateChangeForParamType:(m64p_core_param)paramType value:(int)newValue
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

static void MupenGetKeys(int Control, BUTTONS *Keys)
{
    GET_CURRENT_AND_RETURN();
    
    [current pollControllers];

    Keys->R_DPAD = current->padData[Control][PVN64ButtonDPadRight];
    Keys->L_DPAD = current->padData[Control][PVN64ButtonDPadLeft];
    Keys->D_DPAD = current->padData[Control][PVN64ButtonDPadDown];
    Keys->U_DPAD = current->padData[Control][PVN64ButtonDPadUp];
    Keys->START_BUTTON = current->padData[Control][PVN64ButtonStart];
    Keys->Z_TRIG = current->padData[Control][PVN64ButtonZ];
    Keys->B_BUTTON = current->padData[Control][PVN64ButtonB];
    Keys->A_BUTTON = current->padData[Control][PVN64ButtonA];
    Keys->R_CBUTTON = current->padData[Control][PVN64ButtonCRight];
    Keys->L_CBUTTON = current->padData[Control][PVN64ButtonCLeft];
    Keys->D_CBUTTON = current->padData[Control][PVN64ButtonCDown];
    Keys->U_CBUTTON = current->padData[Control][PVN64ButtonCUp];
    Keys->R_TRIG = current->padData[Control][PVN64ButtonR];
    Keys->L_TRIG = current->padData[Control][PVN64ButtonL];
    Keys->X_AXIS = current->xAxis[Control];
    Keys->Y_AXIS = current->yAxis[Control];
}

static void MupenInitiateControllers (CONTROL_INFO ControlInfo)
{
    ControlInfo.Controls[0].Present = 1;
    ControlInfo.Controls[0].Plugin = 2;
    ControlInfo.Controls[1].Present = 1;
    ControlInfo.Controls[1].Plugin = 2;
    ControlInfo.Controls[2].Present = 1;
    ControlInfo.Controls[2].Plugin = 2;
    ControlInfo.Controls[3].Present = 1;
    ControlInfo.Controls[3].Plugin = 2;
}

- (void)pollControllers
{
    for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
    {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0)
        {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        else if (self.controller3 && playerIndex == 2)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && playerIndex == 3)
        {
            controller = self.controller4;
        }
        
        if ([controller extendedGamepad])
        {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

			// Left Joystick -> Joystick
            xAxis[playerIndex] = gamepad.leftThumbstick.xAxis.value * N64_ANALOG_MAX;
            yAxis[playerIndex] = gamepad.leftThumbstick.yAxis.value * N64_ANALOG_MAX;

			// DPad -> DPad
            padData[playerIndex][PVN64ButtonDPadUp] = dpad.up.isPressed;
            padData[playerIndex][PVN64ButtonDPadDown] = dpad.down.isPressed;
            padData[playerIndex][PVN64ButtonDPadLeft] = dpad.left.isPressed;
            padData[playerIndex][PVN64ButtonDPadRight] = dpad.right.isPressed;

			// A,Y -> A
			// X,B -> B
            padData[playerIndex][PVN64ButtonA] = gamepad.buttonA.isPressed || gamepad.buttonY.isPressed;
            padData[playerIndex][PVN64ButtonB] = gamepad.buttonX.isPressed || gamepad.buttonB.isPressed;

			// Right Trigger -> Start
            padData[playerIndex][PVN64ButtonStart] = gamepad.rightTrigger.isPressed;

			// L / R Shoulder -> L / R
            padData[playerIndex][PVN64ButtonL] = gamepad.leftShoulder.isPressed;
            padData[playerIndex][PVN64ButtonR] = gamepad.rightShoulder.isPressed;

			// Left Trigger -> Z
            padData[playerIndex][PVN64ButtonZ] = gamepad.leftTrigger.isPressed;

			// Right Joystick -> C Buttons
            float rightJoystickDeadZone = 0.45;
            
            padData[playerIndex][PVN64ButtonCUp] = gamepad.rightThumbstick.up.value > rightJoystickDeadZone;
            padData[playerIndex][PVN64ButtonCDown] = gamepad.rightThumbstick.down.value > rightJoystickDeadZone;
            padData[playerIndex][PVN64ButtonCLeft] = gamepad.rightThumbstick.left.value > rightJoystickDeadZone;
            padData[playerIndex][PVN64ButtonCRight] = gamepad.rightThumbstick.right.value > rightJoystickDeadZone;
        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            xAxis[playerIndex] = (dpad.left.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.right.value > 0.5 ? N64_ANALOG_MAX : 0);
            yAxis[playerIndex] = (dpad.down.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.up.value > 0.5 ? N64_ANALOG_MAX : 0);
            
            padData[playerIndex][PVN64ButtonA] = gamepad.buttonA.isPressed;
            padData[playerIndex][PVN64ButtonB] = gamepad.buttonX.isPressed;
            
            padData[playerIndex][PVN64ButtonCLeft] = gamepad.buttonY.isPressed;
            padData[playerIndex][PVN64ButtonCDown] = gamepad.buttonB.isPressed;
            
            padData[playerIndex][PVN64ButtonZ] = gamepad.leftShoulder.isPressed;
            padData[playerIndex][PVN64ButtonR] = gamepad.rightShoulder.isPressed;
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            xAxis[playerIndex] = (dpad.left.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.right.value > 0.5 ? N64_ANALOG_MAX : 0);
            yAxis[playerIndex] = (dpad.down.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.up.value > 0.5 ? N64_ANALOG_MAX : 0);
            
            padData[playerIndex][PVN64ButtonB] = gamepad.buttonA.isPressed;
            padData[playerIndex][PVN64ButtonA] = gamepad.buttonX.isPressed;
        }
#endif
    }
}

static AUDIO_INFO AudioInfo;

static void MupenAudioSampleRateChanged(int SystemType)
{
    GET_CURRENT_AND_RETURN();

    float currentRate = current->sampleRate;
    
    switch (SystemType)
    {
        default:
        case SYSTEM_NTSC:
            current->sampleRate = 48681812 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
        case SYSTEM_PAL:
            current->sampleRate = 49656530 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
    }

    [[current audioDelegate] audioSampleRateDidChange];
    ILOG(@"Mupen rate changed %f -> %f\n", currentRate, current->sampleRate);
}

static void MupenAudioLenChanged()
{
    GET_CURRENT_AND_RETURN();

    int LenReg = *AudioInfo.AI_LEN_REG;
    uint8_t *ptr = (uint8_t*)(AudioInfo.RDRAM + (*AudioInfo.AI_DRAM_ADDR_REG & 0xFFFFFF));
    
    // Swap channels
    for (uint32_t i = 0; i < LenReg; i += 4)
    {
        ptr[i] ^= ptr[i + 2];
        ptr[i + 2] ^= ptr[i];
        ptr[i] ^= ptr[i + 2];
        ptr[i + 1] ^= ptr[i + 3];
        ptr[i + 3] ^= ptr[i + 1];
        ptr[i + 1] ^= ptr[i + 3];
    }
    
    [[current ringBufferAtIndex:0] write:ptr maxLength:LenReg];
}

static void SetIsNTSC()
{
    GET_CURRENT_AND_RETURN();

    extern m64p_rom_header ROM_HEADER;
    switch (ROM_HEADER.Country_code&0xFF)
    {
        case 0x44:
        case 0x46:
        case 0x49:
        case 0x50:
        case 0x53:
        case 0x55:
        case 0x58:
        case 0x59:
            current->isNTSC = NO;
            break;
        case 0x37:
        case 0x41:
        case 0x45:
        case 0x4a:
            current->isNTSC = YES;
            break;
    }
}

static int MupenOpenAudio(AUDIO_INFO info)
{
    AudioInfo = info;
    
    SetIsNTSC();
    
    return M64ERR_SUCCESS;
}

static void MupenSetAudioSpeed(int percent)
{
    // do we need this?
}

static void ConfigureAll(NSString *romFolder) {
	ConfigureCore(romFolder);
	ConfigureVideoGeneral();
	ConfigureGLideN64(romFolder);
	ConfigureRICE();
}

static void ConfigureCore(NSString *romFolder) {
	GET_CURRENT_AND_RETURN();

	// TODO: Proper path
	NSBundle *coreBundle = [NSBundle mainBundle];
	const char *dataPath;
	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];

	/** Core Config **/
	m64p_handle config;
	ConfigOpenSection("Core", &config);

	// set SRAM path
	ConfigSetParameter(config, "SaveSRAMPath", M64TYPE_STRING, [current.batterySavesPath fileSystemRepresentation]);
	// set data path
	ConfigSetParameter(config, "SharedDataPath", M64TYPE_STRING, romFolder.fileSystemRepresentation);

	// Use Pure Interpreter if 0, Cached Interpreter if 1, or Dynamic Recompiler if 2 or more"
	int emulator = 1;
	ConfigSetParameter(config, "R4300Emulator", M64TYPE_INT, &emulator);

	ConfigSaveSection("Core");
	/** End Core Config **/
}

static void ConfigureVideoGeneral() {
	/** Begin General Video Config **/
	m64p_handle general;
	ConfigOpenSection("Video-General", &general);

	// Use fullscreen mode
	int useFullscreen = 1;
	ConfigSetParameter(general, "Fullscreen", M64TYPE_BOOL, &useFullscreen);

#if RESIZE_TO_FULLSCREEN
	CGSize size = UIApplication.sharedApplication.keyWindow.bounds.size;
#if TARGET_OS_TV
	int screenWidth = size.width/2.0;
	int screenHeight = size.height/2.0;
#else
	int screenWidth = MAX(size.width, size.height);
	int screenHeight = MIN(size.width, size.height);
#endif
#else
	int screenWidth = 640;
	int screenHeight = 480;
#endif

	// Screen width
	ConfigSetParameter(general, "ScreenWidth", M64TYPE_INT, &screenWidth);

	// Screen height
	ConfigSetParameter(general, "ScreenHeight", M64TYPE_INT, &screenHeight);

	ConfigSaveSection("Video-General");
	/** End General Video Config **/
}

static void ConfigureGLideN64(NSString *romFolder) {
	/** Begin GLideN64 Config **/
	m64p_handle gliden64;
	ConfigOpenSection("Video-GLideN64", &gliden64);

	// 0 = stretch, 1 = 4:3, 2 = 16:9, 3 = adjust
#if RESIZE_TO_FULLSCREEN
	#if TARGET_OS_TV
		int aspectRatio = 2;
	#else
		int aspectRatio = 3;
	#endif
#else
	int aspectRatio = 1;
#endif
	ConfigSetParameter(gliden64, "AspectRatio", M64TYPE_INT, &aspectRatio);

	// Per-pixel lighting
	int enableHWLighting = 0;
	ConfigSetParameter(gliden64, "EnableHWLighting", M64TYPE_BOOL, &enableHWLighting);

	// HiRez & texture options
	//  txHiresEnable, "Use high-resolution texture packs if available."
	int txHiresEnable = 1;
	ConfigSetParameter(gliden64, "txHiresEnable", M64TYPE_BOOL, &txHiresEnable);

	ConfigSetParameter(gliden64, "txPath", M64TYPE_STRING, [romFolder fileSystemRepresentation]);
	ConfigSetParameter(gliden64, "txCachePath", M64TYPE_STRING, [romFolder fileSystemRepresentation]);
	ConfigSetParameter(gliden64, "txDumpPath", M64TYPE_STRING, [romFolder fileSystemRepresentation]);

#if RESIZE_TO_FULLSCREEN
	// "txFilterMode", "Texture filter (0=none, 1=Smooth filtering 1, 2=Smooth filtering 2, 3=Smooth filtering 3, 4=Smooth filtering 4, 5=Sharp filtering 1, 6=Sharp filtering 2)"
	int txFilterMode = 6;
	ConfigSetParameter(gliden64, "txFilterMode", M64TYPE_INT, &txFilterMode);

	// "txEnhancementMode", config.textureFilter.txEnhancementMode, "Texture Enhancement (0=none, 1=store as is, 2=X2, 3=X2SAI, 4=HQ2X, 5=HQ2XS, 6=LQ2X, 7=LQ2XS, 8=HQ4X, 9=2xBRZ, 10=3xBRZ, 11=4xBRZ, 12=5xBRZ), 13=6xBRZ"
	int txEnhancementMode = 8;
	ConfigSetParameter(gliden64, "txEnhancementMode", M64TYPE_INT, &txEnhancementMode);

	// "txCacheCompression", config.textureFilter.txCacheCompression, "Zip textures cache."
	int txCacheCompression = 1;
	ConfigSetParameter(gliden64, "txCacheCompression", M64TYPE_BOOL, &txCacheCompression);

	// "txSaveCache", config.textureFilter.txSaveCache, "Save texture cache to hard disk."
	int txSaveCache = 1;
	ConfigSetParameter(gliden64, "txSaveCache", M64TYPE_BOOL, &txSaveCache);

	// Warning, anything other than 0 crashes shader compilation
	// "MultiSampling", config.video.multisampling, "Enable/Disable MultiSampling (0=off, 2,4,8,16=quality)"
	int MultiSampling = 0;
	ConfigSetParameter(gliden64, "MultiSampling", M64TYPE_INT, &MultiSampling);
#endif

	/*
	 "txDeposterize", config.textureFilter.txDeposterize, "Deposterize texture before enhancement."
	 "txFilterIgnoreBG", config.textureFilter.txFilterIgnoreBG, "Don't filter background textures."
	 "txCacheSize", config.textureFilter.txCacheSize/ gc_uMegabyte, "Size of filtered textures cache in megabytes."
	 "txDump", config.textureFilter.txDump, "Enable dump of loaded N64 textures."
	 "txForce16bpp", config.textureFilter.txForce16bpp, "Force use 16bit texture formats for HD textures."
	*/

	// "txHresAltCRC", config.textureFilter.txHresAltCRC, "Use alternative method of paletted textures CRC calculation."
	int txHresAltCRC = 0;
	ConfigSetParameter(gliden64, "txHresAltCRC", M64TYPE_BOOL, &txHresAltCRC);


	// "txHiresFullAlphaChannel", "Allow to use alpha channel of high-res texture fully."
	int txHiresFullAlphaChannel = 1;
	ConfigSetParameter(gliden64, "txHiresFullAlphaChannel", M64TYPE_BOOL, &txHiresFullAlphaChannel);

	// Draw on-screen display if True, otherwise don't draw OSD
	int osd = 0;
	ConfigSetParameter(gliden64, "OnScreenDisplay", M64TYPE_BOOL, &osd);
	ConfigSetParameter(gliden64, "ShowFPS", M64TYPE_BOOL, &osd);			// Show FPS counter.
	ConfigSetParameter(gliden64, "ShowVIS", M64TYPE_BOOL, &osd);			// Show VI/S counter.
	ConfigSetParameter(gliden64, "ShowPercent", M64TYPE_BOOL, &osd);		// Show percent counter.
	ConfigSetParameter(gliden64, "ShowInternalResolution", M64TYPE_BOOL, &osd);	// Show internal resolution.
	ConfigSetParameter(gliden64, "ShowRenderingResolution", M64TYPE_BOOL, &osd);	// Show rendering resolution.

	ConfigSaveSection("Video-GLideN64");
	/** End GLideN64 Config **/
}

static void ConfigureRICE() {
	/** RICE CONFIG **/
	m64p_handle rice;
	ConfigOpenSection("Video-Rice", &rice);

	// Use a faster algorithm to speed up texture loading and CRC computation
	int fastTextureLoading = 0;
	ConfigSetParameter(rice, "FastTextureLoading", M64TYPE_BOOL, &fastTextureLoading);

	// Enable this option to have better render-to-texture quality
	int doubleSizeForSmallTextureBuffer = 0;
	ConfigSetParameter(rice, "DoubleSizeForSmallTxtrBuf", M64TYPE_BOOL, &doubleSizeForSmallTextureBuffer);

	// N64 Texture Memory Full Emulation (may fix some games, may break others)
	int fullTEMEmulation = 0;
	ConfigSetParameter(rice, "FullTMEMEmulation", M64TYPE_BOOL, &fullTEMEmulation);

	// Use fullscreen mode if True, or windowed mode if False
	int fullscreen = 1;
	ConfigSetParameter(rice, "Fullscreen", M64TYPE_BOOL, &fullscreen);

	// If this option is enabled, the plugin will skip every other frame
	// Breaks some games in my testing -jm
	int skipFrame = 0;
	ConfigSetParameter(rice, "SkipFrame", M64TYPE_BOOL, &skipFrame);

	// Enable hi-resolution texture file loading
	int hiResTextures = 1;
	ConfigSetParameter(rice, "LoadHiResTextures", M64TYPE_BOOL, &hiResTextures);

	// Use Mipmapping? 0=no, 1=nearest, 2=bilinear, 3=trilinear
	int mipmapping = 0;
	ConfigSetParameter(rice, "Mipmapping", M64TYPE_INT, &mipmapping);

	// Enable/Disable Anisotropic Filtering for Mipmapping (0=no filtering, 2-16=quality).
	// This is uneffective if Mipmapping is 0. If the given value is to high to be supported by your graphic card, the value will be the highest value your graphic card can support. Better result with Trilinear filtering
	int anisotropicFiltering = 16;
	ConfigSetParameter(rice, "AnisotropicFiltering", M64TYPE_INT, &anisotropicFiltering);

	// Enable, Disable or Force fog generation (0=Disable, 1=Enable n64 choose, 2=Force Fog)
	int fogMethod = 0;
	ConfigSetParameter(rice, "FogMethod", M64TYPE_INT, &fogMethod);

	// Color bit depth to use for textures (0=default, 1=32 bits, 2=16 bits)
	// 16 bit breaks some games like GoldenEye
	int textureQuality = 1;
	ConfigSetParameter(rice, "TextureQuality", M64TYPE_INT, &textureQuality);

	// Enable/Disable MultiSampling (0=off, 2,4,8,16=quality)
	int multiSampling = 0;
	ConfigSetParameter(rice, "MultiSampling", M64TYPE_INT, &multiSampling);

	// Color bit depth for rendering window (0=32 bits, 1=16 bits)
	int colorQuality = 0;
	ConfigSetParameter(rice, "ColorQuality", M64TYPE_INT, &colorQuality);

	/** End RICE CONFIG **/
	ConfigSaveSection("Video-Rice");
}

- (void)copyIniFiles:(NSString*)romFolder {
	NSBundle *coreBundle = [NSBundle mainBundle];

	// Copy default config files if they don't exist
	NSArray<NSString*>* iniFiles = @[@"GLideN64.ini", @"GLideN64.custom.ini", @"RiceVideoLinux.ini", @"mupen64plus.ini"];
	NSFileManager *fm = [NSFileManager defaultManager];

	// Create destination folder if missing

	BOOL isDirectory;
	if (![fm fileExistsAtPath:romFolder isDirectory:&isDirectory]) {
		ILOG(@"ROM data folder doesn't exist, creating %@", romFolder);
		NSError *error;
		BOOL success = [fm createDirectoryAtPath:romFolder withIntermediateDirectories:YES attributes:nil error:&error];
		if (!success) {
			ELOG(@"Failed to create destination folder %@. Error: %@", romFolder, error.localizedDescription);
			return;
		}
	}

	for (NSString *iniFile in iniFiles) {
		NSString *destinationPath = [romFolder stringByAppendingPathComponent:iniFile];

		if (![fm fileExistsAtPath:destinationPath]) {
			NSString *fileName = [iniFile stringByDeletingPathExtension];
			NSString *extension = [iniFile pathExtension];
			NSString *source = [coreBundle pathForResource:fileName
													ofType:extension];
			if (source == nil) {
				ELOG(@"No resource path found for file %@", iniFile);
				continue;
			}
			NSError *error;
			BOOL success = [fm copyItemAtPath:source
									   toPath:destinationPath
										error:&error];
			if (!success) {
				ELOG(@"Failed to copy app bundle file %@\n%@", iniFile, error.localizedDescription);
			} else {
				ILOG(@"Copied %@ from app bundle to %@", iniFile, destinationPath);
			}
		}
	}
}

-(void)createHiResFolder:(NSString*)romFolder {
	// Create the directory if this option is enabled to make it easier for users to upload packs
	BOOL hiResTextures = YES;
	if (hiResTextures) {
		// Create the directory for hires_texture, this is a constant in mupen source
		NSArray<NSString*>* subPaths = @[@"/hires_texture/", @"/cache/", @"/texture_dump/"];
		for(NSString *subPath in subPaths) {
			NSString *highResPath = [romFolder stringByAppendingPathComponent:subPath];
			NSError *error;
			BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:highResPath
													 withIntermediateDirectories:YES
																	  attributes:nil
																		   error:&error];
			if (!success) {
				ELOG(@"Error creating hi res texture path: %@", error.localizedDescription);
			}
		}
	}
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
			NSError *error;
			if(![fileManager createDirectoryAtPath:configPath
					   withIntermediateDirectories:true
										attributes:nil
											 error:&error]) {
				ELOG(@"Filed to create path. %@", error.localizedDescription);
			}
		}
	}

	// Create hires folder placement
	[self createHiResFolder:romFolder];

	// Copy default ini files to the config path
	[self copyIniFiles:configPath];
	// Rice looks in the data path for some reason, fuck it copy it there too - joe m
	[self copyIniFiles:dataPath];

	// Setup configs
	ConfigureAll(romFolder);

	// open core here
	CoreStartup(FRONTEND_API_VERSION, configPath.fileSystemRepresentation, dataPath.fileSystemRepresentation, (__bridge void *)self, MupenDebugCallback, (__bridge void *)self, MupenStateCallback);

	// Setup configs
	ConfigureAll(romFolder);

	// Disable the built in speed limiter
	CoreDoCommand(M64CMD_CORE_STATE_SET, M64CORE_SPEED_LIMITER, 0);

    // Load ROM
    romData = [NSData dataWithContentsOfMappedFile:path];
	if (romData == nil || romData.length == 0) {
		ELOG(@"Error loading ROM at path: %@\n File does not exist.", path);

		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to load game.",
								   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus find the game file.",
								   NSLocalizedRecoverySuggestionErrorKey: @"Check the file hasn't been moved or deleted."
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotLoadRom
											userInfo:userInfo];

		*error = newError;

		return NO;
	}

    m64p_error openStatus = CoreDoCommand(M64CMD_ROM_OPEN, [romData length], (void *)[romData bytes]);
    if ( openStatus != M64ERR_SUCCESS) {
        ELOG(@"Error loading ROM at path: %@\n Error code was: %i", path, openStatus);
   
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load game.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported Mupen64Plus ROM format."
                                   };
        
        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];
        
        *error = newError;
        
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
        NSString *rspPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:frameworkPath];
        
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

	EAGLContext* context = [self bestContext];

#if FORCE_RICE_VIDEO
	success = LoadPlugin(M64PLUGIN_GFX, @"PVMupen64PlusVideoRice");
	ptr_PV_ForceUpdateWindowSize = dlsym(RTLD_DEFAULT, "_PV_ForceUpdateWindowSize");
#else
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
#endif
	
    if (!success) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load GFX Plugin.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Provenance may not be compiled correctly."
                                   };
        
        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];
        
        *error = newError;
        return NO;
    }
    

    // Load Audio
    audio.aiDacrateChanged = MupenAudioSampleRateChanged;
    audio.aiLenChanged = MupenAudioLenChanged;
    audio.initiateAudio = MupenOpenAudio;
    audio.setSpeedFactor = MupenSetAudioSpeed;
    plugin_start(M64PLUGIN_AUDIO);

    // Load Input
    input.getKeys = MupenGetKeys;
    input.initiateControllers = MupenInitiateControllers;
    plugin_start(M64PLUGIN_INPUT);
    
#if USE_RSP_CXD4
    // Load RSP
    // Configure if using rsp-cxd4 plugin
    m64p_handle configRSP;
    ConfigOpenSection("rsp-cxd4", &configRSP);
    int usingHLE = 1; // Set to 0 if using LLE GPU plugin/software rasterizer such as Angry Lion
    ConfigSetParameter(configRSP, "DisplayListToGraphicsPlugin", M64TYPE_BOOL, &usingHLE);
	/** End Core Config **/
	ConfigSaveSection("rsp-cxd4");

    success = LoadPlugin(M64PLUGIN_RSP, @"PVRSPCXD4");
#else
    success = LoadPlugin(M64PLUGIN_RSP, @"PVMupen64PlusRspHLE");
#endif
    if (!success) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"Mupen64Plus failed to load RSP Plugin.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Provenance may not be compiled correctly."
                                   };
        
        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];
        
        *error = newError;
        
        return NO;
    }

#if RESIZE_TO_FULLSCREEN
	UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
	if(keyWindow != nil) {
		CGSize fullScreenSize = keyWindow.bounds.size;
		[self tryToResizeVideoTo:fullScreenSize];
	}
#endif

	// Setup configs
	ConfigureAll(romFolder);

    return YES;
}

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

- (void)startEmulation
{
    if(!self.isRunning)
    {
        [super startEmulation];
        [NSThread detachNewThreadSelector:@selector(runMupenEmuThread) toTarget:self withObject:nil];
    }
}

- (void)runMupenEmuThread
{
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

		if(CoreShutdown() != M64ERR_SUCCESS) {
			ELOG(@"Core shutdown failed");
		}else {
			ILOG(@"Core shutdown successfully");
		}
    }
}

- (m64p_error)pluginsUnload
{
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

- (void)videoInterrupt
{
    dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
    
    dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers
{
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    
    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)setPauseEmulation:(BOOL)flag
{
    [super setPauseEmulation:flag];
    if (flag)
    {
        dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
        [self.frontBufferCondition lock];
        [self.frontBufferCondition signal];
        [self.frontBufferCondition unlock];
    }
}

- (void)stopEmulation
{
    CoreDoCommand(M64CMD_STOP, 0, NULL);
    
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
    
    [super stopEmulation];
}

- (void)resetEmulation
{
    // FIXME: do we want/need soft reset? It doesn’t seem to work well with sending M64CMD_RESET alone
    // FIXME: (astrange) should this method worry about this instance’s dispatch semaphores?
    CoreDoCommand(M64CMD_RESET, 1 /* hard reset */, NULL);
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error   {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    __block BOOL savedSuccessfully = NO;
    [self saveStateToFileAtPath:fileName completionHandler:^(BOOL success, NSError *error)
     {
         savedSuccessfully = success;
         dispatch_group_leave(group);
     }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return savedSuccessfully;
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
             NSError *error = [NSError errorWithDomain:@"org.openemu.GameCore.ErrorDomain" code:-5 userInfo:@{
                 NSLocalizedDescriptionKey : @"Mupen Could not save the current state.",
                 NSFilePathErrorKey : fileName
             }];
             if (block) {
                 block(NO, error);
             }
             return NO;
         }

         if (block) {
             block(YES, nil);
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
}


- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error   {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    __block BOOL loadedSuccessfully = NO;
    [self loadStateFromFileAtPath:fileName completionHandler:^(BOOL success, NSError *error)
     {
         loadedSuccessfully = success;
         dispatch_group_leave(group);
     }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return loadedSuccessfully;
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
             NSError *error = [NSError errorWithDomain:@"org.openemu.GameCore.ErrorDomain" code:-3 userInfo:@{
                 NSLocalizedDescriptionKey : @"Mupen Could not load the save state",
                 NSLocalizedRecoverySuggestionErrorKey : @"The loaded file is probably corrupted.",
                 NSFilePathErrorKey : fileName
             }];
             block(NO, error);
             return NO;
         }

         block(YES, nil);
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

- (CGSize)bufferSize
{
    return CGSizeMake(1024, 512);
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, _videoWidth, _videoHeight);
}

- (CGSize)aspectSize
{
    return CGSizeMake(_videoWidth, _videoHeight);
}

- (void) tryToResizeVideoTo:(CGSize)size
{
    VidExt_SetVideoMode(size.width, size.height, 32, M64VIDEO_FULLSCREEN, 1);
	if (ptr_PV_ForceUpdateWindowSize != nil) {
		ptr_PV_ForceUpdateWindowSize(size.width, size.height);
	}
}

- (BOOL)rendersToOpenGL
{
    return YES;
}

- (const void *)videoBuffer
{
    return NULL;
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
    return GL_RGBA;
}

#pragma mark Mupen Audio

- (NSTimeInterval)frameInterval
{
    // Mupen uses 60 but it's probably wrong
    return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return sampleRate;
}

- (void)didMoveN64JoystickDirection:(PVN64Button)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
    switch (button)
    {
        case PVN64ButtonAnalogUp:
            yAxis[player] = value * N64_ANALOG_MAX;
            break;
        case PVN64ButtonAnalogDown:
            yAxis[player] = value * -N64_ANALOG_MAX;
            break;
        case PVN64ButtonAnalogLeft:
            xAxis[player] = value * -N64_ANALOG_MAX;
            break;
        case PVN64ButtonAnalogRight:
            xAxis[player] = value * N64_ANALOG_MAX;
            break;
        default:
            break;
    }
}

- (void)didPushN64Button:(PVN64Button)button forPlayer:(NSUInteger)player
{
    padData[player][button] = 1;
}

- (void)didReleaseN64Button:(PVN64Button)button forPlayer:(NSUInteger)player
{
    padData[player][button] = 0;
}

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
// Need to fix ambigious main.h inclusion
//    // Sanitize
//    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    
//    // Remove any spaces
//    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];
//    
//    NSString *singleCode;
//    NSArray *multipleCodes = [code componentsSeparatedByString:@"+"];
//    m64p_cheat_code *gsCode = (m64p_cheat_code*) calloc([multipleCodes count], sizeof(m64p_cheat_code));
//    int codeCounter = 0;
//    
//    for (singleCode in multipleCodes)
//    {
//        if ([singleCode length] == 12) // GameShark
//        {
//            // GameShark N64 format: XXXXXXXX YYYY
//            NSString *address = [singleCode substringWithRange:NSMakeRange(0, 8)];
//            NSString *value = [singleCode substringWithRange:NSMakeRange(8, 4)];
//            
//            // Convert GS hex to int
//            unsigned int outAddress, outValue;
//            NSScanner* scanAddress = [NSScanner scannerWithString:address];
//            NSScanner* scanValue = [NSScanner scannerWithString:value];
//            [scanAddress scanHexInt:&outAddress];
//            [scanValue scanHexInt:&outValue];
//            
//            gsCode[codeCounter].address = outAddress;
//            gsCode[codeCounter].value = outValue;
//            codeCounter++;
//        }
//    }
//    
//    // Update address directly if code needs GS button pressed
//    if ((gsCode[0].address & 0xFF000000) == 0x88000000 || (gsCode[0].address & 0xFF000000) == 0xA8000000)
//    {
//        *(unsigned char *)((g_rdram + ((gsCode[0].address & 0xFFFFFF)^S8))) = (unsigned char)gsCode[0].value; // Update 8-bit address
//    }
//    else if ((gsCode[0].address & 0xFF000000) == 0x89000000 || (gsCode[0].address & 0xFF000000) == 0xA9000000)
//    {
//        *(unsigned short *)((g_rdram + ((gsCode[0].address & 0xFFFFFF)^S16))) = (unsigned short)gsCode[0].value; // Update 16-bit address
//    }
//    // Else add code as normal
//    else
//    {
//        enabled ? CoreAddCheat([code UTF8String], gsCode, codeCounter+1) : CoreCheatEnabled([code UTF8String], 0);
//    }
}


@end
