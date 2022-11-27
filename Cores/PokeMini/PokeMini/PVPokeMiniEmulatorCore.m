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

#define VIDEO_UPSCALE 1

#import "PVPokeMiniEmulatorCore.h"
@import PVSupport;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#else
@import OpenGL;
@import GLUT;
#endif

#import <AudioToolbox/AudioToolbox.h>
#import "PokeMini.h"
#import "Hardware.h"
#import "Joystick.h"
#import "Video_x1.h"
#import "Video_x4.h"

typedef struct {
    bool a;
    bool b;
    bool c;
    bool up;
    bool down;
    bool left;
    bool right;
    bool menu;
    bool power;
    bool shake;
} PokeMFiState;

@interface PVPokeMiniEmulatorCore ()
{
    uint8_t *audioStream;
    uint32_t *videoBuffer;
    int videoWidth, videoHeight;
    NSString *romPath;
    PokeMFiState controllerState;
}

@end

PVPokeMiniEmulatorCore *current;

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSOUNDBUFF	(SOUNDBUFFER*2)

int OpenEmu_KeysMapping[] =
{
    0,		// Menu
    1,		// A
    2,		// B
    3,		// C
    4,		// Up
    5,		// Down
    6,		// Left
    7,		// Right
    8,		// Power
    9		// Shake
};

@implementation PVPokeMiniEmulatorCore

- (instancetype)init {
    if(self = [super init]) {
#if VIDEO_UPSCALE
        videoWidth = 96 * 4;
        videoHeight = 64 * 4;
#else
        videoWidth = 96;
        videoHeight = 64;
#endif

        audioStream = malloc(PMSOUNDBUFF);
        videoBuffer = malloc(videoWidth*videoHeight*4);
        memset(videoBuffer, 0, videoWidth*videoHeight*4);
        memset(audioStream, 0, PMSOUNDBUFF);
    }

    current = self;
    return self;
}

- (void)dealloc {
    PokeMini_VideoPalette_Free();
    PokeMini_Destroy();
    free(audioStream);
    free(videoBuffer);
}

#pragma - mark Execution

- (void)setupEmulation {
    CommandLineInit();
    CommandLine.forcefreebios = 0; // OFF
    CommandLine.eeprom_share = 1;  // OFF (there is no practical benefit to a shared eeprom save
//                                   //      - it just gets full and becomes a nuisance...)
    CommandLine.updatertc = 2;        // Update RTC (0=Off, 1=State, 2=Host)
    CommandLine.joyenabled = 1;    // ON
    CommandLine.lcdfilter = 1; // 0: None, 1: Dot-Matrix, 2: Scanline
    CommandLine.lcdmode = 0; // LCD Mode (0: analog, 1: 3shades, 2: 2shades)
    CommandLine.lcdcontrast = 64; // LCD contrast
    CommandLine.lcdbright = 0; // LCD brightness offset
    CommandLine.piezofilter = 1; // ON

    CommandLine.palette = 0; // Palette Index (0 - 13; 0 == Default)
/*
 Reference of other palette's from libretro code
 if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &variables))
 {
 if (strcmp(variables.value, "Old") == 0)
 {
 CommandLine.palette = 1;
 }
 else if (strcmp(variables.value, "Monochrome") == 0)
 {
 CommandLine.palette = 2;
 }
 else if (strcmp(variables.value, "Green") == 0)
 {
 CommandLine.palette = 3;
 }
 else if (strcmp(variables.value, "Green Vector") == 0)
 {
 CommandLine.palette = 4;
 }
 else if (strcmp(variables.value, "Red") == 0)
 {
 CommandLine.palette = 5;
 }
 else if (strcmp(variables.value, "Red Vector") == 0)
 {
 CommandLine.palette = 6;
 }
 else if (strcmp(variables.value, "Blue LCD") == 0)
 {
 CommandLine.palette = 7;
 }
 else if (strcmp(variables.value, "LEDBacklight") == 0)
 {
 CommandLine.palette = 8;
 }
 else if (strcmp(variables.value, "Girl Power") == 0)
 {
 CommandLine.palette = 9;
 }
 else if (strcmp(variables.value, "Blue") == 0)
 {
 CommandLine.palette = 10;
 }
 else if (strcmp(variables.value, "Blue Vector") == 0)
 {
 CommandLine.palette = 11;
 }
 else if (strcmp(variables.value, "Sepia") == 0)
 {
 CommandLine.palette = 12;
 }
 else if (strcmp(variables.value, "Monochrome Vector") == 0)
 {
 CommandLine.palette = 13;
 }
 }
 */
    // Set video spec and check if is supported
#if VIDEO_UPSCALE
    if(!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video4x4, 32, CommandLine.lcdfilter, CommandLine.lcdmode))
