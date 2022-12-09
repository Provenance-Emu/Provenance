/*
 Copyright (c) 2013, OpenEmu Team

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

#import "PPSSPPGameCore.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>

#import <PVLibrary/PVLibrary.h>
#import <PVSupport/PVSupport.h>

#include "Common/System/NativeApp.h"
//#include "base/timeutil.h"

#include "Core/Config.h"
#include "Core/CoreParameter.h"
#include "Core/CoreTiming.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/Host.h"
#include "Core/SaveState.h"
#include "Core/System.h"
#include "Common/GraphicsContext.h"
#include "Common/LogManager.h"
#include "Common/GPU/thin3d_create.h"

#define AUDIO_FREQ          44100
#define AUDIO_CHANNELS      2
#define AUDIO_SAMPLES       8192
#define AUDIO_SAMPLESIZE    sizeof(int16_t)
#define AUDIO_BUFFERSIZE   (AUDIO_SAMPLESIZE * AUDIO_CHANNELS * AUDIO_SAMPLES)

#define JIT_MODE IR_JIT // INTERPRETER, JIT, IR_JIT

#define RenderWidth 480
#define RenderHeight 272

@interface PVPPSSPPGameCore () <PVPSXSystemResponderClient>
{
    int16_t *_soundBuffer;
    CoreParameter _coreParam;
    bool _isInitialized;
    bool _shouldReset;
    float _frameInterval;

    bool loggingEnabled;

    GraphicsContext *graphicsContext;
}
@end

class GLDummyGraphicsContext : public GraphicsContext {
public:
    GLDummyGraphicsContext() {

        extern void CheckGLExtensions();

        CheckGLExtensions();
        draw_ = Draw::T3DCreateGLContext();
    }
    ~GLDummyGraphicsContext() { delete draw_; }

    Draw::DrawContext *GetDrawContext() override {
        return draw_;
    }
private:
    Draw::DrawContext *draw_;
};

@implementation PVPPSSPPGameCore

- (id)init
{
    self = [super init];

    if(self)
    {
        _soundBuffer = (int16_t *)malloc(AUDIO_BUFFERSIZE);
        memset(_soundBuffer, 0, AUDIO_BUFFERSIZE);
    }

    return self;
}

- (void)dealloc
{
    free(_soundBuffer);
}

# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    NSBundle *coreBundle = [NSBundle mainBundle];
    NSString *resourcePath = [coreBundle resourcePath];
    NSString *supportDirectoryPath = self.batterySavesPath;

    // Copy over font files if needed
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fontSourceDirectory = [resourcePath stringByAppendingString:@"/flash0/font/"];
    NSString *fontDestinationDirectory = [supportDirectoryPath stringByAppendingString:@"/font/"];
    NSArray *fontFiles = [fileManager contentsOfDirectoryAtPath:fontSourceDirectory error:nil];
    for(NSString *font in fontFiles)
    {
        NSString *fontSource = [fontSourceDirectory stringByAppendingString:font];
        NSString *fontDestination = [fontDestinationDirectory stringByAppendingString:font];

        [fileManager copyItemAtPath:fontSource toPath:fontDestination error:nil];
    }

    LogManager::Init(&loggingEnabled);

    g_Config.Load("");

    NSString *directoryString      = [supportDirectoryPath stringByAppendingString:@"/"];
    g_Config.currentDirectory      = Path([directoryString cStringUsingEncoding:kCFStringEncodingUTF8]);
    g_Config.defaultCurrentDirectory = Path(directoryString.fileSystemRepresentation);
    g_Config.memStickDirectory     = Path(directoryString.fileSystemRepresentation);
    g_Config.flash0Directory       = Path(directoryString.fileSystemRepresentation);
    g_Config.internalDataDirectory = Path(directoryString.fileSystemRepresentation);
//    g_Config.iGPUBackend           = GPU_BACKEND_OPENGL;
    g_Config.bHardwareTransform = true;

    _coreParam.cpuCore      = CPUCore::JIT_MODE;
    _coreParam.gpuCore      = GPUCORE_GLES;
    _coreParam.enableSound  = true;
//    _coreParam.fileToStart  = path.fileSystemRepresentation;
//    _coreParam.mountIso     = "";
//    _coreParam.startPaused  = false;
    _coreParam.printfEmuLog = false;
    _coreParam.headLess     = false;

    _coreParam.renderWidth  = RenderWidth;
    _coreParam.renderHeight = RenderHeight;
    _coreParam.pixelWidth   = RenderWidth;
    _coreParam.pixelHeight  = RenderHeight;

    return YES;
}

- (void)stopEmulation {
    PSP_Shutdown();

    NativeShutdownGraphics();
    NativeShutdown();

    [super stopEmulation];
}

- (void)resetEmulation {
    _shouldReset = YES;
}

- (void)executeFrame {
    if(!_isInitialized)
    {
        // This is where PPSSPP will look for ppge_atlas.zim
        NSBundle *coreBundle = [NSBundle mainBundle];

        NSString *resourcePath = [[coreBundle resourcePath] stringByAppendingString:@"/"];

//        graphicsContext = new GLDummyGraphicsContext();

//        NativeInit(0, nil, nil, resourcePath.fileSystemRepresentation, nil, false);

        _coreParam.graphicsContext = graphicsContext;
//        _coreParam.thin3d = graphicsContext ? graphicsContext->GetDrawContext() : nullptr;

        NativeInitGraphics(graphicsContext);
    }

    if(_shouldReset)
        PSP_Shutdown();

    if(!_isInitialized || _shouldReset)
    {
        _isInitialized = YES;
        _shouldReset = NO;

        std::string error_string;
        if(!PSP_Init(_coreParam, &error_string))
            NSLog(@"ERROR: %s", error_string.c_str());

        host->BootDone();
		host->UpdateDisassembly();
    }
    u64 cyclesBefore, cyclesAfter;
    cyclesBefore = CoreTiming::GetTicks();

    NativeRender(graphicsContext);

    cyclesAfter = CoreTiming::GetTicks();

    _frameInterval = 1000000/(float)cyclesToUs(cyclesAfter-cyclesBefore);
    if (_frameInterval < 1) _frameInterval = 60;

    int samplesWritten = NativeMix(_soundBuffer, AUDIO_BUFFERSIZE / 4);
    [[self ringBufferAtIndex:0] write:_soundBuffer maxLength:AUDIO_CHANNELS * AUDIO_SAMPLESIZE * samplesWritten];
}

# pragma mark - Video

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

//- (void)executeFrameSkippingFrame:(BOOL)skip
//{
//    dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//
//    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
//}

//- (void)executeFrame
//{
//    [self executeFrameSkippingFrame:NO];
//}

- (CGSize)bufferSize {
    return CGSizeMake(RenderWidth, RenderHeight);
}

- (CGSize)aspectSize {
    return CGSizeMake(16, 9);
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, RenderWidth, RenderHeight);
}

- (NSTimeInterval)frameInterval {
    return _frameInterval ?: 60;
}

- (BOOL)rendersToOpenGL {
    return YES;
}

//- (BOOL)isDoubleBuffered {
//    return YES;
//}

- (const void *)videoBuffer {
    return NULL;
}

- (GLenum)pixelFormat {
    return GL_BGRA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

# pragma mark - Audio

- (NSUInteger)channelCount {
    return AUDIO_CHANNELS;
}

- (double)audioSampleRate {
    return AUDIO_FREQ;
}

# pragma mark - Save States

static void _PVSaveStateCallback(bool status, std::string message, void *cbUserData)
{
    void (^block)(BOOL, NSError *) = (__bridge_transfer void(^)(BOOL, NSError *))cbUserData;
    
    block(status, nil);
}

- (BOOL)supportsSaveStates { return NO; }

- (BOOL)supportsRumble { return YES; }

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
//    SaveState::Save(Path(fileName.fileSystemRepresentation), _PVSaveStateCallback, (__bridge_retained void *)[block copy]);
    if(_isInitialized) SaveState::Process();
}


- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
//    SaveState::Load(fileName.fileSystemRepresentation, _PVSaveStateCallback, (__bridge_retained void *)[block copy]);
    if(_isInitialized) SaveState::Process();
}

# pragma mark - Input

const int buttonMap[] = { CTRL_UP, CTRL_DOWN, CTRL_LEFT, CTRL_RIGHT, 0, 0, 0, 0, CTRL_TRIANGLE, CTRL_CIRCLE, CTRL_CROSS, CTRL_SQUARE, CTRL_LTRIGGER, CTRL_RTRIGGER, CTRL_START, CTRL_SELECT };

- (oneway void)didMovePSPJoystickDirection:(PVPSPButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player
{
//    if(button == PVPSPButtonLeftAnalogUp || button == PVPSPButtonLeftAnalogDown)
//        __CtrlSetAnalogY(button == PVPSPButtonLeftAnalogUp ? value : -value);
//    else
//        __CtrlSetAnalogX(button == PVPSPButtonLeftAnalogRight ? value : -value);
}

-(oneway void)didPushPSPButton:(PVPSPButton)button forPlayer:(NSInteger)player
{
    __CtrlButtonDown(buttonMap[button]);
}

- (oneway void)didReleasePSPButton:(PVPSPButton)button forPlayer:(NSInteger)player
{
    __CtrlButtonUp(buttonMap[button]);
}

@end
