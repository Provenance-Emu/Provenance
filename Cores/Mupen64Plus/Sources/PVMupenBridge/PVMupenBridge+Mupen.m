#import "PVMupenBridge+Mupen.h"
#import "PVMupenBridge+Controls.h"
#import "PVMupen64PlusBridge/PVMupen64PlusBridge-Swift.h"
@import PVAudio;
@import PVSettings;
@import PVLogging;
@import PVLoggingObjC;
#if __has_include(<UIKit/UIKit.h>)
@import UIKit.UIWindow;
#else
@import AppKit.NSWindow;
#endif

#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "../Plugins/Core/Core/src/main/version.h"
#import "../Plugins/Core/Core/src/plugin/plugin.h"

AUDIO_INFO AudioInfo;

void MupenAudioSampleRateChanged(int SystemType)
{
    GET_CURRENT_AND_RETURN();

    // Since we're forcing 44.1kHz in the AI controller, we can set this directly
    float newRate = 44100.0f;

    // Update sample rate if changed
    if (current.mupenSampleRate != newRate) {
        current.mupenSampleRate = newRate;
        [[current audioDelegate] audioSampleRateDidChange];

        DLOG(@"N64 Audio Rate: %f Hz (forced 44.1kHz)", newRate);
    }
}

void MupenAudioLenChanged()
{
    GET_CURRENT_AND_RETURN();

    const int LenReg = *AudioInfo.AI_LEN_REG;
    uint8_t *ptr = (uint8_t*)(AudioInfo.RDRAM + (*AudioInfo.AI_DRAM_ADDR_REG & 0xFFFFFF));

    // Get VI clock frequency based on system type
    unsigned int vi_clock = current.isNTSC ? 48681812 : 49656530;

    // Calculate source frequency using DAC rate
    // This matches how ai_init sets up the frequency
    unsigned int source_frequency = vi_clock / (1 + *AudioInfo.AI_DACRATE_REG);

    // Calculate number of samples (16-bit stereo)
    const size_t num_input_samples = LenReg / 4;

    // Calculate resampled size using actual source frequency
    const size_t num_output_samples = (size_t)((num_input_samples * 44100ULL) / source_frequency);

    // Temporary buffer for resampled audio
    static int16_t resampled[65536];
    if (num_output_samples * 4 > sizeof(resampled)) {
        return;
    }

    // Calculate fixed-point step ratio
    uint32_t step_ratio = (uint32_t)(((uint64_t)source_frequency << 16) / 44100);

    // Do the resampling
    const int16_t *src = (int16_t*)ptr;
    uint32_t pos = 0;
    size_t out_idx = 0;

    while (out_idx < num_output_samples && (pos >> 16) < num_input_samples - 1) {
        const size_t src_idx = pos >> 16;
        const uint32_t frac = pos & 0xFFFF;

        for (int ch = 0; ch < 2; ch++) {
            const int32_t s1 = src[src_idx * 2 + ch];
            const int32_t s2 = src[src_idx * 2 + 2 + ch];
            resampled[out_idx * 2 + ch] = (int16_t)(s1 + (((s2 - s1) * frac) >> 16));
        }

        pos += step_ratio;
        out_idx++;
    }

    // Write resampled audio to ring buffer
    [[current ringBufferAtIndex:0] write:(uint8_t*)resampled size:out_idx * 4];
}

void SetIsNTSC()
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
            current.isNTSC = NO;
            break;
        case 0x37:
        case 0x41:
        case 0x45:
        case 0x4a:
            current.isNTSC = YES;
            break;
    }
}

int MupenOpenAudio(AUDIO_INFO info) {
    AudioInfo = info;

    SetIsNTSC();

    ILOG(@"called");

    return M64ERR_SUCCESS;
}

void MupenSetAudioSpeed(int percent) {
    // do we need this?
    ILOG(@"value: %i", percent);
}

void MupenAudioRomOpen() {
    // do we need this?
    DLOG(@"called");
}

void MupenAudioRomClosed() {
    // do we need this?
    DLOG(@"called");
}

void ConfigureAll(NSString *romFolder) {
    ConfigureCore(romFolder);
    ConfigureVideoGeneral();
    ConfigureGLideN64(romFolder);
    ConfigureRICE();
}

