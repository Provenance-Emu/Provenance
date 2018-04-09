//
//  PVBeetlePSXGameCore.m
//  PVBeetlePSX
//
//  Created by Joseph Mattiello on 4/9/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#include <mednafen/mednafen.h>
#include <mednafen/settings-driver.h>
#include <mednafen/state.h>
#include <mednafen/mednafen-driver.h>
#include <mednafen/MemoryStream.h>

#import "PVBeetlePSXGameCore.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import <UIKit/UIKit.h>
#import <PVSupport/OERingBuffer.h>
#import <PVSupport/PVSupport-Swift.h>

#define GET_CURRENT_OR_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

typedef struct OEIntPoint {
	int x;
	int y;
} OEIntPoint;

typedef struct OEIntSize {
	int width;
	int height;
} OEIntSize;

typedef struct OEIntRect {
	OEIntPoint origin;
	OEIntSize size;
} OEIntRect;

static inline OEIntSize OEIntSizeMake(int width, int height)
{
	return (OEIntSize){ width, height };
}
static inline BOOL OEIntSizeEqualToSize(OEIntSize size1, OEIntSize size2)
{
	return size1.width == size2.width && size1.height == size2.height;
}
static inline BOOL OEIntSizeIsEmpty(OEIntSize size)
{
	return size.width == 0 || size.height == 0;
}

static inline OEIntRect OEIntRectMake(int x, int y, int width, int height)
{
	return (OEIntRect){ (OEIntPoint){ x, y }, (OEIntSize){ width, height } };
}

static MDFNGI *game;
static MDFN_Surface *backBufferSurf;
static MDFN_Surface *frontBufferSurf;

@interface PVBeetlePSXGameCore () <PVPSXSystemResponderClient>
{
	uint32_t *inputBuffer[8];
	int videoWidth, videoHeight;
	int videoOffsetX, videoOffsetY;
	int multiTapPlayerCount;
	NSString *romName;
	double sampleRate;
	double masterClock;

	NSString *mednafenCoreModule;
	NSTimeInterval mednafenCoreTiming;
	OEIntSize mednafenCoreAspect;

	EmulateSpecStruct spec;
}
@end

static __weak PVBeetlePSXGameCore *_current;

@implementation PVBeetlePSXGameCore 
-(uint32_t*) getInputBuffer:(int)bufferId
{
	return inputBuffer[bufferId];
}

static void mednafen_init(PVBeetlePSXGameCore* current)
{
	NSString* batterySavesDirectory = current.batterySavesPath;
	NSString* biosPath = current.BIOSPath;

//	MDFNI_InitializeModules();

	std::vector<MDFNSetting> settings;

//	MDFNI_Initialize([biosPath UTF8String], settings);

	// Set bios/system file and memcard save paths
	MDFNI_SetSetting("psx.bios_jp", [[[biosPath stringByAppendingPathComponent:@"scph5500"] stringByAppendingPathExtension:@"bin"] UTF8String]); // JP SCPH-5500 BIOS
	MDFNI_SetSetting("psx.bios_na", [[[biosPath stringByAppendingPathComponent:@"scph5501"] stringByAppendingPathExtension:@"bin"] UTF8String]); // NA SCPH-5501 BIOS
	MDFNI_SetSetting("psx.bios_eu", [[[biosPath stringByAppendingPathComponent:@"scph5502"] stringByAppendingPathExtension:@"bin"] UTF8String]); // EU SCPH-5502 BIOS

	MDFNI_SetSetting("filesys.path_sav", [batterySavesDirectory UTF8String]); // Memcards

	// Global settings

	// Enable time synchronization(waiting) for frame blitting.
	// Disable to reduce latency, at the cost of potentially increased video "juddering", with the maximum reduction in latency being about 1 video frame's time.
	// Will work best with emulated systems that are not very computationally expensive to emulate, combined with running on a relatively fast CPU.
	// Default: 1
	//	MDFNI_SetSettingB("video.blit_timesync", false);
	MDFNI_SetSettingB("video.fs", false); // Enable fullscreen mode. Default: 0

	// VB defaults. dox http://mednafen.sourceforge.net/documentation/09x/vb.html
	// VirtualBoy
	MDFNI_SetSetting("vb.disable_parallax", "1");       // Disable parallax for BG and OBJ rendering
	MDFNI_SetSetting("vb.anaglyph.preset", "disabled"); // Disable anaglyph preset
	MDFNI_SetSetting("vb.anaglyph.lcolor", "0xFF0000"); // Anaglyph l color
	MDFNI_SetSetting("vb.anaglyph.rcolor", "0x000000"); // Anaglyph r color
														//MDFNI_SetSetting("vb.allow_draw_skip", "1");      // Allow draw skipping
														//MDFNI_SetSetting("vb.instant_display_hack", "1"); // Display latency reduction hack


	// PSX Settings
	MDFNI_SetSetting("psx.h_overscan", "1"); // Show horizontal overscan area. 1 default
	MDFNI_SetSetting("psx.region_default", "na"); // Set default region to North America if auto detect fails, default: jp

#pragma message "forget about multitap for now :)"
	// Set multitap configuration if detected
	//    if (multiTapGames[[current ROMSerial]])
	//    {
	//        current->multiTapPlayerCount = [[multiTapGames objectForKey:[current ROMSerial]] intValue];
	//
	//        if([multiTap5PlayerPort2 containsObject:[current ROMSerial]])
	//            MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
	//        else
	//        {
	//            MDFNI_SetSetting("psx.input.pport1.multitap", "1"); // Enable multitap on PSX port 1
	//            if(current->multiTapPlayerCount > 5)
	//                MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
	//        }
	//    }
}


