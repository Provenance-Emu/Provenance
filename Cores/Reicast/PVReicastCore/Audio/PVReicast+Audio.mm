//
//  PVReicast+Audio.m
//  PVReicast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVReicast+Audio.h"
#import "PVReicast+CoreAudio.h"
#import "PVReicast+AudioTypes.h"

#import <PVSupport/PVSupport.h>

#include "oslib/audiobackend_coreaudio.h"

#pragma mark - Reicast Callbacks

#pragma mark Forward Declerations
static void coreaudio_init();
static void coreaudio_term();
static u32 coreaudio_push(void* frame, u32 samples, bool wait);

static u32 coreaudio_push1(void* frame, u32 samples, bool wait);
static u32 coreaudio_push2(void* frame, u32 samples, bool wait);
static u32 coreaudio_push3(void* frame, u32 samples, bool wait);
static u32 coreaudio_push4(void* frame, u32 samples, bool wait);
static u32 coreaudio_push5(void* frame, u32 samples, bool wait);
static u32 coreaudio_push6(void* frame, u32 samples, bool wait);
static u32 coreaudio_push7(void* frame, u32 samples, bool wait);
static u32 coreaudio_push8(void* frame, u32 samples, bool wait);

#pragma mark Externed callback struct
audiobackend_t audiobackend_coreaudio = {
    "coreaudio", // Slug
    "Core Audio", // Name
    &coreaudio_init,
    &coreaudio_push,
    &coreaudio_term
};

#pragma mark Implimentations

void coreaudio_init() {
#if COREAUDIO_USE_DEFAULT
        // Handled by the host app
    VLOG(@"Using host app audio graph.");
    return;
#else
        //    GET_CURRENT_OR_RETURN();
        //    [current ringBufferAtIndex:0];
        //
        //    if (settings.aica.GlobalFocus) {
        //        // TODO: Allow background audio?
        //    }
    NSError *error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
    if(error) {
        ELOG(@"Couldn't set av session %@", error.localizedDescription);
    } else {
        ILOG(@"Successfully set audio session to ambient");
    }

    player = {0};

        // build a graph with output unit and set stream format
    CreateMyAUGraph(&player);
    InitAUPlayer(&player);
#endif // COREAUDIO_USE_DEFAULT
}

static void coreaudio_term()
{
    GET_CURRENT_OR_RETURN();
}

static u32 coreaudio_push(void* frame, u32 samples, bool wait)
{
#if CALLBACK_VERSION == 0
    return 1;
#endif

    GET_CURRENT_OR_RETURN(1);

    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
            //        ELOG(@"Ring buffer was nil!");
        return 1;
    }

    if (current.isEmulationPaused) {
        CALOG("Paused, clearing ring buffer.");
        TPCircularBufferClear(&rb->buffer);
        return 1;
    }

#if USE_DIRECTSOUND_THING
    u16* f=(u16*)frame;

    bool w= false;

    for (u32 i = 0; i < samples*2; i++) {
        if (f[i]) {
            w = true;
            break;
        }
    }

    wait &= w;
#endif

        // Fill the buffer and wait for it to empty
#if CALLBACK_VERSION == 1
    return coreaudio_push1(frame, samples, wait);
#elif CALLBACK_VERSION == 2
    return coreaudio_push2(frame, samples, wait);
#elif CALLBACK_VERSION == 3
        // Faster, stutters
    return coreaudio_push3(frame, samples, wait);
#elif CALLBACK_VERSION == 4
    return coreaudio_push4(frame, samples, wait);
#elif CALLBACK_VERSION == 5
    return coreaudio_push5(frame, samples, wait);
#elif CALLBACK_VERSION == 6
    return coreaudio_push6(frame, samples, wait);
#elif CALLBACK_VERSION == 7
    return coreaudio_push7(frame, samples, wait);
#elif CALLBACK_VERSION == 8
    return coreaudio_push8(frame, samples, wait);
#endif
}

#pragma mark - Callback Variations

static inline u32
coreaudio_push1(void* frame, u32 samples, bool wait) {
    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }

        // Results: Too slow
    while (rb.availableBytes == 0 && wait) { }
    [rb write:(const unsigned char *)frame maxLength:samples * 4];

    return 1;
}

static inline u32
coreaudio_push2(void* frame, u32 samples, bool wait) {
    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }
        // Use a sample counter instead of filling the buffer
    while (samples_ptr > rb.bytesWritten && wait) { }
    if(samples_ptr <= rb.bytesWritten) {
        [rb write:(const unsigned char *)frame maxLength:samples * 4];
        samples_ptr += samples * 4;
    }

    return 1;
}

