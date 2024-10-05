/*
 Copyright (c) 2017 Provenance Team

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

#if __has_include(<GameController/GameController.h>)
@import GameController;
#endif
@import PVCoreBridge;

#import "PVPokeMiniBridge.h"

#define VIDEO_UPSCALE 1

@import PVLoggingObjC;
@import PVEmulatorCore;
@import PVAudio;
@import PokeMiniC;
@import libpokemini;
@import PVPokeMiniOptions;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX && !TARGET_OS_WATCH
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#elif !TARGET_OS_WATCH
@import OpenGL;
@import GLUT;
#endif

#if __has_include(<AudioToolbox/AudioToolbox.h>)
#import <AudioToolbox/AudioToolbox.h>
#endif

@interface PVPokeMiniBridge ()
{
    uint8_t *audioStream;
    uint32_t *videoBuffer;
    int videoWidth, videoHeight;
    NSString *romPath;
    PokeMFiState controllerState;
}
@end

__weak PVPokeMiniBridge *current;

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSOUNDBUFF	(SOUNDBUFFER*2)

@implementation PVPokeMiniBridge

- (instancetype)init {
    if(self = [super init]) {
//        dispatch_sync(dispatch_get_main_queue(), ^{
        NSInteger videoScale = PVPokeMiniOptions.videoScale;
#if VIDEO_UPSCALE
        self->videoWidth = 96 * videoScale;
        self->videoHeight = 64 * videoScale;
#else
            self.videoWidth = 96;
            self.videoHeight = 64;
#endif

        self->audioStream = malloc(PMSOUNDBUFF);
        self->videoBuffer = malloc(self->videoWidth * self->videoHeight * videoScale);
        memset(self.videoBuffer, 0, self->videoWidth * self->videoHeight * videoScale);
        memset(self->audioStream, 0, PMSOUNDBUFF);
//        });
    }

    current = self;
    return self;
}

- (void)dealloc {
    PokeMini_VideoPalette_Free();
    PokeMini_Destroy();
//    dispatch_sync(dispatch_get_main_queue(), ^{
        if(self->audioStream) free(self->audioStream);
        if(self->videoBuffer) free(self->videoBuffer);
//    });
}

- (void)setVideoSpec {
#if VIDEO_UPSCALE
    NSInteger videoScale = PVPokeMiniOptions.videoScale;
    TPokeMini_VideoSpec *videoSpec;
    switch (videoScale) {
        case 1:
            videoSpec = &PokeMini_Video1x1;
            break;
        case 2:
            videoSpec = &PokeMini_Video2x2;
            break;
        case 3:
            videoSpec = &PokeMini_Video3x3;
            break;
        case 4:
            videoSpec = &PokeMini_Video4x4;
            break;
        case 5:
            videoSpec = &PokeMini_Video5x5;
            break;
        case 6:
            videoSpec = &PokeMini_Video6x6;
            break;
        default:
            videoSpec = &PokeMini_Video1x1;
            break;
    }
    
    if(!PokeMini_SetVideo(videoSpec, 32, CommandLine.lcdfilter, CommandLine.lcdmode))
#else
    if(!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video1x1, 32, CommandLine.lcdfilter, CommandLine.lcdmode))
#endif
    {
        ELOG(@"Couldn't set video spec.");
    }
}

#pragma - mark Execution

- (void)setupEmulation {
    CommandLineInit();
    CommandLine.forcefreebios = 0; // OFF
    CommandLine.eeprom_share = 1;  // OFF (there is no practical benefit to a shared eeprom save
//                                   //      - it just gets full and becomes a nuisance...)
    CommandLine.updatertc = 2;        // Update RTC (0=Off, 1=State, 2=Host)
    CommandLine.joyenabled = 1;    // ON
    CommandLine.lcdfilter = (int) PVPokeMiniOptions.lcdFilter; // 0: None, 1: Dot-Matrix, 2: Scanline
    CommandLine.lcdmode = (int) PVPokeMiniOptions.lcdMode; // LCD Mode (0: analog, 1: 3shades, 2: 2shades)
    CommandLine.lcdcontrast = 64; // LCD contrast
    CommandLine.lcdbright = 0; // LCD brightness offset
    CommandLine.piezofilter = 1; // ON

    CommandLine.palette = (int) PVPokeMiniOptions.palette; // Palette Index (0 - 13; 0 == Default)

    // Set video spec and check if is supported
    [self setVideoSpec];
    
    if(!PokeMini_Create(0, PMSOUNDBUFF)) {
        ELOG(@"Error while initializing emulator.");
    }
    
    NSString *biosPathCopy = [[self BIOSPath] copy];
    NSUInteger length = biosPathCopy.length;
    const char *biosPath = [biosPathCopy fileSystemRepresentation];
    PokeMini_GotoCustomDir(biosPath);
    if(FileExist(CommandLine.bios_file)) {
        PokeMini_LoadBIOSFile(CommandLine.bios_file);
    }

    JoystickSetup("OpenEmu", 0, 30000, NULL, 12, OpenEmu_KeysMapping);

    int enableHighColor = 1;
    PokeMini_VideoPalette_Init(PokeMini_BGR32, enableHighColor);
    PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
    PokeMini_ApplyChanges();
    PokeMini_UseDefaultCallbacks();

    // enable sound
    /*
         MINX_AUDIO_DISABLED = 0,    // Disabled
         MINX_AUDIO_GENERATED,        // Generated (Doesn't require sync)
         MINX_AUDIO_DIRECT,        // Direct from Timer 3
         MINX_AUDIO_EMULATED,        // Emulated
         MINX_AUDIO_DIRECTPWM        // Direct from Timer 3 with PWM support
     */
    MinxAudio_ChangeEngine(MINX_AUDIO_GENERATED);
