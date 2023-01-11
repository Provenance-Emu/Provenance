/*
 Copyright (c) 2015, OpenEmu Team

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

#import "PVDuckStation.h"
#import <PVDuckStation/PVDuckStation-Swift.h>
#import <PVSupport/PVSupport.h>
//#import <PVSupport/OERingBuffer.h>
//#import <PVSupport/DebugUtils.h>
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#endif

#define TickCount DuckTickCount
#include "core/types.h"
#include "core/system.h"
#include "common/log.h"
#include "common/file_system.h"
#include "common/byte_stream.h"
#include "util/cd_image.h"
#include "common/error.h"
#include "core/host_display.h"
#include "core/host_interface_progress_callback.h"
//#include "core/gpu.h"
#include "util/audio_stream.h"
#include "frontend-common/common_host.h"

#include "core/controller.h"
#include "core/digital_controller.h"
#include "core/analog_controller.h"
#include "core/guncon.h"
#include "core/playstation_mouse.h"
//#include "OpenGLHostDisplay.hpp"
//#include "frontend-common/game_settings.h"
#include "core/cheats.h"
#include "core/game_database.h"

#undef TickCount
#include <limits>
#include <optional>
#include <cstdint>
#include <vector>
#include <string>
#include <memory>
#include <os/log.h>

#include "common/gl/context.h"
#include "common/vulkan/context.h"

#define OEGameCoreErrorDomain @"org.provenance.core"
#define OEGameCoreCouldNotLoadStateError 420
#define OEGameCoreCouldNotLoadROMError 69
#define OEGameCoreCouldNotSaveStateError 42069

static void updateAnalogAxis(PVPSXButton button, int player, CGFloat amount);
static void updateAnalogControllerButton(PVPSXButton button, int player, bool down);
static void updateDigitalControllerButton(PVPSXButton button, int player, bool down);
// We're keeping this: I think it'll be useful when OpenEmu supports Metal.
static WindowInfo WindowInfoFromGameCore(PVDuckStationCore *core);

os_log_t OE_CORE_LOG;

__weak static PVDuckStationCore * _current;

//void DuckStationWriteSoundBuffer(uint8_t *buffer, unsigned int len);

struct OpenEmuChangeSettings {
    std::optional<GPUTextureFilter> textureFilter = std::nullopt;
    std::optional<bool> pxgp = std::nullopt;
    std::optional<bool> deinterlaced = std::nullopt;
    std::optional<bool> chroma24Interlace = std::nullopt;
    std::optional<u32> multisamples = std::nullopt;
    std::optional<u32> speedPercent = std::nullopt;
};

class OpenEmuAudioStream final : public AudioStream
{
public:
    OpenEmuAudioStream();
    ~OpenEmuAudioStream();

protected:
    bool OpenDevice() {
        m_output_buffer.resize(GetBufferSize() * GetChannels());
        return true;
    }
    void SetPaused(bool paused) override {}
    void CloseDevice() {}
    void FramesAvailable();

private:
    // TODO: Optimize this buffer away.
    std::vector<SampleType> m_output_buffer;
};

class OpenEmuHostInterface final //: public HostInterface
{
public:
    OpenEmuHostInterface();
    ~OpenEmuHostInterface();
    
    bool Initialize() ;
    void Shutdown() ;
    
    void ReportError(const char* message) ;
    void ReportMessage(const char* message) ;
    bool ConfirmMessage(const char* message) ;
    void AddOSDMessage(std::string message, float duration = 2.0f) ;
    
    void GetGameInfo(const char* path, CDImage* image, std::string* code, std::string* title) ;
    std::string GetSharedMemoryCardPath(u32 slot) const ;
    std::string GetGameMemoryCardPath(const char* game_code, u32 slot) const ;
    std::string GetShaderCacheBasePath() const ;
    std::string GetStringSettingValue(const char* section, const char* key, const char* default_value = "") ;
    std::string GetBIOSDirectory() ;
    void ApplyGameSettings(bool display_osd_messages);
    void OnRunningGameChanged(const std::string& path, CDImage* image, const std::string& game_code,
                              const std::string& game_title) ;
    std::vector<std::string> GetSettingStringList(const char* section, const char* key) ;
    
    bool LoadCompatibilitySettings(NSURL* path);
    virtual void CheckForSettingsChanges(const Settings& old_settings) ;

    void ChangeSettings(OpenEmuChangeSettings new_settings);
    
    void Render();
    inline void ResizeRenderWindow(s32 new_window_width, s32 new_window_height)
    {
//        if (m_display) {
//            m_display->ResizeRenderWindow(new_window_width, new_window_height);
//        }
    }
    
    virtual std::unique_ptr<ByteStream> OpenPackageFile(const char* path, u32 flags) ;

protected:
    bool AcquireHostDisplay() ;
    void ReleaseHostDisplay();
    std::unique_ptr<AudioStream> CreateAudioStream(AudioBackend backend);
    void LoadSettings(SettingsInterface& si);
    void LoadSettings();
    
private:
    bool CreateDisplay();
    
    bool m_interfaces_initialized = false;
//    GameSettings::Database m_game_settings;
};

static void OELogFunc(void* pUserParam, const char* channelName, const char* functionName,
                      LOGLEVEL level, const char* message)
{
    switch (level) {
        case LOGLEVEL_ERROR:
            os_log_error(OE_CORE_LOG, "%{public}s: %{public}s", channelName, message);
            break;
            
        case LOGLEVEL_WARNING:
        case LOGLEVEL_PERF:
            os_log(OE_CORE_LOG, "%{public}s: %{public}s", channelName, message);
            break;
            
        case LOGLEVEL_INFO:
        case LOGLEVEL_VERBOSE:
            os_log_info(OE_CORE_LOG, "%{public}s: %{public}s", channelName, message);
            break;
            
        case LOGLEVEL_DEV:
        case LOGLEVEL_DEBUG:
        case LOGLEVEL_PROFILE:
            os_log_debug(OE_CORE_LOG, "%{public}s: %{public}s", channelName, message);
            break;
            
        default:
            break;
    }
}

static NSString * const DuckStationTextureFilterKey = @"duckstation/GPU/TextureFilter";
static NSString * const DuckStationPGXPActiveKey = @"duckstation/PXGP";
static NSString * const DuckStationDeinterlacedKey = @"duckstation/GPU/Deinterlaced";
static NSString * const DuckStationAntialiasKey = @"duckstation/GPU/Antialias";
static NSString * const DuckStation24ChromaSmoothingKey = @"duckstation/GPU/24BitChroma";
static NSString * const DuckStationCPUOverclockKey = @"duckstation/CPU/Overclock";

@interface PVDuckStationCore () <PVPSXSystemResponderClient>
@end

@implementation PVDuckStationCore {
    OpenEmuHostInterface *duckInterface;
    NSString *bootPath;
    NSString *saveStatePath;
    bool isInitialized;
    NSUInteger _maxDiscs;

	dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
	dispatch_semaphore_t coreWaitToEndFrameSemaphore;

@package
    NSMutableDictionary <NSString *, id> *_displayModes;
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OE_CORE_LOG = os_log_create("org.provenance.DuckStation", "");
    });
}

- (instancetype)init {
    if (self = [super init]) {
        _current = self;

		mupenWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
		coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);

//        Log::SetFilterLevel(LOGLEVEL_TRACE);
        Log::RegisterCallback(OELogFunc, NULL);
        if(self.gs == 1) {
            g_settings.gpu_renderer = GPURenderer::HardwareVulkan;
        } else {
            g_settings.gpu_renderer = GPURenderer::HardwareOpenGL;
        }
        g_settings.controller_types[0] = ControllerType::AnalogController;
        g_settings.controller_types[1] = ControllerType::AnalogController;
        g_settings.display_crop_mode = DisplayCropMode::Overscan;
        g_settings.gpu_disable_interlacing = true;
        // match PS2's speed-up
        g_settings.cdrom_read_speedup = 4;
        g_settings.gpu_multisamples = 4;
        g_settings.gpu_pgxp_enable = true;
        g_settings.gpu_pgxp_vertex_cache = true;
        g_settings.gpu_24bit_chroma_smoothing = true;
        g_settings.gpu_texture_filter = GPUTextureFilter::Nearest;
        g_settings.gpu_resolution_scale = 0;
        g_settings.memory_card_types[0] = MemoryCardType::PerGameTitle;
        g_settings.memory_card_types[1] = MemoryCardType::PerGameTitle;
        g_settings.cpu_execution_mode = CPUExecutionMode::Recompiler;
        duckInterface = new OpenEmuHostInterface();
        _displayModes = [[NSMutableDictionary alloc] init];
        NSURL *gameSettingsURL = [[NSBundle bundleForClass:[PVDuckStationCore class]] URLForResource:@"gamesettings" withExtension:@"ini"];
        if (gameSettingsURL) {
            bool success = duckInterface->LoadCompatibilitySettings(gameSettingsURL);
            if (!success) {
                os_log_fault(OE_CORE_LOG, "Game settings for particular discs didn't load, name %{public}@ at path %{private}@", gameSettingsURL.lastPathComponent, gameSettingsURL.path);
            }
        } else {
            os_log_fault(OE_CORE_LOG, "Game settings for particular discs wasn't found.");
        }
        gameSettingsURL = [[NSBundle bundleForClass:[PVDuckStationCore class]] URLForResource:@"OEOverrides" withExtension:@"ini"];
        if (gameSettingsURL) {
            bool success = duckInterface->LoadCompatibilitySettings(gameSettingsURL);
            if (!success) {
                os_log_fault(OE_CORE_LOG, "OpenEmu-specific overrides for particular discs didn't load, name %{public}@ at path %{private}@", gameSettingsURL.lastPathComponent, gameSettingsURL.path);
            }
        } else {
            os_log_fault(OE_CORE_LOG, "OpenEmu-specific overrides for particular discs wasn't found.");
        }
    }
    return self;
}

- (void)dealloc {
}

#pragma mark - Execution

-(NSString*) systemIdentifier {
    return @"com.provenance.psx";
}

//-(NSString*)biosDirectoryPath {
//    return self.BIOSPath;
//}

//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
//    [[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath]
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:NULL];
//
//}
//
//- (void)executeFrame
//{
//
//}
//
//- (void)resetEmulation
//{
//}
//
//- (void)stopEmulation
//{
//    [super stopEmulation];
//}

//- (NSTimeInterval)frameInterval
//{
//    return Atari800_tv_mode == Atari800_TV_NTSC ? Atari800_FPS_NTSC : Atari800_FPS_PAL;
//}

#pragma mark - Video

- (const void *)videoBuffer {
    return NULL;
//    if ( frontBufferSurf == NULL )
//    {
//        return NULL;
//    }
//    else
//    {
//        return frontBufferSurf->pixels;
//    }
}

//- (CGSize)bufferSize {
////    if ( game == NULL )
////    {
////        return CGSizeMake(0, 0);
////    }
////    else
////    {
////        return CGSizeMake(game->fb_width, game->fb_height);
////    }
//    return self.screenRect.size;
//}

- (CGRect)screenRect {
    return CGRectMake(0, 0, 640, 480);
//    return CGRectMake(24, 0, Screen_WIDTH, Screen_HEIGHT);
}

//- (CGSize)aspectSize
//{
//    // TODO: fix PAR
//    //return CGSizeMake(336 * (6.0 / 7.0), 240);
//    return CGSizeMake(640, 480);
//}

- (GLenum)pixelFormat {
    return GL_RGBA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

- (BOOL)rendersToOpenGL {
    return YES;
}

//- (BOOL)isDoubleBuffered {
//    return YES;
//}


- (dispatch_time_t)frameTime {
	float frameTime = 1.0/[self frameInterval];
	__block BOOL expired = NO;
	dispatch_time_t killTime = dispatch_time(DISPATCH_TIME_NOW, frameTime * NSEC_PER_SEC);
	return killTime;
}


- (void)videoInterrupt
{
	dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

	dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, [self frameTime]);
}


- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

//- (BOOL)isDoubleBuffered {
//    return YES;
//}
//
//- (void)swapBuffers
//{
////    Mednafen::MDFN_Surface *tempSurf = backBufferSurf;
////    backBufferSurf = frontBufferSurf;
////    frontBufferSurf = tempSurf;
//}

#pragma mark - Audio

//- (double)audioSampleRate
//{
//    return 44100;
//}
//
//- (NSUInteger)channelCount
//{
//    return 1;
//}

#pragma mark - Save States
- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    NSAssert(NO, @"Shouldn't be here since we overload the async version");
}
//
//- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
//{
//    #warning "Placeholder"
//    BOOL success = true;
//
//    if (!success) {
//        NSDictionary *userInfo = @{
//                                   NSLocalizedDescriptionKey: @"Failed to save state.",
//                                   NSLocalizedFailureReasonErrorKey: @"DuckStation failed to create save state.",
//                                   NSLocalizedRecoverySuggestionErrorKey: @""
//                                   };
//
//        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
//                                                code:PVEmulatorCoreErrorCodeCouldNotSaveState
//                                            userInfo:userInfo];
//        block(NO, newError);
//    } else {
//        block(YES, nil);
//    }
//}
//
- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    NSAssert(NO, @"Shouldn't be here since we overload the async version");
}
//
//- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//    #warning "Placeholder"
//    BOOL success = true;
//    if (!success) {
//        NSDictionary *userInfo = @{
//                                   NSLocalizedDescriptionKey: @"Failed to save state.",
//                                   NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
//                                   NSLocalizedRecoverySuggestionErrorKey: @""
//                                   };
//
//        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
//                                                code:PVEmulatorCoreErrorCodeCouldNotLoadState
//                                            userInfo:userInfo];
//
//        block(NO, newError);
//    } else {
//        block(YES, nil);
//    }
//}

#pragma mark - Input

- (void)pollControllers {
    NSUInteger maxNumberPlayers = 4; //MIN([self maxNumberPlayers], 4);

    for (NSInteger playerIndex = 0; playerIndex < maxNumberPlayers; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
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
        
//        if (controller) {
//            uint8 *d8 = (uint8 *)inputBuffer[playerIndex];
//            bool analogMode = (d8[2] & 0x02);
//            
//            for (unsigned i=0; i<maxValue; i++) {
//                
//                if (self.systemType != MednaSystemPSX || i < PVPSXButtonLeftAnalogUp) {
//                    uint32_t value = (uint32_t)[self controllerValueForButtonID:i forPlayer:playerIndex withAnalogMode:analogMode];
//                    
//                    if(value > 0) {
//                        inputBuffer[playerIndex][0] |= 1 << map[i];
//                    } else {
//                        inputBuffer[playerIndex][0] &= ~(1 << map[i]);
//                    }
//                } else if (analogMode) {
//                    float analogValue = [self PSXAnalogControllerValueForButtonID:i forController:controller];
//                    [self didMovePSXJoystickDirection:(PVPSXButton)i
//                                            withValue:analogValue
//                                            forPlayer:playerIndex];
//                }
//            }
//        }
    }
}

#pragma mark - OpenEMU Code

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    [[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    Log::SetFileOutputParams(true, [self.BIOSPath stringByAppendingPathComponent:@"emu.log"].fileSystemRepresentation);
    if ([[path pathExtension] compare:@"ccd" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        //DuckStation doens't handle CCD files at all. Replace with the likely-present .IMG instead
        path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"img"];
    } else if([path.pathExtension.lowercaseString isEqualToString:@"m3u"]) {
        // Parse number of discs in m3u
        NSString *m3uString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".*\\.cue|.*\\.ccd" options:NSRegularExpressionCaseInsensitive error:nil];
        NSRegularExpression *ccdRegex = [NSRegularExpression regularExpressionWithPattern:@".*\\.ccd" options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger numberOfCcds = [ccdRegex numberOfMatchesInString:m3uString options:0 range:NSMakeRange(0, m3uString.length)];
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:m3uString options:0 range:NSMakeRange(0, m3uString.length)];
        if (numberOfCcds > 0) {
            if (error) {
                *error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadROMError userInfo:@{
                    NSLocalizedDescriptionKey: NSLocalizedStringFromTableInBundle(@"Clone CD Files Aren't Supported", nil, [NSBundle bundleForClass:[self class]], @"Clone CD Files Aren't Supported"),
                    NSDebugDescriptionErrorKey: @"Clone CD Files Aren't Supported",
                    NSLocalizedFailureReasonErrorKey: NSLocalizedStringFromTableInBundle(@"DuckStation currently doesn't support Clone CD (.ccd) files in .m3u playlists.", nil, [NSBundle bundleForClass:[self class]], @"Clone CD Files Aren't Supported (longer)"),
                    NSLocalizedRecoverySuggestionErrorKey: NSLocalizedStringFromTableInBundle(@"Convert the .ccd files to .cue files, then update the playlist to point to the new .cue files.", nil, [NSBundle bundleForClass:[self class]], @"Clone CD Files Aren't Supported (suggestion)")
                }];
            }
            return NO;
        }
        
        os_log_debug(OE_CORE_LOG, "Loading m3u containing %lu cue sheets", numberOfMatches);
        
        self.maxDiscs = numberOfMatches;
    } else if ([path.pathExtension.lowercaseString isEqualToString:@"pbp"]) {
        Common::Error pbpError;
        auto pbpImage = CDImage::OpenPBPImage(path.fileSystemRepresentation, &pbpError);
        if (pbpImage) {
            self.maxDiscs = pbpImage->GetSubImageCount();
            os_log_debug(OE_CORE_LOG, "Loading PBP containing %ld discs", (long)self.maxDiscs);
            pbpImage.reset();
        } else if (pbpError.GetMessage() == "Encrypted PBP images are not supported") {
            // Error out
            if (error) {
                *error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadROMError userInfo:@{
                    NSLocalizedDescriptionKey: NSLocalizedStringFromTableInBundle(@"Encrypted PBP images are not supported", nil, [NSBundle bundleForClass:[self class]], @"Encrypted PBP Images Aren't Supported"),
                    NSDebugDescriptionErrorKey: @"Encrypted PBP images are not supported",
                    NSLocalizedFailureReasonErrorKey: NSLocalizedStringFromTableInBundle(@"DuckStation currently doesn't support encrypted PBP files.", nil, [NSBundle bundleForClass:[self class]], @"Encrypted PBP Images Aren't Supported (longer)"),
                    NSLocalizedRecoverySuggestionErrorKey: NSLocalizedStringFromTableInBundle(@"Decrypt the PBP file or find a version of the game that is in another format.", nil, [NSBundle bundleForClass:[self class]], @"Encrypted PBP Images Aren't Supported (suggestion)")
                }];
            }
            return NO;
        } else {
            std::string cppStr = std::string(pbpError.GetCodeAndMessage());
            //TODO: Show the warning to the user!
            os_log_info(OE_CORE_LOG, "Failed to load PBP: %s. Will continue to attempt to load, but no guaranteee of it loading successfully\nAlso, only one disc will load.", cppStr.c_str());
        }
    }
    bootPath = [path copy];

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    EAGLContext* context = [self bestContext];
#endif
    
    return true;
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

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    if (!isInitialized) {
        saveStatePath = [fileName copy];
        block(YES, nil);
        return;
    }
    const bool result = System::LoadState(fileName.fileSystemRepresentation);
    
    block(result, nil);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
//    std::unique_ptr<ByteStream> stream = FileSystem::OpenFile(fileName.fileSystemRepresentation, BYTESTREAM_OPEN_CREATE | BYTESTREAM_OPEN_WRITE | BYTESTREAM_OPEN_TRUNCATE |
//                                       BYTESTREAM_OPEN_ATOMIC_UPDATE | BYTESTREAM_OPEN_STREAMED | BYTESTREAM_OPEN_CREATE_PATH);
//    if (!stream) {
//        block(NO, [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{NSFilePathErrorKey: fileName}]);
//        return;
//    }
//
//    const bool result = System::SaveState(stream.get(), 0);
//
//    block(result, nil);
}

//- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
//{
//    auto mem = std::make_unique<ReadOnlyMemoryByteStream>(state.bytes, (u32)state.length);
//    bool okay = System::LoadState(mem.get());
//    if (!okay && outError) {
//        *outError = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadStateError userInfo:nil];
//    }
//    return okay;
//}

//- (NSData *)serializeStateWithError:(NSError *__autoreleasing *)outError
//{
//    auto mem = std::make_unique<GrowableMemoryByteStream>((void*)NULL, 0);
//    const bool result = System::SaveState(mem.get(), 0);
//    if (!result) {
//        if (outError) {
//            *outError = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotSaveStateError userInfo:nil];
//        }
//        return nil;
//    }
//    NSData *toRet = [NSData dataWithBytes:mem->GetMemoryPointer() length:mem->GetMemorySize()];
//    return toRet;
//}

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
    //TODO: implement
    auto list = std::make_unique<CheatList>();
    list->LoadFromPCSXRString(code.UTF8String);
    //list->Apply();
    //System::SetCheatList(std::move(list));
}

- (NSUInteger)discCount
{
    return self.maxDiscs ?: 1;
}

- (void)setDisc:(NSUInteger)discNumber {
    if (System::HasMediaSubImages()) {
        uint32_t index = (uint32_t)discNumber - 1; // 0-based index
        System::SwitchMediaSubImage(index);
    }
}

- (void)resetEmulation {
    System::ResetSystem();
}

- (void)stopEmulation {
    System::ShutdownSystem(false);
//
//    duckInterface->Shutdown();
    
    [super stopEmulation];
}

- (CGSize)aspectSize {
//    return CGSizeMake(640, 480);
    return (CGSize){ 4, 3 };
}

- (BOOL)tryToResizeVideoTo:(CGSize)size
{
    if (!System::IsShutdown() && isInitialized) {
        duckInterface->ResizeRenderWindow(size.width, size.height);
        
//        g_gpu->UpdateResolutionScale();
    }
    return YES;
}

//- (OEGameCoreRendering)gameCoreRendering
//{
//    //TODO: return OEGameCoreRenderingMetal1Video;
//    return OEGameCoreRenderingOpenGL3Video;
//}

- (oneway void)mouseMovedAtPoint:(CGPoint)point
{
    switch (g_settings.controller_types[0]) {
        case ControllerType::GunCon:
        case ControllerType::PlayStationMouse:
        {
            //TODO: scale input!
//            HostDisplay* display = g_host_interface->GetDisplay();
//            display->SetMousePosition(point.x, point.y);
        }
            return;
            break;
            
        default:
            break;
    }
    
    switch (g_settings.controller_types[1]) {
        case ControllerType::PlayStationMouse:
        {
            //TODO: scale input!
//            HostDisplay* display = g_host_interface->GetDisplay();
//            display->SetMousePosition(point.x, point.y);
        }
            break;
            
        default:
            break;
    }
}

- (oneway void)leftMouseDownAtPoint:(CGPoint)point
{
    switch (g_settings.controller_types[0]) {
        case ControllerType::GunCon:
        {
            [self mouseMovedAtPoint:point];
            GunCon *controller = static_cast<GunCon*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(GunCon::Button::Trigger), true);
        }
            return;
            break;
            
        case ControllerType::PlayStationMouse:
        {
            [self mouseMovedAtPoint:point];
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), true);
        }
            return;
            break;
            
        default:
            break;
    }
    
    switch (g_settings.controller_types[1]) {
        case ControllerType::PlayStationMouse:
        {
            [self mouseMovedAtPoint:point];
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(1));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), true);
        }
            break;
            
        default:
            break;
    }
}

- (oneway void)leftMouseUp
{
    switch (g_settings.controller_types[0]) {
        case ControllerType::GunCon:
        {
            GunCon *controller = static_cast<GunCon*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(GunCon::Button::Trigger), false);
        }
            return;
            break;
            
        case ControllerType::PlayStationMouse:
        {
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), false);
        }
            return;
            break;

        default:
            break;
    }
    
    switch (g_settings.controller_types[1]) {
        case ControllerType::PlayStationMouse:
        {
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(1));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), false);
        }
            break;

        default:
            break;
    }
}

- (oneway void)rightMouseDownAtPoint:(CGPoint)point
{
    switch (g_settings.controller_types[0]) {
        case ControllerType::GunCon:
        {
//            [self mouseMovedAtPoint:point];
            GunCon *controller = static_cast<GunCon*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(GunCon::Button::ShootOffscreen), true);
        }
            return;
            break;
            
        case ControllerType::PlayStationMouse:
        {
            [self mouseMovedAtPoint:point];
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Right), true);
        }
            return;
            break;
            
        default:
            break;
    }
    
    switch (g_settings.controller_types[1]) {
        case ControllerType::PlayStationMouse:
        {
            [self mouseMovedAtPoint:point];
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(1));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Right), true);
        }
            break;
            
        default:
            break;
    }
}

- (oneway void)rightMouseUp
{
    switch (g_settings.controller_types[0]) {
        case ControllerType::GunCon:
        {
            GunCon *controller = static_cast<GunCon*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(GunCon::Button::ShootOffscreen), false);
        }
            return;
            break;
            
        case ControllerType::PlayStationMouse:
        {
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Right), false);
        }
            return;
            break;

        default:
            break;
    }
    
    switch (g_settings.controller_types[1]) {
        case ControllerType::PlayStationMouse:
        {
            PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(1));
            controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Right), false);
        }
            break;

        default:
            break;
    }
}

- (oneway void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player {
    player -= 1;
    switch (button) {
        case PVPSXButtonLeftAnalogLeft:
        case PVPSXButtonLeftAnalogUp:
        case PVPSXButtonRightAnalogLeft:
        case PVPSXButtonRightAnalogUp:
            value *= -1;
            break;
        default:
            break;
    }
    switch (g_settings.controller_types[player]) {
        case ControllerType::AnalogController:
            updateAnalogAxis(button, (int)player, value);
            break;
            
        default:
            break;
    }
}

- (oneway void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player {
    player -= 1;
    
    switch (g_settings.controller_types[player]) {
        case ControllerType::DigitalController:
            updateDigitalControllerButton(button, (int)player, true);
            break;
            
        case ControllerType::AnalogController:
            updateAnalogControllerButton(button, (int)player, true);
            break;
            
        case ControllerType::GunCon:
        {
            if (player != 0) {
                break;
            }
            GunCon *controller = static_cast<GunCon*>(System::GetController(0));
            switch (button) {
                case PVPSXButtonCircle:
                case PVPSXButtonSquare:
                    controller->SetBindState(static_cast<u32>(GunCon::Button::A), true);
                    break;
                    
                case PVPSXButtonCross:
                case PVPSXButtonTriangle:
                case PVPSXButtonStart:
                    controller->SetBindState(static_cast<u32>(GunCon::Button::B), true);
                    break;

                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
}


- (oneway void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player {
    player -= 1;
    
    switch (g_settings.controller_types[player]) {
        case ControllerType::DigitalController:
            updateDigitalControllerButton(button, (int)player, false);
            break;
            
        case ControllerType::AnalogController:
            updateAnalogControllerButton(button, (int)player, false);
            break;
            
        case ControllerType::GunCon:
        {
            if (player != 0) {
                break;
            }
            GunCon *controller = static_cast<GunCon*>(System::GetController(0));
            switch (button) {
                case PVPSXButtonCircle:
                case PVPSXButtonSquare:
                    controller->SetBindState(static_cast<u32>(GunCon::Button::A), false);
                    break;
                    
                case PVPSXButtonCross:
                case PVPSXButtonTriangle:
                case PVPSXButtonStart:
                    controller->SetBindState(static_cast<u32>(GunCon::Button::B), false);
                    break;

                default:
                    break;
            }
        }
            break;

        default:
            break;
    }
}

- (NSUInteger)channelCount {
    return 2;
}

- (NSUInteger)audioBitDepth {
    return 16;
}

- (double)audioSampleRate {
    return 44100;
//    return AudioStream::DefaultOutputSampleRate;
}

- (CGSize)bufferSize {
//    return self.screenRect.size;
    return (CGSize){ 640, 480 };
}

- (void)startEmulation
{
	if(!self.isRunning)
	{
		[super startEmulation];
		[NSThread detachNewThreadSelector:@selector(runDuckstationEmuThread) toTarget:self withObject:nil];
	}
}


- (void)runDuckstationEmuThread
{
	@autoreleasepool
	{
		if (!isInitialized){
            SystemBootParameters params;
            params.filename = std::move(bootPath.fileSystemRepresentation);
//            params.save_state = std::move(state);
//            params.override_fast_boot = std::move(fast_boot);


            isInitialized = System::BootSystem(std::move(params));
//			isInitialized = duckInterface->BootSystem(params);
			if (saveStatePath) {
                System::LoadState(saveStatePath.fileSystemRepresentation);
				saveStatePath = nil;
			}
		}
		[self.renderDelegate startRenderingOnAlternateThread];
        //#error either this, or emuThread
        do {
            System::RunFrames();
//            if (!skip) {
                duckInterface->Render();
//          }
        }while(!shouldStop);
//        System::RunFrame();
//
//        if (!skip) {
//            duckInterface->Render();
//        }
//		if(CoreDoCommand(M64CMD_EXECUTE, 0, NULL) != M64ERR_SUCCESS) {
//			ELOG(@"Core execture did not exit correctly");
//		} else {
//			ILOG(@"Core finished executing main");
//		}
//
//		if(CoreDetachPlugin(M64PLUGIN_GFX) != M64ERR_SUCCESS) {
//			ELOG(@"Failed to detach GFX plugin");
//		} else {
//			ILOG(@"Detached GFX plugin");
//		}
//
//		if(CoreDetachPlugin(M64PLUGIN_RSP) != M64ERR_SUCCESS) {
//			ELOG(@"Failed to detach RSP plugin");
//		} else {
//			ILOG(@"Detached RSP plugin");
//		}
//
//		[self pluginsUnload];

//		if(CoreDoCommand(M64CMD_ROM_CLOSE, 0, NULL) != M64ERR_SUCCESS) {
//			ELOG(@"Failed to close ROM");
//		} else {
//			ILOG(@"ROM closed");
//		}

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


- (void)executeFrameSkippingFrame:(BOOL)skip {
	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

	dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
//#error either this, or emuThread
//    System::RunFrame();
//
//    if (!skip) {
//        duckInterface->Render();
//    }
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}


- (NSDictionary<NSString *,id> *)displayModeInfo {
    return [_displayModes copy];
}

- (void)setDisplayModeInfo:(NSDictionary<NSString *, id> *)displayModeInfo {
    const struct {
        NSString *const key;
        Class valueClass;
        id defaultValue;
    } defaultValues[] = {
        { DuckStationPGXPActiveKey,        [NSNumber class], @YES  },
        { DuckStationDeinterlacedKey,      [NSNumber class], @YES  },
        { DuckStationTextureFilterKey,     [NSNumber class], @0 /*GPUTextureFilter::Nearest*/ },
        { DuckStationAntialiasKey,         [NSNumber class], @4 },
        { DuckStationCPUOverclockKey,      [NSNumber class], @100 },
        { DuckStation24ChromaSmoothingKey, [NSNumber class], @YES}
    };
    /* validate the defaults to avoid crashes caused by users playing
     * around where they shouldn't */
    _displayModes = [[NSMutableDictionary alloc] init];
    const int n = sizeof(defaultValues)/sizeof(defaultValues[0]);
    for (int i=0; i<n; i++) {
        id thisPref = displayModeInfo[defaultValues[i].key];
        if ([thisPref isKindOfClass:defaultValues[i].valueClass])
            _displayModes[defaultValues[i].key] = thisPref;
        else
            _displayModes[defaultValues[i].key] = defaultValues[i].defaultValue;
    }
}

