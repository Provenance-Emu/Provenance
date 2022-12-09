#import "MupenGameNXCore+Mupen.h"
#import "MupenGameNXCore+Controls.h"
#import <PVMupen64Plus-NX/PVMupen64Plus-NX-Swift.h>

@import UIKit.UIWindow;

#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "Plugins/Core/src/main/version.h"
#import "Plugins/Core/src/plugin/plugin.h"

AUDIO_INFO AudioInfo;

unsigned char DataCRC( unsigned char *Data, int iLenght )
{
    unsigned char Remainder = Data[0];

    int iByte = 1;
    unsigned char bBit = 0;

    while( iByte <= iLenght ) {
        int HighBit = ((Remainder & 0x80) != 0);
        Remainder = Remainder << 1;

        Remainder += ( iByte < iLenght && Data[iByte] & (0x80 >> bBit )) ? 1 : 0;

        Remainder ^= (HighBit) ? 0x85 : 0;

        bBit++;
        iByte += bBit/8;
        bBit %= 8;
    }

    return Remainder;
}

void MupenAudioSampleRateChanged(int SystemType)
{
    GET_CURRENT_AND_RETURN();

    float currentRate = current.mupenSampleRate;

    switch (SystemType) {
        default:
        case SYSTEM_NTSC:
            current.mupenSampleRate = 48681812 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
        case SYSTEM_MPAL:
            current.mupenSampleRate = 48628316 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
        case SYSTEM_PAL:
            current.mupenSampleRate = 49656530 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
    }

    [[current audioDelegate] audioSampleRateDidChange];
    ILOG(@"Mupen rate changed %f -> %f\n", currentRate, current.mupenSampleRate);
}

void MupenAudioLenChanged()
{
    GET_CURRENT_AND_RETURN();

    const int LenReg = *AudioInfo.AI_LEN_REG;
    uint8_t *ptr = (uint8_t*)(AudioInfo.RDRAM + (*AudioInfo.AI_DRAM_ADDR_REG & 0xFFFFFF));
    
    // Swap channels
    for (uint32_t i = 0; i < LenReg; i += 4) {
        ptr[i] ^= ptr[i + 2];
        ptr[i + 2] ^= ptr[i];
        ptr[i] ^= ptr[i + 2];
        ptr[i + 1] ^= ptr[i + 3];
        ptr[i + 3] ^= ptr[i + 1];
        ptr[i + 1] ^= ptr[i + 3];
    }
    
    [[current ringBufferAtIndex:0] write:ptr maxLength:LenReg];
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
    int emulator = [MupenGameNXCore intForOption:@"CPU Mode"];
    ConfigSetParameter(config, "R4300Emulator", M64TYPE_INT, &emulator);

	int SiDmaDuration = [MupenGameNXCore intForOption:@"SiDmaDuration"];
	ConfigSetParameter(config, "SiDmaDuration", M64TYPE_INT, &SiDmaDuration);

	int disableExtraMemory = [MupenGameNXCore boolForOption:@"Disable Extra Memory"];
	ConfigSetParameter(config, "DisableExtraMem", M64TYPE_BOOL, &disableExtraMemory);

	int randomizeInterrupt = [MupenGameNXCore boolForOption:@"Randomize Interrupt"];
	ConfigSetParameter(config, "RandomizeInterrupt", M64TYPE_BOOL, &randomizeInterrupt);


		// Draw on-screen display if True, otherwise don't draw OSD
	int osd = [MupenGameNXCore boolForOption:@"Debug OSD"];
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
    if(RESIZE_TO_FULLSCREEN) {
        CGSize size = UIApplication.sharedApplication.keyWindow.bounds.size;
        float widthScale = floor(size.height / WIDTHf);
        float heightScale = floor(size.height / HEIGHTf);
        float scale = MAX(MIN(widthScale, heightScale), 1);
        screenWidth =  scale * WIDTHf;
        screenHeight = scale * HEIGHTf;
    }

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
    int aspectRatio = [MupenGameNXCore intForOption:@"Aspect Ratio"];

//    if(RESIZE_TO_FULLSCREEN) {
//        #if TARGET_OS_TV
//            aspectRatio = 1;
//        #else
//            aspectRatio = 3;
//        #endif
//    }

    ConfigSetParameter(gliden64, "AspectRatio", M64TYPE_INT, &aspectRatio);

    // Per-pixel lighting
    int enableHWLighting = MupenGameNXCore.perPixelLighting ? 1 : 0;
    ConfigSetParameter(gliden64, "EnableHWLighting", M64TYPE_BOOL, &enableHWLighting);

    // HiRez & texture options
    //  txHiresEnable, "Use high-resolution texture packs if available."
    int txHiresEnable = [MupenGameNXCore boolForOption:@"Enable HiRes Texture packs"];
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
    int txFilterMode = [MupenGameNXCore intForOption:@"Texture Filter Mode"];
    ConfigSetParameter(gliden64, "txFilterMode", M64TYPE_INT, &txFilterMode);

    // "txEnhancementMode", config.textureFilter.txEnhancementMode,
    // "Texture Enhancement (0=none, 1=store as is, 2=X2, 3=X2SAI, 4=HQ2X, 5=HQ2XS, 6=LQ2X, 7=LQ2XS, 8=HQ4X, 9=2xBRZ, 10=3xBRZ, 11=4xBRZ, 12=5xBRZ), 13=6xBRZ"
    int txEnhancementMode = [MupenGameNXCore intForOption:@"Texture Enhancement Mode"];
    ConfigSetParameter(gliden64, "txEnhancementMode", M64TYPE_INT, &txEnhancementMode);

    // "txCacheCompression", config.textureFilter.txCacheCompression, "Zip textures cache."
    int txCacheCompression = [MupenGameNXCore boolForOption:@"Compress texture cache"];
    ConfigSetParameter(gliden64, "txCacheCompression", M64TYPE_BOOL, &txCacheCompression);

    // "txSaveCache", config.textureFilter.txSaveCache,
    // "Save texture cache to hard disk."
    int txSaveCache = [MupenGameNXCore boolForOption:@"Save texture cache"];
    ConfigSetParameter(gliden64, "txSaveCache", M64TYPE_BOOL, &txSaveCache);

    // Warning, anything other than 0 crashes shader compilation
    // "MultiSampling", config.video.multisampling, "Enable/Disable MultiSampling (0=off, 2,4,8,16=quality)"
    int MultiSampling = [MupenGameNXCore intForOption:@"Multi Sampling"];
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
    int txDump = [MupenGameNXCore boolForOption:@"Texture Dump"];
    ConfigSetParameter(gliden64, "txDump", M64TYPE_BOOL, &txDump);

    int txFilterIgnoreBG = [MupenGameNXCore boolForOption:@"Ignore BG Textures"];
    ConfigSetParameter(gliden64, "txFilterIgnoreBG", M64TYPE_BOOL, &txFilterIgnoreBG);


    int txForce16bpp = [MupenGameNXCore boolForOption:@"Force 16bpp textures"];
    ConfigSetParameter(gliden64, "txForce16bpp", M64TYPE_BOOL, &txForce16bpp);


    // "txHresAltCRC", config.textureFilter.txHresAltCRC, "Use alternative method of paletted textures CRC calculation."
    int txHresAltCRC = [MupenGameNXCore boolForOption:@"HiRes Alt CRC"];
    ConfigSetParameter(gliden64, "txHresAltCRC", M64TYPE_BOOL, &txHresAltCRC);


    // "txHiresFullAlphaChannel", "Allow to use alpha channel of high-res texture fully."
    int txHiresFullAlphaChannel = [MupenGameNXCore boolForOption:@"HiRes Full Alpha"];;
    ConfigSetParameter(gliden64, "txHiresFullAlphaChannel", M64TYPE_BOOL, &txHiresFullAlphaChannel);

    ConfigSaveSection("Video-GLideN64");
    /** End GLideN64 Config **/
}