//    MinxAudio_ChangeEngine(CommandLine.sound);

    [self EEPROMSetup];
}

- (void)EEPROMSetup {
//    PokeMini_CustomLoadEEPROM = loadEEPROM;
//    PokeMini_CustomSaveEEPROM = saveEEPROM;

    NSString *extensionlessFilename = [[self->romPath lastPathComponent] stringByDeletingPathExtension];
    NSString *batterySavesDirectory = [self batterySavesPath];

    MinxIO_FormatEEPROM();
    if([batterySavesDirectory length] != 0) {
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
        
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"eep"]];
        strcpy(CommandLine.eeprom_file, [filePath UTF8String]);

        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            PokeMini_LoadEEPROMFile(CommandLine.eeprom_file);
            ILOG(@"Read EEPROM file %@", filePath);
        }
    } else {
        ELOG(@"Empty battery saves path");
    }
}

// Read EEPROM
int loadEEPROM(const char *filename) {
    FILE *fp;
    
    // Read EEPROM from RAM file
    fp = fopen(filename, "rb");
    if (!fp) return 0;
    fread(EEPROM, 8192, 1, fp);
    fclose(fp);
    
    return 1;
}

// Write EEPROM
int saveEEPROM(const char *filename) {
    FILE *fp;

    // Write EEPROM to RAM file
    fp = fopen(filename, "wb");
    if (!fp) return 0;
    fwrite(EEPROM, 8192, 1, fp);
    fclose(fp);

    return 1;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    self->romPath = path;
    return YES;
}

- (void)executeFrame {
    // Rumble only on first frame that calls for rumble
    static BOOL shouldRumble = YES;
    
    // Emulate 1 frame
    PokeMini_EmulateFrame();
    
    if(PokeMini_Rumbling) {
        // TODO: Fix rumble
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
        if (shouldRumble) {
            [self rumbleWithPlayer:0];
            shouldRumble = NO;
        }
#endif
      
        PokeMini_VideoBlit(self->videoBuffer + PokeMini_GenRumbleOffset((int)self->videoWidth), (int)self->videoWidth);
    }
    else
    {
        shouldRumble = YES;
        PokeMini_VideoBlit(self->videoBuffer, (int)self->videoWidth);
    }
    LCDDirty = 0;
    
    MinxAudio_GetSamplesU8(self->audioStream, PMSOUNDBUFF);
    [[current ringBufferAtIndex:0] write:self->audioStream size:PMSOUNDBUFF];
}

- (void)startEmulation {
//    if(self.rate != 0) return;
#if !TARGET_OS_WATCH
    [self setupController];
#endif
    [self setupEmulation];
    
    [super startEmulation];
    int loadStatus = PokeMini_LoadROM((char*)[self->romPath UTF8String]);
    if (loadStatus != 1) {
        ELOG(@"Failed to load rom")
    }
}

- (void)stopEmulation {
    if (self.isRunning) {
        PokeMini_SaveFromCommandLines(1);

            // Save EEPROM
        if (PokeMini_EEPROMWritten && StringIsSet(CommandLine.eeprom_file)) {
            PokeMini_EEPROMWritten = 0;
            PokeMini_SaveEEPROMFile(CommandLine.eeprom_file);
            ILOG(@"Wrote EEPROM file: %s\n", CommandLine.eeprom_file);
        }
    }
    
    [super stopEmulation];
}

- (void)resetEmulation {
    PokeMini_Reset(1);
}