- (void)loadConfiguration {
    NSNumber *pxgpActive = _displayModes[DuckStationPGXPActiveKey];
    NSNumber *textureFilter = _displayModes[DuckStationTextureFilterKey];
    NSNumber *deinterlace = _displayModes[DuckStationDeinterlacedKey];
    NSNumber *antialias = _displayModes[DuckStationAntialiasKey];
    NSNumber *overclock = _displayModes[DuckStationCPUOverclockKey];
    NSNumber *chroma24 = _displayModes[DuckStation24ChromaSmoothingKey];
    OpenEmuChangeSettings settings;
    if (pxgpActive && [pxgpActive isKindOfClass:[NSNumber class]]) {
        settings.pxgp = [pxgpActive boolValue];
    }
    if (textureFilter && [textureFilter isKindOfClass:[NSNumber class]]) {
        settings.textureFilter = GPUTextureFilter([textureFilter intValue]);
    }
    if (deinterlace && [deinterlace isKindOfClass:[NSNumber class]]) {
        settings.deinterlaced = [deinterlace boolValue];
    }
    if (antialias && [antialias isKindOfClass:[NSNumber class]]) {
        settings.multisamples = [antialias unsignedIntValue];
    }
    if (overclock && [overclock isKindOfClass:[NSNumber class]]) {
        settings.speedPercent = [overclock unsignedIntValue];
    }
    if (chroma24 && [overclock isKindOfClass:[NSNumber class]]) {
        settings.chroma24Interlace = [chroma24 boolValue];
    }
    duckInterface->ChangeSettings(settings);
}

