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

#import "PVGBAEmulatorCore.h"
#import <PVSupport/OERingBuffer.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#include <sys/time.h>
#include "System.h"
#include "Util.h"
#include "gba/GBA.h"
#include "gba/RTC.h"
#include "gba/Sound.h"
#include "common/SoundDriver.h"

EmulatedSystem vba;
int emulating = 0;
uint32_t pad[PVGBAButtonCount];

@interface PVGBAEmulatorCore ()
{
    uint8_t *videoBuffer;
    int32_t *soundBuffer;
    NSURL *_romFile, *_saveFile;

    NSString *_romID;
    BOOL _enableRTC, _enableMirroring, _useBIOS, _haveFrame, _migratingSave;
    int _flashSize, _cpuSaveType;
}
- (void)loadOverrides:(NSString *)gameID;
- (void)writeSaveFile;
- (void)migrateSaveFile;
@end

@implementation PVGBAEmulatorCore

static __weak PVGBAEmulatorCore *_current;

- (id)init
{
    if((self = [super init]))
    {
        videoBuffer = (uint8_t *) malloc(240 * 160 * 4);
        vba = GBASystem;
    }

    _current = self;

    return self;
}

- (void)dealloc
{
    free(videoBuffer);
}

# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    memset(pad, 0, sizeof(uint32_t) * PVGBAButtonCount);

    _romFile = [NSURL fileURLWithPath:path];

    int loaded = CPULoadRom([path UTF8String]);

    if(loaded == 0)
        return NO;

    utilUpdateSystemColorMaps(false);

    // Read the cart's Game ID
    char gameID[5];
    gameID[0] = rom[0xac];
    gameID[1] = rom[0xad];
    gameID[2] = rom[0xae];
    gameID[3] = rom[0xaf];
    gameID[4] = 0;

    DLog(@"VBA: GameID in ROM is: %s\n", gameID);

    // Load per-game settings from vba-over.ini
    [self loadOverrides:[NSString stringWithFormat:@"%s", gameID]];

    // Apply settings
    rtcEnable(_enableRTC);
    mirroringEnable = _enableMirroring;
    doMirroring(mirroringEnable);
    cpuSaveType = _cpuSaveType;
    if(_flashSize == 0x10000 || _flashSize == 0x20000)
        flashSetSize(_flashSize);

    soundInit();
    soundSetSampleRate(32768); // 44100 chirps
    //soundFiltering = 0.0;
    //soundInterpolation = false;

    soundReset();

    CPUInit(0, false);
    CPUReset();

    // Load battery save or migrate old one
    NSString *extensionlessFilename = [[_romFile lastPathComponent] stringByDeletingPathExtension];
    NSString *batterySavesDirectory = [self batterySavesPath];
    if([batterySavesDirectory length])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    _saveFile = [NSURL fileURLWithPath:[batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav2"]]];

    if ([_saveFile checkResourceIsReachableAndReturnError:nil] && vba.emuReadBattery([[_saveFile path] UTF8String]))
        DLog(@"VBA: Battery loaded");
    else
        [self migrateSaveFile];

    emulating = 1;

    return YES;
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    _haveFrame = NO;

    while (!_haveFrame)
    {
        vba.emuMain(vba.emuCount);
    }
}

- (void)resetEmulation
{
    vba.emuReset();
}

- (void)stopEmulation
{
    [super stopEmulation]; //Leave emulation loop first

    emulating = 0;

    [self writeSaveFile];

    vba.emuCleanUp();
    soundShutdown();
}

- (NSTimeInterval)frameInterval
{
    return 59.727501;
}

# pragma mark - Video

- (const void *)videoBuffer
{
    return videoBuffer;
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, 240, 160);
}

- (CGSize)bufferSize
{
    return CGSizeMake(240, 160);
}

- (CGSize)aspectSize
{
    return CGSizeMake(3, 2);
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
    return soundGetSampleRate();
}