#else
    if(!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video1x1, 32, CommandLine.lcdfilter, CommandLine.lcdmode))
#endif
    {
        NSLog(@"Couldn't set video spec.");
    }
    
    if(!PokeMini_Create(0, PMSOUNDBUFF))
    {
        NSLog(@"Error while initializing emulator.");
    }
    
    PokeMini_GotoCustomDir([[self BIOSPath] UTF8String]);
    if(FileExist(CommandLine.bios_file))
    {
        PokeMini_LoadBIOSFile(CommandLine.bios_file);
    }

    JoystickSetup("OpenEmu", 0, 30000, NULL, 12, OpenEmu_KeysMapping);

    int enableHighColor = 1;
    PokeMini_VideoPalette_Init(PokeMini_BGR32, enableHighColor);
    PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
    PokeMini_ApplyChanges();
    PokeMini_UseDefaultCallbacks();

    // enable sound
    MinxAudio_ChangeEngine(MINX_AUDIO_GENERATED);
//    MinxAudio_ChangeEngine(CommandLine.sound);

    [self EEPROMSetup];
}

- (void)EEPROMSetup {
//    PokeMini_CustomLoadEEPROM = loadEEPROM;
//    PokeMini_CustomSaveEEPROM = saveEEPROM;

    NSString *extensionlessFilename = [[romPath lastPathComponent] stringByDeletingPathExtension];
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

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    romPath = path;
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
            [self rumble];
            shouldRumble = NO;
        }
#endif
      
        PokeMini_VideoBlit(videoBuffer + PokeMini_GenRumbleOffset(current->videoWidth), current->videoWidth);
    }
    else
    {
        shouldRumble = YES;
        PokeMini_VideoBlit(videoBuffer, current->videoWidth);
    }
    LCDDirty = 0;
    
    MinxAudio_GetSamplesU8(audioStream, PMSOUNDBUFF);
    [[current ringBufferAtIndex:0] write:audioStream maxLength:PMSOUNDBUFF];
}

- (void)startEmulation
{
//    if(self.rate != 0) return;
    [self setupController];
    [self setupEmulation];
    
    [super startEmulation];
    PokeMini_LoadROM((char*)[romPath UTF8String]);
}

- (void)stopEmulation
{
    PokeMini_SaveFromCommandLines(1);

        // Save EEPROM
    if (PokeMini_EEPROMWritten && StringIsSet(CommandLine.eeprom_file)) {
        PokeMini_EEPROMWritten = 0;
        PokeMini_SaveEEPROMFile(CommandLine.eeprom_file);
        ILOG(@"Wrote EEPROM file: %s\n", CommandLine.eeprom_file);
    }
    
    [super stopEmulation];
}

- (void)resetEmulation
{
    PokeMini_Reset(1);
}

#pragma mark - Save State

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    BOOL success = PokeMini_SaveSSFile(fileName.fileSystemRepresentation, romPath.fileSystemRepresentation);
	if (!success) {
        if(error != nil) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to save state.",
                                       NSLocalizedFailureReasonErrorKey: @"Core failed to create save state.",
                                       NSLocalizedRecoverySuggestionErrorKey: @""
                                       };

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
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

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];

            *error = newError;
        }
	}
	return success;
}

#pragma mark - Video

- (CGSize)aspectSize
{
    return (CGSize){videoWidth, videoHeight};
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, videoWidth, videoHeight);
}

- (CGSize)bufferSize
{
    return CGSizeMake(videoWidth, videoHeight);
}