/* Groups (submenus) */

/** The NSString which will be shown in the Display Mode as the parent menu item
 *  for the submenu. */
#define OEGameCoreDisplayModeGroupNameKey @"OEGameCoreDisplayModeGroupNameKey"
/** An NSArray of NSDictionaries containing the entries in the group.
 *  @warning Only one level of indentation is supported to disallow over-complicated
 *    menus. */
#define OEGameCoreDisplayModeGroupItemsKey @"OEGameCoreDisplayModeGroupItemsKey"

/* Binary (toggleable) and Mutually-Exclusive Display Modes */

/** The NSString which will be shown in the Display Mode menu for this entry. This
 *  string must be unique to each display mode. */
#define OEGameCoreDisplayModeNameKey @"OEGameCoreDisplayModeNameKey"
/** Toggleable modes only. @(YES) if this mode is standalone and can be toggled.
 *  If @(NO) or unspecified, this item is part of a group of mutually-exclusive modes. */
#define OEGameCoreDisplayModeAllowsToggleKey @"OEGameCoreDisplayModeAllowsToggleKey"
/** Mutually-exclusive modes only. An NSString uniquely identifying this display mode
 *  within its group. Optional. if not specified, the value associated with
 *  OEGameCoreDisplayModeNameKey will be used instead. */
