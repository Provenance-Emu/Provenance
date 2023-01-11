// Copyright (c) 2020, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "DuckStationGameCore.h"
#import "OEPSXSystemResponderClient.h"
#import <OpenEmuBase/OpenEmuBase.h>
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

Log_SetChannel(OpenEmu);

static void updateAnalogAxis(OEPSXButton button, int player, CGFloat amount);
static void updateAnalogControllerButton(OEPSXButton button, int player, bool down);
static void updateDigitalControllerButton(OEPSXButton button, int player, bool down);
static bool LoadCompatibilitySettings(NSURL* path);
// We're keeping this: I think it'll be useful when OpenEmu supports Metal.
static WindowInfo WindowInfoFromGameCore(DuckStationGameCore *core);

static __weak DuckStationGameCore *_current;
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

@interface DuckStationGameCore () <OEPSXSystemResponderClient>

@end

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

@implementation DuckStationGameCore {
    NSString *bootPath;
	NSString *saveStatePath;
    bool isInitialized;
	NSInteger _maxDiscs;
@package
	NSMutableDictionary <NSString *, id> *_displayModes;
}

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		OE_CORE_LOG = os_log_create("org.openemu.DuckStation", "");
	});
}

- (instancetype)init
{
	if (self = [super init]) {
		_current = self;
//		Log::SetFilterLevel(LOGLEVEL_TRACE);
		Log::RegisterCallback(OELogFunc, NULL);
		g_settings.gpu_renderer = GPURenderer::HardwareOpenGL;
		g_settings.controller_types[0] = ControllerType::AnalogController;
		g_settings.controller_types[1] = ControllerType::AnalogController;
		g_settings.display_crop_mode = DisplayCropMode::Overscan;
		g_settings.gpu_disable_interlacing = true;
		// match PS2's speed-up
		g_settings.cdrom_read_speedup = 4;
		g_settings.cdrom_seek_speedup = 4;
		
		g_settings.gpu_multisamples = 4;
		g_settings.gpu_pgxp_enable = true;
		g_settings.gpu_pgxp_vertex_cache = true;
		g_settings.gpu_24bit_chroma_smoothing = true;
		g_settings.gpu_texture_filter = GPUTextureFilter::Nearest;
		g_settings.gpu_resolution_scale = 0;
		g_settings.memory_card_types[0] = MemoryCardType::PerGameTitle;
		g_settings.memory_card_types[1] = MemoryCardType::PerGameTitle;
		g_settings.cpu_execution_mode = CPUExecutionMode::Recompiler;
		_displayModes = [[NSMutableDictionary alloc] init];
		NSURL *gameSettingsURL = [[NSBundle bundleForClass:[DuckStationGameCore class]] URLForResource:@"OEOverrides" withExtension:@"ini"];
		if (gameSettingsURL) {
			bool success = LoadCompatibilitySettings(gameSettingsURL);
			if (!success) {
				os_log_fault(OE_CORE_LOG, "OpenEmu-specific overrides for particular discs didn't load, name %{public}@ at path %{private}@", gameSettingsURL.lastPathComponent, gameSettingsURL.path);
			}
		} else {
			os_log_fault(OE_CORE_LOG, "OpenEmu-specific overrides for particular discs wasn't found.");
		}
	}
	return self;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
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
		
		_maxDiscs = numberOfMatches;
	} else if ([path.pathExtension.lowercaseString isEqualToString:@"pbp"]) {
		Common::Error pbpError;
		auto pbpImage = CDImage::OpenPBPImage(path.fileSystemRepresentation, &pbpError);
		if (pbpImage) {
			_maxDiscs = pbpImage->GetSubImageCount();
			os_log_debug(OE_CORE_LOG, "Loading PBP containing %ld discs", (long)_maxDiscs);
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

    return true;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
	if (!isInitialized) {
		saveStatePath = [fileName copy];
		block(YES, nil);
		return;
	}
	const bool result = System::LoadState(fileName.fileSystemRepresentation);
	
	block(result, result ? nil : [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadStateError userInfo:@{NSFilePathErrorKey: fileName}]);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
	const bool result = System::SaveState(fileName.fileSystemRepresentation, 0);
	
	block(result, result ? nil : [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotSaveStateError userInfo:@{NSFilePathErrorKey: fileName}]);
}

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
	return _maxDiscs ? _maxDiscs : 1;
}

