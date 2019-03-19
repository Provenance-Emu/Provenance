/*
 Copyright (c) 2009, OpenEmu Team
 

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

#import "PVYabauseGameCore.h"

@import OpenGLES.ES2;
@import PVSupport;
#import <PVSupport/PVSupport-Swift.h>
#import <PVYabause/PVYabause-Swift.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
@import Yabause;


u32 *videoBuffer = NULL;

yabauseinit_struct yinit;
PerPad_struct *c1, *c2 = NULL;
BOOL firstRun = YES;

// Global variables because the callbacks need to access them...
static OERingBuffer *ringBuffer;

PVYabauseGameCore * __weak _current;

#pragma mark -
#pragma mark OpenEmu SNDCORE for Yabause

#ifndef SNDOE_H
#define SNDOE_H
#define SNDCORE_OE   11
#endif

#define BUFFER_LEN 65536

@interface PVYabauseGameCore()
- (void)initYabauseWithCDCore:(int)cdcore;
- (void)setupEmulation;
- (void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
@end

static int SNDOEInit(void)
{
    return 0;
}

static void SNDOEDeInit(void)
{
}

static int SNDOEReset(void)
{
    return 0;
}

static int SNDOEChangeVideoFormat(UNUSED int vertfreq)
{
    return 0;
}

static void sdlConvert32uto16s(s32 *srcL, s32 *srcR, s16 *dst, u32 len) {
    u32 i;
    
    for (i = 0; i < len; i++)
    {
        // Left Channel
        if (*srcL > 0x7FFF)
            *dst = 0x7FFF;
        else if (*srcL < -0x8000)
            *dst = -0x8000;
        else
            *dst = *srcL;
        srcL++;
        dst++;
        
        // Right Channel
        if (*srcR > 0x7FFF)
            *dst = 0x7FFF;
        else if (*srcR < -0x8000)
            *dst = -0x8000;
        else
            *dst = *srcR;
        srcR++;
        dst++;
    }
}

static void SNDOEUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples)
{
    static unsigned char buffer[BUFFER_LEN];
    sdlConvert32uto16s((s32*)leftchanbuffer, (s32*)rightchanbuffer, (s16*)buffer, num_samples);
    
    [ringBuffer write:buffer maxLength:num_samples << 2];
}

static u32 SNDOEGetAudioSpace(void)
{
    return ([ringBuffer usedBytes] >> 2);
}

void SNDOEMuteAudio()
{
}

void SNDOEUnMuteAudio()
{
}

void SNDOESetVolume(UNUSED int volume)
{
}

SoundInterface_struct SNDOE = {
    SNDCORE_OE,
    "Provenance Sound Interface",
    SNDOEInit,
    SNDOEDeInit,
    SNDOEReset,
    SNDOEChangeVideoFormat,
    SNDOEUpdateAudio,
    SNDOEGetAudioSpace,
    SNDOEMuteAudio,
    SNDOEUnMuteAudio,
    SNDOESetVolume
};

#pragma mark -
#pragma mark Yabause Structs

M68K_struct *M68KCoreList[] = {
    &M68KDummy,
    &M68KC68K,
    NULL
};

SH2Interface_struct *SH2CoreList[] = {
    &SH2Interpreter,
    &SH2DebugInterpreter,
    NULL
};

PerInterface_struct *PERCoreList[] = {
    &PERDummy,
//    &PERMacJoy,
    NULL
};

CDInterface *CDCoreList[] = {
    &DummyCD,
    &ISOCD,
    NULL
};

SoundInterface_struct *SNDCoreList[] = {
    &SNDDummy,
    //&SNDMac,
    &SNDOE,
    NULL
};

VideoInterface_struct *VIDCoreList[] = {
    //&VIDDummy,
#ifdef HAVE_LIBGL
    &VIDOGL,
#endif
    &VIDSoft,
    NULL
};

#pragma mark -
#pragma mark OE Core Implementation

@implementation PVYabauseGameCore (ObjC)

- (id)init
{
    DLOG(@"Yabause init /debug");
    self = [super init];
    if(self != nil)
    {
        videoBuffer = (u32 *)calloc(sizeof(u32), PVYabauseGameCore.HIRES_WIDTH * PVYabauseGameCore.HIRES_HEIGHT);
        ringBuffer = [self ringBufferAtIndex:0];
        _current = self;
    }
    return self;
}

- (void)setupEmulation
{
    self.width = PVYabauseGameCore.HIRES_WIDTH;
    self.height = PVYabauseGameCore.HIRES_HEIGHT;
    
    PerPortReset();
    c1 = PerPadAdd(&PORTDATA1);
    c2 = PerPadAdd(&PORTDATA2);
}

- (void)dealloc
{
    YabauseDeInit();
    free(videoBuffer);
}

- (const void *)videoBuffer
{
    return videoBuffer;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    self.filename = [path copy];
	DLOG(@"Saturn - %@", filename);
    [self setupEmulation];
    return YES;
}

- (BOOL)saveStateToFileAtPath: (NSString *) path error:(NSError**)error {
    int saveError = 0;
    @synchronized(self) {
        ScspMuteAudio(SCSP_MUTE_SYSTEM);
        saveError = YabSaveState([path UTF8String]);
        ScspUnMuteAudio(SCSP_MUTE_SYSTEM);
    }

//    NSDictionary *userInfo = @{
//                               NSLocalizedDescriptionKey: @"Failed to save state.",
//                               NSLocalizedFailureReasonErrorKey: @"Stella does not support save states.",
//                               NSLocalizedRecoverySuggestionErrorKey: @"Check for future updates on ticket #753."
//                               };
//
//    NSError *newError = [NSError errorWithDomain:EmulatorCoreErrorCodeDomain
//                                            code:EmulatorCoreErrorCodeCouldNotSaveState
//                                        userInfo:userInfo];
//
//    *error = newError;

	return saveError;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError**)error {
	ScspMuteAudio(SCSP_MUTE_SYSTEM);
	int loadError = YabLoadState([path UTF8String]);
	ScspUnMuteAudio(SCSP_MUTE_SYSTEM);

	return loadError;
}

- (BOOL)supportsSaveStates {
    return YES;
}

#pragma mark -
#pragma mark Inputs

- (oneway void)didPushSaturnButton:(PVSaturnButton)button forPlayer:(NSUInteger)player
{
	PerPad_struct *c = player == 0 ? c1 : c2;
    switch (button)
    {
        case PVSaturnButtonUp:
            PerPadUpPressed(c);
            break;
        case PVSaturnButtonDown:
            PerPadDownPressed(c);
            break;
        case PVSaturnButtonLeft:
            PerPadLeftPressed(c);
            break;
        case PVSaturnButtonRight:
            PerPadRightPressed(c);
            break;
        case PVSaturnButtonStart:
            PerPadStartPressed(c);
            break;
        case PVSaturnButtonL:
            PerPadLTriggerPressed(c);
            break;
        case PVSaturnButtonR:
            PerPadRTriggerPressed(c);
            break;
        case PVSaturnButtonA:
            PerPadAPressed(c);
            break;
        case PVSaturnButtonB:
            PerPadBPressed(c);
            break;
        case PVSaturnButtonC:
            PerPadCPressed(c);
            break;
        case PVSaturnButtonX:
            PerPadXPressed(c);
            break;
        case PVSaturnButtonY:
            PerPadYPressed(c);
            break;
        case PVSaturnButtonZ:
            PerPadZPressed(c);
            break;
        default:
            break;
    }
}

- (oneway void)didReleaseSaturnButton:(PVSaturnButton)button forPlayer:(NSUInteger)player
{
	PerPad_struct *c = player == 0 ? c1 : c2;
    switch (button)
    {
        case PVSaturnButtonUp:
            PerPadUpReleased(c);
            break;
        case PVSaturnButtonDown:
            PerPadDownReleased(c);
            break;
        case PVSaturnButtonLeft:
            PerPadLeftReleased(c);
            break;
        case PVSaturnButtonRight:
            PerPadRightReleased(c);
            break;
        case PVSaturnButtonStart:
            PerPadStartReleased(c);
            break;
        case PVSaturnButtonL:
            PerPadLTriggerReleased(c);
            break;
        case PVSaturnButtonR:
            PerPadRTriggerReleased(c);
            break;
        case PVSaturnButtonA:
            PerPadAReleased(c);
            break;
        case PVSaturnButtonB:
            PerPadBReleased(c);
            break;
        case PVSaturnButtonC:
            PerPadCReleased(c);
            break;
        case PVSaturnButtonX:
            PerPadXReleased(c);
            break;
        case PVSaturnButtonY:
            PerPadYReleased(c);
            break;
        case PVSaturnButtonZ:
            PerPadZReleased(c);
            break;
        default:
            break;
    }
}

#ifdef HAVE_LIBGL
-(BOOL)rendersToOpenGL
{
    return YES;
}
#endif

- (void)executeFrame
{
    if(firstRun) {
        DLOG(@"Yabause executeFrame firstRun, lazy init");
        [self initYabauseWithCDCore:CDCORE_DUMMY];
        [self startYabauseEmulation];
        firstRun = NO;
    }
    else {
        [self.videoLock lock];
        ScspUnMuteAudio(SCSP_MUTE_SYSTEM);
        YabauseExec();
        ScspMuteAudio(SCSP_MUTE_SYSTEM);
        [self.videoLock unlock];
    }
}

#pragma mark -
#pragma mark Yabause Callbacks

void YuiErrorMsg(const char *string)
{
    DLOG(@"Yabause Error %@", [NSString stringWithUTF8String:string]);
}

void YuiSwapBuffers(void)
{
    updateCurrentResolution();
    for (int i = 0; i < _current.height; i++) {
        memcpy(videoBuffer + i*PVYabauseGameCore.HIRES_WIDTH, dispbuffer + i*_current.width, sizeof(u32) * _current.width);
    }
}

#pragma mark -
#pragma mark Helpers

void updateCurrentResolution(void) {
    int current_width = PVYabauseGameCore.HIRES_WIDTH;
    int current_height = PVYabauseGameCore.HIRES_HEIGHT;
    
    // Avoid calling GetGlSize if Dummy/id=0 is selected
    if (VIDCore && VIDCore->id) {
        VIDCore->GetGlSize(&current_width,&current_height);
    }
	
    _current.width = current_width;
    _current.height = current_height;
}

@end
