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

#import "PVGambatteBridge.h"

@import PVEmulatorCore;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVAudio;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

@import PVGambatteOptions;
@import libgambatte;
@import libresample;
//#include "gambatte.h"
//#include "resamplerinfo.h"
//#include "resampler.h"

#include "gbcpalettes.h"

gambatte::GB gb;
Resampler *resampler;
uint32_t gb_pad[PVGBButtonCount];

@interface PVGBEmulatorCoreBridge ()
{
    uint32_t *videoBuffer;
    uint32_t *inSoundBuffer;
    int16_t *outSoundBuffer;
    double sampleRate;
    GBPalette displayMode;
}
- (void)outputAudio:(unsigned)frames;
- (void)applyCheat:(NSString *)code;
- (void)loadPalette;
@end

// ---------------------------------------------------------------------------
// MARK: - RetroAchievements rc_client integration
//
// The rc_client API is guarded by HAVE_RCHEEVOS. To enable full integration:
//  1. Add a `librcheevos` SPM target (or depend on PVRcheevos package) in Package.swift.
//  2. Add `.define("HAVE_RCHEEVOS", to: "1")` to cSettings of PVGambatteBridge target.
//  3. Import the rc_client.h header.
//
// What is implemented below:
//  - wramBasePtr / vramBasePtr / wramSize — always available, backed by gambatte's
//    wramData() / vramData() / wramSize() (added to gambatte's vendored source).
//  - tickAchievements — calls rc_client_do_frame() when HAVE_RCHEEVOS is set.
//  - The read-memory callback and event handler stubs that rc_client needs.
// ---------------------------------------------------------------------------
#if HAVE_RCHEEVOS
#include "rc_client.h"   // from the librcheevos SPM target

static uint32_t pvgb_read_memory(uint32_t address, uint8_t *buffer,
                                  uint32_t num_bytes, rc_client_t *client) {
    PVGBEmulatorCoreBridge *core = (__bridge PVGBEmulatorCoreBridge *)
                                    rc_client_get_userdata(client);
    unsigned char *wram0 = (unsigned char *)core.wramBasePtr;
    unsigned char *wram1 = (unsigned char *)core.wramBank1Ptr;
    unsigned char *vram  = (unsigned char *)core.vramBasePtr;
    uint32_t read = 0;

    for (uint32_t i = 0; i < num_bytes; ++i) {
        uint16_t addr = (uint16_t)(address + i);
        uint8_t value = 0xFF;

        // WRAM: 0xC000–0xFDFF (0xE000–0xFDFF is an echo of 0xC000–0xDDFF).
        // Exclude 0xFE00–0xFFFF (OAM, I/O, HRAM, IE) which are not WRAM.
        if (addr >= 0xC000 && addr < 0xFE00) {
            uint16_t effAddr = (addr >= 0xE000) ? (addr - 0x2000u) : addr;
            if (effAddr < 0xD000) {
                // Fixed bank (area 0): 0xC000–0xCFFF
                if (wram0) { value = wram0[effAddr - 0xC000]; }
            } else {
                // Switchable bank (area 1): 0xD000–0xDFFF
                if (wram1) { value = wram1[effAddr - 0xD000]; }
            }
        } else if (vram && addr >= 0x8000 && addr <= 0x9FFF) {
            // vramBasePtr[0] = first byte of VRAM (GB address 0x8000).
            value = vram[addr - 0x8000];
        }
        buffer[i] = value;
        ++read;
    }
    return read;
}

// Minimal no-op server call; real implementation delegates to PVCheevos network layer.
static void pvgb_server_call(const rc_api_request_t *request,
                              rc_client_server_callback_t callback,
                              void *callback_data, rc_client_t *client) {
    // TODO: Forward to PVCheevos RetroNetworkClient.
    rc_api_server_response_t resp = {};
    resp.http_status_code = 0;
    callback(&resp, callback_data);
}