- (NSUInteger)channelCount
{
    return 2;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    @synchronized(self) {
        return vba.emuWriteState([fileName UTF8String]);
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    @synchronized(self) {
        return vba.emuReadState([fileName UTF8String]);
    }
}

# pragma mark - Input

enum {
    KEY_BUTTON_A      = 1 << 0,
    KEY_BUTTON_B      = 1 << 1,
    KEY_BUTTON_SELECT = 1 << 2,
    KEY_BUTTON_START  = 1 << 3,
    KEY_RIGHT         = 1 << 4,
    KEY_LEFT          = 1 << 5,
    KEY_UP            = 1 << 6,
    KEY_DOWN          = 1 << 7,
    KEY_BUTTON_R      = 1 << 8,
    KEY_BUTTON_L      = 1 << 9
};
const int GBAMap[] = {KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_BUTTON_A, KEY_BUTTON_B, KEY_BUTTON_L, KEY_BUTTON_R, KEY_BUTTON_START, KEY_BUTTON_SELECT};

- (oneway void)pushGBAButton:(PVGBAButton)button forPlayer:(NSInteger)player
{
    pad[player] |= GBAMap[button];
}

- (oneway void)releaseGBAButton:(PVGBAButton)button forPlayer:(NSInteger)player
{
    pad[player] &= ~GBAMap[button];
}

bool systemReadJoypads()
{
    __strong PVGBAEmulatorCore *strongCurrent = _current;

    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++)
    {
        GCController *controller = nil;
        if (strongCurrent.controller1 && playerIndex == 0)
        {
            controller = strongCurrent.controller1;
        }
        else if (strongCurrent.controller2 && playerIndex == 1)
        {
            controller = strongCurrent.controller2;
            playerIndex = 1;
        }

        if (controller)
        {
            if ([controller extendedGamepad])
            {
                GCExtendedGamepad *gamepad = [controller extendedGamepad];
                GCControllerDirectionPad *dpad = [gamepad dpad];

                (gamepad.dpad.up.isPressed || gamepad.leftThumbstick.up.isPressed) ? pad[playerIndex] |= KEY_UP : pad[playerIndex] &= ~KEY_UP;
                (gamepad.dpad.down.isPressed || gamepad.leftThumbstick.down.isPressed) ? pad[playerIndex] |= KEY_DOWN : pad[playerIndex] &= ~KEY_DOWN;
                (gamepad.dpad.left.isPressed || gamepad.leftThumbstick.left.isPressed) ? pad[playerIndex] |= KEY_LEFT : pad[playerIndex] &= ~KEY_LEFT;
                (gamepad.dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed) ? pad[playerIndex] |= KEY_RIGHT : pad[playerIndex] &= ~KEY_RIGHT;

                gamepad.buttonA.isPressed ? pad[playerIndex] |= KEY_BUTTON_B : pad[playerIndex] &= ~KEY_BUTTON_B;
                gamepad.buttonB.isPressed ? pad[playerIndex] |= KEY_BUTTON_A : pad[playerIndex] &= ~KEY_BUTTON_A;

                gamepad.leftShoulder.isPressed ? pad[playerIndex] |= KEY_BUTTON_L : pad[playerIndex] &= ~KEY_BUTTON_L;
                gamepad.rightShoulder.isPressed ? pad[playerIndex] |= KEY_BUTTON_R : pad[playerIndex] &= ~KEY_BUTTON_R;

                (gamepad.buttonX.isPressed || gamepad.leftTrigger.isPressed) ? pad[playerIndex] |= KEY_BUTTON_START : pad[playerIndex] &= ~KEY_BUTTON_START;
                (gamepad.buttonY.isPressed || gamepad.rightTrigger.isPressed) ? pad[playerIndex] |= KEY_BUTTON_SELECT : pad[playerIndex] &= ~KEY_BUTTON_SELECT;
            }
            else if ([controller gamepad])
            {
                GCGamepad *gamepad = [controller gamepad];
                GCControllerDirectionPad *dpad = [gamepad dpad];

                gamepad.dpad.up.isPressed ? pad[playerIndex] |= KEY_UP : pad[playerIndex] &= ~KEY_UP;
                gamepad.dpad.down.isPressed ? pad[playerIndex] |= KEY_DOWN : pad[playerIndex] &= ~KEY_DOWN;
                gamepad.dpad.left.isPressed ? pad[playerIndex] |= KEY_LEFT : pad[playerIndex] &= ~KEY_LEFT;
                gamepad.dpad.right.isPressed ? pad[playerIndex] |= KEY_RIGHT : pad[playerIndex] &= ~KEY_RIGHT;

                gamepad.buttonA.isPressed ? pad[playerIndex] |= KEY_BUTTON_B : pad[playerIndex] &= ~KEY_BUTTON_B;
                gamepad.buttonB.isPressed ? pad[playerIndex] |= KEY_BUTTON_A : pad[playerIndex] &= ~KEY_BUTTON_A;

                gamepad.leftShoulder.isPressed ? pad[playerIndex] |= KEY_BUTTON_L : pad[playerIndex] &= ~KEY_BUTTON_L;
                gamepad.rightShoulder.isPressed ? pad[playerIndex] |= KEY_BUTTON_R : pad[playerIndex] &= ~KEY_BUTTON_R;

                gamepad.buttonX.isPressed ? pad[playerIndex] |= KEY_BUTTON_START : pad[playerIndex] &= ~KEY_BUTTON_START;
                gamepad.buttonY.isPressed ? pad[playerIndex] |= KEY_BUTTON_SELECT : pad[playerIndex] &= ~KEY_BUTTON_SELECT;
            }
#if TARGET_OS_TV
            else if ([controller microGamepad])
            {
                GCMicroGamepad *gamepad = [controller microGamepad];
                GCControllerDirectionPad *dpad = [gamepad dpad];

                gamepad.dpad.up.value > 0.5 ? pad[playerIndex] |= KEY_UP : pad[playerIndex] &= ~KEY_UP;
                gamepad.dpad.down.value > 0.5 ? pad[playerIndex] |= KEY_DOWN : pad[playerIndex] &= ~KEY_DOWN;
                gamepad.dpad.left.value > 0.5 ? pad[playerIndex] |= KEY_LEFT : pad[playerIndex] &= ~KEY_LEFT;
                gamepad.dpad.right.value > 0.5 ? pad[playerIndex] |= KEY_RIGHT : pad[playerIndex] &= ~KEY_RIGHT;
                
                gamepad.buttonA.isPressed ? pad[playerIndex] |= KEY_BUTTON_B : pad[playerIndex] &= ~KEY_BUTTON_B;
                gamepad.buttonX.isPressed ? pad[playerIndex] |= KEY_BUTTON_A : pad[playerIndex] &= ~KEY_BUTTON_A;
            }
#endif
        }
    }

    return true;
}