#pragma mark - Save State

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    BOOL success = PokeMini_SaveSSFile(fileName.fileSystemRepresentation, self->romPath.fileSystemRepresentation);
	if (!success) {
        if(error != nil) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to save state.",
                                       NSLocalizedFailureReasonErrorKey: @"Core failed to create save state.",
                                       NSLocalizedRecoverySuggestionErrorKey: @""
                                       };

            NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                userInfo:userInfo];
            
            *error = newError;
        }
	}
	return success;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error  
{
    BOOL success = PokeMini_LoadSSFile(fileName.fileSystemRepresentation);
	if (!success) {
        if (error != nil) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to save state.",
                                       NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
                                       NSLocalizedRecoverySuggestionErrorKey: @""
                                       };

            NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];

            *error = newError;
        }
	}
	return success;
}

#pragma mark - Video

- (CGSize)aspectSize { return (CGSize){self->videoWidth, self->videoHeight}; }

#if !TARGET_OS_WATCH
- (CGRect)screenRect { return CGRectMake(0, 0, self->videoWidth, self->videoHeight); }

- (CGSize)bufferSize { return CGSizeMake(self->videoWidth, self->videoHeight); }
#endif

- (const void *)videoBuffer { return self->videoBuffer; }

#if !TARGET_OS_WATCH
- (GLenum)pixelFormat { return GL_BGRA; }

- (GLenum)pixelType { return GL_UNSIGNED_BYTE; }

- (GLenum)internalPixelFormat { return GL_RGBA; }
#endif

- (NSTimeInterval)frameInterval { return 72; }

#pragma mark - Audio

- (double)sampleRate { return 44100; }
- (double)audioSampleRate { return 44100; }

- (NSUInteger)audioBitDepth { return 8; }

- (NSUInteger)channelCount { return 1; }

#pragma mark - Input
#if !TARGET_OS_WATCH

- (void)didPushPMButton:(PVPMButton)button forPlayer:(NSInteger)player {
    JoystickButtonsEvent((int)button, 1);
}

- (void)didReleasePMButton:(PVPMButton)button forPlayer:(NSInteger)player {
    JoystickButtonsEvent((int)button, 0);
}

#endif

#if __has_include(<GameController/GameController.h>)

- (void)dpadValueChanged:(GCControllerDirectionPad * _Nonnull)dpad {
    // DPAD
    if (self->controllerState.up != dpad.up.isPressed) {
        JoystickButtonsEvent(PVPMButtonUp, dpad.up.isPressed ? 1 : 0);
        self->controllerState.up = dpad.up.isPressed;
        DLOG(@"Up %@", dpad.up.isPressed ? @"Pressed" : @"Unpressed");
    }
    
    if (self->controllerState.down != dpad.down.isPressed) {
        JoystickButtonsEvent(PVPMButtonDown, dpad.down.isPressed ? 1 : 0);
        self->controllerState.down = dpad.down.isPressed;
        DLOG(@"Down %@", dpad.down.isPressed ? @"Pressed" : @"Unpressed");
    }
    
    if (self->controllerState.left != dpad.left.isPressed) {
        JoystickButtonsEvent(PVPMButtonLeft, dpad.left.isPressed ? 1 : 0);
        self->controllerState.left = dpad.left.isPressed;
        DLOG(@"Left %@", dpad.left.isPressed ? @"Pressed" : @"Unpressed");
    }
    
    if (self->controllerState.right != dpad.right.isPressed) {
        JoystickButtonsEvent(PVPMButtonRight, dpad.right.isPressed ? 1 : 0);
        self->controllerState.right = dpad.right.isPressed;
        DLOG(@"Right %@", dpad.right.isPressed ? @"Pressed" : @"Unpressed");
    }
}