static inline u32
coreaudio_push3(void* frame, u32 samples, bool wait) {
    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }

    NSLog(@"%lu %lu diff: %lu", (unsigned long)samples_ptr, (unsigned long)rb.bytesWritten, (unsigned long)samples_ptr-rb.bytesWritten);

        // Use a sample counter instead of filling the buffer
    while (samples_ptr != 0 && samples_ptr != rb.bytesRead && rb.bytesRead != 0 && wait) { }
    [rb write:(const unsigned char *)frame maxLength:samples * 4];
    samples_ptr += samples * 4;

    return 1;
}

static inline u32
coreaudio_push4(void* frame, u32 samples, bool wait) {
    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }

    while (samples_ptr >= rb.bytesWritten && wait) { }
    if (samples_ptr >= rb.bytesWritten)
        [rb write:(const unsigned char *)frame maxLength:samples * 4];
    samples_ptr += samples * 4;

    return 1;
}

static inline u32
coreaudio_push5(void* frame, u32 samples, bool wait) {
    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }

    if (samples_ptr <= rb.bytesWritten)
        [rb write:(const unsigned char *)frame maxLength:samples * 4];

    samples_ptr += samples * 4;

    while (samples_ptr >= rb.bytesWritten > 0 && wait) { }

    return 1;
}

static inline u32
coreaudio_push6(void* frame, u32 samples, bool wait) {
    static uint clearedCounter = 0;

    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }

    TPCircularBuffer buffer = rb->buffer;
    NSUInteger maxFillSize = clearedCounter > 4 ? samples * 8 : -1;
    CALOG("used bytes: %lu", (unsigned long)buffer.fillCount);
#define notfull [rb write:(const unsigned char *)frame maxLength:samples * 4]

    while ([rb availableBytes] > maxFillSize && wait) {    }

    [rb write:(const unsigned char *)frame maxLength:samples * 4];

        //    dispatch_async(current->_callbackQueue, ^{
        //        [rb write:(const unsigned char *)frame maxLength:samples * 4];
        //    });
    if (buffer.fillCount == 0) {
        clearedCounter++;
    }

    return 1;
}

static inline u32
coreaudio_push7(void* frame, u32 samples, bool wait) {
    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }

        // render into our buffer
    OSStatus inputProcErr = noErr;
    UInt32 inNumberFrames = samples;
    UInt32 inNumberBytes = samples * 4;

    AudioTimeStamp timeStamp = {0};
    FillOutAudioTimeStampWithSampleTime(timeStamp, settings.dreamcast.RTC);

        //write_ptr += inNumberFrames;

        // have we ever logged input timing? (for offset calculation)
    if (player.firstInputSampleTime < 0.0) {
        player.firstInputSampleTime = write_ptr;
        if ((player.firstOutputSampleTime > -1.0) &&
            (player.inToOutSampleTimeOffset < 0.0)) {
            player.inToOutSampleTimeOffset =
            player.firstInputSampleTime - player.firstOutputSampleTime;
        }
    }

        // In order to render continuously, the effect audio unit needs a new time stamp for each buffer
        // Use the number of frames for each unit of time continuously incrementing
        //player.firstInputSampleTime += (double)samples * 4;
        //AudioBufferList ioData = {0};
        //ioData.mNumberBuffers = 1;
        //ioData.mBuffers[0] =
        //ioData.mBuffers[0].mNumberChannels = 2;
        //ioData.mBuffers[0].mDataByteSize = (UInt32)(inNumberBytes);
        //ioData.mBuffers[0].mData = frame;

        //AudioBufferList *bufferList = NULL;
        //UInt32 numBuffers = 1;
        //UInt32 channelsPerBuffer = 2;
        //bufferList = static_cast<AudioBufferList *>(calloc(1, offsetof(AudioBufferList, mBuffers) + (sizeof(AudioBuffer) * numBuffers)));
        //bufferList->mNumberBuffers = numBuffers;
        //
        //for(UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; ++bufferIndex) {
        //    bufferList->mBuffers[bufferIndex].mData = frame; //static_cast<void *>(calloc(capacityFrames, bytesPerFrame));
        //    bufferList->mBuffers[bufferIndex].mDataByteSize = inNumberBytes;
        //    bufferList->mBuffers[bufferIndex].mNumberChannels = 2;
        //}



    CALOG("set %d frames at time %f\n", inNumberFrames, timeStamp.mSampleTime);

    /*
     #define kNumChannels 2
     AudioBufferList *bufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList) * kNumChannels);
     bufferList->mNumberBuffers = kNumChannels; // 2 for stereo, 1 for mono
     for(int i = 0; i < 2; i++) {
     int numSamples = 123456; // Number of sample frames in the buffer
     bufferList->mBuffers[i].mNumberChannels = 1;
     bufferList->mBuffers[i].mDataByteSize = numSamples * sizeof(Float32);
     bufferList->mBuffers[i].mData = (Float32*)malloc(sizeof(Float32) * numSamples);
     }

     // Do stuff...

     for(int i = 0; i < 2; i++) {
     free(bufferList->mBuffers[i].mData);
     }
     free(bufferList);
     */
        //AudioUnitGetProperty(player.graph,
        //                     kAudioUnitProperty_CurrentPlayTime,
        //                     kAudioUnitScope_Global,
        //                     0,
        //                     &ts,
        //                     &size);
        //
        //AudioUnitGetProperty(player.graph,
        //                     kAudioUnitProperty_CurrentPlayTime,
        //                     kAudioUnitScope_Global,
        //                     0,
        //                     (void*)&ts,
        //                     &size);

        //    float freq = 440.f;
        //    int seconds = 4;
        //    unsigned sample_rate = 44100;
        //    size_t buf_size = seconds * sample_rate;
        //
        //    short *staticsamples;
        //    staticsamples = new short[buf_size];
        //    for(int i=0; i<buf_size; ++i) {
        //        staticsamples[i] = 32760 * sin( (2.f*float(M_PI)*freq)/sample_rate * i );
        //    }

        //    memcpy(player.inputBuffer->mBuffers[0].mData, frame, inNumberBytes);


        //    player.inputBuffer->mBuffers[0].mDataByteSize = inNumberBytes;

        //    memcpy(player.inputBuffer->mBuffers[0].mData, frame, inNumberBytes);
    player.inputBuffer->mBuffers[0].mData = frame;
    player.inputBuffer->mBuffers[0].mDataByteSize = inNumberBytes;
    player.inputBuffer->mBuffers[0].mNumberChannels = 2;

        // copy from our buffer to ring buffer
    if (! inputProcErr) {
        inputProcErr = player.ringBuffer->Store(player.inputBuffer,
                                                inNumberFrames,
                                                timeStamp.mSampleTime);
        CALOG("Stored: %i", inputProcErr);
    }

        //    });
    /* Yeah, right */
        //    while (samples_ptr != 0 && wait) ;
        //
        //    if (samples_ptr == 0) {
        //        memcpy(&samples_temp[samples_ptr], frame, samples * 4);
        //        samples_ptr += samples * 4;
        //    }
        //

    return 1;
}