#pragma mark - Cheats

NSMutableDictionary *cheatList = [[NSMutableDictionary alloc] init];

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
    // Sanitize
    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // VBA expects cheats UPPERCASE
    code = [code uppercaseString];

    // Remove any spaces
    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];

    if (enabled)
        [cheatList setValue:@YES forKey:code];
    else
        [cheatList removeObjectForKey:code];

    cheatsDeleteAll(false); // Old values not restored by default. Dunno if matters much to cheaters

    NSArray *multipleCodes = [[NSArray alloc] init];

    // Apply enabled cheats found in dictionary
    for (id key in cheatList)
    {
        if ([[cheatList valueForKey:key] isEqual:@YES])
        {
            // Handle multi-line cheats
            multipleCodes = [key componentsSeparatedByString:@"+"];

            for (NSString *singleCode in multipleCodes)
            {
                if ([singleCode length] == 11 || [singleCode length] == 13 || [singleCode length] == 17) // Code with Address:Value
                {
                    // XXXXXXXX:YY || XXXXXXXX:YYYY || XXXXXXXX:YYYYYYYY
                    cheatsAddCheatCode([singleCode UTF8String], "code");
                }

                if ([singleCode length] == 12) // Codebreaker/GameShark SP/Xploder code
                {
                    // VBA expects 12-character Codebreaker/GameShark SP codes in format: XXXXXXXX YYYY
                    NSMutableString *formattedCode = [NSMutableString stringWithString:singleCode];
                    [formattedCode insertString:@" " atIndex:8];

                    cheatsAddCBACode([formattedCode UTF8String], "code");
                }

                if ([singleCode length] == 16) // GameShark Advance/Action Replay (v1/v2) and Action Replay v3
                {
                    // Note: GameShark and Action Replay were synonymous until AR v3. Same codes and devices, but different names by region
                    if ([type isEqual: @"GameShark"])
                        cheatsAddGSACode([singleCode UTF8String], "code", false);

                    // AR v3 was an entirely different device from GS/AR v1/v2, with different code types and encryption
                    else if ([type isEqual: @"Action Replay"])
                        cheatsAddGSACode([singleCode UTF8String], "code", true); // true = AR v3 code

                    else // default to GS/AR v1/v2 code (can't determine GS/AR v1/v2 vs AR v3 because same length)
                        cheatsAddGSACode([singleCode UTF8String], "code", false);
                }
            }
        }
    }
}

