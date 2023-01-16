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
//#import <PVLibrary/PVLibrary.h>

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
#include "core/host.h"
#include "core/gpu.h"
#include "util/audio_stream.h"
#include "core/digital_controller.h"
#include "core/analog_controller.h"
#include "core/guncon.h"
#include "core/playstation_mouse.h"
#include "OpenGLHostDisplay.hpp"
#include "common/settings_interface.h"
#include "frontend-common/game_list.h"
#include "core/cheats.h"
#include "frontend-common/game_list.h"
#undef TickCount
#include <limits>
#include <optional>
#include <cstdint>
#include <vector>
#include <string>
#include <memory>
#include <os/log.h>

#define USE_THREADS 0
#define USE_DOUBLE_BUFFER NO

#define OEGameCoreErrorDomain @"org.provenance.core"
#define OEGameCoreCouldNotLoadStateError 420
#define OEGameCoreCouldNotLoadROMError 69
#define OEGameCoreCouldNotSaveStateError 42069

static void updateAnalogAxis(PVPSXButton button, int player, CGFloat amount);
static void updateAnalogControllerButton(PVPSXButton button, int player, bool down);
static void updateDigitalControllerButton(PVPSXButton button, int player, bool down);
static bool LoadCompatibilitySettings(NSURL* path);
// We're keeping this: I think it'll be useful when OpenEmu supports Metal.
static WindowInfo WindowInfoFromGameCore(PVDuckStationCore *core);

os_log_t OE_CORE_LOG;

struct OpenEmuChangeSettings {
    std::optional<GPUTextureFilter> textureFilter = std::nullopt;
    std::optional<bool> pxgp = std::nullopt;
    std::optional<bool> deinterlaced = std::nullopt;
    std::optional<bool> chroma24Interlace = std::nullopt;
    std::optional<u32> multisamples = std::nullopt;
    std::optional<u32> speedPercent = std::nullopt;
};

static void ChangeSettings(OpenEmuChangeSettings new_settings);
static void ApplyGameSettings(bool display_osd_messages);

class OpenEmuAudioStream final : public AudioStream
{
public:
    OpenEmuAudioStream(u32 sample_rate, u32 channels, u32 buffer_ms, AudioStretchMode stretch);
    ~OpenEmuAudioStream();

    bool OpenDevice()  {
        m_output_buffer.resize(GetBufferSize() * m_channels);
        return true;
    }
    void SetPaused(bool paused) override {}
    void CloseDevice()  {}
    void FramesAvailable() ;
    static std::unique_ptr<OpenEmuAudioStream> CreateOpenEmuStream(u32 sample_rate, u32 channels, u32 buffer_ms);

private:
        // TODO: Optimize this buffer away.
    std::vector<SampleType> m_output_buffer;
};

static void OELogFunc(void* pUserParam, const char* channelName, const char* functionName,
                      LOGLEVEL level, const char* message)
{
    switch (level) {
        case LOGLEVEL_ERROR:
            ELOG(@"%s: %s", channelName, message);
            break;
            
        case LOGLEVEL_WARNING:
        case LOGLEVEL_PERF:
            DLOG(@"%s: %s", channelName, message);
            break;
            
        case LOGLEVEL_INFO:
        case LOGLEVEL_VERBOSE:
            ILOG(@"%s: %s", channelName, message);
            break;
            
        case LOGLEVEL_DEV:
        case LOGLEVEL_DEBUG:
        case LOGLEVEL_PROFILE:
            DLOG(@"%s: %s", channelName, message);
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
    NSString *bootPath;
    NSString *saveStatePath;
    bool isInitialized;
    NSUInteger _maxDiscs;

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
    }
    return self;
}

- (void)dealloc {
}

#pragma mark - Execution

-(NSString*) systemIdentifier {
    return @"com.provenance.psx";
}

#pragma mark - Video