#define OEGameCoreDisplayModePrefValueNameKey @"OEGameCoreDisplayModePrefValueNameKey"
/** Toggleable modes: An NSString uniquely identifying this display mode.
 *  Mutually-exclusive modes: An NSString uniquely identifying the group of mutually
 *  exclusive modes this mode is part of.
 *  Every group of mutually-exclusive modes is defined implicitly as a set of modes with
 *  the same OEGameCoreDisplayModePrefValueNameKey. */
#define OEGameCoreDisplayModePrefKeyNameKey @"OEGameCoreDisplayModePrefKeyNameKey"
/** @(YES) if this mode is currently selected. */
#define OEGameCoreDisplayModeStateKey @"OEGameCoreDisplayModeStateKey"
/** @(YES) if this mode is inaccessible through the nextDisplayMode: and lastDisplayMode:
 *  actions */
#define OEGameCoreDisplayModeManualOnlyKey @"OEGameCoreDisplayModeMenuOnlyKey"
/** @(YES) if this mode is not saved in the preferences. */
#define OEGameCoreDisplayModeDisallowPrefSaveKey @"OEGameCoreDisplayModeDisallowPrefSaveKey"

/* Labels & Separators */

/** Separator only. Present if this item is a separator. Value does not matter. */
#define OEGameCoreDisplayModeSeparatorItemKey @"OEGameCoreDisplayModeSeparatorItemKey"
/** Label only. The NSString which will be shown in the Display Mode menu for this label. */
#define OEGameCoreDisplayModeLabelKey @"OEGameCoreDisplayModeLabelKey"