static void audio_callback(int16_t left, int16_t right)
{
	__strong PVBeetlePSXGameCore *strongCurrent = _current;

	[[strongCurrent ringBufferAtIndex:0] write:&left maxLength:2];
	[[strongCurrent ringBufferAtIndex:0] write:&right maxLength:2];

	strongCurrent = nil;
}


static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
	__strong PVBeetlePSXGameCore *strongCurrent = _current;

	[strongCurrent swapBuffers];
//	strongCurrent->_videoWidth  = width;
//	strongCurrent->_videoHeight = height;
//
//	dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//
//	dispatch_apply(height, the_queue, ^(size_t y){
//		const uint16_t *src = (uint16_t*)data + y * (pitch >> 1); //pitch is in bytes not pixels
//		uint16_t *dst = strongCurrent->_videoBuffer + y * 320;
//
//		memcpy(dst, src, sizeof(uint16_t)*width);
//	});

	strongCurrent = nil;
}

static void input_poll_callback(void)
{
	//DLog(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
	//DLog(@"polled input: port: %d device: %d id: %d", port, device, id);

	__strong PVBeetlePSXGameCore *strongCurrent = _current;
	int16_t value = 0;

//	if (port == 0 & device == RETRO_DEVICE_JOYPAD)
//	{
//		if (strongCurrent.controller1)
//		{
//			value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
//		}
//
//		if (value == 0)
//		{
//			value = strongCurrent->_pad[0][_id];
//		}
//	}
//	else if(port == 1 & device == RETRO_DEVICE_JOYPAD)
//	{
//		if (strongCurrent.controller2)
//		{
//			value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
//		}
//
//		if (value == 0)
//		{
//			value = strongCurrent->_pad[1][_id];
//		}
//	}

	strongCurrent = nil;

	return value;
}

