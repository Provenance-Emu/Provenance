#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#import <AVFoundation/AVFoundation.h>
#include "common/settings.h"

static const double PVAzahar3DSSampleRate = 32728.0;
static const NSUInteger PVAzaharChannelCount = 2;

@implementation PVAzaharCoreBridge (Audio)

// 3DS native format; azahar's CoreAudio sink owns playback, PV's audio graph is unused.
- (double)audioSampleRate { return PVAzahar3DSSampleRate; }
- (NSUInteger)channelCount { return PVAzaharChannelCount; }

// Volume is host-side: the base bridge exposes no volume property, so there is nothing to override here.

- (void)configureAudioSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryAmbient mode:AVAudioSessionModeDefault options:0 error:&error];
    [session setActive:YES error:&error];
}

@end