/* Other Keys */

/** An NSNumber specifying the level of indentation of this item. */
#define OEGameCoreDisplayModeIndentationLevelKey @"OEGameCoreDisplayModeIndentationLevelKey"


/*
 * Utility macros
 */
 
#define OEDisplayMode_OptionWithStateValue(_NAME_, _PREFKEY_, _STATE_, _VAL_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModePrefValueNameKey : _VAL_ }
    
#define OEDisplayMode_OptionWithValue(_NAME_, _PREFKEY_, _VAL_) \
    OEDisplayMode_OptionWithStateValue(_NAME_, _PREFKEY_, @NO, _VAL_)
    
#define OEDisplayMode_OptionDefaultWithValue(_NAME_, _PREFKEY_, _VAL_) \
    OEDisplayMode_OptionWithStateValue(_NAME_, _PREFKEY_, @YES, _VAL_)
 
#define OEDisplayMode_OptionWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_ }

#define OEDisplayMode_Option(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionWithState(_NAME_, _PREFKEY_, @NO)

#define OEDisplayMode_OptionDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionWithState(_NAME_, _PREFKEY_, @YES)

#define OEDisplayMode_OptionIndentedWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeIndentationLevelKey : @(1) }
    
#define OEDisplayMode_OptionIndented(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionIndentedWithState(_NAME_, _PREFKEY_, @NO)
    
#define OEDisplayMode_OptionDefaultIndented(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionIndentedWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_OptionToggleableWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeAllowsToggleKey : @YES }
    