static bool environment_callback(unsigned cmd, void *data)
{
	__strong PVBeetlePSXGameCore *strongCurrent = _current;

	switch(cmd)
	{
		case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY :
		{
			NSString *appSupportPath = [strongCurrent BIOSPath];

			*(const char **)data = [appSupportPath UTF8String];
			DLog(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
			break;
		}
		case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
		{
			break;
		}
		default :
			DLog(@"Environ UNSUPPORTED (#%u).\n", cmd);
			return false;
	}

	strongCurrent = nil;

	return true;
}

- (id)init {
	if((self = [super init]))
	{
		_current = self;

		multiTapPlayerCount = 2;

		for(unsigned i = 0; i < 8; i++) {
			inputBuffer[i] = (uint32_t *) calloc(9, sizeof(uint32_t));
		}
	}

	return self;
}

- (void)dealloc {
	for(unsigned i = 0; i < 8; i++) {
		free(inputBuffer[i]);
	}

	delete backBufferSurf;
	delete frontBufferSurf;

	if (_current == self) {
		_current = nil;
	}
}

# pragma mark - Execution

static void emulation_run(BOOL skipFrame) {
	retro_run();
//	GET_CURRENT_OR_RETURN();
//
//	static int16_t sound_buf[0x10000];
//	int32 rects[game->fb_height];
//	rects[0] = ~0;
//
//	current->spec = {0};
//	current->spec.surface = backBufferSurf;
//	current->spec.SoundRate = current->sampleRate;
//	current->spec.SoundBuf = sound_buf;
//	current->spec.LineWidths = rects;
//	current->spec.SoundBufMaxSize = sizeof(sound_buf) / 2;
//	current->spec.SoundBufSize = 0;
//	current->spec.SoundVolume = 1.0;
//	current->spec.soundmultiplier = 1.0;
//	current->spec.skip = skipFrame;
//
//	MDFNI_Emulate(&current->spec);
//
//	current->mednafenCoreTiming = current->masterClock / current->spec.MasterCycles;
//
//	// Fix for game stutter. mednafenCoreTiming flutters on init before settling so
//	// now we reset the game speed each frame to make sure current->gameInterval
//	// is up to date while respecting the current game speed setting
//	[current setGameSpeed:[current gameSpeed]];
//
//	if(current->_systemType == MednaSystemPSX)
//	{
//		current->videoWidth = rects[current->spec.DisplayRect.y];
//		current->videoOffsetX = current->spec.DisplayRect.x;
//	}
//	else if(game->multires)
//	{
//		current->videoWidth = rects[current->spec.DisplayRect.y];
//		current->videoOffsetX = current->spec.DisplayRect.x;
//	}
//	else
//	{
//		current->videoWidth = current->spec.DisplayRect.w;
//		current->videoOffsetX = current->spec.DisplayRect.x;
//	}
//
//	current->videoHeight = current->spec.DisplayRect.h;
//	current->videoOffsetY = current->spec.DisplayRect.y;
//
//	update_audio_batch(current->spec.SoundBuf, current->spec.SoundBufSize);
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error
{
	[[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath] withIntermediateDirectories:YES attributes:nil error:NULL];

	mednafenCoreModule = @"psx";
	// Note: OpenEMU sets this to 4, 3.
	mednafenCoreAspect = OEIntSizeMake(3, 2);
	//mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
	sampleRate         = 44100;

	const char *meta = NULL;

	retro_set_environment(environment_callback);
	retro_init();

	retro_set_audio_sample(audio_callback);
	retro_set_audio_sample_batch(update_audio_batch);
	retro_set_video_refresh(video_callback);
	retro_set_input_poll(input_poll_callback);
	retro_set_input_state(input_state_callback);

	const char *fullPath = [path UTF8String];

	struct retro_game_info info = {NULL};
	info.path = fullPath;
	info.data = nil; //data;
	info.size = 0; //size;
	info.meta = meta;

	if (retro_load_game(&info))
	{
		if ([self.batterySavesPath length])
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath withIntermediateDirectories:YES attributes:nil error:NULL];

			NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[self.romName stringByAppendingPathExtension:@"sav"]];

			[self loadSaveFile:filePath forType:RETRO_MEMORY_SAVE_RAM];
		}

		struct retro_system_av_info info;
		retro_get_system_av_info(&info);

		_frameInterval = info.timing.fps;
		_sampleRate = info.timing.sample_rate;

		retro_get_region();
		retro_run();

		return YES;
	}

	NSDictionary *userInfo = @{
							   NSLocalizedDescriptionKey: @"Failed to load game.",
							   NSLocalizedFailureReasonErrorKey: @"GenPlusGX failed to load game.",
							   NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported GenPlusGX ROM format."
							   };

	NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
											code:PVEmulatorCoreErrorCodeCouldNotLoadRom
										userInfo:userInfo];

	*error = newError;

	return NO;
		//	assert(_current);
