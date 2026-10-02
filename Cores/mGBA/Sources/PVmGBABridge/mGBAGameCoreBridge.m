/*
 Copyright (c) 2016, Jeffrey Pfau

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS''
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */

#import "mGBAGameCoreBridge.h"

@import libmGBA;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVEmulatorCore;
@import PVAudio;

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
#import <OpenGL/OpenGL.h>
#import <GLUT/glut.h>
#endif

#include <mgba-util/common.h>

#include <mgba/core/core.h>
#include <mgba/core/cheats.h>
#include <mgba/core/serialize.h>
#include <mgba/gba/core.h>
#include <mgba/internal/gba/cheats.h>
#include <mgba/internal/gba/input.h>
#include <mgba/internal/gba/memory.h>
#include <mgba-util/audio-buffer.h>
#include <mgba-util/circle-buffer.h>
#include <mgba-util/memory.h>
#include <mgba-util/vfs.h>
#include <mgba-util/audio-resampler.h>

/// Fixed rate handed to Provenance's audio graph. The GBA's own output rate
/// follows the SOUNDBIAS resolution bits (32768/65536/131072/262144 Hz), so
/// mGBA's buffer is resampled to this rate every frame, as upstream's SDL and
/// Qt frontends do. 32768 Hz is the rate at the default resolution, where the
/// resampler's step is exactly 1.
static const double kPVmGBAOutputSampleRate = 32768.0;

/// Stereo frames the resampler output buffer holds. One frame at the output
/// rate is ~549 samples; this leaves room for a frame that runs long.
static const size_t kPVmGBAResampledCapacity = 0x1000;

/// rcheevos maps GBA Save RAM to 64 KB (flat 0x048000-0x057FFF in
/// rcheevos/src/rcheevos/consoleinfo.c), so the mirror is that size.
static const size_t kPVmGBASaveRAMMirrorSize = 0x10000;

static void _audioLowPassFilter(int16_t* buffer, int count);

static int32_t audioLowPassRange = (60 * 0x10000) / 100;
static int32_t audioLowPassLeftPrev = 0;
static int32_t audioLowPassRightPrev = 0;

const int GBAMap[] = {
    GBA_KEY_UP,
    GBA_KEY_DOWN,
    GBA_KEY_LEFT,
    GBA_KEY_RIGHT,
    GBA_KEY_A,
    GBA_KEY_B,
    GBA_KEY_L,
    GBA_KEY_R,
    GBA_KEY_START,
    GBA_KEY_SELECT
};

@interface PVmGBAGameCoreBridge () <PVGBASystemResponderClient> {
    struct mCore* core;
    void* outputBuffer;
    NSMutableDictionary *cheatSets;
    struct mAudioResampler resampler;
    struct mAudioBuffer resampledAudio;
    int16_t *audioBuffer;
    unsigned width, height;
    BOOL audioLowPassEnabled;
    BOOL romLoaded;
    uint8_t *saveRAMMirror;
}
@end

static void _log(struct mLogger* log,
                 int category,
                 enum mLogLevel level,
                 const char* format,
                 va_list args)
{}

static struct mLogger logger = { .log = _log };

@implementation PVmGBAGameCoreBridge

- (instancetype)init {
    if ((self = [super init])) {

    }

    return self;
}

- (void)dealloc {
    mCoreConfigDeinit(&core->config);
    free(audioBuffer);
    audioBuffer = NULL;
    free(saveRAMMirror);
    saveRAMMirror = NULL;
    core->deinit(core);
    free(outputBuffer);
    mAudioResamplerDeinit(&resampler);
    mAudioBufferDeinit(&resampledAudio);
}

#pragma mark - Execution