#define OEDisplayMode_OptionToggleable(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableWithState(_NAME_, _PREFKEY_, @NO)
    
#define OEDisplayMode_OptionToggleableDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_OptionToggleableNoSaveWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeAllowsToggleKey : @YES, \
    OEGameCoreDisplayModeDisallowPrefSaveKey : @YES }
    
#define OEDisplayMode_OptionToggleableNoSave(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableNoSaveWithState(_NAME_, _PREFKEY_, @NO)
    
#define OEDisplayMode_OptionToggleableNoSaveDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionToggleableNoSaveWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_OptionManualWithState(_NAME_, _PREFKEY_, _STATE_) @{ \
    OEGameCoreDisplayModeNameKey : _NAME_, \
    OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, \
    OEGameCoreDisplayModeStateKey : _STATE_, \
    OEGameCoreDisplayModeManualOnlyKey : @YES }
    
#define OEDisplayMode_OptionManual(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionManualWithState(_NAME_, _PREFKEY_, @NO)

#define OEDisplayMode_OptionManualDefault(_NAME_, _PREFKEY_) \
    OEDisplayMode_OptionManualWithState(_NAME_, _PREFKEY_, @YES)
    
#define OEDisplayMode_Label(_NAME_) @{ \
    OEGameCoreDisplayModeLabelKey : _NAME_ }

#define OEDisplayMode_SeparatorItem() @{ \
    OEGameCoreDisplayModeSeparatorItemKey : @"" }

#define OEDisplayMode_Submenu(_NAME_, ...) @{ \
    OEGameCoreDisplayModeGroupNameKey: _NAME_, \
    OEGameCoreDisplayModeGroupItemsKey: __VA_ARGS__ }


NS_INLINE BOOL OEDisplayModeListGetPrefKeyValueFromModeName(
    NSArray<NSDictionary<NSString *,id> *> *list, NSString *name,
    NSString * __autoreleasing *outKey, id __autoreleasing *outValue)
{
    for (NSDictionary<NSString *,id> *option in list) {
        if (option[OEGameCoreDisplayModeGroupNameKey]) {
            NSArray *content = option[OEGameCoreDisplayModeGroupItemsKey];
            BOOL res = OEDisplayModeListGetPrefKeyValueFromModeName(content, name, outKey, outValue);
            if (res) return res;
        } else {
            NSString *optname = option[OEGameCoreDisplayModeNameKey];
            if (!optname) continue;
            if ([optname isEqual:name]) {
                if (outKey) *outKey = option[OEGameCoreDisplayModePrefKeyNameKey];
                if (outValue) {
                    BOOL toggleable = [option[OEGameCoreDisplayModeAllowsToggleKey] boolValue];
                    if (toggleable) {
                        *outValue = option[OEGameCoreDisplayModeStateKey];
                    } else {
                        id val = option[OEGameCoreDisplayModePrefValueNameKey];
                        *outValue = val ?: optname;
                    }
                }
                return YES;
            }
        }
    }
    return NO;
}

NS_INLINE NSString *OEDisplayModeListGetPrefKeyFromModeName(
    NSArray<NSDictionary<NSString *,id> *> *list, NSString *name)
{
    NSString *tmp;
    BOOL res = OEDisplayModeListGetPrefKeyValueFromModeName(list, name, &tmp, NULL);
    return res ? tmp : nil;
}

- (NSArray <NSDictionary <NSString *, id> *> *)displayModes
{
#define OptionWithValue(n, k, v) \
@{ \
    OEGameCoreDisplayModeNameKey : n, \
    OEGameCoreDisplayModePrefKeyNameKey : k, \
    OEGameCoreDisplayModeStateKey : @([_displayModes[k] isEqual:@(v)]), \
    OEGameCoreDisplayModePrefValueNameKey : @(v) }
#define OptionToggleable(n, k) \
    OEDisplayMode_OptionToggleableWithState(n, k, _displayModes[k])

    return @[
        OEDisplayMode_Submenu(@"Texture Filtering",
                              @[OptionWithValue(@"Nearest Neighbor", DuckStationTextureFilterKey, int(GPUTextureFilter::Nearest)),
                                OptionWithValue(@"Bilinear", DuckStationTextureFilterKey, int(GPUTextureFilter::Bilinear)),
                                OptionWithValue(@"Bilinear (No Edge Blending)", DuckStationTextureFilterKey, int(GPUTextureFilter::BilinearBinAlpha)),
                                OptionWithValue(@"JINC2", DuckStationTextureFilterKey, int(GPUTextureFilter::JINC2)),
                                OptionWithValue(@"JINC2 (No Edge Blending)", DuckStationTextureFilterKey, int(GPUTextureFilter::JINC2BinAlpha)),
                                OptionWithValue(@"xBR", DuckStationTextureFilterKey, int(GPUTextureFilter::xBR)),
                                OptionWithValue(@"xBR (No Edge Blending)", DuckStationTextureFilterKey, int(GPUTextureFilter::xBRBinAlpha))]),
        OptionToggleable(@"PGXP", DuckStationPGXPActiveKey),
        OptionToggleable(@"Deinterlace", DuckStationDeinterlacedKey),
//        OptionToggleable(@"Chroma 24 Interlace", DuckStation24ChromaSmoothingKey),
        OEDisplayMode_Submenu(@"MSAA", @[OptionWithValue(@"Off", DuckStationAntialiasKey, 1), OptionWithValue(@"2x", DuckStationAntialiasKey, 2), OptionWithValue(@"4x", DuckStationAntialiasKey, 4), OptionWithValue(@"8x", DuckStationAntialiasKey, 8), OptionWithValue(@"16x", DuckStationAntialiasKey, 16)]),
        OEDisplayMode_Submenu(@"CPU speed",
                              @[OptionWithValue(@"100% (default)", DuckStationCPUOverclockKey, 100),
                                OptionWithValue(@"200%", DuckStationCPUOverclockKey, 200),
                                OptionWithValue(@"300%", DuckStationCPUOverclockKey, 300),
                                OptionWithValue(@"400%", DuckStationCPUOverclockKey, 400),
                                OptionWithValue(@"500%", DuckStationCPUOverclockKey, 500),
                                OptionWithValue(@"600%", DuckStationCPUOverclockKey, 600)]),
    ];

#undef OptionWithValue
#undef OptionToggleable
}

- (void)changeDisplayWithMode:(NSString *)displayMode {
    NSString *key;
    id currentVal;
    OpenEmuChangeSettings settings;
    OEDisplayModeListGetPrefKeyValueFromModeName(self.displayModes, displayMode, &key, &currentVal);
    if (key == nil) {
             return;
     }
    _displayModes[key] = currentVal;

    if ([key isEqualToString:DuckStationTextureFilterKey]) {
        settings.textureFilter = GPUTextureFilter([currentVal intValue]);
    } else if ([key isEqualToString:DuckStationPGXPActiveKey]) {
        settings.pxgp = ![currentVal boolValue];
    } else if ([key isEqualToString:DuckStationDeinterlacedKey]) {
        settings.deinterlaced = ![currentVal boolValue];
    } else if ([key isEqualToString:DuckStationAntialiasKey]) {
        settings.multisamples = [currentVal unsignedIntValue];
    } else if ([key isEqualToString:DuckStationCPUOverclockKey]) {
        settings.speedPercent = [currentVal unsignedIntValue];
    } else if ([key isEqualToString:DuckStation24ChromaSmoothingKey]) {
        settings.chroma24Interlace = [currentVal boolValue];
    }
    duckInterface->ChangeSettings(settings);
}


@end

#pragma mark -