//	mednafen_init(_current);
//
//	game = MDFNI_LoadGame([mednafenCoreModule UTF8String], [path UTF8String]);
//
//	if(!game) {
//		NSDictionary *userInfo = @{
//								   NSLocalizedDescriptionKey: @"Failed to load game.",
//								   NSLocalizedFailureReasonErrorKey: @"Mednafen failed to load game.",
//								   NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported Mednafen ROM format."
//								   };
//
//		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
//												code:PVEmulatorCoreErrorCodeCouldNotLoadRom
//											userInfo:userInfo];
//
//		*error = newError;
//		return NO;
//	}
//
//	// BGRA pixel format
//	MDFN_PixelFormat pix_fmt(MDFN_COLORSPACE_RGB, 16, 8, 0, 24);
//	backBufferSurf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);
//	frontBufferSurf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);
//
//	masterClock = game->MasterClock >> 32;
//
//	for(unsigned i = 0; i < multiTapPlayerCount; i++) {
//		game->SetInput(i, "dualshock", (uint8_t *)inputBuffer[i]);
//	}
//
//	// Multi-Disc check
//	BOOL multiDiscGame = NO;
////	NSNumber *discCount = [PVBeetlePSXGameCore multiDiscPSXGames][self.romSerial];
////	if (discCount) {
////		self.maxDiscs = [discCount intValue];
////		multiDiscGame = YES;
////	}
//
//	// PSX: Set multitap configuration if detected
//	NSString *serial = [self romSerial];
//	//        NSNumber* multitapCount = [MednafenGameCore multiDiscPSXGames][serial];
//	//
//	//        if (multitapCount != nil)
//	//        {
//	//            multiTapPlayerCount = [multitapCount intValue];
//	//
//	//            if([[MednafenGameCore multiTap5PlayerPort2] containsObject:serial]) {
//	//                MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
//	//            } else {
//	//                MDFNI_SetSetting("psx.input.pport1.multitap", "1"); // Enable multitap on PSX port 1
//	//                if(multiTapPlayerCount > 5) {
//	//                    MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
//	//                }
//	//            }
//	//        }
//
//	if (multiDiscGame && ![path.pathExtension.lowercaseString isEqualToString:@"m3u"]) {
//		NSString *m3uPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"m3u"];
//		NSRange rangeOfDocuments = [m3uPath rangeOfString:@"/Documents/" options:NSCaseInsensitiveSearch];
//		if (rangeOfDocuments.location != NSNotFound) {
//			m3uPath = [m3uPath substringFromIndex:rangeOfDocuments.location + 11];
//		}
//
//		NSString *message = [NSString stringWithFormat:@"This game requires multiple discs and must be loaded using a m3u file with all %lu discs.\n\nTo enable disc switching and ensure save files load across discs, it cannot be loaded as a single disc.\n\nPlease install a .m3u file with the filename %@.\nSee https://bitly.com/provm3u", self.maxDiscs, m3uPath];
//
//		NSDictionary *userInfo = @{
//								   NSLocalizedDescriptionKey: @"Failed to load game.",
//								   NSLocalizedFailureReasonErrorKey: @"Missing required m3u file.",
//								   NSLocalizedRecoverySuggestionErrorKey: message
//								   };
//
//		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
//												code:PVEmulatorCoreErrorCodeMissingM3U
//											userInfo:userInfo];
//
//		*error = newError;
//		return NO;
//	}
//
//	if (self.maxDiscs > 1) {
//		// Parse number of discs in m3u
//		NSString *m3uString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
//		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".cue|.ccd" options:NSRegularExpressionCaseInsensitive error:nil];
//		NSUInteger numberOfMatches = [regex numberOfMatchesInString:m3uString options:0 range:NSMakeRange(0, [m3uString length])];
//
//		NSLog(@"Loaded m3u containing %lu cue sheets or ccd",numberOfMatches);
//	}
//
//	MDFNI_SetMedia(0, 2, 0, 0); // Disc selection API
//
//	emulation_run(NO);

	return YES;
}

