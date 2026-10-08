#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#import <AVFoundation/AVFoundation.h>
#import <PVAzahar/PVAzahar-Swift.h>
#import <PVLogging/PVLoggingObjC.h>
#include "common/settings.h"

static const double PVAzahar3DSSampleRate = 32728.0;
static const NSUInteger PVAzaharChannelCount = 2;

@implementation PVAzaharCoreBridge (Audio)

// 3DS native format; azahar's CoreAudio sink owns playback, PV's audio graph is unused.
- (double)audioSampleRate { return PVAzahar3DSSampleRate; }
- (NSUInteger)channelCount { return PVAzaharChannelCount; }

// volume/mute: host exposes no bridge hook; follow-up.

/// Same policy as PVCoreAudio's engines: honour the "Respect mute switch" setting.
- (void)configureAudioSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionCategory category = PVAzaharCore.respectsMuteSwitch ? AVAudioSessionCategoryAmbient
                                                                      : AVAudioSessionCategoryPlayback;
    // Only MixWithOthers, like PVCoreAudio: AllowAirPlay/A2DP are rejected (-50) with .ambient/.playback.
    const AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers;
    if (![session setCategory:category mode:AVAudioSessionModeDefault options:options error:&error]) {
        ELOG(@"[PVAzahar] audio session category failed: %@", error);
    }
    if (![session setActive:YES error:&error]) {
        ELOG(@"[PVAzahar] audio session activation failed: %@", error);
    }
}

@end
