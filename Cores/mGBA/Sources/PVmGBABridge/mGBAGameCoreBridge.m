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

//#include <mgba/core/blip_buf.h>
#include <mgba/core/core.h>
#include <mgba/core/cheats.h>
#include <mgba/core/serialize.h>
#include <mgba/gba/core.h>
#include <mgba/internal/gba/cheats.h>
#include <mgba/internal/gba/input.h>
#include <mgba-util/audio-buffer.h>
#include <mgba-util/circle-buffer.h>
#include <mgba-util/memory.h>
#include <mgba-util/vfs.h>

#define SAMPLES_PER_FRAME_MOVING_AVG_ALPHA (1.0f / 180.0f)
static void _audioLowPassFilter(int16_t* buffer, int count);

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

const char* const binaryName = "mGBA";
const char* const projectName = "Provenance EMU";
const char* const projectVersion = "3.0.0";

@interface PVmGBAGameCoreBridge () <PVGBASystemResponderClient> {
    struct mCore* core;
    void* outputBuffer;
    NSMutableDictionary *cheatSets;
    float audioSamplesPerFrameAvg;
    size_t audioSampleBufferSize;
    int16_t *audioSampleBuffer;
    BOOL audioLowPassEnabled;
    unsigned width, height;
    struct mAVStream stream;
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
        // TODO: Make a core option
        audioLowPassEnabled = true;
    }
    
    return self;
}

- (void)dealloc {
    mCoreConfigDeinit(&core->config);
    if (audioSampleBuffer) {
        free(audioSampleBuffer);
        audioSampleBuffer = NULL;
    }
    audioSampleBufferSize = 0;
    audioSamplesPerFrameAvg = 0.0f;
    core->deinit(core);
    free(outputBuffer);
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
    
    /// Setup video buffer
    unsigned width, height;
    core->currentVideoSize(core, &width, &height);
    outputBuffer = malloc(width * height * BYTES_PER_PIXEL);
    core->setVideoBuffer(core, outputBuffer, width);
    
    /// Setup audo buffer
    /* Set initial output audio buffer size
     * to nominal number of samples per frame.
     * Buffer will be resized as required in
     * retro_run(). */
    size_t audioSamplesPerFrame = (size_t)((float) core->audioSampleRate(core) * (float) core->frameCycles(core) /
                                           (float)core->frequency(core));
    audioSampleBufferSize  = ceil(audioSamplesPerFrame) * 2;
    audioSampleBuffer = malloc(audioSampleBufferSize * sizeof(int16_t));
    audioSamplesPerFrameAvg = (float) audioSamplesPerFrame;
    /* Internal audio buffer size should be
     * audioSamplesPerFrame, but number of samples
     * actually generated varies slightly on a
     * frame-by-frame basis. We therefore allow
     * for some wriggle room by setting double
     * what we need (accounting for the hard
     * coded blip buffer limit of 0x4000). */
    size_t internalAudioBufferSize = audioSamplesPerFrame * 2;
    if (internalAudioBufferSize > 0x4000) {
        internalAudioBufferSize = 0x4000;
    }
    stream.videoDimensionsChanged = NULL;
    stream.postAudioFrame = NULL;
    stream.postAudioBuffer = NULL;
    stream.postVideoFrame = NULL;
    //    stream.audioRateChanged = _audioRateChanged;

    core->setAudioBufferSize(core, internalAudioBufferSize);
    core->setAVStream(core, &stream);
        
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
    return YES;
}

- (void)executeFrame {
    core->runFrame(core);
    
    core->currentVideoSize(core, &width, &height);
    
    int available = 0;
    
    
    // Old open emu code, needs their blitter code injected into core function pointers
    //	available = blip_samples_avail(core->getAudioChannel(core, 0));
    //	blip_read_samples(core->getAudioChannel(core, 0), samples, available, true);
    //	blip_read_samples(core->getAudioChannel(core, 1), samples + 1, available, true);
    
    struct mAudioBuffer* buffer = core->getAudioBuffer(core);
    int samplesAvail = mAudioBufferAvailable(buffer);
    if (samplesAvail > 0) {
        /* Update 'running average' of number of
         * samples per frame.
         * Note that this is not a true running
         * average, but just a leaky-integrator/
         * exponential moving average, used because
         * it is simple and fast (i.e. requires no
         * window of samples). */
        audioSamplesPerFrameAvg = (SAMPLES_PER_FRAME_MOVING_AVG_ALPHA * (float)samplesAvail) +
        ((1.0f - SAMPLES_PER_FRAME_MOVING_AVG_ALPHA) * audioSamplesPerFrameAvg);
        size_t samplesToRead = (size_t)(audioSamplesPerFrameAvg);
        /* Resize audio output buffer, if required */
        if (audioSampleBufferSize < (samplesToRead * 2)) {
            audioSampleBufferSize = (samplesToRead * 2);
            audioSampleBuffer     = realloc(audioSampleBuffer, audioSampleBufferSize * sizeof(int16_t));
        }
        int produced = mAudioBufferRead(buffer, audioSampleBuffer, samplesToRead);
        if (produced > 0) {
            if (audioLowPassEnabled) {
                _audioLowPassFilter(audioSampleBuffer, produced);
            }
            //            audioCallback(audioSampleBuffer, (size_t)produced);
            [[self ringBufferAtIndex:0] write:audioSampleBuffer size:produced];
        }
    }
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
    return core->audioSampleRate(core);
    //    return 32768;
}