-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc {
//	disk_set_eject_state(open);
//	disk_set_image_index(disc);
//	MDFNI_SetMedia(0, open ? 0 : 2, disc, 0);
}

-(NSUInteger)maxNumberPlayers {
	NSUInteger maxPlayers = multiTapPlayerCount;
	return maxPlayers;
}

- (void)pollControllers {
	unsigned maxValue = 0;
	const int*map;

	maxValue = PVPSXButtonCount;
	map = PSXMap;

	NSUInteger maxNumberPlayers = MIN([self maxNumberPlayers], 4);

	for (NSInteger playerIndex = 0; playerIndex < maxNumberPlayers; playerIndex++) {
		GCController *controller = nil;

		if (self.controller1 && playerIndex == 0) {
			controller = self.controller1;
		}
		else if (self.controller2 && playerIndex == 1)
		{
			controller = self.controller2;
		}
		else if (self.controller3 && playerIndex == 3)
		{
			controller = self.controller3;
		}
		else if (self.controller4 && playerIndex == 4)
		{
			controller = self.controller4;
		}

		if (controller) {
			for (unsigned i=0; i<maxValue; i++) {
				if (i < PVPSXButtonLeftAnalogUp) {
					uint32_t value = (uint32_t)[self PSXcontrollerValueForButtonID:i forController:controller];

					if(value > 0) {
						inputBuffer[playerIndex][0] |= 1 << map[i];
					} else {
						inputBuffer[playerIndex][0] &= ~(1 << map[i]);
					}
				} else {
					float analogValue = [self PSXAnalogControllerValueForButtonID:i forController:controller];
					[self didMovePSXJoystickDirection:(PVPSXButton)i
											withValue:analogValue
											forPlayer:playerIndex];
				}
			}
		}
	}
}

- (void)executeFrameSkippingFrame: (BOOL) skip
{
	// Should we be using controller callbacks instead?
	if (!skip && (self.controller1 || self.controller2 || self.controller3 || self.controller4)) {
		[self pollControllers];
	}

	emulation_run(skip);
}

- (void)executeFrame
{
	[self executeFrameSkippingFrame:NO];
}

- (void)resetEmulation
{
	retro_reset();
}