- (const void *)videoBuffer {
    return NULL;
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

- (BOOL)isDoubleBuffered {
    return USE_DOUBLE_BUFFER;
}

- (dispatch_time_t)frameTime {
    float frameTime = 1.0/[self frameInterval];
    __block BOOL expired = NO;
    dispatch_time_t killTime = dispatch_time(DISPATCH_TIME_NOW, frameTime * NSEC_PER_SEC);
    return killTime;
}

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

#pragma mark - Settings

- (void)initializeSettings {
        // GLES == 0, Vulkan == 1
    if(self.gs == 1) {
        DLOG(@"Set `gpu_renderer` = HardwareVulkan");
        g_settings.gpu_renderer = GPURenderer::HardwareVulkan;
    } else {
        DLOG(@"Set `gpu_renderer` = HardwareOpenGL");
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
//    g_settings.gpu_pgxp_cpu = true;
    g_settings.gpu_pgxp_vertex_cache = true;
    g_settings.gpu_24bit_chroma_smoothing = true;
    g_settings.gpu_texture_filter = GPUTextureFilter::Nearest;
    g_settings.gpu_resolution_scale = 0;
    g_settings.gpu_use_thread = true;
    // TODO: Settings for this
//    g_settings.gpu_widescreen_hack = true;
    g_settings.display_show_fps = true;
    g_settings.display_show_resolution = true;
    g_settings.display_show_gpu = true;
    g_settings.display_show_frame_times = true;
    g_settings.display_show_enhancements = true;
    g_settings.display_show_status_indicators = true;

    g_settings.memory_card_types[0] = MemoryCardType::PerGameTitle;
    g_settings.memory_card_types[1] = MemoryCardType::PerGameTitle;
    // TODO: Add Core Option for this.
    // {CachedInterpreter, Interpreter, Recompiler}
    g_settings.cpu_execution_mode = CPUExecutionMode::CachedInterpreter;
    _displayModes = [[NSMutableDictionary alloc] init];
    NSURL *gameSettingsURL = [[NSBundle bundleForClass:[PVDuckStationCore class]] URLForResource:@"gamesettings"
                                                                                   withExtension:@"ini"];
    if (gameSettingsURL) {
        bool success = LoadCompatibilitySettings(gameSettingsURL);
        if (!success) {
            ELOG(@"OpenEmu-specific overrides for particular discs didn't load, name %@ at path %{private}@", gameSettingsURL.lastPathComponent, gameSettingsURL.path);
        }
    } else {
        ILOG(@"OpenEmu-specific overrides for particular discs wasn't found.");
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
        
        DLOG(@"Loading m3u containing %lu cue sheets", numberOfMatches);
        
        self.maxDiscs = numberOfMatches;
    } else if ([path.pathExtension.lowercaseString isEqualToString:@"pbp"]) {
        Common::Error pbpError;
        auto pbpImage = CDImage::OpenPBPImage(path.fileSystemRepresentation, &pbpError);
        if (pbpImage) {
            self.maxDiscs = pbpImage->GetSubImageCount();
            DLOG(@"Loading PBP containing %ld discs", (long)self.maxDiscs);
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
            ILOG(@"Failed to load PBP: %s. Will continue to attempt to load, but no guaranteee of it loading successfully\nAlso, only one disc will load.", cppStr.c_str());
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

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    if (!isInitialized) {
        saveStatePath = [fileName copy];
        block(YES, nil);
        return;
    }
    const bool result = System::LoadState(fileName.fileSystemRepresentation);
    
    block(result, nil);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    const bool result = System::SaveState(fileName.fileSystemRepresentation, 0);
    block(result, nil);
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
    [super stopEmulation];
}

- (CGSize)aspectSize {
    return (CGSize){ 4, 3 };
}

- (BOOL)tryToResizeVideoTo:(CGSize)size {
    if (!System::IsShutdown() && isInitialized) {
        g_host_display->ResizeWindow(size.width, size.height);

        g_gpu->UpdateResolutionScale();
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

#pragma mark - Audio

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

#pragma mark - Video

- (CGSize)bufferSize {
        //    return self.screenRect.size;
    return (CGSize){ 640, 480 };
}

#if USE_THREADS

- (void)videoInterrupt {
    dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

    dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, [self frameTime]);
}

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)startEmulation {
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
        if (!isInitialized) {
            EmuFolders::AppRoot = [NSBundle bundleForClass:[PVDuckStationCore class]].resourceURL.fileSystemRepresentation;
            EmuFolders::Bios = self.BIOSPath.fileSystemRepresentation;
            EmuFolders::Cache = [self.BIOSPath stringByAppendingPathComponent:@"ShaderCache.nobackup"].fileSystemRepresentation;
            EmuFolders::MemoryCards = self.batterySavesPath.fileSystemRepresentation;
            auto params = SystemBootParameters(bootPath.fileSystemRepresentation);
            if (saveStatePath) {
                params.save_state = std::string(saveStatePath.fileSystemRepresentation);
                saveStatePath = nil;
            }
            isInitialized = System::BootSystem(params);
        }
        [self.renderDelegate startRenderingOnAlternateThread];

        #if 0
        System::Execute()
        #else
        do {
            System::RunFrames();
//            Host::RenderDisplay(skip);
            Host::RenderDisplay(false);
        }while(!shouldStop);
        #endif


            // Unlock rendering thread
        dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        [super stopEmulation];
    }
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
}

#else // NOT USE_THREADS

//- (void)startEmulation {
//   [self parseOptions];
//    [super startEmulation];
//}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    if (UNLIKELY(!isInitialized)) {
        [self initializeSettings];

        NSBundle *coreBundle = [NSBundle bundleForClass:[PVDuckStationCore class]];
        NSString *duck_resourcesPath = [coreBundle.bundlePath stringByAppendingPathComponent:@"/duck_resources"];
        NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true).firstObject
                               stringByAppendingPathComponent:@"/ShaderCache.nobackup"];
        NSString *shadersPath = [self.BIOSPath stringByAppendingPathComponent:@"/shaders"];
        NSString *texturesPath = [self.BIOSPath stringByAppendingPathComponent:@"/textures"];

        EmuFolders::AppRoot = self.BIOSPath.fileSystemRepresentation;
        EmuFolders::DataRoot = self.BIOSPath.fileSystemRepresentation;
        EmuFolders::Bios = self.BIOSPath.fileSystemRepresentation;
        EmuFolders::Cache = cachePath.fileSystemRepresentation;
        EmuFolders::MemoryCards = self.batterySavesPath.fileSystemRepresentation;
        EmuFolders::Resources = duck_resourcesPath.fileSystemRepresentation;
        EmuFolders::SaveStates = self.saveStatesPath.fileSystemRepresentation;
        EmuFolders::Shaders = shadersPath.fileSystemRepresentation;
        EmuFolders::Textures = texturesPath.fileSystemRepresentation;

        NSFileManager *fm = [NSFileManager defaultManager];

        NSArray<NSString*> *pathsToCreate = @[shadersPath, texturesPath, cachePath];

        for(NSString *path in pathsToCreate) {
            if(![fm fileExistsAtPath:path]) {
                NSError *error;
                BOOL successs = [fm createDirectoryAtPath:path
                              withIntermediateDirectories:true
                                               attributes:nil
                                                    error:&error];
                if(!successs) {
                    ELOG(@"Failed to make ShaderCache dir <%@>", error.localizedDescription);
                } else {
                    ILOG(@"Made directory: <%@>", path);
                }
            }
        }

        auto params = SystemBootParameters(bootPath.fileSystemRepresentation);
        if (saveStatePath) {
            params.save_state = std::string(saveStatePath.fileSystemRepresentation);
            saveStatePath = nil;
        }

        MAKEWEAK(self);
//        Host::RunOnCPUThread([params = std::move(params), weakself]() {
            MAKESTRONG_RETURN_IF_NIL(self);
            BOOL isInitialized = System::BootSystem(params);
            strongself->isInitialized = isInitialized;

            if(!isInitialized) {
                ELOG(@"Duckstaion didn't initialize");
                NAssert(@"Duckstaion didn't initialize");
                [strongself stopEmulation];
                return;
            }
//        });
    }

    System::RunFrame();

    Host::RenderDisplay(skip);
}
#endif // USE_THREADS

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
    ChangeSettings(settings);
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
    ChangeSettings(settings);
}