-(void)initialize {
    [super initialize];
    core = GBACoreCreate();
    mCoreInitConfig(core, nil);

    struct mCoreOptions opts = {
        .useBios = true,
    };

    // Set up a logger. The default logger prints everything to STDOUT, which is not usually desirable.
    mLogSetDefaultLogger(&logger);
    mCoreConfigSetDefaultIntValue(&core->config, "logToStdout", true);
    mCoreConfigLoadDefaults(&core->config, &opts);
    core->init(core);
    outputBuffer = nil;

    // Video setup using currentVideoSize
    core->currentVideoSize(core, &width, &height);
    outputBuffer = malloc(width * height * BYTES_PER_PIXEL);
    core->setVideoBuffer(core, outputBuffer, width);

    // Audio: resample mGBA's variable-rate buffer to a fixed output rate.
    mAudioBufferInit(&resampledAudio, kPVmGBAResampledCapacity, 2);
    mAudioResamplerInit(&resampler, mINTERPOLATOR_SINC);
    mAudioResamplerSetDestination(&resampler, &resampledAudio, kPVmGBAOutputSampleRate);
    audioBuffer = malloc(kPVmGBAResampledCapacity * 2 * sizeof(int16_t));

    audioLowPassEnabled = YES;
    saveRAMMirror = calloc(1, kPVmGBASaveRAMMirrorSize);
    cheatSets = [[NSMutableDictionary alloc] init];
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    NSString *batterySavesDirectory = [self batterySavesPath];
    [[NSFileManager defaultManager] createDirectoryAtURL:[NSURL fileURLWithPath:batterySavesDirectory]
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    if (core->dirs.save) {
        core->dirs.save->close(core->dirs.save);
    }
    core->dirs.save = VDirOpen([batterySavesDirectory fileSystemRepresentation]);

    if (!mCoreLoadFile(core, [path fileSystemRepresentation])) {
        if (error) {
            *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                         code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                     userInfo:nil];
        }
        return NO;
    }
    mCoreAutoloadSave(core);

    core->reset(core);
    romLoaded = YES;
    return YES;
}

- (void)executeFrame {
    core->runFrame(core);
    [self drainAudio];
    [self refreshSaveRAMMirror];

    void (^handler)(void) = self.frameCompletedHandler;
    if (handler) {
        handler();
    }
}

/// Resample everything mGBA produced this frame to the fixed output rate.
/// The source rate is read every frame because a game can change the
/// SOUNDBIAS resolution (and so mGBA's sample rate) at any time.
- (void)drainAudio {
    struct mAudioBuffer *buffer = core->getAudioBuffer(core);
    mAudioResamplerSetSource(&resampler, buffer, core->audioSampleRate(core), true);
    mAudioResamplerProcess(&resampler);

    size_t produced = mAudioBufferRead(&resampledAudio, audioBuffer, kPVmGBAResampledCapacity);
    if (produced > 0) {
        if (audioLowPassEnabled) {
            _audioLowPassFilter(audioBuffer, (int)produced);
        }
        [[self ringBufferAtIndex:0] write:audioBuffer size:produced * sizeof(int16_t) * 2];
    }
}

/// Copy mGBA's current save image into the stable mirror rcheevos reads.
- (void)refreshSaveRAMMirror {
    if (!romLoaded || !saveRAMMirror) {
        return;
    }
    size_t size = 0;
    const void *save = core->getMemoryBlock(core, GBA_REGION_SRAM_MIRROR, &size);
    size_t copied = save ? MIN(size, kPVmGBASaveRAMMirrorSize) : 0;
    if (copied > 0) {
        memcpy(saveRAMMirror, save, copied);
    }
    memset(saveRAMMirror + copied, 0, kPVmGBASaveRAMMirrorSize - copied);
}

- (BOOL)isSaveStateLoadBlocked {
    BOOL (^handler)(void) = self.saveStateLoadBlockedHandler;
    return handler ? handler() : NO;
}

- (void)resetEmulation {
    core->reset(core);
}

- (void)setupEmulation {

}

#pragma mark - Video

- (CGSize)aspectSize {
    return CGSizeMake(3, 2);
}