static void pvgb_event_handler(const rc_client_event_t *event, rc_client_t *client) {
    PVGBEmulatorCoreBridge *core = (__bridge PVGBEmulatorCoreBridge *)
                                    rc_client_get_userdata(client);
    if (!core) { return; }

    switch (event->type) {
        case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED: {
            const rc_client_achievement_t *ach = event->achievement;
            NSString *badgeName = ach->badge_name ? @(ach->badge_name) : nil;
            NSURL *badgeURL = badgeName.length
                ? [NSURL URLWithString:[NSString stringWithFormat:
                      @"https://media.retroachievements.org/Badge/%@.png", badgeName]]
                : nil;
            [core rcAchievementTriggeredWithID:ach->id
                                         title:ach->title       ? @(ach->title)       : nil
                                   description:ach->description ? @(ach->description) : nil
                                        points:ach->points
                                      badgeURL:badgeURL
                                    isHardcore:(BOOL)rc_client_get_hardcore_enabled(client)];
            break;
        }
        case RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW: {
            const rc_client_achievement_t *ach = event->achievement;
            [core rcAchievementProgressWithID:ach->id
                                        title:ach->title ? @(ach->title) : nil
                                 progressText:ach->measured_progress ? @(ach->measured_progress) : nil];
            break;
        }
        case RC_CLIENT_EVENT_LEADERBOARD_STARTED: {
            const rc_client_leaderboard_t *lb = event->leaderboard;
            [core rcLeaderboardStartedWithID:lb->id
                                       title:lb->title       ? @(lb->title)       : nil
                                 description:lb->description ? @(lb->description) : nil
                                   scoreText:lb->tracker_value ? @(lb->tracker_value) : nil];
            break;
        }
        case RC_CLIENT_EVENT_LEADERBOARD_FAILED:
            [core rcLeaderboardFailedWithID:event->leaderboard->id];
            break;
        case RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED: {
            const rc_client_leaderboard_t *lb = event->leaderboard;
            [core rcLeaderboardSubmittedWithID:lb->id
                                         title:lb->title       ? @(lb->title)       : nil
                                   description:lb->description ? @(lb->description) : nil
                                     scoreText:lb->tracker_value ? @(lb->tracker_value) : nil];
            break;
        }
        default:
            break;
    }
}
#endif // HAVE_RCHEEVOS

@implementation PVGBEmulatorCoreBridge {
#if HAVE_RCHEEVOS
    rc_client_t *_rcClient;
#endif
    BOOL _achievementsActive;
}

static __weak PVGBEmulatorCoreBridge *_current;

// MARK: - RetroAchievements memory properties

- (void *)wramBasePtr {
    return gb.wramData(0);
}

- (void *)wramBank1Ptr {
    return gb.wramData(1);
}

- (void *)vramBasePtr {
    return gb.vramData();
}

- (NSUInteger)wramSize {
    return (NSUInteger)gb.wramSize();
}

- (BOOL)achievementsActive {
    return _achievementsActive;
}

// MARK: - Achievement tick

- (void)tickAchievements {
#if HAVE_RCHEEVOS
    if (_rcClient && _achievementsActive) {
        rc_client_do_frame(_rcClient);
    }
#endif
}

class GetInput : public gambatte::InputGetter
{
public:
    unsigned operator()()
    {
        __strong PVGBEmulatorCoreBridge *strongCurrent = _current;
        if (strongCurrent.controller1)
        {
            [strongCurrent updateControllers];
        }

        return gb_pad[0];
    }
} static GetInput;

- (instancetype) init {
    if((self = [super init])) {
        videoBuffer = (uint32_t *)malloc(160 * 144 * 4);
        inSoundBuffer = (uint32_t *)malloc(2064 * 2 * 4);
        outSoundBuffer = (int16_t *)malloc(2064 * 2 * 2);
        displayMode = GBPalettePeaSoupGreen;
    }

	_current = self;

	return self;
}