@end


#pragma mark -

#define TickCount DuckTickCount
#include "common/assert.h"
#include "common/byte_stream.h"
#include "common/file_system.h"
#include "common/threading.h"
#include "common/log.h"
//#include "common/string_util.h"
#include "core/analog_controller.h"
#include "core/bus.h"
#include "core/cheats.h"
#include "core/digital_controller.h"
#include "core/gpu.h"
#include "core/system.h"
#include "frontend-common/vulkan_host_display.h"
#import "core/host_display.h"
#undef TickCount
#include <array>
#include <cstring>
#include <tuple>
#include <utility>
#include <vector>

#pragma mark - Host Mapping
namespace Host {
    static Threading::Thread s_cpu_thread;
    static std::mutex s_cpu_thread_events_mutex;
    static std::condition_variable s_cpu_thread_event_done;
    static std::condition_variable s_cpu_thread_event_posted;
    static std::deque<std::pair<std::function<void()>, bool>> s_cpu_thread_events;
    static u32 s_blocking_cpu_events_pending = 0;
    void OnAchievementsRefreshed() {
    }
    void RunOnCPUThread(std::function<void()> function, bool block /* = false */) {
        std::unique_lock lock(s_cpu_thread_events_mutex);
        s_cpu_thread_events.emplace_back(std::move(function), block);
        s_cpu_thread_event_posted.notify_one();
        if (block)
            s_cpu_thread_event_done.wait(lock, []() { return s_blocking_cpu_events_pending == 0; });
    }
}
namespace FullscreenUI {
    bool IsInitialized() {
        return true;
    }
}
bool Host::AcquireHostDisplay(RenderAPI api)
{
    GET_CURRENT_OR_RETURN(false);

    BOOL useVulkan = current.gs == 1;

    std::unique_ptr<HostDisplay> display;

    if(useVulkan) {
        NSBundle *bundle = [NSBundle mainBundle];

        // Use `libMoltenVK.dylib`
        // Needs Vulkan 1.1+
        const char * filename = [NSString stringWithFormat:@"%@/libMoltenVK.dylib", bundle.sharedFrameworksPath].cString;

            // Set vulkan path to molktenVK
        setenv("LIBVULKAN_PATH", filename, 1);

            // Alloc vulkan host
        display = std::make_unique<VulkanHostDisplay>();
    } else {
#if TARGET_OS_OSX
        display = std::make_unique<OpenGLHostDisplay>(current);
#else
        display = std::make_unique<OpenEmu::PVOpenGLHostDisplay>(current);
#endif
    }
    WindowInfo wi = WindowInfoFromGameCore(current);
    if (!display->CreateDevice(wi, false) ||
        !display->SetupDevice()) {
        ELOG(@"Failed to create/initialize display render device");
        return false;
    }

    g_host_display = std::move(display);

    return true;
}