- (CGRect)screenRect {
    core->currentVideoSize(core, &width, &height);
    return CGRectMake(0, 0, width, height);
}

- (CGSize)bufferSize {
    core->currentVideoSize(core, &width, &height);
    return CGSizeMake(width, height);
}

- (void *)videoBuffer { return [self getVideoBufferWithHint:nil]; }

- (const void *)getVideoBufferWithHint:(void *)hint {
    CGSize bufferSize = [self bufferSize];

    if (!hint) {
        hint = outputBuffer;
    }

    outputBuffer = hint;
    core->setVideoBuffer(core, hint, bufferSize.width);

    return hint;
}

- (GLenum)pixelFormat { return GL_RGBA; }
- (GLenum)internalPixelFormat { return GL_RGBA; }

- (GLenum)pixelType {
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    return GL_UNSIGNED_INT_8_8_8_8_REV;
#else
    return GL_UNSIGNED_BYTE;
#endif
}

- (NSTimeInterval)frameInterval {
    return core->frequency(core) / (double) core->frameCycles(core);
}

#pragma mark - Audio

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return kPVmGBAOutputSampleRate;
}

- (NSUInteger)audioBitDepth {
    return 16; // Int16 samples
}

#pragma mark - Save State

- (NSData *)serializeStateWithError:(NSError **)outError
{
    struct VFile* vf = VFileMemChunk(nil, 0);
    if (!mCoreSaveStateNamed(core, vf, SAVESTATE_SAVEDATA)) {
        if (outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotSaveState userInfo:nil];
        }
        vf->close(vf);
        return nil;
    }
    size_t size = vf->size(vf);
    void* data = vf->map(vf, size, MAP_READ);
    NSData *nsdata = [NSData dataWithBytes:data length:size];
    vf->unmap(vf, data, size);
    vf->close(vf);
    return nsdata;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
    // Hardcore mode: save-state loads are disallowed while achievements are active.
    if ([self isSaveStateLoadBlocked]) {
        if (outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                           code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                       userInfo:@{NSLocalizedDescriptionKey: @"Save state loading is disabled in RetroAchievements Hardcore Mode."}];
        }
        return NO;
    }

    struct VFile* vf = VFileFromConstMemory(state.bytes, state.length);
    if (!mCoreLoadStateNamed(core, vf, SAVESTATE_SAVEDATA)) {
        if (outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:nil];
        }
        vf->close(vf);
        return NO;
    }
    vf->close(vf);
    return YES;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    struct VFile* vf = VFileOpen([fileName fileSystemRepresentation], O_CREAT | O_TRUNC | O_RDWR);
    BOOL success = mCoreSaveStateNamed(core, vf, SAVESTATE_SAVEDATA | SAVESTATE_RTC);
    if(!success) {
        NSError *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                             code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                         userInfo:@{
            NSLocalizedDescriptionKey : @"mGBA could not save the current state.",
            NSFilePathErrorKey : fileName
        }];
        block(error);
    } else {
        block(nil);
    }
    vf->close(vf);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    // Hardcore mode: save-state loads are disallowed while achievements are active.
    if ([self isSaveStateLoadBlocked]) {
        NSError *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                            code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                        userInfo:@{
            NSLocalizedDescriptionKey : @"Save state loading is disabled in RetroAchievements Hardcore Mode.",
            NSFilePathErrorKey : fileName
        }];
        block(error);
        return;
    }

    struct VFile* vf = VFileOpen([fileName fileSystemRepresentation], O_RDONLY);
    BOOL success = mCoreLoadStateNamed(core, vf, SAVESTATE_RTC);
    if(!success) {
        NSError *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                             code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                         userInfo:@{
            NSLocalizedDescriptionKey : @"mGBA could not load the current state.",
            NSFilePathErrorKey : fileName
        }];
        block(error);
    } else {
        block(nil);
    }
    vf->close(vf);
}

#pragma mark - RetroAchievements memory

- (void *)iwramPointer:(NSUInteger *)sizeOut {
    return [self memoryBlock:GBA_REGION_IWRAM size:sizeOut];
}