#define TickCount DuckTickCount
#include "common/assert.h"
#include "common/byte_stream.h"
#include "common/file_system.h"
#include "common/log.h"
#include "common/string_util.h"
#include "core/analog_controller.h"
#include "core/bus.h"
#include "core/cheats.h"
#include "core/digital_controller.h"
#include "core/gpu.h"
#include "core/system.h"
#undef TickCount
#include <array>
#include <cstring>
#include <tuple>
#include <utility>
#include <vector>


#pragma mark OpenEmuHostInterface methods -

OpenEmuHostInterface::OpenEmuHostInterface()=default;
OpenEmuHostInterface::~OpenEmuHostInterface()=default;

bool OpenEmuHostInterface::Initialize() {
    m_program_directory = [NSBundle bundleForClass:[PVDuckStationCore class]].resourceURL.fileSystemRepresentation;
    GET_CURRENT_OR_RETURN(false);
    m_user_directory = [current BIOSPath].fileSystemRepresentation;
    if (!HostInterface::Initialize())
      return false;

    if (!CreateDisplay()) {
        return false;
    }
    LoadSettings();
    
    return true;
}

void OpenEmuHostInterface::Shutdown()
{
    System::ShutdownSystem(false);
}

void OpenEmuHostInterface::Render()
{
    m_display->Render();
}

std::unique_ptr<ByteStream> OpenEmuHostInterface::OpenPackageFile(const char* path, u32 flags)
{
    os_log_error(OE_CORE_LOG, "Ignoring request for package file '%{public}s'", path);
    return nullptr;
}

void OpenEmuHostInterface::ReportError(const char* message)
{
    os_log_error(OE_CORE_LOG, "Internal DuckStation error: %{public}s", message);
}

void OpenEmuHostInterface::ReportMessage(const char* message)
{
    os_log_info(OE_CORE_LOG, "DuckStation info: %{public}s", message);
}

bool OpenEmuHostInterface::ConfirmMessage(const char* message)
{
    os_log(OE_CORE_LOG, "DuckStation asking for confirmation about '%{public}s', assuming true", message);
    return true;
}

void OpenEmuHostInterface::AddOSDMessage(std::string message, float duration)
{
    os_log_info(OE_CORE_LOG, "DuckStation OSD: %{public}s", message.c_str());
}

void OpenEmuHostInterface::GetGameInfo(const char* path, CDImage* image, std::string* code, std::string* title)
{
    if (image) {
        *code = GameDatabase::GetSerialForDisc(image);
        *title = GameDatabase::GetEntryForDisc(image)->title;
    } else {
        os_log(OE_CORE_LOG, "unable to identify game at %{private}s: missing CDImage parameter.", path);
    }
}

