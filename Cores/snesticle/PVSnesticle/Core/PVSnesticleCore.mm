#import "PVSnesticleCore.h"
#import <PVSupport/OERingBuffer.h>
#import <PVLogging/PVLogging.h>
#import <PVSupport/PVSupport-Swift.h>

//#import <PVSupport/PVGameControllerUtilities.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#include <pthread.h>

#define WIDTH 256
#define HEIGHT 224
#define SNES_HEIGHT_EXTENDED    239
#define MAX_SNES_WIDTH          (WIDTH * 2)
#define MAX_SNES_HEIGHT         (SNES_HEIGHT_EXTENDED * 2)

#define SAMPLERATE      48000
#define SIZESOUNDBUFFER SAMPLERATE / 50 * 4

static __weak PVSnesticleCore *_current;

@interface PVSnesticleCore () {

@public
    UInt16        *soundBuffer;
    unsigned char *videoBuffer;
    unsigned char *videoBufferA;
    unsigned char *videoBufferB;
    NSMutableDictionary *cheatList;
}

@end

NSString *SNESEmulatorKeys[] = { @"Up", @"Down", @"Left", @"Right", @"A", @"B", @"X", @"Y", @"L", @"R", @"Start", @"Select", nil };

@implementation PVSnesticleCore

- (id)init
{
	if ((self = [super init]))
	{
        if(soundBuffer) free(soundBuffer);
		soundBuffer = (UInt16 *)malloc(SIZESOUNDBUFFER * sizeof(UInt16));
		memset(soundBuffer, 0, SIZESOUNDBUFFER * sizeof(UInt16));
        _current = self;
        cheatList = [[NSMutableDictionary alloc] init];
    }
	
	return self;
}

- (void)dealloc
{
    free(videoBufferA);
    videoBufferA = NULL;
    free(videoBufferB);
    videoBufferB = NULL;
    videoBuffer = NULL;
    free(soundBuffer);
    soundBuffer = NULL;
}

#pragma mark Execution

- (void)resetEmulation
{
}

- (void)stopEmulation
{
    [super stopEmulation];
}

- (void)executeFrame
{
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error
{


    if (videoBuffer)
        {
        free(videoBuffer);
        }
    
    if (videoBufferA)
        {
        free(videoBufferA);
        }

    if (videoBufferB)
        {
        free(videoBufferB);
        }

    videoBuffer = NULL;

    videoBufferA = (unsigned char *)malloc(MAX_SNES_WIDTH * MAX_SNES_HEIGHT * sizeof(uint16_t));
    videoBufferB = (unsigned char *)malloc(MAX_SNES_WIDTH * MAX_SNES_HEIGHT * sizeof(uint16_t));

    DLOG(@"loading %@", path);

	if(error != NULL) {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: @"Failed to load game.",
                               NSLocalizedFailureReasonErrorKey: @"Snes9x failed to load ROM.",
                               NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format Snes9x supports."
                               };
    
    NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                            code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                        userInfo:userInfo];
    
    *error = newError;
	}
    return NO;
}

#pragma mark Video

- (void)swapBuffers
{
}

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
	return CGSizeMake(WIDTH * (8.0/7.0), HEIGHT);
}

- (CGSize)bufferSize
{
    return CGSizeMake(MAX_SNES_WIDTH, MAX_SNES_HEIGHT);
}

- (GLenum)pixelFormat
{
    return GL_RGB;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB;
}

- (NSTimeInterval)frameInterval
{
    return false ? 50 : 60; // for more "accuracy" does 50.007 : 60.098806 make a difference?
}

- (BOOL)isDoubleBuffered
{
    return NO;
}

#pragma mark Audio

- (double)audioSampleRate
{
    return SAMPLERATE;
}

- (NSUInteger)channelCount
{
    return 2;
}

#pragma mark Save States
- (BOOL)supportsSaveStates { return NO; }

- (BOOL)saveStateToFileAtPath: (NSString *) fileName error:(NSError**)error  
{
    @synchronized(self) {
    }
}

- (BOOL)loadStateFromFileAtPath: (NSString *) fileName error:(NSError**)error
{
    @synchronized(self) {
    }
}

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled  error:(NSError**)error
{
    return false;
}


#pragma mark - Input

- (void)didPushSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player
{
}

- (void)didReleaseSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player
{
}

- (void)updateControllers
{

}

@end
