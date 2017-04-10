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

#import "PVPokeMiniEmulatorCore.h"

#import <PVSupport/OERingBuffer.h>
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import "PVPMSystemResponderClient.h"
#import "PokeMini.h"
#import "Hardware.h"
#import "Joystick.h"
#import "Video_x1.h"

@interface PVPokeMiniEmulatorCore ()
{
    uint8_t *audioStream;
    uint32_t *videoBuffer;
    int videoWidth, videoHeight;
    NSString *romPath;
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
        videoWidth = 96;
        videoHeight = 64;
        
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

- (void)setupEmulation
{
    CommandLineInit();
    CommandLine.eeprom_share = 1;
    
    // Set video spec and check if is supported
    if(!PokeMini_SetVideo((TPokeMini_VideoSpec *)&PokeMini_Video1x1, 32, CommandLine.lcdfilter, CommandLine.lcdmode))
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
    
    [self EEPROMSetup];
    
    JoystickSetup("OpenEmu", 0, 30000, NULL, 12, OpenEmu_KeysMapping);
    
    PokeMini_VideoPalette_Init(PokeMini_RGB32, 0);
    PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
    PokeMini_ApplyChanges();
    PokeMini_UseDefaultCallbacks();
    
    MinxAudio_ChangeEngine(MINX_AUDIO_GENERATED);
}

- (void)EEPROMSetup
{
    PokeMini_CustomLoadEEPROM = loadEEPROM;
    PokeMini_CustomSaveEEPROM = saveEEPROM;
    
    NSString *extensionlessFilename = [[romPath lastPathComponent] stringByDeletingPathExtension];
    NSString *batterySavesDirectory = [self batterySavesPath];
    
    if([batterySavesDirectory length] != 0)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
        
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"eep"]];
        
        strcpy(CommandLine.eeprom_file, [filePath UTF8String]);
        loadEEPROM(CommandLine.eeprom_file);
    }
}

// Read EEPROM
int loadEEPROM(const char *filename)
{
    FILE *fp;
    
    // Read EEPROM from RAM file
    fp = fopen(filename, "rb");
    if (!fp) return 0;
    fread(EEPROM, 8192, 1, fp);
    fclose(fp);
    
    return 1;
}

// Write EEPROM
int saveEEPROM(const char *filename)
{
    FILE *fp;
    
    // Write EEPROM to RAM file
    fp = fopen(filename, "wb");
    if (!fp) return 0;
    fwrite(EEPROM, 8192, 1, fp);
    fclose(fp);
    
    return 1;
}

- (BOOL)loadFileAtPath:(NSString *)path // error:(NSError **)error
{
    romPath = path;
    return YES;
}

- (void)executeFrame
{
    // Emulate 1 frame
    PokeMini_EmulateFrame();
    
    if(PokeMini_Rumbling) {
        PokeMini_VideoBlit(videoBuffer + PokeMini_GenRumbleOffset(current->videoWidth), current->videoWidth);
    }
    else
    {
        PokeMini_VideoBlit(videoBuffer, current->videoWidth);
    }
    LCDDirty = 0;
    
    MinxAudio_GetSamplesU8(audioStream, PMSOUNDBUFF);
    [[current ringBufferAtIndex:0] write:audioStream maxLength:PMSOUNDBUFF];
}

- (void)startEmulation
{
//    if(self.rate != 0) return;
    [self setupEmulation];
    
    [super startEmulation];
    PokeMini_LoadROM((char*)[romPath UTF8String]);
}

- (void)stopEmulation
{
    PokeMini_SaveFromCommandLines(1);
    
    [super stopEmulation];
}

- (void)resetEmulation
{
    PokeMini_Reset(1);
}

#pragma mark - Save State

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    return PokeMini_SaveSSFile(fileName.fileSystemRepresentation, romPath.fileSystemRepresentation);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    return PokeMini_LoadSSFile(fileName.fileSystemRepresentation);
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

- (oneway void)didPushPMButton:(PVPMButton)button forPlayer:(NSUInteger)player
{
    JoystickButtonsEvent(button, 1);
}

- (oneway void)didReleasePMButton:(PVPMButton)button forPlayer:(NSUInteger)player
{
    JoystickButtonsEvent(button, 0);
}

@end