void ConfigureRICE() {
    /** RICE CONFIG **/
    m64p_handle rice;
    ConfigOpenSection("Video-Rice", &rice);

    // Use a faster algorithm to speed up texture loading and CRC computation
    int fastTextureLoading = [MupenGameNXCore boolForOption:@"Fast Texture Loading"];

    ConfigSetParameter(rice, "FastTextureLoading", M64TYPE_BOOL, &fastTextureLoading);

    // Enable this option to have better render-to-texture quality
    int doubleSizeForSmallTextureBuffer = [MupenGameNXCore boolForOption:@"DoubleSizeForSmallTxtrBuf"];
    ConfigSetParameter(rice, "DoubleSizeForSmallTxtrBuf", M64TYPE_BOOL, &doubleSizeForSmallTextureBuffer);

    // N64 Texture Memory Full Emulation (may fix some games, may break others)
    int fullTEMEmulation = [MupenGameNXCore boolForOption:@"FullTMEMEmulation"];
    ConfigSetParameter(rice, "FullTMEMEmulation", M64TYPE_BOOL, &fullTEMEmulation);

    // Use fullscreen mode if True, or windowed mode if False
    int fullscreen = 1;
    ConfigSetParameter(rice, "Fullscreen", M64TYPE_BOOL, &fullscreen);

    // If this option is enabled, the plugin will skip every other frame
    // Breaks some games in my testing -jm
    int skipFrame = [MupenGameNXCore boolForOption:@"SkipFrame"];
    ConfigSetParameter(rice, "SkipFrame", M64TYPE_BOOL, &skipFrame);

    // Enable hi-resolution texture file loading
    int hiResTextures = [MupenGameNXCore boolForOption:@"LoadHiResTextures"];
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

@implementation MupenGameNXCore (Mupen)

@end