#pragma mark - Save State

- (NSData *)serializeStateWithError:(NSError **)outError
{
    struct VFile* vf = VFileMemChunk(nil, 0);
    if (!mCoreSaveStateNamed(core, vf, SAVESTATE_SAVEDATA)) {
        if (outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:nil];
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
        NSError *error = nil;
        error = [NSError errorWithDomain:@"org.provenance.GameCore.ErrorDomain"
                                    code:-5
                                userInfo:@{
            NSLocalizedDescriptionKey : @"Jagar Could not load the current state.",
            NSFilePathErrorKey : fileName
        }];
        block(error);
    } else {
        block(nil);
    }
    vf->close(vf);
    return success;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    struct VFile* vf = VFileOpen([fileName fileSystemRepresentation], O_RDONLY);
    BOOL success = mCoreLoadStateNamed(core, vf, SAVESTATE_RTC);
    if(!success) {
        NSError *error = nil;
        error = [NSError errorWithDomain:@"org.provenance.GameCore.ErrorDomain"
                                    code:-5
                                userInfo:@{
            NSLocalizedDescriptionKey : @"Jagar Could not load the current state.",
            NSFilePathErrorKey : fileName
        }];
        block(error);
    } else {
        block(nil);
    }
    vf->close(vf);
    return success;
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

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSString *codeId = [code stringByAppendingFormat:@"/%@", type];
    struct mCheatSet* cheatSet = [[cheatSets objectForKey:codeId] pointerValue];
    if (cheatSet) {
        cheatSet->enabled = enabled;
        return;
    }
    struct mCheatDevice* cheats = core->cheatDevice(core);
    cheatSet = cheats->createSet(cheats, [codeId UTF8String]);
    size_t size = mCheatSetsSize(&cheats->cheats);
    if (size) {
        cheatSet->copyProperties(cheatSet, *mCheatSetsGetPointer(&cheats->cheats, size - 1));
    }
    int codeType = GBA_CHEAT_AUTODETECT;
    // NOTE: This is deprecated and was only meant to test cheats with the UI using cheats-database.xml
    // Will be replaced with a sqlite database in the future.
    //    if ([type isEqual:@"GameShark"]) {
    //        codeType = GBA_CHEAT_GAMESHARK;
    //    } else if ([type isEqual:@"Action Replay"]) {
    //        codeType = GBA_CHEAT_PRO_ACTION_REPLAY;
    //    }
    NSArray *codeSet = [code componentsSeparatedByString:@"+"];
    for (id c in codeSet) {
        //        if ([c length] == 12)
        //            codeType = GBA_CHEAT_CODEBREAKER;
        //        if ([c length] == 16) // default to GS/AR v1/v2 code (can't determine GS/AR v1/v2 vs AR v3 because same length)
        //            codeType = GBA_CHEAT_GAMESHARK;
        mCheatAddLine(cheatSet, [c UTF8String], codeType);
    }
    cheatSet->enabled = enabled;
    [cheatSets setObject:[NSValue valueWithPointer:cheatSet] forKey:codeId];
    mCheatAddSet(cheats, cheatSet);
}
@end


//static struct blip_t* _GBACoreGetAudioChannel(struct mCore* core, int ch) {
//    struct GBA* gba = core->board;
//    switch (ch) {
//    case 0:
//        return gba->audio.psg.left;
//    case 1:
//        return gba->audio.psg.right;
//    default:
//        return NULL;
//    }
//}
/* Audio post processing */
static int32_t audioLowPassRange = (60 * 0x10000) / 100;
static int32_t audioLowPassLeftPrev = 0;
static int32_t audioLowPassRightPrev = 0;
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
        
        /* Update sound buffer */
        out[0] = (int16_t) audioLowPassLeft;
        out[1] = (int16_t) audioLowPassRight;
        out += 2;
    };
    
    /* Save last samples for next frame */
    audioLowPassLeftPrev = audioLowPassLeft;
    audioLowPassRightPrev = audioLowPassRight;
}