void ConfigureCore(NSString *romFolder) {
    GET_CURRENT_AND_RETURN();

    // TODO: Proper path
    NSBundle *coreBundle = [NSBundle mainBundle];
    const char *dataPath;
    dataPath = [[coreBundle resourcePath] fileSystemRepresentation];

    /** Core Config **/
    m64p_handle config;
    ConfigOpenSection("Core", &config);

    // set SRAM path
    ConfigSetParameter(config, "SaveSRAMPath", M64TYPE_STRING, current.batterySavesPath.fileSystemRepresentation);
    // set data path
    ConfigSetParameter(config, "SharedDataPath", M64TYPE_STRING, romFolder.fileSystemRepresentation);

    // Use Pure Interpreter if 0, Cached Interpreter if 1, or Dynamic Recompiler if 2 or more"
    int emulator = [MupenGameCoreOptions intForOption:@"CPU Mode"];
    ConfigSetParameter(config, "R4300Emulator", M64TYPE_INT, &emulator);

	int SiDmaDuration = [MupenGameCoreOptions intForOption:@"SiDmaDuration"];
    if (SiDmaDuration >= 0) {
        ConfigSetParameter(config, "SiDmaDuration", M64TYPE_INT, &SiDmaDuration);
    }

	int disableExtraMemory = [MupenGameCoreOptions boolForOption:@"Disable Extra Memory"];
	ConfigSetParameter(config, "DisableExtraMem", M64TYPE_BOOL, &disableExtraMemory);

	int randomizeInterrupt = [MupenGameCoreOptions boolForOption:@"Randomize Interrupt"];
	ConfigSetParameter(config, "RandomizeInterrupt", M64TYPE_BOOL, &randomizeInterrupt);

    int countPerOp = [MupenGameCoreOptions boolForOption:@"Count Per Op"];
    if (countPerOp >= 1) {
        ConfigSetParameter(config, "CountPerOp", M64TYPE_INT, &countPerOp);
    }

    // Save state slot (0-9) to use when saving/loading the emulator state
//    int currentStateSlot = [MupenGameCore boolForOption:@"Save State Slot"];
//    ConfigSetParameter(config, "CurrentStateSlot", M64TYPE_INT, &currentStateSlot);


		// Draw on-screen display if True, otherwise don't draw OSD
	int osd = [MupenGameCoreOptions boolForOption:@"Debug OSD"];
	ConfigSetParameter(config, "OnScreenDisplay", M64TYPE_BOOL, &osd);
	ConfigSetParameter(config, "ShowFPS", M64TYPE_BOOL, &osd);            // Show FPS counter.
	ConfigSetParameter(config, "ShowVIS", M64TYPE_BOOL, &osd);            // Show VI/S counter.
	ConfigSetParameter(config, "ShowPercent", M64TYPE_BOOL, &osd);        // Show percent counter.
	ConfigSetParameter(config, "ShowInternalResolution", M64TYPE_BOOL, &osd);    // Show internal resolution.
	ConfigSetParameter(config, "ShowRenderingResolution", M64TYPE_BOOL, &osd);    // Show rendering resolution.


    ConfigSaveSection("Core");
    /** End Core Config **/
}

void ConfigureVideoGeneral() {
    /** Begin General Video Config **/
    m64p_handle general;
    ConfigOpenSection("Video-General", &general);

    // Use fullscreen mode
    int useFullscreen = 1;
    ConfigSetParameter(general, "Fullscreen", M64TYPE_BOOL, &useFullscreen);

    int screenWidth = WIDTH;
    int screenHeight = HEIGHT;
#if __has_include(<UIKit/UIKit.h>)
    if(RESIZE_TO_FULLSCREEN) {
        CGSize size = UIApplication.sharedApplication.keyWindow.bounds.size;
        float widthScale = floor(size.height / WIDTHf);
        float heightScale = floor(size.height / HEIGHTf);
        float scale = MAX(MIN(widthScale, heightScale), 1);
        screenWidth =  scale * WIDTHf;
        screenHeight = scale * HEIGHTf;
    }
#endif

    // Screen width
    ConfigSetParameter(general, "ScreenWidth", M64TYPE_INT, &screenWidth);

    // Screen height
    ConfigSetParameter(general, "ScreenHeight", M64TYPE_INT, &screenHeight);


    DLOG(@"Setting size to (%i,%i)", screenWidth, screenHeight);

    ConfigSaveSection("Video-General");
    /** End General Video Config **/
}