void Host::ReleaseHostDisplay()
{
    g_host_display->DestroySurface();
    g_host_display.reset();
    g_host_display = NULL;
}

void Host::InvalidateDisplay()
{
    Host::RenderDisplay(false);
}

void Host::RenderDisplay(bool skip_present)
{
    g_host_display->Render(skip_present);
}

void Host::OnSystemStarting()
{

}

void Host::OnSystemStarted()
{

}

void Host::OnSystemDestroyed()
{

}

void Host::OnSystemPaused()
{

}

void Host::OnSystemResumed()
{

}

float Host::GetOSDScale()
{
    return 1.0f;
}

std::optional<std::vector<u8>> Host::ReadResourceFile(const char* filename)
{
    @autoreleasepool {
        NSString *nsFile = @(filename);
        NSString *baseName = nsFile.lastPathComponent.stringByDeletingPathExtension;
        NSString *upperName = nsFile.stringByDeletingLastPathComponent;
        NSString *baseExt = nsFile.pathExtension;
        if (baseExt.length == 0) {
            baseExt = nil;
        }
        if (upperName.length == 0 || [upperName isEqualToString:@"/"]) {
            upperName = nil;
        }
        NSURL *aURL;
        if (upperName) {
            aURL = [[NSBundle bundleForClass:[PVDuckStationCore class]] URLForResource:baseName withExtension:baseExt subdirectory:upperName];
        } else {
            aURL = [[NSBundle bundleForClass:[PVDuckStationCore class]] URLForResource:baseName withExtension:baseExt];
        }
        if (!aURL) {
            return std::nullopt;
        }
        NSData *data = [[NSData alloc] initWithContentsOfURL:aURL];
        if (!data) {
            return std::nullopt;
        }
        auto retVal = std::vector<u8>(data.length);
        [data getBytes:retVal.data() length:retVal.size()];
        return retVal;
    }
}