# pragma mark - Misc Helper Methods

- (void)loadOverrides:(NSString *)gameID
{
    // Set defaults
    _enableRTC       = NO;
    _enableMirroring = NO;
    _useBIOS         = NO;
    _cpuSaveType     = 0;
    _flashSize       = 0x10000;

    // Read in vba-over.ini and break it into an array of strings
    NSString *iniPath = [[NSBundle mainBundle] pathForResource:@"vba-over" ofType:@"ini"];
    NSString *iniString = [NSString stringWithContentsOfFile:iniPath encoding:NSUTF8StringEncoding error:NULL];
    NSArray *settings = [iniString componentsSeparatedByString:@"\n"];

    BOOL matchFound = NO;
    NSMutableDictionary *overridesFound = [[NSMutableDictionary alloc] init];
    NSString *temp;

    // Check if vba-over.ini has per-game settings for our gameID
    for (NSString *s in settings)
    {
        temp = nil;

        if ([s hasPrefix:@"["])
        {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"[" intoString:nil];
            [scanner scanUpToString:@"]" intoString:&temp];

            if([temp caseInsensitiveCompare:gameID] == NSOrderedSame)
            {
                matchFound = YES;
                _romID = temp;
            }

            continue;
        }

        else if (matchFound && [s hasPrefix:@"saveType="])
        {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"saveType=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            _cpuSaveType = [temp intValue];
            [overridesFound setObject:temp forKey:@"CPU saveType"];

            continue;
        }

        else if (matchFound && [s hasPrefix:@"rtcEnabled="])
        {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"rtcEnabled=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            _enableRTC = [temp boolValue];
            [overridesFound setObject:temp forKey:@"rtcEnabled"];

            continue;
        }

        else if (matchFound && [s hasPrefix:@"flashSize="])
        {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"flashSize=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            _flashSize = [temp intValue];
            [overridesFound setObject:temp forKey:@"flashSize"];

            continue;
        }

        else if (matchFound && [s hasPrefix:@"mirroringEnabled="])
        {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"mirroringEnabled=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            _enableMirroring = [temp boolValue];
            [overridesFound setObject:temp forKey:@"mirroringEnabled"];

            continue;
        }

        else if (matchFound && [s hasPrefix:@"useBios="])
        {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"useBios=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            _useBIOS = [temp boolValue];
            [overridesFound setObject:temp forKey:@"useBios"];

            continue;
        }

        else if (matchFound)
            break;
    }

    if (matchFound)
        DLog(@"VBA: overrides found: %@", overridesFound);
}

- (void)writeSaveFile
{
    if (vba.emuWriteBattery([[_saveFile path] UTF8String]))
        DLog(@"VBA: Battery saved");
}

/*
 This migration method is meant to correct broken behavior in forks of VBA/VBA-M so that we can reuse battery saves with our unmodified VBA-M core port. Forks vba-next/vbam-libretro created battery saves incompatible with vanilla VBA-M. Problems include:

 - EEPROM and FLASH all arbitrarily saved as 139KB (139264 bytes) instead of correct sizes.
 - SRAM sometimes saved incorrectly as 8KB (8192 bytes) instead of proper 66KB (65536 bytes).
 - SRAM sometimes saved incorrectly as 512 bytes instead of proper 66KB, resulting in data loss.
 - SRAM sometimes saved incorrectly as 139KB (139264 bytes) instead of proper 66KB (65536 bytes).
 - FLASH sometimes saved corrupt/empty 66KB files instead of saves meant to be 131KB (131072 bytes).
 - Battery save files always generated even if a game did not support saving.
 */