- (void)dealloc {
    free(videoBuffer);
    free(inSoundBuffer);
    free(outSoundBuffer);
}

# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    memset(gb_pad, 0, sizeof(uint32_t) * PVGBButtonCount);

    // Set battery save dir
    NSURL *batterySavesDirectory = [NSURL fileURLWithPath:[self batterySavesPath]];
    [[NSFileManager defaultManager] createDirectoryAtURL:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    gb.setSaveDir([[batterySavesDirectory path] UTF8String]);

    // Set input state callback
    gb.setInputGetter(&GetInput);

    // Setup resampler
    double fps = 4194304.0 / 70224.0;
    double inSampleRate = fps * 35112; // 2097152

    // 2 = "Very high quality (polyphase FIR)", see resamplerinfo.cpp
    resampler = ResamplerInfo::get(2).create(inSampleRate, 48000.0, 2 * 2064);

    unsigned long mul, div;
    resampler->exactRatio(mul, div);

    double outSampleRate = inSampleRate * mul / div;
    sampleRate = outSampleRate; // 47994.326636

    unsigned loadFlags = 0;
    if ([PVGBEmulatorCoreOptions forceDMG]) {
        loadFlags |= gambatte::GB::FORCE_DMG;
    }

    if (gb.load([path UTF8String], loadFlags) != 0) {
        if (error) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: @"Gambatte failed to load ROM.",
                                       NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format Gambatte supports."
                                       };

            NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                                userInfo:userInfo];

            *error = newError;
        }
        return NO;
    }

    // Load built-in GBC palette for monochrome games if supported.
    // When FORCE_DMG is enabled, treat the game as non-color regardless of ROM header.
    if (gb.isCgb()) {
        displayMode = [PVGBEmulatorCoreOptions getPalette];
    } else {
        [self loadPalette];
    }

#if HAVE_RCHEEVOS
    // Initialise rc_client on successful ROM load.
    if (!_rcClient) {
        _rcClient = rc_client_create(pvgb_read_memory, pvgb_server_call);
        if (_rcClient) {
            rc_client_set_userdata(_rcClient, (__bridge void *)self);
            rc_client_set_event_handler(_rcClient, pvgb_event_handler);
        }
    }
#endif

    return YES;
}

-(BOOL)isGameboyColor {
	return gb.isCgb();
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    std::size_t samples = 2064;

    // Note: 2 symbols (possibly due to incorrect pointer casting?) don't
    // link in dynamic mode
    // Undefined symbol: gambatte::GB::runFor(unsigned long*, long, unsigned long*, unsigned long&)
    while (gb.runFor(videoBuffer, 160, inSoundBuffer, samples) == -1) {
        [self outputAudio:samples];
    }

    [self outputAudio:samples];
    [self tickAchievements];
}
    
- (void)resetEmulation
{
    gb.reset();
}

- (void)stopEmulation
{
    if (self.isRunning)
    {
        gb.saveSavedata();

        delete resampler;

#if HAVE_RCHEEVOS
        if (_rcClient) {
            rc_client_unload_game(_rcClient);
            rc_client_destroy(_rcClient);
            _rcClient = NULL;
        }
        _achievementsActive = NO;
#endif

        [super stopEmulation];
    }
}

- (NSTimeInterval)frameInterval
{
    return 59.727501;
}

# pragma mark - Video

- (const void *)videoBuffer
{
    return videoBuffer;
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, 160, 144);
}

- (CGSize)bufferSize
{
    return CGSizeMake(160, 144);
}