- (void)setDisc:(NSUInteger)discNumber
{
	if (System::HasMediaSubImages()) {
		uint32_t index = (uint32_t)discNumber - 1; // 0-based index
		System::SwitchMediaSubImage(index);
	}
}

- (void)resetEmulation
{
	System::ResetSystem();
}

- (void)startEmulation
{
	Log::SetFileOutputParams(true, [self.supportDirectoryPath stringByAppendingPathComponent:@"emu.log"].fileSystemRepresentation);
	[super startEmulation];
}

- (void)stopEmulation
{
	System::ShutdownSystem(false);
	
	[super stopEmulation];
}

- (OEIntSize)aspectSize
{
	return (OEIntSize){ 4, 3 };
}

- (BOOL)tryToResizeVideoTo:(OEIntSize)size
{
	if (!System::IsShutdown() && isInitialized) {
		g_host_display->ResizeRenderWindow(size.width, size.height);
		
		g_gpu->UpdateResolutionScale();
	}
	return YES;
}

- (OEGameCoreRendering)gameCoreRendering
{
	//TODO: return OEGameCoreRenderingMetal1Video;
	return OEGameCoreRenderingOpenGL3Video;
}

- (oneway void)mouseMovedAtPoint:(OEIntPoint)point
{
	switch (g_settings.controller_types[0]) {
		case ControllerType::GunCon:
		case ControllerType::PlayStationMouse:
		{
			//TODO: scale input?
			g_host_display->SetMousePosition(point.x, point.y);
		}
			return;
			break;
			
		default:
			break;
	}
	
	switch (g_settings.controller_types[1]) {
		case ControllerType::PlayStationMouse:
		{
			//TODO: scale input?
			g_host_display->SetMousePosition(point.x, point.y);
		}
			break;
			
		default:
			break;
	}
}

- (oneway void)leftMouseDownAtPoint:(OEIntPoint)point
{
	switch (g_settings.controller_types[0]) {
		case ControllerType::GunCon:
		{
			[self mouseMovedAtPoint:point];
			GunCon *controller = static_cast<GunCon*>(System::GetController(0));
			controller->SetBindState(static_cast<u32>(GunCon::Button::Trigger), 1);
		}
			return;
			break;
			
		case ControllerType::PlayStationMouse:
		{
			[self mouseMovedAtPoint:point];
			PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
			controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), 1);
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
			controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), 1);
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
			controller->SetBindState(static_cast<u32>(GunCon::Button::Trigger), 0);
		}
			return;
			break;
			
		case ControllerType::PlayStationMouse:
		{
			PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
			controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), 0);
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
			controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Left), 0);
		}
			break;

		default:
			break;
	}
}