- (void)stopEmulation
{
	retro_unload_game();
	[super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
	return mednafenCoreTiming ?: 60;
}

# pragma mark - Video

- (CGRect)screenRect
{
	return CGRectMake(videoOffsetX, videoOffsetY, videoWidth, videoHeight);
}

- (CGSize)bufferSize
{
	if ( game == NULL )
	{
		return CGSizeMake(0, 0);
	}
	else
	{
		return CGSizeMake(game->fb_width, game->fb_height);
	}
}

- (CGSize)aspectSize
{
	return CGSizeMake(mednafenCoreAspect.width,mednafenCoreAspect.height);
}

- (const void *)videoBuffer
{
	if ( frontBufferSurf == NULL )
	{
		return NULL;
	}
	else
	{
		return frontBufferSurf->pixels;
	}
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

- (BOOL)isDoubleBuffered {
	return YES;
}

- (void)swapBuffers
{
	MDFN_Surface *tempSurf = backBufferSurf;
	backBufferSurf = frontBufferSurf;
	frontBufferSurf = tempSurf;
}

# pragma mark - Audio

static size_t update_audio_batch(const int16_t *data, size_t frames)
{
	GET_CURRENT_OR_RETURN(frames);

	[[current ringBufferAtIndex:0] write:data maxLength:frames * [current channelCount] * 2];
	return frames;
}

- (double)audioSampleRate
{
	return sampleRate ? sampleRate : 48000;
}

- (NSUInteger)channelCount
{
	return game->soundchan;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	return NO; //MDFNI_SaveState(fileName.fileSystemRepresentation, "", NULL, NULL, NULL);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	return NO; //MDFNI_LoadState(fileName.fileSystemRepresentation, "");
}

- (NSData *)serializeStateWithError:(NSError **)outError
{
//	MemoryStream stream(65536, false);
//	MDFNSS_SaveSM(&stream, true);
//	size_t length = stream.map_size();
//	void *bytes = stream.map();
//
//	if(length) {
//		return [NSData dataWithBytes:bytes length:length];
//	}
//
//	if(outError) {
//		assert(false);
//#pragma message "fix error log"
//		//        *outError = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotSaveStateError  userInfo:@{
//		//            NSLocalizedDescriptionKey : @"Save state data could not be written",
//		//            NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
//		//        }];
//	}

	return nil;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError {
	NSError *error;
//	const void *bytes = [state bytes];
//	size_t length = [state length];
//
//	MemoryStream stream(length, -1);
//	memcpy(stream.map(), bytes, length);
//	MDFNSS_LoadSM(&stream, true);
//	size_t serialSize = stream.map_size();
//
//	if(serialSize != length)
//	{
//#pragma message "fix error log"
//		//        error = [NSError errorWithDomain:OEGameCoreErrorDomain
//		//                                    code:OEGameCoreStateHasWrongSizeError
//		//                                userInfo:@{
//		//                                           NSLocalizedDescriptionKey : @"Save state has wrong file size.",
//		//                                           NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The size of the save state does not have the right size, %lu expected, got: %ld.", serialSize, [state length]],
//		//                                        }];
//	}

	if(error) {
		if(outError) {
			*outError = error;
		}
		return false;
	} else {
		return true;
	}
}

# pragma mark - Input -

// Select, Triangle, X, Start, R1, R2, left stick u, left stick left,
const int PSXMap[]  = { 4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17 };

#pragma mark PSX
- (void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;
{
	if (button == PVPSXButtonStart) {
		self.isStartPressed = true;
	} else if (button == PVPSXButtonSelect) {
		self.isSelectPressed = true;
	}
	inputBuffer[player][0] |= 1 << PSXMap[button];
}

- (void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;
{
	if (button == PVPSXButtonStart) {
		self.isStartPressed = false;
	} else if (button == PVPSXButtonSelect) {
		self.isSelectPressed = false;
	}
	inputBuffer[player][0] &= ~(1 << PSXMap[button]);
}

- (void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player
{
//	// Fix the analog circle-to-square axis range conversion by scaling between a value of 1.00 and 1.50
//	// We cannot use MDFNI_SetSetting("psx.input.port1.dualshock.axis_scale", "1.33") directly.
//	// Background: https://mednafen.github.io/documentation/psx.html#Section_analog_range
//	value *= 32767; // de-normalize
//	double scaledValue = MIN(floor(0.5 + value * 1.33), 32767); // 30712 / cos(2*pi/8) / 32767 = 1.33
//
//	int analogNumber = PSXMap[button] - 17;
//	uint8_t *buf = (uint8_t *)inputBuffer[player];
//	MDFN_en16lsb(&buf[3 + analogNumber * 2], scaledValue);
//	MDFN_en16lsb(&buf[3 + (analogNumber ^ 1) * 2], 0);
}

- (float)PSXAnalogControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
	if ([controller extendedGamepad])
	{
		GCExtendedGamepad *pad = [controller extendedGamepad];
		switch (buttonID) {
			case PVPSXButtonLeftAnalogUp:
				return [pad leftThumbstick].up.value;
			case PVPSXButtonLeftAnalogDown:
				return [pad leftThumbstick].down.value;
			case PVPSXButtonLeftAnalogLeft:
				return [pad leftThumbstick].left.value;
			case PVPSXButtonLeftAnalogRight:
				return [pad leftThumbstick].right.value;
			case PVPSXButtonRightAnalogUp:
				return [pad rightThumbstick].up.value;
			case PVPSXButtonRightAnalogDown:
				return [pad rightThumbstick].down.value;
			case PVPSXButtonRightAnalogLeft:
				return [pad rightThumbstick].left.value;
			case PVPSXButtonRightAnalogRight:
				return [pad rightThumbstick].right.value;
			default:
				break;
		}
	} else if ([controller gamepad]) {
		GCGamepad *pad = [controller gamepad];
		switch (buttonID) {
			case PVPSXButtonLeftAnalogUp:
				return [pad dpad].up.value;
			case PVPSXButtonLeftAnalogDown:
				return [pad dpad].down.value;
			case PVPSXButtonLeftAnalogLeft:
				return [pad dpad].left.value;
			case PVPSXButtonLeftAnalogRight:
				return [pad dpad].right.value;
			default:
				break;
		}
	}
	return 0;
}

- (NSInteger)PSXcontrollerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
	if ([controller extendedGamepad])
	{
		GCExtendedGamepad *pad = [controller extendedGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVPSXButtonUp:
				return [[dpad up] isPressed];
			case PVPSXButtonDown:
				return [[dpad down] isPressed];
			case PVPSXButtonLeft:
				return [[dpad left] isPressed];
			case PVPSXButtonRight:
				return [[dpad right] isPressed];
			case PVPSXButtonLeftAnalogUp:
				return [pad leftThumbstick].up.value;
			case PVPSXButtonLeftAnalogDown:
				return [pad leftThumbstick].down.value;
			case PVPSXButtonLeftAnalogLeft:
				return [pad leftThumbstick].left.value;
			case PVPSXButtonLeftAnalogRight:
				return [pad leftThumbstick].right.value;
			case PVPSXButtonSquare:
				return [[pad buttonX] isPressed];
			case PVPSXButtonCross:
				return [[pad buttonA] isPressed];
			case PVPSXButtonCircle:
				return [[pad buttonB] isPressed];
			case PVPSXButtonL1:
				return [[pad leftShoulder] isPressed];
			case PVPSXButtonTriangle:
				return [[pad buttonY] isPressed];
			case PVPSXButtonR1:
				return [[pad rightShoulder] isPressed];
			case PVPSXButtonL2:
				return [[pad leftTrigger] isPressed];
			case PVPSXButtonR2:
				return [[pad rightTrigger] isPressed];
			case PVPSXButtonStart:
				return self.isStartPressed;
			case PVPSXButtonSelect:
				return self.isSelectPressed;
			default:
				break;
		}
	}
	else if ([controller gamepad])
	{
		GCGamepad *pad = [controller gamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVPSXButtonUp:
				return [[dpad up] isPressed];
			case PVPSXButtonDown:
				return [[dpad down] isPressed];
			case PVPSXButtonLeft:
				return [[dpad left] isPressed];
			case PVPSXButtonRight:
				return [[dpad right] isPressed];
			case PVPSXButtonSquare:
				return [[pad buttonX] isPressed];
			case PVPSXButtonCross:
				return [[pad buttonA] isPressed];
			case PVPSXButtonCircle:
				return [[pad buttonB] isPressed];
			case PVPSXButtonL1:
				return [[pad leftShoulder] isPressed];
			case PVPSXButtonTriangle:
				return [[pad buttonY] isPressed];
			case PVPSXButtonR1:
				return [[pad rightShoulder] isPressed];
			case PVPSXButtonStart:
				return self.isStartPressed;
			case PVPSXButtonSelect:
				return self.isSelectPressed;
			default:
				break;
		}
	}
#if TARGET_OS_TV
	else if ([controller microGamepad])
	{
		GCMicroGamepad *pad = [controller microGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVPSXButtonUp:
				return [[dpad up] value] > 0.5;
				break;
			case PVPSXButtonDown:
				return [[dpad down] value] > 0.5;
				break;
			case PVPSXButtonLeft:
				return [[dpad left] value] > 0.5;
				break;
			case PVPSXButtonRight:
				return [[dpad right] value] > 0.5;
				break;
			case PVPSXButtonCross:
				return [[pad buttonA] isPressed];
				break;
			case PVPSXButtonCircle:
				return [[pad buttonX] isPressed];
				break;
			default:
				break;
		}
	}
#endif
	return 0;
}

@end