- (void)migrateSaveFile
{
    // Build a path to the old save file and check if it exists
    NSURL *extensionlessFilename = [_saveFile URLByDeletingPathExtension];
    NSURL *saveFileToMigrate = [extensionlessFilename URLByAppendingPathExtension:@"sav"];

    if (![saveFileToMigrate checkResourceIsReachableAndReturnError:nil])
        return;

    /*
     +----------------+----------+-------------+-----------------+--------------------------------------+
     |     Format     | saveType | cpuSaveType |  Size in Bytes  |            Example Games             |
     +----------------+----------+-------------+-----------------+--------------------------------------|
     |  (AUTODETECT)  |    0     |      0      |        -        |                                      |
     |  SRAM          |    1     |      2      |      65536*     | F-Zero, Kirby Nightmare in Dreamland |
     |  FLASH         |    2     |      3      | 65536 or 131072 | Golden Sun, Pokemon Emerald          |
     |  EEPROM        |    3     |      1      |   512 or 8192   | Super Mario Advance, LoZ: Minish Cap |
     |  EEPROM+Sensor |    3     |      4      |   512 or 8192   | Yoshi's Universal Gravitation        |
     |  (NONE)        |    5     |      5      |        -        |                                      |
     +-----------------------------------------------------------+--------------------------------------+
     * According to some docs, SRAM should be 32768 bytes but VBA saves SRAM as 65536
     Note: `saveType` = `gbaSaveType` global save var, `cpuSaveType` = `saveType=` in vba-over.ini
     See: GBA.cpp:3500 and http://problemkaputt.de/gbatek.htm#gbacartbackupids
     */

    // Step 0
    // Backup original save file as .sav.old
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *backupSaveFile = [saveFileToMigrate URLByAppendingPathExtension:@"old"];
    [fileManager copyItemAtURL:saveFileToMigrate toURL:backupSaveFile error:nil];

    // Step 1
    // Run the CPU for 500 cycles to try and determine the save type
    // Seems high but save types for some games cannot be determined until 300+ cycles (e.g. Golden Sun)
    _migratingSave = YES;

    for (int i = 0; i < 500; i++)
    {
        vba.emuMain(vba.emuCount);
    }

    // Step 2
    // If VBA did not determine the save type while cycling the CPU, fall back to lookup by the GBA Cart Backup ID. Sometimes VBA cannot determine save types until certain points in game when memory is accessed. This routine, adapted from Util.cpp, is rarely used as cycling the CPU is usually enough.
    // Note: Lookup via GBA Cart Backup ID is not 100% accurate http://zork.net/~st/jottings/GBA_saves.html
    if (saveType == 0 && !eepromInUse)
    {
        uint8_t *data;
        size_t size;

        // Load GBA cart, read bytes, get length
        NSData *dataObj = [NSData dataWithContentsOfURL:[_romFile URLByStandardizingPath]];
        if(dataObj == nil) return;
        size = [dataObj length];
        data = (uint8_t *)[dataObj bytes];

        uint32_t *p = (uint32_t *)data;
        uint32_t *end = (uint32_t *)(data + size);

        while(p < end) {
            uint32_t d = *((uint32_t *)p);

            if(d == 0x52504545) {
                if(memcmp(p, "EEPROM_", 7) == 0) {
                    if(saveType == 0)
                    {
                        saveType = 3;
                        eepromSize = 8192;
                    }
                }
            } else if (d == 0x4D415253) {
                if(memcmp(p, "SRAM_", 5) == 0) {
                    if(saveType == 0)
                        saveType = 1;
                }
            } else if (d == 0x53414C46) {
                if(memcmp(p, "FLASH1M_", 8) == 0) {
                    if(saveType == 0) {
                        saveType = 2;
                        flashSize = 0x20000;
                    }
                } else if(memcmp(p, "FLASH", 5) == 0) {
                    if(saveType == 0) {
                        saveType = 2;
                        flashSize = 0x10000;
                    }
                }
            } else if (d == 0x52494953) {
                if(memcmp(p, "SIIRTC_V", 8) == 0)
                    _enableRTC = true;
            }
            p++;
        }
        // if no matches found, then set it to NONE
        if(saveType == 0) {
            saveType = 5;
        }

        if (saveType == 0 || saveType == 5) DLog(@"saveType 0 NONE");
        if (saveType == 3) DLog(@"saveType 3 EEPROM_");
        if (saveType == 1) DLog(@"saveType 1 SRAM_");
        if (saveType == 2) DLog(@"saveType 2 FLASH size %d", flashSize);
        if (_enableRTC) DLog(@"rtcFound");
    }

    DLog(@"saveType: %d eepromInUse %d flashSize %d eepromSize %d", saveType, eepromInUse, flashSize, eepromSize);

    // Step 3
    // Migrate save file if needed
    uint8_t *saveFileData;
    size_t saveFileSize;

    // Load save file, read bytes, get length
    NSData *dataObj = [NSData dataWithContentsOfURL:saveFileToMigrate];
    if(dataObj == nil) return;
    saveFileSize = [dataObj length];
    saveFileData = (uint8_t *)[dataObj bytes];

    // EEPROM saves

    // 139KB to 8KB - remove the front 131072 bytes
    if ((saveType == 3 || eepromInUse) && eepromSize == 8192 && saveFileSize == 139264)
        memmove(saveFileData, saveFileData + 131072, saveFileSize -= 131072);

    // 139KB to 512 bytes - remove the front 131072 and last 7680 bytes
    else if ((saveType == 3 || eepromInUse) && eepromSize == 512 && saveFileSize == 139264)
    {
        memmove(saveFileData, saveFileData + 131072, saveFileSize -= 131072);
        saveFileData[512] = 0; // null terminate to drop the last 7680 bytes
        saveFileSize = 512;
    }

    // FLASH saves

    // 139KB to 131KB - remove the last 8192 bytes
    else if (saveType == 2 && flashSize == 131072 && saveFileSize == 139264)
    {
        saveFileData[131072] = 0;
        saveFileSize = 131072;
    }
    // 139KB to 66KB  - remove the last 73728 bytes
    else if (saveType == 2 && flashSize == 65536 && saveFileSize == 139264)
    {
        saveFileData[65536] = 0;
        saveFileSize = 65536;
    }
    // Case where some 131KB FLASH saved as 66KB with nothing but 0xFF bytes and no save data
    // All we can do is delete so the game doesn't crash
    else if (saveType == 2 && flashSize == 131072 && saveFileSize == 65536)
    {
        [fileManager removeItemAtURL:saveFileToMigrate error:nil];
        CPUReset();
        _migratingSave = NO;
        return;
    }

    // SRAM saves

    // 139KB to 66KB  - remove the last 73728 bytes
    else if (saveType == 1 && saveFileSize == 139264)
    {
        saveFileData[65536] = 0;
        saveFileSize = 65536;
    }
    // Case where some 66KB SRAM saved as 8KB - add 57344 bytes of 0xFF to the end
    // e.g. Kirby Nightmare in Dreamland
    // Note: This is a lot of potential data lost and might not fix all saves
    else if (saveType == 1 && saveFileSize == 8192)
    {
        NSMutableData *appendedData = [NSMutableData dataWithBytes:saveFileData length:saveFileSize];
        uint8_t *bytesToAppend = (uint8_t *)malloc(57344);
        memset(bytesToAppend, 0xFF, 57344);
        NSData *append = [NSData dataWithBytesNoCopy:bytesToAppend length:57344 freeWhenDone:YES];
        [appendedData appendBytes:[append bytes] length:[append length]];

        saveFileData = (uint8_t *)[appendedData bytes];
        saveFileSize = [appendedData length];
    }
    else
    {
        DLog(@"VBA: Did not migrate save file because unnecessary or not detected.");
    }

    // Step 4
    // Save migrated file to .sav2 and delete old save file
    if (saveFileSize < 139264)
    {
        NSError *error = nil;
        NSURL *extensionlessFilename = [saveFileToMigrate URLByDeletingPathExtension];
        NSURL *migratedSaveFile = [extensionlessFilename URLByAppendingPathExtension:@"sav2"];
        NSData *outData = [NSData dataWithBytes:saveFileData length:saveFileSize];

        [outData writeToURL:migratedSaveFile options:NSDataWritingAtomic error:&error];

        if (error)
        {
            DLog(@"VBA: Error writing migrated save file: %@", error);
            CPUReset();
            _migratingSave = NO;
            return;
        }

        DLog(@"VBA: Writing new save file: %@", migratedSaveFile);

        // Reset because we ran the CPU
        CPUReset();
        _migratingSave = NO;

        if (vba.emuReadBattery([[migratedSaveFile path] UTF8String]))
            DLog(@"VBA: Battery loaded");
    }
    else
    {
        CPUReset();
        _migratingSave = NO;
    }

    // Delete old save file since we created a backup .sav.old
    [fileManager removeItemAtURL:saveFileToMigrate error:nil];
}