std::optional<std::string> Host::ReadResourceFileToString(const char* filename)
{
    @autoreleasepool {
        NSString *nsFile = @(filename);
        NSString *baseName = nsFile.lastPathComponent.stringByDeletingPathExtension;
        NSString *upperName = nsFile.stringByDeletingLastPathComponent;
        NSString *baseExt = nsFile.pathExtension;
        if (baseExt.length == 0) {
            baseExt = nil;
        }
        if (upperName.length == 0 || [upperName isEqualToString:@"/"]) {
            upperName = nil;
        }
        NSURL *aURL;
        if (upperName) {
            aURL = [[NSBundle bundleForClass:[PVEmulatorCore class]] URLForResource:baseName withExtension:baseExt subdirectory:upperName];
        } else {
            aURL = [[NSBundle bundleForClass:[PVEmulatorCore class]] URLForResource:baseName withExtension:baseExt];
        }
        if (!aURL) {
            return std::nullopt;
        }
        NSData *data = [[NSData alloc] initWithContentsOfURL:aURL];
        if (!data) {
            return std::nullopt;
        }
        std::string ret;
        ret.resize(data.length);
        [data getBytes:ret.data() length:ret.size()];
        return ret;
    }
}

std::optional<std::time_t> Host::GetResourceFileTimestamp(const char* filename)
{
    @autoreleasepool {
        NSString *nsFile = @(filename);
        NSString *baseName = nsFile.lastPathComponent.stringByDeletingPathExtension;
        NSString *upperName = nsFile.stringByDeletingLastPathComponent;
        NSString *baseExt = nsFile.pathExtension;
        if (baseExt.length == 0) {
            baseExt = nil;
        }
        if (upperName.length == 0 || [upperName isEqualToString:@"/"]) {
            upperName = nil;
        }
        NSURL *aURL;
        if (upperName) {
            aURL = [[NSBundle bundleForClass:[PVEmulatorCore class]] URLForResource:baseName withExtension:baseExt subdirectory:upperName];
        } else {
            aURL = [[NSBundle bundleForClass:[PVEmulatorCore class]] URLForResource:baseName withExtension:baseExt];
        }
        if (!aURL) {
            return std::nullopt;
        }

        FILESYSTEM_STAT_DATA sd;
        if (!FileSystem::StatFile(aURL.fileSystemRepresentation, &sd))
        {
            ELOG(@"Failed to stat resource file '%s'", filename);
            return std::nullopt;
        }

        return sd.ModificationTime;
    }
}

TinyString Host::TranslateString(const char* context, const char* str, const char* disambiguation /*= nullptr*/,
                                 int n /*= -1*/)
{
    return TinyString(str, (u32)strnlen(str, 64));
}

std::string Host::TranslateStdString(const char* context, const char* str, const char* disambiguation /*= nullptr*/, int n /*= -1*/)
{
    return std::string(str);
}

void Host::AddOSDMessage(std::string message, float duration)
{
    ILOG(@"DuckStation OSD: %s", message.c_str());
}

void Host::AddKeyedOSDMessage(std::string key, std::string message, float duration)
{
    ILOG(@"DuckStation OSD: %s", message.c_str());
}