std::string OpenEmuHostInterface::GetSharedMemoryCardPath(u32 slot) const
{
    GET_CURRENT_OR_RETURN([NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Shared Memory Card-%d.mcd", slot]].fileSystemRepresentation);
    NSString *path = current.batterySavesPath;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return [path stringByAppendingPathComponent:[NSString stringWithFormat:@"Shared Memory Card-%d.mcd", slot]].fileSystemRepresentation;
}

std::string OpenEmuHostInterface::GetGameMemoryCardPath(const char* game_code, u32 slot) const
{
    GET_CURRENT_OR_RETURN([NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%s-%d.mcd", game_code, slot]].fileSystemRepresentation);
    NSString *path = current.batterySavesPath;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%s-%d.mcd", game_code, slot]].fileSystemRepresentation;
}

std::string OpenEmuHostInterface::GetShaderCacheBasePath() const
{
    GET_CURRENT_OR_RETURN([current.BIOSPath stringByAppendingPathComponent:@"ShaderCache.nobackup"].fileSystemRepresentation);
    NSString *path = [current.BIOSPath stringByAppendingPathComponent:@"ShaderCache.nobackup"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return path.fileSystemRepresentation;
}

std::string OpenEmuHostInterface::GetStringSettingValue(const char* section, const char* key, const char* default_value)
{
    if (strcmp("AutoEnableAnalog", key) == 0) {
        return "true";
    }
    return default_value;
}

std::string OpenEmuHostInterface::GetBIOSDirectory()
{
    GET_CURRENT_OR_RETURN(NSHomeDirectory().fileSystemRepresentation);
    return current.BIOSPath.fileSystemRepresentation;
}

bool OpenEmuHostInterface::AcquireHostDisplay()
{
    if (!m_display) {
        return CreateDisplay();
    }
    return true;
}

void OpenEmuHostInterface::ReleaseHostDisplay()
{
    m_display->DestroyRenderDevice();
    m_display.reset();
    m_display = NULL;
}

std::unique_ptr<AudioStream> OpenEmuHostInterface::CreateAudioStream(AudioBackend backend)
{
    return std::make_unique<OpenEmuAudioStream>();
}

void OpenEmuHostInterface::LoadSettings(SettingsInterface& si)
{
    HostInterface::LoadSettings(si);
}

void OpenEmuHostInterface::LoadSettings()
{
    GET_CURRENT_OR_RETURN();
    [current loadConfiguration];
}

bool OpenEmuHostInterface::CreateDisplay()
{
    GET_CURRENT_OR_RETURN(false);
    std::unique_ptr<HostDisplay> display = std::make_unique<OpenEmu::OpenGLHostDisplay>(current);
    WindowInfo wi = WindowInfoFromGameCore(current);
    if (!display->CreateRenderDevice(wi, "", g_settings.gpu_use_debug_device, false) ||
        !display->InitializeRenderDevice(GetShaderCacheBasePath(), g_settings.gpu_use_debug_device, false)) {
        os_log_error(OE_CORE_LOG, "Failed to create/initialize display render device");
        return false;
    }
    
    m_display = std::move(display);
    return true;
}

void OpenEmuHostInterface::ApplyGameSettings(bool display_osd_messages)
{
    // this gets called while booting, so can't use valid
    if (System::IsShutdown() || System::GetRunningCode().empty() || !g_settings.apply_game_settings)
        return;
    
    const GameSettings::Entry* gs = m_game_settings.GetEntry(System::GetRunningCode());
    if (gs) {
        gs->ApplySettings(display_osd_messages);
    } else {
        os_log_info(OE_CORE_LOG, "Unable to find game-specific settings for %{public}s.", System::GetRunningCode().c_str());
    }
}

void OpenEmuHostInterface::OnRunningGameChanged(const std::string& path, CDImage* image,
                                                const std::string& game_code, const std::string& game_title)
{
    HostInterface::OnRunningGameChanged(path, image, game_code, game_title);

    const Settings old_settings = g_settings;
    ApplyGameSettings(false);
    do {
        const std::string &type = System::GetRunningCode();
        NSString *nsType = [@(type.c_str()) uppercaseString];
        
//        PVPSXHacks hacks = OEGetPSXHacksNeededForGame(nsType);
//        if (hacks == PVPSXHacksNone) {
//            break;
//        }
//
//        // PlayStation GunCon supported games
//        switch (hacks & PVPSXHacksCustomControllers) {
//            case PVPSXHacksGunCon:
//                g_settings.controller_types[0] = ControllerType::GunCon;
//                break;
//
//            case PVPSXHacksMouse:
//                g_settings.controller_types[0] = ControllerType::PlayStationMouse;
//                break;
//
//            case PVPSXHacksJustifier:
//                //TODO: implement?
//                break;
//
//            default:
//                break;
//        }
    } while (0);
    FixIncompatibleSettings(false);
    CheckForSettingsChanges(old_settings);
}

std::vector<std::string> OpenEmuHostInterface::GetSettingStringList(const char* section, const char* key)
{
    return {};
}

void OpenEmuHostInterface::CheckForSettingsChanges(const Settings& old_settings)
{
    HostInterface::CheckForSettingsChanges(old_settings);
    GET_CURRENT_OR_RETURN();
    
    current->_displayModes[DuckStationTextureFilterKey] = @(int(g_settings.gpu_texture_filter));
    current->_displayModes[DuckStationPGXPActiveKey] = @(g_settings.gpu_pgxp_enable);
    current->_displayModes[DuckStationDeinterlacedKey] = @(g_settings.gpu_disable_interlacing);
    current->_displayModes[DuckStationAntialiasKey] = @(g_settings.gpu_multisamples);
    current->_displayModes[DuckStationCPUOverclockKey] = @(g_settings.GetCPUOverclockPercent());
    current->_displayModes[DuckStation24ChromaSmoothingKey] = @(g_settings.gpu_24bit_chroma_smoothing);
}

bool OpenEmuHostInterface::LoadCompatibilitySettings(NSURL* path)
{
    NSData *theDat = [NSData dataWithContentsOfURL:path];
    if (!theDat) {
        return false;
    }
    const std::string theStr((const char*)theDat.bytes, theDat.length);
    return m_game_settings.Load(theStr);
}

void OpenEmuHostInterface::ChangeSettings(OpenEmuChangeSettings new_settings)
{
    const Settings old_settings = g_settings;
    if (new_settings.pxgp.has_value()) {
        g_settings.gpu_pgxp_enable = new_settings.pxgp.value();
    }
    if (new_settings.textureFilter.has_value()) {
        g_settings.gpu_texture_filter = new_settings.textureFilter.value();
    }
    if (new_settings.deinterlaced.has_value()) {
        g_settings.gpu_disable_interlacing = new_settings.deinterlaced.value();
    }
    if (new_settings.multisamples.has_value()) {
        g_settings.gpu_multisamples = new_settings.multisamples.value();
    }
    if (new_settings.speedPercent.has_value()) {
        auto speed = new_settings.speedPercent.value();
        g_settings.SetCPUOverclockPercent(speed);
        if (speed == 100) {
            g_settings.cpu_overclock_enable = false;
        } else {
            g_settings.cpu_overclock_enable = true;
        }
        g_settings.UpdateOverclockActive();
    }
    if (new_settings.chroma24Interlace.has_value()) {
        g_settings.gpu_24bit_chroma_smoothing = new_settings.chroma24Interlace.value();
    }
    FixIncompatibleSettings(false);
    CheckForSettingsChanges(old_settings);
}

#pragma mark OpenEmuAudioStream methods -

OpenEmuAudioStream::OpenEmuAudioStream()=default;
OpenEmuAudioStream::~OpenEmuAudioStream()=default;

void OpenEmuAudioStream::FramesAvailable()
{
    const u32 num_frames = GetSamplesAvailable();
    ReadFrames(m_output_buffer.data(), num_frames, false);
    GET_CURRENT_OR_RETURN();
    OERingBuffer* rb = [current ringBufferAtIndex:0];
    [rb write:m_output_buffer.data() maxLength:num_frames * m_channels * sizeof(SampleType)];
}

#pragma mark - Controller mapping

static void updateDigitalControllerButton(PVPSXButton button, int player, bool down) {
    DigitalController* controller = static_cast<DigitalController*>(System::GetController((u32)player));
    
    static constexpr std::array<std::pair<DigitalController::Button, PVPSXButton>, 14> mapping = {
        {{DigitalController::Button::Left, PVPSXButtonLeft},
            {DigitalController::Button::Right, PVPSXButtonRight},
            {DigitalController::Button::Up, PVPSXButtonUp},
            {DigitalController::Button::Down, PVPSXButtonDown},
            {DigitalController::Button::Circle, PVPSXButtonCircle},
            {DigitalController::Button::Cross, PVPSXButtonCross},
            {DigitalController::Button::Triangle, PVPSXButtonTriangle},
            {DigitalController::Button::Square, PVPSXButtonSquare},
            {DigitalController::Button::Start, PVPSXButtonStart},
            {DigitalController::Button::Select, PVPSXButtonSelect},
            {DigitalController::Button::L1, PVPSXButtonL1},
            {DigitalController::Button::L2, PVPSXButtonL2},
            {DigitalController::Button::R1, PVPSXButtonR1},
            {DigitalController::Button::R2, PVPSXButtonR2}}};
    
    for (const auto& [dsButton, oeButton] : mapping) {
        if (oeButton == button) {
            controller->SetBindState(dsButton, down);
            break;
        }
    }
}

static void updateAnalogControllerButton(PVPSXButton button, int player, bool down) {
    AnalogController* controller = static_cast<AnalogController*>(System::GetController((u32)player));
    
    static constexpr std::array<std::pair<AnalogController::Button, PVPSXButton>, 17> button_mapping = {
        {{AnalogController::Button::Left, PVPSXButtonLeft},
            {AnalogController::Button::Right, PVPSXButtonRight},
            {AnalogController::Button::Up, PVPSXButtonUp},
            {AnalogController::Button::Down, PVPSXButtonDown},
            {AnalogController::Button::Circle, PVPSXButtonCircle},
            {AnalogController::Button::Cross, PVPSXButtonCross},
            {AnalogController::Button::Triangle, PVPSXButtonTriangle},
            {AnalogController::Button::Square, PVPSXButtonSquare},
            {AnalogController::Button::Start, PVPSXButtonStart},
            {AnalogController::Button::Select, PVPSXButtonSelect},
            {AnalogController::Button::L1, PVPSXButtonL1},
            {AnalogController::Button::L2, PVPSXButtonL2},
            {AnalogController::Button::L3, PVPSXButtonL3},
            {AnalogController::Button::R1, PVPSXButtonR1},
            {AnalogController::Button::R2, PVPSXButtonR2},
            {AnalogController::Button::R3, PVPSXButtonR3},
            {AnalogController::Button::Analog, PVPSXButtonAnalogMode}}};
    
    for (const auto& [dsButton, oeButton] : button_mapping) {
        if (oeButton == button) {
            controller->SetBindState(dsButton, down);
            break;
        }
    }
}

static void updateAnalogAxis(PVPSXButton button, int player, CGFloat amount) {
    AnalogController* controller = static_cast<AnalogController*>(System::GetController((u32)player));
    
    static constexpr std::array<std::pair<AnalogController::Axis, std::pair<PVPSXButton, PVPSXButton>>, 4> axis_mapping = {
        {{AnalogController::Axis::LeftX, {PVPSXButtonLeftAnalogLeft, PVPSXButtonLeftAnalogRight}},
            {AnalogController::Axis::LeftY, {PVPSXButtonLeftAnalogUp, PVPSXButtonLeftAnalogDown}},
            {AnalogController::Axis::RightX, {PVPSXButtonRightAnalogLeft, PVPSXButtonRightAnalogRight}},
            {AnalogController::Axis::RightY, {PVPSXButtonRightAnalogUp, PVPSXButtonRightAnalogDown}}}};
    for (const auto& [dsAxis, oeAxes] : axis_mapping) {
        if (oeAxes.first == button || oeAxes.second == button) {
            controller->SetAxisState(dsAxis, static_cast<u8>(std::clamp(((static_cast<float>(amount) + 1.0f) / 2.0f) * 255.0f, 0.0f, 255.0f)));
        }
    }
}

static WindowInfo WindowInfoFromGameCore(PVDuckStationCore *core)
{
    WindowInfo wi = WindowInfo();
    //wi.type = WindowInfo::Type::MacOS;
    wi.surface_width = 640;
    wi.surface_height = 480;
    return wi;
}