- (CGSize)aspectSize
{
    return CGSizeMake(10, 9);
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

# pragma mark - Audio


- (double)audioSampleRate
{
    return sampleRate;
}

- (NSUInteger)channelCount
{
    return 2;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error  
{
    @synchronized(self) {
        // Note: 2 symbols (possibly due to incorrect pointer casting?) don't
        // link in dynamic mode
        // Undefined symbol: gambatte::GB::runFor(unsigned long*, long, unsigned long*, unsigned long&)
        // Undefined symbol: gambatte::GB::saveState(unsigned long const*, long, std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> const&)

        BOOL success = gb.saveState(nil, 0, [fileName UTF8String]);
		if (!success) {
            if (error) {
                NSDictionary *userInfo = @{
                                           NSLocalizedDescriptionKey: @"Failed to save state.",
                                           NSLocalizedFailureReasonErrorKey: @"Core failed to create save state.",
                                           NSLocalizedRecoverySuggestionErrorKey: @""
                                           };

                NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                    userInfo:userInfo];

                *error = newError;
            }
		}
		return success;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error
{
    @synchronized(self) {
        BOOL success = gb.loadState([fileName UTF8String]);
		if (!success) {
            if (error) {
                NSDictionary *userInfo = @{
                                           NSLocalizedDescriptionKey: @"Failed to load state.",
                                           NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
                                           NSLocalizedRecoverySuggestionErrorKey: @""
                                           };

                NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];

                *error = newError;
            }
		}
		return success;
    }
}

# pragma mark - Input

const int GBMap[] = {gambatte::InputGetter::UP, gambatte::InputGetter::DOWN, gambatte::InputGetter::LEFT, gambatte::InputGetter::RIGHT, gambatte::InputGetter::A, gambatte::InputGetter::B, gambatte::InputGetter::START, gambatte::InputGetter::SELECT};
- (void)didPushGBButton:(PVGBButton)button forPlayer:(NSInteger)player
{
    gb_pad[0] |= GBMap[button];
}

- (void)didReleaseGBButton:(PVGBButton)button forPlayer:(NSInteger)player
{
    gb_pad[0] &= ~GBMap[button];
}

- (void)updateControllers
{
    if ([self.controller1 extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [self.controller1 extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        
        GCControllerButtonInput *selectButton = nil;
        GCControllerButtonInput *startButton = nil;
        // Resolve Start/Select using shared utility:
        // DualSense/DualShock → touchpad or Create/Share; Xbox → View; Switch → −; MFi → shoulders
        PVResolveStartSelectShareButtons(self.controller1, &startButton, &selectButton, nil);

        (dpad.up.isPressed || gamepad.leftThumbstick.up.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonUp] : gb_pad[0] &= ~GBMap[PVGBButtonUp];
        (dpad.down.isPressed || gamepad.leftThumbstick.down.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonDown] : gb_pad[0] &= ~GBMap[PVGBButtonDown];
        (dpad.left.isPressed || gamepad.leftThumbstick.left.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonLeft] : gb_pad[0] &= ~GBMap[PVGBButtonLeft];
        (dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonRight] : gb_pad[0] &= ~GBMap[PVGBButtonRight];

        (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonB] : gb_pad[0] &= ~GBMap[PVGBButtonB];
        (gamepad.buttonB.isPressed || gamepad.buttonX.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonA] : gb_pad[0] &= ~GBMap[PVGBButtonA];

        (gamepad.leftShoulder.isPressed || gamepad.leftTrigger.isPressed || (selectButton && selectButton.isPressed)) ? gb_pad[0] |= GBMap[PVGBButtonSelect] : gb_pad[0] &= ~GBMap[PVGBButtonSelect];
        (gamepad.rightShoulder.isPressed || gamepad.rightTrigger.isPressed || (startButton && startButton.isPressed)) ? gb_pad[0] |= GBMap[PVGBButtonStart] : gb_pad[0] &= ~GBMap[PVGBButtonStart];
    }
    else if ([self.controller1 gamepad])
    {
        GCGamepad *gamepad = [self.controller1 gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];

        dpad.up.isPressed ? gb_pad[0] |= GBMap[PVGBButtonUp] : gb_pad[0] &= ~GBMap[PVGBButtonUp];
        dpad.down.isPressed ? gb_pad[0] |= GBMap[PVGBButtonDown] : gb_pad[0] &= ~GBMap[PVGBButtonDown];
        dpad.left.isPressed ? gb_pad[0] |= GBMap[PVGBButtonLeft] : gb_pad[0] &= ~GBMap[PVGBButtonLeft];
        dpad.right.isPressed ? gb_pad[0] |= GBMap[PVGBButtonRight] : gb_pad[0] &= ~GBMap[PVGBButtonRight];

        (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonB] : gb_pad[0] &= ~GBMap[PVGBButtonB];
        (gamepad.buttonB.isPressed || gamepad.buttonX.isPressed) ? gb_pad[0] |= GBMap[PVGBButtonA] : gb_pad[0] &= ~GBMap[PVGBButtonA];

        gamepad.leftShoulder.isPressed ? gb_pad[0] |= GBMap[PVGBButtonSelect] : gb_pad[0] &= ~GBMap[PVGBButtonSelect];
        gamepad.rightShoulder.isPressed ? gb_pad[0] |= GBMap[PVGBButtonStart] : gb_pad[0] &= ~GBMap[PVGBButtonStart];
    }
#if TARGET_OS_TV
    else if ([self.controller1 microGamepad])
    {
        GCMicroGamepad *pad = [self.controller1 microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];

        dpad.up.value > 0.5 ? gb_pad[0] |= GBMap[PVGBButtonUp] : gb_pad[0] &= ~GBMap[PVGBButtonUp];
        dpad.down.value > 0.5 ? gb_pad[0] |= GBMap[PVGBButtonDown] : gb_pad[0] &= ~GBMap[PVGBButtonDown];
        dpad.left.value > 0.5 ? gb_pad[0] |= GBMap[PVGBButtonLeft] : gb_pad[0] &= ~GBMap[PVGBButtonLeft];
        dpad.right.value > 0.5 ? gb_pad[0] |= GBMap[PVGBButtonRight] : gb_pad[0] &= ~GBMap[PVGBButtonRight];

        pad.buttonA.isPressed ? gb_pad[0] |= GBMap[PVGBButtonB] : gb_pad[0] &= ~GBMap[PVGBButtonB];
        pad.buttonX.isPressed ? gb_pad[0] |= GBMap[PVGBButtonA] : gb_pad[0] &= ~GBMap[PVGBButtonA];
    }
#endif
}

# pragma mark - Display Mode

- (void)changeDisplayMode:(GBPalette)displayMode {
    if (gb.isCgb()) {
        return;
    }

    unsigned short *gbc_bios_palette = NULL;
    self->displayMode = displayMode;
    switch (displayMode)
    {
        case GBPalettePeaSoupGreen:
        {
            // GB Pea Soup Green
            gb.setDmgPaletteColor(0, 0, 8369468);
            gb.setDmgPaletteColor(0, 1, 6728764);
            gb.setDmgPaletteColor(0, 2, 3629872);
            gb.setDmgPaletteColor(0, 3, 3223857);
            gb.setDmgPaletteColor(1, 0, 8369468);
            gb.setDmgPaletteColor(1, 1, 6728764);
            gb.setDmgPaletteColor(1, 2, 3629872);
            gb.setDmgPaletteColor(1, 3, 3223857);
            gb.setDmgPaletteColor(2, 0, 8369468);
            gb.setDmgPaletteColor(2, 1, 6728764);
            gb.setDmgPaletteColor(2, 2, 3629872);
            gb.setDmgPaletteColor(2, 3, 3223857);
            return;
        }
        case GBPalettePocket:
        {
            // GB Pocket
            gb.setDmgPaletteColor(0, 0, 13487791);
            gb.setDmgPaletteColor(0, 1, 10987158);
            gb.setDmgPaletteColor(0, 2, 6974033);
            gb.setDmgPaletteColor(0, 3, 2828823);
            gb.setDmgPaletteColor(1, 0, 13487791);
            gb.setDmgPaletteColor(1, 1, 10987158);
            gb.setDmgPaletteColor(1, 2, 6974033);
            gb.setDmgPaletteColor(1, 3, 2828823);
            gb.setDmgPaletteColor(2, 0, 13487791);
            gb.setDmgPaletteColor(2, 1, 10987158);
            gb.setDmgPaletteColor(2, 2, 6974033);
            gb.setDmgPaletteColor(2, 3, 2828823);

            return;
        }
        case GBPaletteBlue:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Blue"));
            break;
        case GBPaletteDarkBlue:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Dark Blue"));
            break;
        case GBPaletteGreen:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Green"));
            break;
        case GBPaletteDarkGreen:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Dark Green"));
            break;
        case GBPaletteBrown:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Brown"));
            break;
        case GBPaletteDarkBrown:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Dark Brown"));
            break;
        case GBPaletteRed:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Red"));
            break;
        case GBPaletteYellow:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Yellow"));
            break;
        case GBPaletteOrange:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Orange"));
            break;
        case GBPalettePastelMix:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Pastel Mix"));
            break;
        case GBPaletteInverted:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Inverted"));
            break;
		case GBPaletteRomTitle:
        {
            std::string str = gb.romTitle(); // read ROM internal title
            const char *internal_game_name = str.c_str();
            gbc_bios_palette = const_cast<unsigned short *>(findGbcTitlePal(internal_game_name));

            if (gbc_bios_palette == 0)
            {
                gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Grayscale"));
            }
			break;
		}
        case GBPaletteGrayscale:
            gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Grayscale"));
			break;
        default:
            return;
			break;
	}

    unsigned rgb32 = 0;
    for (unsigned palnum = 0; palnum < 3; ++palnum)
    {
        for (unsigned colornum = 0; colornum < 4; ++colornum)
        {
            rgb32 = gbcToRgb32(gbc_bios_palette[palnum * 4 + colornum]);
            gb.setDmgPaletteColor(palnum, colornum, rgb32);
        }
    }
}

# pragma mark - Misc Helper Methods

- (void)outputAudio:(unsigned)frames {
    if (!frames) {
        return;
    }

    size_t len = resampler->resample(outSoundBuffer, reinterpret_cast<const int16_t *>(inSoundBuffer), frames);

    if (len) {
        [[self ringBufferAtIndex:0] write:outSoundBuffer size:len << 2];
    }
}

- (void)applyCheat:(NSString *)code
{
    std::string s = [code UTF8String];
    if (s.find("-") != std::string::npos)
        gb.setGameGenie(s);
    else
        gb.setGameShark(s);
}

// MARK: - Achievement game loading

#if HAVE_RCHEEVOS
typedef struct pvgb_load_ctx {
    void *bridge;        // __bridge_retained PVGBEmulatorCoreBridge *
    void (^completion)(BOOL);
} pvgb_load_ctx_t;

static void pvgb_load_callback(int result, const char * __unused error_message,
                                rc_client_t * __unused client, void *userdata) {
    pvgb_load_ctx_t *ctx = (pvgb_load_ctx_t *)userdata;
    // Transfer ownership back.
    PVGBEmulatorCoreBridge *core = (__bridge_transfer PVGBEmulatorCoreBridge *)ctx->bridge;
    void (^completion)(BOOL) = ctx->completion;
    free(ctx);

    BOOL success = (result == RC_OK);
    core->_achievementsActive = success;
    if (completion) { completion(success); }
}
#endif // HAVE_RCHEEVOS

- (void)loadAchievementsForGameHash:(NSString *)gameHash
                         completion:(void (^)(BOOL success))completion {
#if HAVE_RCHEEVOS
    if (!_rcClient) {
        if (completion) { completion(NO); }
        return;
    }
    pvgb_load_ctx_t *ctx = (pvgb_load_ctx_t *)malloc(sizeof(pvgb_load_ctx_t));
    if (!ctx) {
        if (completion) { completion(NO); }
        return;
    }
    ctx->bridge = (__bridge_retained void *)self;
    ctx->completion = completion ? [completion copy] : nil;
    rc_client_load_game(_rcClient, gameHash.UTF8String, pvgb_load_callback, ctx);
#else
    if (completion) { completion(NO); }
#endif
}

- (void)unloadAchievements {
#if HAVE_RCHEEVOS
    if (_rcClient) {
        rc_client_unload_game(_rcClient);
    }
    _achievementsActive = NO;
#endif
}

- (void)loadPalette
{
    std::string str = gb.romTitle(); // read ROM internal title
    const char *internal_game_name = str.c_str();

    // load a GBC BIOS builtin palette
    unsigned short *gbc_bios_palette = NULL;
    gbc_bios_palette = const_cast<unsigned short *>(findGbcTitlePal(internal_game_name));

    if (gbc_bios_palette == 0)
    {
        // no custom palette found, load the default (Original Grayscale)
        gbc_bios_palette = const_cast<unsigned short *>(findGbcDirPal("GBC - Grayscale"));
    }

    unsigned rgb32 = 0;
    for (unsigned palnum = 0; palnum < 3; ++palnum)
    {
        for (unsigned colornum = 0; colornum < 4; ++colornum)
        {
            rgb32 = gbcToRgb32(gbc_bios_palette[palnum * 4 + colornum]);
            gb.setDmgPaletteColor(palnum, colornum, rgb32);
        }
    }
}

@end

#pragma mark - Cheats

static NSMutableDictionary *gb_cheatlist = nil;

@implementation PVGBEmulatorCoreBridge (Cheats)

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
    // Lazy-initialise cheat dictionary
    if (!gb_cheatlist) {
        gb_cheatlist = [[NSMutableDictionary alloc] init];
    }

    // Sanitize
    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Gambatte expects cheats UPPERCASE
    code = [code uppercaseString];

    // Remove any spaces
    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];

    if (enabled)
        [gb_cheatlist setValue:@YES forKey:code];
    else
        [gb_cheatlist removeObjectForKey:code];

    NSMutableArray *combinedGameSharkCodes = [[NSMutableArray alloc] init];
    NSMutableArray *combinedGameGenieCodes = [[NSMutableArray alloc] init];

    // Gambatte expects all cheats in one combined string per-type e.g. 01xxxxxx+01xxxxxx
    // Add enabled per-type cheats to arrays and later join them all by a '+' separator
    for (id key in gb_cheatlist)
    {
        if ([[gb_cheatlist valueForKey:key] isEqual:@YES])
        {
            // GameShark (no hyphen) vs Game Genie (contains hyphen)
            if ([key rangeOfString:@"-"].location == NSNotFound)
                [combinedGameSharkCodes addObject:key];
            else
                [combinedGameGenieCodes addObject:key];
        }
    }

    // Apply combined cheats or force a final reset if all cheats are disabled
    [self applyCheat:[combinedGameSharkCodes count] != 0 ? [combinedGameSharkCodes componentsJoinedByString:@"+"] : @"0"];
    [self applyCheat:[combinedGameGenieCodes count] != 0 ? [combinedGameGenieCodes componentsJoinedByString:@"+"] : @"0-"];

    return YES;
}

- (void)resetCheatCodes
{
    if (gb_cheatlist) {
        [gb_cheatlist removeAllObjects];
    }
    // Gambatte clears its internal cheat lists by applying sentinel values:
    // "0" clears all GameShark (GS) codes; "0-" clears all Game Genie (GG) codes.
    [self applyCheat:@"0"];
    [self applyCheat:@"0-"];
}

@end

// NOTE: @implementation PVGBEmulatorCoreBridge (AchievementsEvents) is NOT
// provided here. The Swift extension in PVGBEmulatorCore+RetroAchievements.swift
// provides the only implementations of these methods, routing events through
// achievementsEventOwner → PVGBEmulatorCore → _achievementsDelegate.