void ConfigureGLideN64(NSString *romFolder) {
    /** Begin GLideN64 Config **/
    m64p_handle gliden64;
    ConfigOpenSection("Video-GLideN64", &gliden64);

        // 0 = stretch, 1 = 4:3, 2 = 16:9, 3 = adjust
    int aspectRatio = [MupenGameCoreOptions intForOption:@"Aspect Ratio"];

//    if(RESIZE_TO_FULLSCREEN) {
//        #if TARGET_OS_TV
//            aspectRatio = 1;
//        #else
//            aspectRatio = 3;
//        #endif
//    }

    ConfigSetParameter(gliden64, "AspectRatio", M64TYPE_INT, &aspectRatio);

    // Per-pixel lighting
    int enableHWLighting = MupenGameCoreOptions.perPixelLighting ? 1 : 0;
    ConfigSetParameter(gliden64, "EnableHWLighting", M64TYPE_BOOL, &enableHWLighting);

    // HiRez & texture options
    //  txHiresEnable, "Use high-resolution texture packs if available."
    int txHiresEnable = [MupenGameCoreOptions boolForOption:@"Enable HiRes Texture packs"];
    ConfigSetParameter(gliden64, "txHiresEnable", M64TYPE_BOOL, &txHiresEnable);

    // Path to folder with hi-res texture packs.
    ConfigSetParameter(gliden64, "txPath", M64TYPE_STRING, [romFolder stringByAppendingPathComponent:@"/"].fileSystemRepresentation);
    // Path to folder where plugin saves texture cache files.
    ConfigSetParameter(gliden64, "txCachePath", M64TYPE_STRING, [romFolder stringByAppendingPathComponent:@"/cache/"].fileSystemRepresentation);
    // Path to folder where plugin saves dumped textures.
    ConfigSetParameter(gliden64, "txDumpPath", M64TYPE_STRING, [romFolder stringByAppendingPathComponent:@"/texture_dump/"].fileSystemRepresentation);

//    if(RESIZE_TO_FULLSCREEN) {
    // "txFilterMode",
    // "Texture filter (0=none, 1=Smooth filtering 1, 2=Smooth filtering 2, 3=Smooth filtering 3, 4=Smooth filtering 4, 5=Sharp filtering 1, 6=Sharp filtering 2)"
    int txFilterMode = [MupenGameCoreOptions intForOption:@"Texture Filter Mode"];
    ConfigSetParameter(gliden64, "txFilterMode", M64TYPE_INT, &txFilterMode);

    // "txEnhancementMode", config.textureFilter.txEnhancementMode,
    // "Texture Enhancement (0=none, 1=store as is, 2=X2, 3=X2SAI, 4=HQ2X, 5=HQ2XS, 6=LQ2X, 7=LQ2XS, 8=HQ4X, 9=2xBRZ, 10=3xBRZ, 11=4xBRZ, 12=5xBRZ), 13=6xBRZ"
    int txEnhancementMode = [MupenGameCoreOptions intForOption:@"Texture Enhancement Mode"];
    ConfigSetParameter(gliden64, "txEnhancementMode", M64TYPE_INT, &txEnhancementMode);

    // "txCacheCompression", config.textureFilter.txCacheCompression, "Zip textures cache."
    int txCacheCompression = [MupenGameCoreOptions boolForOption:@"Compress texture cache"];
    ConfigSetParameter(gliden64, "txCacheCompression", M64TYPE_BOOL, &txCacheCompression);

    // "txSaveCache", config.textureFilter.txSaveCache,
    // "Save texture cache to hard disk."
    int txSaveCache = [MupenGameCoreOptions boolForOption:@"Save texture cache"];
    ConfigSetParameter(gliden64, "txSaveCache", M64TYPE_BOOL, &txSaveCache);

    // Warning, anything other than 0 crashes shader compilation
    // "MultiSampling", config.video.multisampling, "Enable/Disable MultiSampling (0=off, 2,4,8,16=quality)"
    int MultiSampling = [MupenGameCoreOptions intForOption:@"Multi Sampling"];
    ConfigSetParameter(gliden64, "MultiSampling", M64TYPE_INT, &MultiSampling);
//    }


        //#Gamma correction settings
//    res = ConfigSetDefaultBool(g_configVideoGliden64, "ForceGammaCorrection", config.gammaCorrection.force, "Force gamma correction.");
//    assert(res == M64ERR_SUCCESS);
//    res = ConfigSetDefaultFloat(g_configVideoGliden64, "GammaCorrectionLevel", config.gammaCorrection.level, "Gamma correction level.");
//    assert(res == M64ERR_SUCCESS);

    /*
     "txCacheSize", config.textureFilter.txCacheSize/ gc_uMegabyte, "Size of filtered textures cache in megabytes."
    */
    int txDump = [MupenGameCoreOptions boolForOption:@"Texture Dump"];
    ConfigSetParameter(gliden64, "txDump", M64TYPE_BOOL, &txDump);

    int txFilterIgnoreBG = [MupenGameCoreOptions boolForOption:@"Ignore BG Textures"];
    ConfigSetParameter(gliden64, "txFilterIgnoreBG", M64TYPE_BOOL, &txFilterIgnoreBG);


    int txForce16bpp = [MupenGameCoreOptions boolForOption:@"Force 16bpp textures"];
    ConfigSetParameter(gliden64, "txForce16bpp", M64TYPE_BOOL, &txForce16bpp);


    // "txHresAltCRC", config.textureFilter.txHresAltCRC, "Use alternative method of paletted textures CRC calculation."
    int txHresAltCRC = [MupenGameCoreOptions boolForOption:@"HiRes Alt CRC"];
    ConfigSetParameter(gliden64, "txHresAltCRC", M64TYPE_BOOL, &txHresAltCRC);


    // "txHiresFullAlphaChannel", "Allow to use alpha channel of high-res texture fully."
    int txHiresFullAlphaChannel = [MupenGameCoreOptions boolForOption:@"HiRes Full Alpha"];;
    ConfigSetParameter(gliden64, "txHiresFullAlphaChannel", M64TYPE_BOOL, &txHiresFullAlphaChannel);

    ConfigSaveSection("Video-GLideN64");
    /** End GLideN64 Config **/
}