void Host::AddIconOSDMessage(std::string key, const char* icon, std::string message, float duration)
{
    ILOG(@"DuckStation OSD: %s", message.c_str());
}

void Host::AddFormattedOSDMessage(float duration, const char* format, ...)
{
        // Do nothing
}

void Host::AddKeyedFormattedOSDMessage(std::string key, float duration, const char* format, ...)
{
        // Do nothing
}

void Host::RemoveKeyedOSDMessage(std::string key)
{
        // Do nothing
}

void Host::ClearOSDMessages()
{
        // Do nothing
}

void Host::LoadSettings(SettingsInterface& si, std::unique_lock<std::mutex>& lock)
{
    GET_CURRENT_OR_RETURN();
    [current loadConfiguration];
    [current initializeSettings];
}

void Host::OnGameChanged(const std::string& disc_path, const std::string& game_serial, const std::string& game_name)
{
    const Settings old_settings = g_settings;
    ApplyGameSettings(false);

    do {
        const std::string &type = System::GetRunningSerial();
        NSString *nsType = [@(type.c_str()) uppercaseString];

        OEPSXHacks hacks = OEGetPSXHacksNeededForGame(nsType);
        if (hacks == OEPSXHacksNone) {
            break;
        }

            // PlayStation GunCon supported games
        switch (hacks & OEPSXHacksCustomControllers) {
            case OEPSXHacksGunCon:
                g_settings.controller_types[0] = ControllerType::GunCon;
                break;

            case OEPSXHacksMouse:
                g_settings.controller_types[0] = ControllerType::PlayStationMouse;
                break;

            case OEPSXHacksJustifier:
                    //TODO: implement?
                break;

            default:
                break;
        }
        if (hacks & OEPSXHacksOnlyOneMemcard) {
            g_settings.memory_card_types[1] = MemoryCardType::None;
        }
            //        if (hacks & OEPSXHacksMultiTap5PlayerPort2) {
            //            g_settings.multitap_mode = MultitapMode::Port2Only;
            //            g_settings.controller_types;
            //        }
        if (hacks & OEPSXHacksMultiTap) {
            g_settings.multitap_mode = MultitapMode::BothPorts;
            g_settings.controller_types[2] = ControllerType::AnalogController;
            g_settings.controller_types[3] = ControllerType::AnalogController;
            g_settings.controller_types[4] = ControllerType::AnalogController;
            g_settings.controller_types[5] = ControllerType::AnalogController;
            g_settings.controller_types[6] = ControllerType::AnalogController;
            g_settings.controller_types[7] = ControllerType::AnalogController;
        }
    } while (0);
    g_settings.FixIncompatibleSettings(false);
    CheckForSettingsChanges(old_settings);
}

bool Host::ConfirmMessage(const std::string_view& title, const std::string_view& message)
{
    auto fullStr = std::string(message);
    DLOG(@"DuckStation asking for confirmation about '%s', assuming true", fullStr.c_str());
    return true;
}

void Host::ReportErrorAsync(const std::string_view& title, const std::string_view& message)
{
    auto fullStr = std::string(message);
    auto strTitle = std::string(title);
    ELOG(@"%s: %s", strTitle.c_str(), fullStr.c_str());
}

void Host::ReportDebuggerMessage(const std::string_view& message)
{
    auto fullStr = std::string(message);
    DLOG(@"%s", fullStr.c_str());
}

std::unique_ptr<AudioStream> Host::CreateAudioStream(AudioBackend backend, u32 sample_rate, u32 channels, u32 buffer_ms,
                                                     u32 latency_ms, AudioStretchMode stretch)
{
    return OpenEmuAudioStream::CreateOpenEmuStream(sample_rate, channels, buffer_ms);
}

void Host::DisplayLoadingScreen(const char* message, int progress_min, int progress_max, int progress_value)
{
        // Do nothing
}

