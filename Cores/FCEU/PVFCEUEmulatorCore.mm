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

#import "PVFCEUEmulatorCore.h"

@import PVLoggingObjC;
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

#include "fceux/src/fceu.h"
#include "fceux/src/driver.h"
#include "fceux/src/input.h"
#include "fceux/src/sound.h"
#include "fceux/src/movie.h"
#include "fceux/src/palette.h"
#include "fceux/src/state.h"
#include "fceux/src/emufile.h"
#include "zlib.h"

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

#define WIDTH 256
#define HEIGHT 240

extern uint8 *XBuf;
static uint32_t palette[256];

@interface PVFCEUEmulatorCoreBridge ()
{
    uint32_t *videoBuffer;
    uint8_t *pXBuf;
    int32_t *soundBuffer;
    int32_t soundSize;
    
    NSUInteger currentDisc;
}

@end

@implementation PVFCEUEmulatorCoreBridge

static __weak PVFCEUEmulatorCoreBridge *_current;

- (id)init
{
    if((self = [super init]))
    {
        soundBuffer = nil;
        pXBuf = nil;
        soundSize = 0;
        
        videoBuffer = (uint32_t *)malloc(WIDTH * HEIGHT * 4);
        currentDisc = 1;
    }

	_current = self;

	return self;
}

- (void)dealloc
{
    free(videoBuffer);
}

- (void)internalSwapDisc:(NSUInteger)discNumber
{
    if (discNumber == currentDisc) {
        WLOG(@"Won't swap for same disc number <%lul>", (unsigned long)discNumber);
        return;
    }
    currentDisc = discNumber;
    
    [self setPauseEmulation:NO];

    FCEUI_FDSInsert();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        FCEUI_FDSSelect();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            FCEUI_FDSInsert();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            });
        });
    });
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error
{
    memset(pad, 0, sizeof(uint32_t) * PVNESButtonCount);

    //newppu = 0 default off, set 1 to enable

    FCEUI_Initialize();

    NSURL *batterySavesDirectory = [NSURL fileURLWithPath:[self batterySavesPath]];
    [[NSFileManager defaultManager] createDirectoryAtURL:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    //FCEUI_SetBaseDirectory([[self biosDirectoryPath] UTF8String]); unused for now
    FCEUI_SetDirOverride(FCEUIOD_NV, strdup([[batterySavesDirectory path] UTF8String]));
    FCEUI_SetDirOverride(FCEUIOD_FDSROM, strdup([[self BIOSPath] UTF8String]));

    FCEUI_SetSoundVolume(256);
    FCEUI_Sound(48000);

    FCEUGI *FCEUGameInfo;
    FCEUGameInfo = FCEUI_LoadGame([path UTF8String], 1, false);

    if(!FCEUGameInfo) {
		if(error != NULL) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to load game.",
				NSLocalizedFailureReasonErrorKey: @"FCEUI failed to load game.",
				NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported FCEUI ROM format."
			};

			NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
													code:PVEmulatorCoreErrorCodeCouldNotLoadRom
												userInfo:userInfo];

			*error = newError;
		}
        return NO;
    }

    //DLOG(@"FPS: %d", FCEUI_GetDesiredFPS() >> 24); // Hz

    FCEUI_SetInput(0, SI_GAMEPAD, &pad[0], 0);
    FCEUI_SetInput(1, SI_GAMEPAD, &pad[1], 0);

	// 4 Player
	if (FCEUGameInfo->inputfc == SIFC_4PLAYER) {
		FCEUI_SetInputFourscore(true);
		// This needed?
		//	FCEUI_SetInput(2, SI_GAMEPAD, &pad[2], 0);
		//	FCEUI_SetInput(3, SI_GAMEPAD, &pad[3], 0);
	}

    FCEU_ResetPalette();

    return YES;
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    pXBuf = 0;
    soundSize = 0;

    FCEUI_Emulate(&pXBuf, &soundBuffer, &soundSize, 0);

    pXBuf = XBuf;
    for (unsigned y = 0; y < HEIGHT; y++)
        for (unsigned x = 0; x < WIDTH; x++, pXBuf++)
            videoBuffer[y * WIDTH + x] = palette[*pXBuf];

    for (int i = 0; i < soundSize; i++)
        soundBuffer[i] = (soundBuffer[i] << 16) | (soundBuffer[i] & 0xffff);

    [[self ringBufferAtIndex:0] write:soundBuffer size:soundSize << 2];
}

- (void)resetEmulation
{
    ResetNES();
}

- (void)stopEmulation
{
    FCEUI_CloseGame();
    FCEUI_Kill();

    [super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
    return FCEUI_GetDesiredFPS() / 16777216.0;
}

# pragma mark - Video

- (const void *)videoBuffer
{
    return videoBuffer;
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, WIDTH, HEIGHT);
}

- (CGSize)aspectSize
{
    return CGSizeMake(4, 3);
}

- (CGSize)bufferSize
{
    return CGSizeMake(WIDTH, HEIGHT);
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
    return FSettings.SndRate;
}