- (const void *)videoBuffer
{
    return videoBuffer;
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

- (NSTimeInterval)frameInterval
{
    return 72;
}

#pragma mark - Audio

- (double)audioSampleRate
{
    return 44100;
}

- (NSUInteger)audioBitDepth
{
    return 8;
}

- (NSUInteger)channelCount
{
    return 1;
}

#pragma mark - Input

- (void)didPushPMButton:(PVPMButton)button forPlayer:(NSUInteger)player
{
    JoystickButtonsEvent(button, 1);
}

- (void)didReleasePMButton:(PVPMButton)button forPlayer:(NSUInteger)player
{
    JoystickButtonsEvent(button, 0);
}

- (void)dpadValueChanged:(GCControllerDirectionPad * _Nonnull)dpad {
    // DPAD
    if (controllerState.up != dpad.up.isPressed) {
        JoystickButtonsEvent(PVPMButtonUp, dpad.up.isPressed ? 1 : 0);
        controllerState.up = dpad.up.isPressed;
        DLOG(@"Up %@", dpad.up.isPressed ? @"Pressed" : @"Unpressed");
    }
    
    if (controllerState.down != dpad.down.isPressed) {
        JoystickButtonsEvent(PVPMButtonDown, dpad.down.isPressed ? 1 : 0);
        controllerState.down = dpad.down.isPressed;
        DLOG(@"Down %@", dpad.down.isPressed ? @"Pressed" : @"Unpressed");
    }
    
    if (controllerState.left != dpad.left.isPressed) {
        JoystickButtonsEvent(PVPMButtonLeft, dpad.left.isPressed ? 1 : 0);
        controllerState.left = dpad.left.isPressed;
        DLOG(@"Left %@", dpad.left.isPressed ? @"Pressed" : @"Unpressed");
    }
    
    if (controllerState.right != dpad.right.isPressed) {
        JoystickButtonsEvent(PVPMButtonRight, dpad.right.isPressed ? 1 : 0);
        controllerState.right = dpad.right.isPressed;
        DLOG(@"Right %@", dpad.right.isPressed ? @"Pressed" : @"Unpressed");
    }
}

- (void)setupController {
    
    if (self.controller1) {
        if (self.controller1.extendedGamepad) {
            
            __weak PVPokeMiniEmulatorCore* weakSelf = self;
            
            self.controller1.extendedGamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
                [weakSelf dpadValueChanged:dpad];
            };
            
            self.controller1.extendedGamepad.valueChangedHandler = ^(GCExtendedGamepad * _Nonnull gamepad, GCControllerElement * _Nonnull element) {
                __strong PVPokeMiniEmulatorCore* strongSelf = weakSelf;
                
                // Buttons
                if (element == gamepad.buttonA) {
                    if (strongSelf->controllerState.a != gamepad.buttonA.isPressed) {
                        JoystickButtonsEvent(PVPMButtonA, gamepad.buttonA.isPressed ? 1 : 0);
                        strongSelf->controllerState.a = gamepad.buttonA.isPressed;
                        DLOG(@"A %@", strongSelf->controllerState.a ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.buttonB) {
                    if (strongSelf->controllerState.b != gamepad.buttonB.isPressed) {
                        JoystickButtonsEvent(PVPMButtonB, gamepad.buttonB.isPressed ? 1 : 0);
                        strongSelf->controllerState.b = gamepad.buttonB.isPressed;
                        DLOG(@"B %@", strongSelf->controllerState.b ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.buttonX) {
                    if (strongSelf->controllerState.c != gamepad.buttonX.isPressed) {
                        JoystickButtonsEvent(PVPMButtonC, gamepad.buttonX.isPressed ? 1 : 0);
                        strongSelf->controllerState.c = gamepad.buttonX.isPressed;
                        DLOG(@"C %@", strongSelf->controllerState.c ? @"Pressed" : @"Unpressed");
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
                        DLOG(@"Menu %@", strongSelf->controllerState.menu ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.leftTrigger) {
                    if (strongSelf->controllerState.shake != gamepad.leftTrigger.isPressed) {
                        JoystickButtonsEvent(PVPMButtonShake, gamepad.leftTrigger.isPressed ? 1 : 0);
                        strongSelf->controllerState.shake = gamepad.leftTrigger.isPressed;
                        DLOG(@"Shake %@", strongSelf->controllerState.shake ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.rightShoulder) {
                    if (strongSelf->controllerState.power != gamepad.rightShoulder.isPressed) {
                        JoystickButtonsEvent(PVPMButtonPower, gamepad.rightShoulder.isPressed ? 1 : 0);
                        strongSelf->controllerState.power = gamepad.rightShoulder.isPressed;
                        DLOG(@"Power %@", strongSelf->controllerState.power ? @"Pressed" : @"Unpressed");
                    }
                }
                else if (element == gamepad.rightTrigger) {
                    if (strongSelf->controllerState.power != gamepad.rightTrigger.isPressed) {
                        JoystickButtonsEvent(PVPMButtonPower, gamepad.rightTrigger.isPressed ? 1 : 0);
                        strongSelf->controllerState.power = gamepad.rightTrigger.isPressed;
                        DLOG(@"Power %@", strongSelf->controllerState.power ? @"Pressed" : @"Unpressed");
                    }
                }
            };
        }
        else if (self.controller1.gamepad) {
            
            __weak PVPokeMiniEmulatorCore* weakSelf = self;

            self.controller1.gamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
                __strong PVPokeMiniEmulatorCore* strongSelf = weakSelf;

                [strongSelf dpadValueChanged:dpad];
            };

            self.controller1.gamepad.valueChangedHandler = ^(GCGamepad * _Nonnull gamepad, GCControllerElement * _Nonnull element) {
                __strong PVPokeMiniEmulatorCore* strongSelf = weakSelf;

                    // Buttons
                if (element == gamepad.buttonA) {
                    if (strongSelf->controllerState.a != gamepad.buttonA.isPressed) {
                        JoystickButtonsEvent(PVPMButtonA, gamepad.buttonA.isPressed ? 1 : 0);
                        strongSelf->controllerState.a = gamepad.buttonA.isPressed;
                    }
                }
                else if (element == gamepad.buttonB) {
                    if (strongSelf->controllerState.b != gamepad.buttonB.isPressed) {
                        JoystickButtonsEvent(PVPMButtonB, gamepad.buttonB.isPressed ? 1 : 0);
                        strongSelf->controllerState.b = gamepad.buttonB.isPressed;
                    }
                }
                else if (element == gamepad.buttonX) {
                    if (strongSelf->controllerState.c != gamepad.buttonX.isPressed) {
                        JoystickButtonsEvent(PVPMButtonC, gamepad.buttonX.isPressed ? 1 : 0);
                        strongSelf->controllerState.c = gamepad.buttonX.isPressed;
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
                    if (strongSelf->controllerState.shake != gamepad.leftShoulder.isPressed) {
                        JoystickButtonsEvent(PVPMButtonShake, gamepad.leftShoulder.isPressed ? 1 : 0);
                        strongSelf->controllerState.shake = gamepad.leftShoulder.isPressed;
                    }
                }
                else if (element == gamepad.rightShoulder) {
                    if (strongSelf->controllerState.power != gamepad.rightShoulder.isPressed) {
                        JoystickButtonsEvent(PVPMButtonPower, gamepad.rightShoulder.isPressed ? 1 : 0);
                        strongSelf->controllerState.power = gamepad.rightShoulder.isPressed;
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
                    if (strongSelf->controllerState.a != gamepad.buttonA.isPressed) {
                        JoystickButtonsEvent(PVPMButtonA, gamepad.buttonA.isPressed ? 1 : 0);
                        strongSelf->controllerState.a = gamepad.buttonA.isPressed;
                    }
                }
                else if (element == gamepad.buttonX) {
                    if (strongSelf->controllerState.b != gamepad.buttonX.isPressed) {
                        JoystickButtonsEvent(PVPMButtonB, gamepad.buttonX.isPressed ? 1 : 0);
                        strongSelf->controllerState.b = gamepad.buttonX.isPressed;
                    }
                }
            };
        }
#endif
    }
}

@end

@implementation PVPokeMiniEmulatorCore (Rumble)

- (BOOL)supportsRumble {
    return YES;
}

@end