// VBA internal functions and stubs
uint16_t systemColorMap16[0x10000];
uint32_t systemColorMap32[0x10000];
int systemColorDepth = 32;
int systemRedShift = 19;
int systemGreenShift = 11;
int systemBlueShift = 3;
int RGB_LOW_BITS_MASK = 0x00010101;
int systemDebug = 0;
int systemVerbose = 0;
int systemFrameSkip = 0;
int systemSaveUpdateCounter = SYSTEM_SAVE_NOT_UPDATED;
int systemSpeed = 0;
uint32_t systemGetClock()
{
    //struct timeval tv;

    //gettimeofday(&tv, NULL);
    //return tv.tv_sec*1000;
    return 0;
}

int systemGetSensorX(void) {return 0;}
int systemGetSensorY(void) {return 0;}
bool systemPauseOnFrame() {return false;}
bool systemCanChangeSoundQuality() {return false;} // ?
void (*dbgOutput)(const char *s, uint32_t addr);
void systemFrame() {}
void systemShowSpeed(int speed) {}
void systemScreenCapture(int a) {}
void systemUpdateMotionSensor() {}
void systemOnSoundShutdown() {}
void systemOnWriteDataToSoundBuffer(const uint16_t *finalWave, int length) {}

// VBA video and execution
void system10Frames(int rate)
{
    __strong PVGBAEmulatorCore *strongCurrent = _current;

    if(systemSaveUpdateCounter && !strongCurrent->_migratingSave)
    {
        if(--systemSaveUpdateCounter <= SYSTEM_SAVE_NOT_UPDATED)
        {
            [_current writeSaveFile];
            systemSaveUpdateCounter = SYSTEM_SAVE_NOT_UPDATED;
        }
    }
}