- (oneway void)rightMouseDownAtPoint:(OEIntPoint)point
{
	switch (g_settings.controller_types[0]) {
		case ControllerType::GunCon:
		{
//			[self mouseMovedAtPoint:point];
			GunCon *controller = static_cast<GunCon*>(System::GetController(0));
			controller->SetBindState(static_cast<u32>(GunCon::Button::ShootOffscreen), 1);
		}
			return;
			break;
			
		case ControllerType::PlayStationMouse:
		{
			[self mouseMovedAtPoint:point];
			PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
			controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Right), 1);
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
			controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Right), 1);
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
			controller->SetBindState(static_cast<u32>(GunCon::Button::ShootOffscreen), 0);
		}
			return;
			break;
			
		case ControllerType::PlayStationMouse:
		{
			PlayStationMouse *controller = static_cast<PlayStationMouse*>(System::GetController(0));
			controller->SetBindState(static_cast<u32>(PlayStationMouse::Button::Right), 0);
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

- (oneway void)didMovePSXJoystickDirection:(OEPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player {
    player -= 1;
    switch (button) {
        case OEPSXLeftAnalogLeft:
        case OEPSXLeftAnalogUp:
        case OEPSXRightAnalogLeft:
        case OEPSXRightAnalogUp:
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

- (oneway void)didPushPSXButton:(OEPSXButton)button forPlayer:(NSUInteger)player {
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
			GunCon *controller = static_cast<GunCon*>(System::GetController((int)player));
			switch (button) {
				case OEPSXButtonCircle:
				case OEPSXButtonSquare:
					controller->SetBindState(static_cast<u32>(GunCon::Button::A), 1);
					break;
					
				case OEPSXButtonCross:
				case OEPSXButtonTriangle:
				case OEPSXButtonStart:
					controller->SetBindState(static_cast<u32>(GunCon::Button::B), 1);
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

- (oneway void)didReleasePSXButton:(OEPSXButton)button forPlayer:(NSUInteger)player {
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
			GunCon *controller = static_cast<GunCon*>(System::GetController((int)player));
			switch (button) {
				case OEPSXButtonCircle:
				case OEPSXButtonSquare:
					controller->SetBindState(static_cast<u32>(GunCon::Button::A), false);
					break;
					
				case OEPSXButtonCross:
				case OEPSXButtonTriangle:
				case OEPSXButtonStart:
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

- (NSUInteger)channelCount
{
	return 2;
}

- (NSUInteger)audioBitDepth
{
	return 16;
}

- (double)audioSampleRate
{
	return 44100;
}

- (OEIntSize)bufferSize
{
	return (OEIntSize){ 640, 480 };
}

- (void)executeFrame
{
    if (!isInitialized) {
		EmuFolders::AppRoot = [NSBundle bundleForClass:[DuckStationGameCore class]].resourceURL.fileSystemRepresentation;
		EmuFolders::Bios = self.biosDirectoryPath.fileSystemRepresentation;
		EmuFolders::Cache = [self.supportDirectoryPath stringByAppendingPathComponent:@"ShaderCache.nobackup"].fileSystemRepresentation;
		EmuFolders::MemoryCards = self.batterySavesDirectoryPath.fileSystemRepresentation;
		auto params = SystemBootParameters(bootPath.fileSystemRepresentation);
		if (saveStatePath) {
			params.save_state = std::string(saveStatePath.fileSystemRepresentation);
			saveStatePath = nil;
		}
		isInitialized = System::BootSystem(params);
    }
    
	System::RunFrame();
	
	Host::RenderDisplay(false);
}

- (NSDictionary<NSString *,id> *)displayModeInfo
{
	return [_displayModes copy];
}

- (void)setDisplayModeInfo:(NSDictionary<NSString *, id> *)displayModeInfo
{
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
		if ([thisPref isKindOfClass:defaultValues[i].valueClass]) {
			_displayModes[defaultValues[i].key] = thisPref;
		} else {
			_displayModes[defaultValues[i].key] = defaultValues[i].defaultValue;
		}
	}
}

- (void)loadConfiguration
{
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
//		OptionToggleable(@"Chroma 24 Interlace", DuckStation24ChromaSmoothingKey),
		OEDisplayMode_Submenu(@"MSAA", @[OptionWithValue(@"Off", DuckStationAntialiasKey, 1), OptionWithValue(@"2x", DuckStationAntialiasKey, 2), OptionWithValue(@"4x", DuckStationAntialiasKey, 4), OptionWithValue(@"8x", DuckStationAntialiasKey, 8), OptionWithValue(@"16x", DuckStationAntialiasKey, 16)]),
		OEDisplayMode_Submenu(@"CPU speed",
							  @[OptionWithValue(@"100% (default)", DuckStationCPUOverclockKey, 100),
								OptionWithValue(@"200%", DuckStationCPUOverclockKey, 200),
								OptionWithValue(@"300%", DuckStationCPUOverclockKey, 300),
								OptionWithValue(@"400%", DuckStationCPUOverclockKey, 400),
								OptionWithValue(@"500%", DuckStationCPUOverclockKey, 500),
								OptionWithValue(@"600%", DuckStationCPUOverclockKey, 600),
								OptionWithValue(@"800%", DuckStationCPUOverclockKey, 800)]),
	];
	
#undef OptionWithValue
#undef OptionToggleable
}

- (void)changeDisplayWithMode:(NSString *)displayMode
{
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

#pragma mark - Host Mapping

bool Host::AcquireHostDisplay(RenderAPI api)
{
	GET_CURRENT_OR_RETURN(false);
	std::unique_ptr<HostDisplay> display = std::make_unique<OpenEmu::OpenGLHostDisplay>(current);
	WindowInfo wi = WindowInfoFromGameCore(current);
	if (!display->CreateRenderDevice(wi, "", g_settings.gpu_use_debug_device, false) ||
		!display->InitializeRenderDevice(EmuFolders::Cache, g_settings.gpu_use_debug_device, false)) {
		os_log_error(OE_CORE_LOG, "Failed to create/initialize display render device");
		return false;
	}
	
	g_host_display = std::move(display);

	return true;
}

void Host::ReleaseHostDisplay()
{
	g_host_display->DestroyRenderSurface();
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
			aURL = [[NSBundle bundleForClass:[DuckStationGameCore class]] URLForResource:baseName withExtension:baseExt subdirectory:upperName];
		} else {
			aURL = [[NSBundle bundleForClass:[DuckStationGameCore class]] URLForResource:baseName withExtension:baseExt];
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
			aURL = [[NSBundle bundleForClass:[DuckStationGameCore class]] URLForResource:baseName withExtension:baseExt subdirectory:upperName];
		} else {
			aURL = [[NSBundle bundleForClass:[DuckStationGameCore class]] URLForResource:baseName withExtension:baseExt];
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
			aURL = [[NSBundle bundleForClass:[DuckStationGameCore class]] URLForResource:baseName withExtension:baseExt subdirectory:upperName];
		} else {
			aURL = [[NSBundle bundleForClass:[DuckStationGameCore class]] URLForResource:baseName withExtension:baseExt];
		}
		if (!aURL) {
			return std::nullopt;
		}
		
		FILESYSTEM_STAT_DATA sd;
		if (!FileSystem::StatFile(aURL.fileSystemRepresentation, &sd))
		{
			Log_ErrorPrintf("Failed to stat resource file '%s'", filename);
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
	os_log_info(OE_CORE_LOG, "DuckStation OSD: %{public}s", message.c_str());
}

void Host::AddKeyedOSDMessage(std::string key, std::string message, float duration)
{
	os_log_info(OE_CORE_LOG, "DuckStation OSD: %{public}s", message.c_str());
}

void Host::AddIconOSDMessage(std::string key, const char* icon, std::string message, float duration)
{
	os_log_info(OE_CORE_LOG, "DuckStation OSD: %{public}s", message.c_str());
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
}

void Host::OnGameChanged(const std::string& disc_path, const std::string& game_serial, const std::string& game_name)
{
	const Settings old_settings = g_settings;
//	ApplyGameSettings(false);
	do {
		const std::string &type = System::GetRunningCode();
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
//		if (hacks & OEPSXHacksMultiTap5PlayerPort2) {
//			g_settings.multitap_mode = MultitapMode::Port2Only;
//			g_settings.controller_types;
//		}
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
	os_log(OE_CORE_LOG, "DuckStation asking for confirmation about '%{public}s', assuming true", fullStr.c_str());
	return true;
}

void Host::ReportErrorAsync(const std::string_view& title, const std::string_view& message)
{
	auto fullStr = std::string(message);
	auto strTitle = std::string(title);
	os_log_error(OE_CORE_LOG, "%{public}s: %{public}s", strTitle.c_str(), fullStr.c_str());
}

void Host::ReportDebuggerMessage(const std::string_view& message)
{
	auto fullStr = std::string(message);
	os_log_debug(OE_CORE_LOG, "%{public}s", fullStr.c_str());
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
//	if (InputManager::HasPointerAxisBinds())
//	{
//		relative = true;
//		hide_cursor = true;
//	}
	
	// emit g_emu_thread->mouseModeRequested(relative, hide_cursor);
}

void ApplyGameSettings(bool display_osd_messages)
{
	// this gets called while booting, so can't use valid
	if (System::IsShutdown() || System::GetRunningCode().empty() || !g_settings.apply_game_settings)
		return;
	
	const GameDatabase::Entry* gs = GameDatabase::GetEntryForCode(System::GetRunningCode());
	if (gs) {
		gs->ApplySettings(g_settings, display_osd_messages);
	} else {
		os_log_info(OE_CORE_LOG, "Unable to find game-specific settings for %{public}s.", System::GetRunningCode().c_str());
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
	id<OEAudioBuffer> rb = [current audioBufferAtIndex:0];
	[rb write:m_output_buffer.data() maxLength:num_frames * m_channels * sizeof(SampleType)];
}

std::unique_ptr<OpenEmuAudioStream> OpenEmuAudioStream::CreateOpenEmuStream(u32 sample_rate, u32 channels, u32 buffer_ms)
{
  std::unique_ptr<OpenEmuAudioStream> stream = std::make_unique<OpenEmuAudioStream>(sample_rate, channels, buffer_ms, AudioStretchMode::Off);
  stream->BaseInitialize();
  return stream;
}

#pragma mark - Controller mapping

static void updateDigitalControllerButton(OEPSXButton button, int player, bool down) {
    DigitalController* controller = static_cast<DigitalController*>(System::GetController((u32)player));
    
	static constexpr std::array<std::pair<DigitalController::Button, OEPSXButton>, 14> mapping = {
		{{DigitalController::Button::Left, OEPSXButtonLeft},
			{DigitalController::Button::Right, OEPSXButtonRight},
			{DigitalController::Button::Up, OEPSXButtonUp},
			{DigitalController::Button::Down, OEPSXButtonDown},
			{DigitalController::Button::Circle, OEPSXButtonCircle},
			{DigitalController::Button::Cross, OEPSXButtonCross},
			{DigitalController::Button::Triangle, OEPSXButtonTriangle},
			{DigitalController::Button::Square, OEPSXButtonSquare},
			{DigitalController::Button::Start, OEPSXButtonStart},
			{DigitalController::Button::Select, OEPSXButtonSelect},
			{DigitalController::Button::L1, OEPSXButtonL1},
			{DigitalController::Button::L2, OEPSXButtonL2},
			{DigitalController::Button::R1, OEPSXButtonR1},
			{DigitalController::Button::R2, OEPSXButtonR2}}};
    
	for (const auto& [dsButton, oeButton] : mapping) {
		if (oeButton == button) {
			controller->SetBindState(static_cast<u32>(dsButton), down);
			break;
		}
	}
}

static void updateAnalogControllerButton(OEPSXButton button, int player, bool down) {
    AnalogController* controller = static_cast<AnalogController*>(System::GetController((u32)player));
    
	static constexpr std::array<std::pair<AnalogController::Button, OEPSXButton>, 17> button_mapping = {
		{{AnalogController::Button::Left, OEPSXButtonLeft},
			{AnalogController::Button::Right, OEPSXButtonRight},
			{AnalogController::Button::Up, OEPSXButtonUp},
			{AnalogController::Button::Down, OEPSXButtonDown},
			{AnalogController::Button::Circle, OEPSXButtonCircle},
			{AnalogController::Button::Cross, OEPSXButtonCross},
			{AnalogController::Button::Triangle, OEPSXButtonTriangle},
			{AnalogController::Button::Square, OEPSXButtonSquare},
			{AnalogController::Button::Start, OEPSXButtonStart},
			{AnalogController::Button::Select, OEPSXButtonSelect},
			{AnalogController::Button::L1, OEPSXButtonL1},
			{AnalogController::Button::L2, OEPSXButtonL2},
			{AnalogController::Button::L3, OEPSXButtonL3},
			{AnalogController::Button::R1, OEPSXButtonR1},
			{AnalogController::Button::R2, OEPSXButtonR2},
			{AnalogController::Button::R3, OEPSXButtonR3},
			{AnalogController::Button::Analog, OEPSXButtonAnalogMode}}};
    
	for (const auto& [dsButton, oeButton] : button_mapping) {
		if (oeButton == button) {
			controller->SetBindState(static_cast<u32>(dsButton), down);
			break;
		}
	}
}

static void updateAnalogAxis(OEPSXButton button, int player, CGFloat amount) {
    AnalogController* controller = static_cast<AnalogController*>(System::GetController((u32)player));
    
	static constexpr std::array<std::pair<AnalogController::Axis, std::pair<OEPSXButton, OEPSXButton>>, 4> axis_mapping = {
		{{AnalogController::Axis::LeftX, {OEPSXLeftAnalogLeft, OEPSXLeftAnalogRight}},
			{AnalogController::Axis::LeftY, {OEPSXLeftAnalogUp, OEPSXLeftAnalogDown}},
			{AnalogController::Axis::RightX, {OEPSXRightAnalogLeft, OEPSXRightAnalogRight}},
			{AnalogController::Axis::RightY, {OEPSXRightAnalogUp, OEPSXRightAnalogDown}}}};
	for (const auto& [dsAxis, oeAxes] : axis_mapping) {
        if (oeAxes.first == button || oeAxes.second == button) {
			// TODO: test this!
            controller->SetBindState(static_cast<u32>(dsAxis) + static_cast<u32>(AnalogController::Button::Count), ((static_cast<float>(amount) + 1.0f) / 2.0f));
        }
	}
}

static WindowInfo WindowInfoFromGameCore(DuckStationGameCore *core)
{
	WindowInfo wi = WindowInfo();
	//wi.type = WindowInfo::Type::MacOS;
	wi.surface_width = 640;
	wi.surface_height = 480;
	return wi;
}