- (void)setupController {
    
    if (self.controller1) {
        if (self.controller1.extendedGamepad) {
            
            __weak PVPokeMiniBridge* weakSelf = self;
            
            self.controller1.extendedGamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
                [weakSelf dpadValueChanged:dpad];
            };
            
            self.controller1.extendedGamepad.valueChangedHandler = ^(GCExtendedGamepad * _Nonnull gamepad, GCControllerElement * _Nonnull element) {
                __strong PVPokeMiniBridge* strongSelf = weakSelf;
                
                // Buttons
                if (element == gamepad.buttonA) {
                    if (strongSelf->controllerState.a != gamepad.buttonA.isPressed) {
                        JoystickButtonsEvent(PVPMButtonA, gamepad.buttonA.isPressed ? 1 : 0);
                        strongSelf->controllerState.a = gamepad.buttonA.isPressed;
                        DLOG(@"A %@", strongSelf.controllerState.a ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.buttonB) {
                    if (strongSelf->controllerState.b != gamepad.buttonB.isPressed) {
                        JoystickButtonsEvent(PVPMButtonB, gamepad.buttonB.isPressed ? 1 : 0);
                        strongSelf->controllerState.b = gamepad.buttonB.isPressed;
                        DLOG(@"B %@", strongSelf.controllerState.b ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.buttonX) {
                    if (strongSelf->controllerState.c != gamepad.buttonX.isPressed) {
                        JoystickButtonsEvent(PVPMButtonC, gamepad.buttonX.isPressed ? 1 : 0);
                        strongSelf->controllerState.c = gamepad.buttonX.isPressed;
                        DLOG(@"C %@", strongSelf.controllerState.c ? @"Pressed" : @"Unpressed");
                    }
                }
                // Extra buttons
                else if (element == gamepad.buttonY) {
                    if (strongSelf->controllerState.menu != gamepad.buttonY.isPressed) {
                        JoystickButtonsEvent(PVPMButtonMenu, gamepad.buttonY.isPressed ? 1 : 0);
                        strongSelf->controllerState.menu = gamepad.buttonY.isPressed;
                    }
                }
                else if (element == gamepad.leftShoulder) {
                    if (strongSelf->controllerState.menu != gamepad.leftShoulder.isPressed) {
                        JoystickButtonsEvent(PVPMButtonMenu, gamepad.leftShoulder.isPressed ? 1 : 0);
                        strongSelf->controllerState.menu = gamepad.leftShoulder.isPressed;
                        DLOG(@"Menu %@", strongSelf.controllerState.menu ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.leftTrigger) {
                    if (strongSelf->controllerState.shake != gamepad.leftTrigger.isPressed) {
                        JoystickButtonsEvent(PVPMButtonShake, gamepad.leftTrigger.isPressed ? 1 : 0);
                        strongSelf->controllerState.shake = gamepad.leftTrigger.isPressed;
                        DLOG(@"Shake %@", strongSelf.controllerState.shake ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.rightShoulder) {
                    if (strongSelf->controllerState.power != gamepad.rightShoulder.isPressed) {
                        JoystickButtonsEvent(PVPMButtonPower, gamepad.rightShoulder.isPressed ? 1 : 0);
                        strongSelf->controllerState.power = gamepad.rightShoulder.isPressed;
                        DLOG(@"Power %@", strongSelf.controllerState.power ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.rightTrigger) {
                    if (strongSelf->controllerState.power != gamepad.rightTrigger.isPressed) {
                        JoystickButtonsEvent(PVPMButtonPower, gamepad.rightTrigger.isPressed ? 1 : 0);
                        strongSelf->controllerState.power = gamepad.rightTrigger.isPressed;
                        DLOG(@"Power %@", strongSelf.controllerState.power ? @"Pressed" : @"Unpressed");
                    }
                }
            };
        }
#if TARGET_OS_TV
        else if ([self.controller1 microGamepad]) {
            GCMicroGamepad *microGamepad = [self.controller1 microGamepad];
            
            __weak PVPokeMiniEmulatorCore* weakSelf = self;
            
            self.controller1.microGamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
                __strong PVPokeMiniEmulatorCore* strongSelf = weakSelf;
                
                [strongSelf dpadValueChanged:dpad];
            };

            
            microGamepad.valueChangedHandler = ^(GCMicroGamepad * _Nonnull gamepad, GCControllerElement * _Nonnull element) {
                __strong PVPokeMiniEmulatorCore* strongSelf = weakSelf;

                // Buttons
                if (element == gamepad.buttonA) {
                    if (strongSelf.controllerState.a != gamepad.buttonA.isPressed) {
                        JoystickButtonsEvent(PVPMButtonA, gamepad.buttonA.isPressed ? 1 : 0);
                        strongSelf.controllerState.a = gamepad.buttonA.isPressed;
                    }
                }
                else if (element == gamepad.buttonX) {
                    if (strongSelf.controllerState.b != gamepad.buttonX.isPressed) {
                        JoystickButtonsEvent(PVPMButtonB, gamepad.buttonX.isPressed ? 1 : 0);
                        strongSelf.controllerState.b = gamepad.buttonX.isPressed;
                    }
                }
            };
        }
#endif
    }
}
#endif

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushPMButton:button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player { 
    [self didReleasePMButton:button forPlayer:player];
}

@synthesize valueChangedHandler;

@end

@implementation PVPokeMiniBridge (Rumble)

- (void)rumbleWithPlayer:(NSUInteger)player {
#warning "Rumble not implemented"
    // Should make a callback handler for Bridge's
}

- (BOOL)supportsRumble {
    return YES;
}

@end