- (NSUInteger)channelCount
{
    return 2;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error  
{
    @synchronized(self) {
        FCEUSS_Save([fileName UTF8String], false);
        return YES;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error
{
    @synchronized(self) {
        BOOL success = FCEUSS_Load([fileName UTF8String], false);
		if (!success) {
			if(error != NULL) {
				NSDictionary *userInfo = @{
										   NSLocalizedDescriptionKey: @"Failed to save state.",
										   NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
										   NSLocalizedRecoverySuggestionErrorKey: @""
										   };

				NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
														code:PVEmulatorCoreErrorCodeCouldNotLoadState
													userInfo:userInfo];

				*error = newError;
			}
		}
		return success;
    }
}

- (NSData *)serializeStateWithError:(NSError **)outError
{
    std::vector<u8> byteVector;
    EMUFILE *emuFile = new EMUFILE_MEMORY(&byteVector);
    NSData *data = nil;
    
    if(FCEUSS_SaveMS(emuFile, Z_NO_COMPRESSION))
    {
        const void *bytes = (const void *)(&byteVector[0]);
        NSUInteger length = byteVector.size();
        
        data = [NSData dataWithBytes:bytes length:length];
    }
    
    delete emuFile;
    return data;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
    u8 *bytes = (u8 *)[state bytes];
    size_t length = [state length];
    std::vector<u8> byteVector(bytes, bytes + length);
    EMUFILE *emuFile = new EMUFILE_MEMORY(&byteVector);
    
    BOOL result = FCEUSS_LoadFP(emuFile, SSLOADPARAM_NOBACKUP);
    
    delete emuFile;
    
    return result;
}

#pragma mark - FCEUX internal functions and stubs
void FCEUD_SetPalette(unsigned char index, unsigned char r, unsigned char g, unsigned char b)
{
    palette[index] = ( r << 16 ) | ( g << 8 ) | b;
}

void FCEUD_GetPalette(unsigned char i, unsigned char *r, unsigned char *g, unsigned char *b) {}
uint64 FCEUD_GetTime(void) {return 0;}
uint64 FCEUD_GetTimeFreq(void) {return 0;}
const char *GetKeyboard(void) {return "";}
bool turbo = false;
bool swapDuty = 0; // some Famicom and NES clones had duty cycle bits swapped
int dendy = 0;
int pal_emulation = 0;
int closeFinishedMovie = 0;
int FCEUD_ShowStatusIcon(void) {return 0;}
int FCEUD_SendData(void *data, uint32 len) {return 1;}
int FCEUD_RecvData(void *data, uint32 len) {return 1;}
FILE *FCEUD_UTF8fopen(const char *fn, const char *mode)
{
    return fopen(fn, mode);
}
EMUFILE_FILE *FCEUD_UTF8_fstream(const char *fn, const char *m)
{
#if 0
	std::ios_base::openmode mode = std::ios_base::binary;
    if(!strcmp(m,"r") || !strcmp(m,"rb"))
        mode |= std::ios_base::in;
    else if(!strcmp(m,"w") || !strcmp(m,"wb"))
        mode |= std::ios_base::out | std::ios_base::trunc;
    else if(!strcmp(m,"a") || !strcmp(m,"ab"))
        mode |= std::ios_base::out | std::ios_base::app;
    else if(!strcmp(m,"r+") || !strcmp(m,"r+b"))
        mode |= std::ios_base::in | std::ios_base::out;
    else if(!strcmp(m,"w+") || !strcmp(m,"w+b"))
        mode |= std::ios_base::in | std::ios_base::out | std::ios_base::trunc;
    else if(!strcmp(m,"a+") || !strcmp(m,"a+b"))
        mode |= std::ios_base::in | std::ios_base::out | std::ios_base::app;
	return new std::fstream(fn,mode);
#else
    return new EMUFILE_FILE(fn, m);
#endif
}
void FCEUD_NetplayText(uint8 *text) {}
void FCEUD_NetworkClose(void) {}
void FCEUD_VideoChanged (void) {}
bool FCEUD_ShouldDrawInputAids() {return false;}
bool FCEUD_PauseAfterPlayback() {return false;}
void FCEUI_AviVideoUpdate(const unsigned char* buffer) {}
bool FCEUI_AviEnableHUDrecording() {return false;}
bool FCEUI_AviIsRecording(void) {return false;}
bool FCEUI_AviDisableMovieMessages() {return true;}
FCEUFILE *FCEUD_OpenArchiveIndex(ArchiveScanRecord &asr, std::string &fname, int innerIndex) {return 0;}
FCEUFILE *FCEUD_OpenArchiveIndex(ArchiveScanRecord &asr, std::string &fname, int innerIndex, int* userCancel) {return 0;}
FCEUFILE *FCEUD_OpenArchive(ArchiveScanRecord &asr, std::string &fname, std::string *innerFilename) {return 0;}
FCEUFILE *FCEUD_OpenArchive(ArchiveScanRecord &asr, std::string &fname, std::string *innerFilename, int* userCancel) {return 0;}
ArchiveScanRecord FCEUD_ScanArchive(std::string fname) { return ArchiveScanRecord(); }
void FCEUD_PrintError(const char *s)
{
    ELOG(@"FCEUX: %s", s);
}
void FCEUD_Message(const char *s)
{
    ILOG(@"FCEUX: %s", s);
}

@end