void ConfigureRICE() {
    /** RICE CONFIG **/
    m64p_handle rice;
    ConfigOpenSection("Video-Rice", &rice);

    // Use a faster algorithm to speed up texture loading and CRC computation
    int fastTextureLoading = [MupenGameCoreOptions boolForOption:@"Fast Texture Loading"];

    ConfigSetParameter(rice, "FastTextureLoading", M64TYPE_BOOL, &fastTextureLoading);

    // Enable this option to have better render-to-texture quality
    int doubleSizeForSmallTextureBuffer = [MupenGameCoreOptions boolForOption:@"DoubleSizeForSmallTxtrBuf"];
    ConfigSetParameter(rice, "DoubleSizeForSmallTxtrBuf", M64TYPE_BOOL, &doubleSizeForSmallTextureBuffer);

    // N64 Texture Memory Full Emulation (may fix some games, may break others)
    int fullTEMEmulation = [MupenGameCoreOptions boolForOption:@"FullTMEMEmulation"];
    ConfigSetParameter(rice, "FullTMEMEmulation", M64TYPE_BOOL, &fullTEMEmulation);

    // Use fullscreen mode if True, or windowed mode if False
    int fullscreen = 1;
    ConfigSetParameter(rice, "Fullscreen", M64TYPE_BOOL, &fullscreen);

    // If this option is enabled, the plugin will skip every other frame
    // Breaks some games in my testing -jm
    int skipFrame = [MupenGameCoreOptions boolForOption:@"SkipFrame"];
    ConfigSetParameter(rice, "SkipFrame", M64TYPE_BOOL, &skipFrame);

    // Enable hi-resolution texture file loading
    int hiResTextures = [MupenGameCoreOptions boolForOption:@"LoadHiResTextures"];
    ConfigSetParameter(rice, "LoadHiResTextures", M64TYPE_BOOL, &hiResTextures);

    // Use Mipmapping? 0=no, 1=nearest, 2=bilinear, 3=trilinear
    int mipmapping = 0;
    ConfigSetParameter(rice, "Mipmapping", M64TYPE_INT, &mipmapping);

    // Enable/Disable Anisotropic Filtering for Mipmapping (0=no filtering, 2-16=quality).
    // This is uneffective if Mipmapping is 0. If the given value is to high to be supported by your graphic card, the value will be the highest value your graphic card can support. Better result with Trilinear filtering
    int anisotropicFiltering = 16;
    ConfigSetParameter(rice, "AnisotropicFiltering", M64TYPE_INT, &anisotropicFiltering);

    // Enable, Disable or Force fog generation (0=Disable, 1=Enable n64 choose, 2=Force Fog)
    int fogMethod = 1;
    ConfigSetParameter(rice, "FogMethod", M64TYPE_INT, &fogMethod);

    // Color bit depth to use for textures (0=default, 1=32 bits, 2=16 bits)
    // 16 bit breaks some games like GoldenEye
    int textureQuality = 1;
    ConfigSetParameter(rice, "TextureQuality", M64TYPE_INT, &textureQuality);

    // Enable/Disable MultiSampling (0=off, 2,4,8,16=quality)
    int multiSampling = RESIZE_TO_FULLSCREEN ? 4 : 0;
    ConfigSetParameter(rice, "MultiSampling", M64TYPE_INT, &multiSampling);

    // Color bit depth for rendering window (0=32 bits, 1=16 bits)
    int colorQuality = 0;
    ConfigSetParameter(rice, "ColorQuality", M64TYPE_INT, &colorQuality);

    /** End RICE CONFIG **/
    ConfigSaveSection("Video-Rice");
}
