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

#import "PVDuckStation.h"

#import <PVSupport/PVSupport.h>
//#import <PVSupport/OERingBuffer.h>
//#import <PVSupport/DebugUtils.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

//static Mednafen::MDFNGI *game;
//static Mednafen::MDFN_Surface *backBufferSurf;
//static Mednafen::MDFN_Surface *frontBufferSurf;


@interface PVDuckStationCore () <PVPSXSystemResponderClient>
@end

__weak static PVDuckStationCore * _currentCore;

//void DuckStationWriteSoundBuffer(uint8_t *buffer, unsigned int len);

@implementation PVDuckStationCore

- (id)init
{
    if((self = [super init])) {
    }

    _currentCore = self;

    return self;
}

- (void)dealloc {
}

#pragma mark - Execution

-(NSString*) systemIdentifier {
    return @"com.provenance.psx";
}

//-(NSString*)biosDirectoryPath {
//    return self.BIOSPath;
//}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    [[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

}

- (void)executeFrame
{
 
}

- (void)resetEmulation
{
}

- (void)stopEmulation
{
    [super stopEmulation];
}

//- (NSTimeInterval)frameInterval
//{
//    return Atari800_tv_mode == Atari800_TV_NTSC ? Atari800_FPS_NTSC : Atari800_FPS_PAL;
//}

#pragma mark - Video

- (const void *)videoBuffer
{
//    if ( frontBufferSurf == NULL )
//    {
//        return NULL;
//    }
//    else
//    {
//        return frontBufferSurf->pixels;
//    }
}

- (CGSize)bufferSize {
//    if ( game == NULL )
//    {
//        return CGSizeMake(0, 0);
//    }
//    else
//    {
//        return CGSizeMake(game->fb_width, game->fb_height);
//    }
    return self.screenRect.size;
}

- (CGRect)screenRect {
    return CGRectMake(24, 0, 336, 240);
//    return CGRectMake(24, 0, Screen_WIDTH, Screen_HEIGHT);
}

- (CGSize)aspectSize
{
    // TODO: fix PAR
    //return CGSizeMake(336 * (6.0 / 7.0), 240);
    return CGSizeMake(640, 480);
}

- (GLenum)pixelFormat
{
    return GL_RGBA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
    return GL_RGBA;
}

- (BOOL)isDoubleBuffered {
    return YES;
}

- (void)swapBuffers
{
//    Mednafen::MDFN_Surface *tempSurf = backBufferSurf;
//    backBufferSurf = frontBufferSurf;
//    frontBufferSurf = tempSurf;
}

#pragma mark - Audio

- (double)audioSampleRate
{
    return 44100;
}

- (NSUInteger)channelCount
{
    return 1;
}

#pragma mark - Save States
- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    NSAssert(NO, @"Shouldn't be here since we overload the async version");
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    #warning "Placeholder"
    BOOL success = true;

    if (!success) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to save state.",
                                   NSLocalizedFailureReasonErrorKey: @"DuckStation failed to create save state.",
                                   NSLocalizedRecoverySuggestionErrorKey: @""
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                            userInfo:userInfo];
        block(NO, newError);
    } else {
        block(YES, nil);
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    NSAssert(NO, @"Shouldn't be here since we overload the async version");
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    #warning "Placeholder"
    BOOL success = true;
    if (!success) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to save state.",
                                   NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
                                   NSLocalizedRecoverySuggestionErrorKey: @""
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                            userInfo:userInfo];

        block(NO, newError);
    } else {
        block(YES, nil);
    }
}

#pragma mark - Input

- (void)pollControllers {
    NSUInteger maxNumberPlayers = 4; //MIN([self maxNumberPlayers], 4);

    for (NSInteger playerIndex = 0; playerIndex < maxNumberPlayers; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        else if (self.controller3 && playerIndex == 2)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && playerIndex == 3)
        {
            controller = self.controller4;
        }
        
//        if (controller) {
//            uint8 *d8 = (uint8 *)inputBuffer[playerIndex];
//            bool analogMode = (d8[2] & 0x02);
//            
//            for (unsigned i=0; i<maxValue; i++) {
//                
//                if (self.systemType != MednaSystemPSX || i < PVPSXButtonLeftAnalogUp) {
//                    uint32_t value = (uint32_t)[self controllerValueForButtonID:i forPlayer:playerIndex withAnalogMode:analogMode];
//                    
//                    if(value > 0) {
//                        inputBuffer[playerIndex][0] |= 1 << map[i];
//                    } else {
//                        inputBuffer[playerIndex][0] &= ~(1 << map[i]);
//                    }
//                } else if (analogMode) {
//                    float analogValue = [self PSXAnalogControllerValueForButtonID:i forController:controller];
//                    [self didMovePSXJoystickDirection:(PVPSXButton)i
//                                            withValue:analogValue
//                                            forPlayer:playerIndex];
//                }
//            }
//        }
    }
}

@end