void Host::CheckForSettingsChanges(const Settings& old_settings)
{
    GET_CURRENT_OR_RETURN();

    current->_displayModes[DuckStationTextureFilterKey] = @(int(g_settings.gpu_texture_filter));
    current->_displayModes[DuckStationPGXPActiveKey] = @(g_settings.gpu_pgxp_enable);
    current->_displayModes[DuckStationDeinterlacedKey] = @(g_settings.gpu_disable_interlacing);
    current->_displayModes[DuckStationAntialiasKey] = @(g_settings.gpu_multisamples);
    current->_displayModes[DuckStationCPUOverclockKey] = @(g_settings.GetCPUOverclockPercent());
    current->_displayModes[DuckStation24ChromaSmoothingKey] = @(g_settings.gpu_24bit_chroma_smoothing);
}

void Host::SetPadVibrationIntensity(u32 pad_index, float large_or_single_motor_intensity, float small_motor_intensity)
{
        // Do nothing… for now
}

void Host::SetMouseMode(bool relative, bool hide_cursor)
{
        // TODO: Find a better home for this.
        //    if (InputManager::HasPointerAxisBinds())
        //    {
        //        relative = true;
        //        hide_cursor = true;
        //    }

        // emit g_emu_thread->mouseModeRequested(relative, hide_cursor);
}

void ApplyGameSettings(bool display_osd_messages)
{
        // this gets called while booting, so can't use valid
    if (System::IsShutdown() || System::GetRunningSerial().empty() || !g_settings.apply_game_settings)
        return;

    const GameDatabase::Entry* gs = GameDatabase::GetEntryForSerial(System::GetRunningSerial());
    if (gs) {
        gs->ApplySettings(g_settings, display_osd_messages);
    } else {
        ILOG(@"Unable to find game-specific settings for %s.", System::GetRunningSerial().c_str());
    }
}

bool LoadCompatibilitySettings(NSURL* path)
{
    NSData *theDat = [NSData dataWithContentsOfURL:path];
    if (!theDat) {
        return false;
    }
    const std::string theStr((const char*)theDat.bytes, theDat.length);
    return false;
}

void ChangeSettings(OpenEmuChangeSettings new_settings)
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
    g_settings.FixIncompatibleSettings(false);
    System::CheckForSettingsChanges(old_settings);
}

#pragma mark - OpenEmuAudioStream methods

OpenEmuAudioStream::OpenEmuAudioStream(u32 sample_rate, u32 channels, u32 buffer_ms, AudioStretchMode stretch) : AudioStream(sample_rate, channels, buffer_ms, stretch) { }
OpenEmuAudioStream::~OpenEmuAudioStream()=default;

void OpenEmuAudioStream::FramesAvailable()
{
    const u32 num_frames = GetBufferedFramesRelaxed();
    ReadFrames(m_output_buffer.data(), num_frames);
    GET_CURRENT_OR_RETURN();
    OERingBuffer* rb = [current ringBufferAtIndex:0];
    [rb write:m_output_buffer.data() maxLength:num_frames * m_channels * sizeof(SampleType)];
}

std::unique_ptr<OpenEmuAudioStream> OpenEmuAudioStream::CreateOpenEmuStream(u32 sample_rate, u32 channels, u32 buffer_ms)
{
    std::unique_ptr<OpenEmuAudioStream> stream = std::make_unique<OpenEmuAudioStream>(sample_rate, channels, buffer_ms, AudioStretchMode::Off);
    stream->BaseInitialize();
    return stream;
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
            controller->SetBindState(static_cast<u32>(dsButton), down);
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
            controller->SetBindState(static_cast<u32>(dsButton), down);
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
                // TODO: test this!
            controller->SetBindState(static_cast<u32>(dsAxis) + static_cast<u32>(AnalogController::Button::Count), ((static_cast<float>(amount) + 1.0f) / 2.0f));
        }
    }
}

static WindowInfo WindowInfoFromGameCore(PVDuckStationCore *core)
{
    WindowInfo wi = WindowInfo();
//    wi.type = WindowInfo::Type::Android;
    wi.type = WindowInfo::Type::MacOS;
    wi.surface_width = core.bufferSize.width;
    wi.surface_height = core.bufferSize.height;
//    wi.surface_width = 640;
//    wi.surface_height = 480;
    return wi;
}