void systemDrawScreen()
{
    __strong PVGBAEmulatorCore *strongCurrent = _current;

    strongCurrent->_haveFrame = YES;

    // Get rid of the first line and the last row
    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_apply(160, the_queue, ^(size_t y){
        memcpy(strongCurrent->videoBuffer + y * 240 * 4, pix + (y + 1) * (240 + 1) * 4, 240 * 4);
    });
}

// VBA input
uint32_t systemReadJoypad(int which)
{
    uint32_t res = 0;

    which %= 4;
    if(which == -1)
        which = 0;

    res = pad[which];

    // Disallow L+R or U+D of being pressed at the same time
    if((res & (KEY_RIGHT | KEY_LEFT)) == (KEY_RIGHT | KEY_LEFT)) res &= ~ KEY_RIGHT;
    if((res & (KEY_UP    | KEY_DOWN)) == (KEY_UP    | KEY_DOWN)) res &= ~ KEY_UP;

    //if((res & 48) == 48)
    //    res &= ~16;
    //if((res & 192) == 192)
    //    res &= ~128;

    return res;
}

// VBA audio
class DummySound : public SoundDriver
{
public:
    DummySound();
    virtual ~DummySound();

    virtual bool init(long sampleRate);
    virtual void pause();
    virtual void reset();
    virtual void resume();
    virtual void write(uint16_t * finalWave, int length);
};

DummySound::DummySound() {}

void DummySound::write(u16 * finalWave, int length)
{
    __strong PVGBAEmulatorCore *strongCurrent = _current;

    [[strongCurrent ringBufferAtIndex:0] write:finalWave maxLength:length];
}

bool DummySound::init(long sampleRate)
{
    return true;
}

DummySound::~DummySound() {}
void DummySound::pause() {}
void DummySound::resume() {}
void DummySound::reset() {}

SoundDriver *systemSoundInit()
{
    soundShutdown();

    return new DummySound();
}

// VBA logging
void systemMessage(int, const char * str, ...)
{
    DLog(@"VBA message: %s", str);
}

@end