- (void *)ewramPointer:(NSUInteger *)sizeOut {
    return [self memoryBlock:GBA_REGION_EWRAM size:sizeOut];
}

- (void *)saveRAMMirrorPointer:(NSUInteger *)sizeOut {
    BOOL available = romLoaded && saveRAMMirror;
    if (sizeOut) {
        *sizeOut = available ? kPVmGBASaveRAMMirrorSize : 0;
    }
    return available ? saveRAMMirror : NULL;
}

/// IWRAM and EWRAM are mapped once when the core is created and freed only in
/// `core->deinit`, so the pointers survive reset and state loads.
- (void *)memoryBlock:(size_t)region size:(NSUInteger *)sizeOut {
    size_t size = 0;
    void *block = romLoaded ? core->getMemoryBlock(core, region, &size) : NULL;
    if (sizeOut) {
        *sizeOut = block ? (NSUInteger)size : 0;
    }
    return block;
}

#pragma mark - Input

- (oneway void)didPushGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player {
    UNUSED(player);
    core->addKeys(core, 1 << GBAMap[button]);
}

- (oneway void)didReleaseGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player {
    UNUSED(player);
    core->clearKeys(core, 1 << GBAMap[button]);
}

#pragma mark - Cheats

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];

    NSString *codeId = [code stringByAppendingFormat:@"/%@", type];
    struct mCheatSet* cheatSet = [[cheatSets objectForKey:codeId] pointerValue];
    if (cheatSet) {
        cheatSet->enabled = enabled;
        return YES;
    }
    struct mCheatDevice* cheats = core->cheatDevice(core);
    if (!cheats) {
        return NO;
    }
    cheatSet = cheats->createSet(cheats, [codeId UTF8String]);
    if (!cheatSet) {
        return NO;
    }
    size_t size = mCheatSetsSize(&cheats->cheats);
    if (size) {
        cheatSet->copyProperties(cheatSet, *mCheatSetsGetPointer(&cheats->cheats, size - 1));
    }
    int codeType = GBA_CHEAT_AUTODETECT;
    NSArray *codeSet = [code componentsSeparatedByString:@"+"];
    for (id c in codeSet) {
        mCheatAddLine(cheatSet, [c UTF8String], codeType);
    }
    cheatSet->enabled = enabled;
    [cheatSets setObject:[NSValue valueWithPointer:cheatSet] forKey:codeId];
    mCheatAddSet(cheats, cheatSet);
    return YES;
}

- (void)resetCheatCodes
{
    struct mCheatDevice* cheats = core->cheatDevice(core);
    if (cheats) {
        mCheatDeviceClear(cheats);
    }
    [cheatSets removeAllObjects];
}

@end

static void _audioLowPassFilter(int16_t* buffer, int count) {
    int16_t* out = buffer;

    /* Restore previous samples */
    int32_t audioLowPassLeft = audioLowPassLeftPrev;
    int32_t audioLowPassRight = audioLowPassRightPrev;

    /* Single-pole low-pass filter (6 dB/octave) */
    int32_t factorA = audioLowPassRange;
    int32_t factorB = 0x10000 - factorA;

    int samples;
    for (samples = 0; samples < count; ++samples) {
        /* Apply low-pass filter */
        audioLowPassLeft = (audioLowPassLeft * factorA) + (out[0] * factorB);
        audioLowPassRight = (audioLowPassRight * factorA) + (out[1] * factorB);

        /* 16.16 fixed point */
        audioLowPassLeft  >>= 16;
        audioLowPassRight >>= 16;

        /* Update outputs */
        out[0] = (int16_t) audioLowPassLeft;
        out[1] = (int16_t) audioLowPassRight;

        out += 2;
    }

    /* Store last samples for next frame */
    audioLowPassLeftPrev = audioLowPassLeft;
    audioLowPassRightPrev = audioLowPassRight;
}