static inline u32
coreaudio_push8(void* frame, u32 samples, bool wait) {
    GET_CURRENT_OR_RETURN(1);
    OERingBuffer *rb = [current ringBufferAtIndex:0];

    if (rb == nil) {
        ELOG(@"Ring buffer was nil!");
        return 1;
    }

    static dispatch_queue_t serialQueue;
    static dispatch_group_t group;
    static CFAbsoluteTime lastTime;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
        serialQueue = dispatch_queue_create("com.provenance.reicase.audio", queueAttributes);

        group = dispatch_group_create();
        lastTime = CFAbsoluteTimeGetCurrent();
    });

//    BOOL fullBuffer = rb.availableBytes < samples / 4;
    static u32 previousSampleCount = 0;
    static const float samplePerSecond = 2.0 * (1.0 / 44100.0);
    static const float bytesPerSample = 2.0;

    int currentAvailable = rb.availableBytes;

    [rb write:(const unsigned char *)frame maxLength:samples * 4];

    if (wait) {
        while ( rb.availableBytes < (currentAvailable + (previousSampleCount * 4))) {

        }
    }

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFTimeInterval deltaTime = now - lastTime;
#if DEBUG
    printf("TimeDelta: %i", deltaTime);
#endif
    /* TODO: Look into what the options here are
 var timestamp = AudioTimeStamp()

 timestamp.mSampleTime = numberOfSamplesRecorded
 timestamp.mFlags = .sampleHostTimeValid

     static var sampleTimeValid: AudioTimeStampFlags
     static var hostTimeValid: AudioTimeStampFlags
     static var rateScalarValid: AudioTimeStampFlags
     static var wordClockTimeValid: AudioTimeStampFlags
     static var smpteTimeValid: AudioTimeStampFlags
 */

//    if (fullBuffer && wait) {
        dispatch_time_t maxWait = dispatch_time( DISPATCH_TIME_NOW, samples / samplePerSecond);
//        dispatch_group_wait(group, maxWait);
//        dispatch_group_enter(group);
//        dispatch_async(serialQueue, ^{
//            // Note, is the frame pointer too volitile if we return early?
//            // should we do a max wait instead of 1 or 2 frames?
            [rb write:(const unsigned char *)frame maxLength:samples * 4];
//            dispatch_group_leave(group);
//        });
//    } else {
//        [rb write:(const unsigned char *)frame maxLength:samples * 4];
//    }

//    if(wait) {
//        float waitTime = samplePerSecond * samples;
//        printf("wait %f", waitTime);
//        [NSThread sleepForTimeInterval:waitTime];
//    }
    previousSampleCount = samples;

    return 1;
}
