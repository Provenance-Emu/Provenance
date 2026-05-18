//
//  MednafenGameCoreBridge+UserPortDevice.mm
//  MednafenGameCoreBridge
//
//  Reads the pause-menu "Port Devices" tile choice that
//  MednafenGameCore+PortDevices.swift persists to UserDefaults and translates
//  the libretro device-type integer back into the Mednafen device-name string
//  expected by `Mednafen::MDFNGI::SetInput`.
//
//  Each Mednafen subsystem has its own device-name vocabulary
//  ("gamepad" / "dualshock" / "guncon" / "superscope" / "zapper" / "gun" /
//   "3dpad" / "mouse" / …). The mapping below mirrors
//   MednafenGameCore+PortDevices.swift's descriptor topology.
//

#import "MednafenGameCoreBridge.h"
#import <MednafenGameCoreC/MednafenControllerMappings.h>
#import <Foundation/Foundation.h>

@implementation MednafenGameCoreBridge (UserPortDevice)

/// Returns the Mednafen device-name string to pass to `game->SetInput(port, ...)` for
/// the given port. If the user picked a device via the pause-menu Port Devices tile
/// and it maps to a meaningful name on the current subsystem, that takes precedence;
/// otherwise `defaultName` is returned unchanged so existing behaviour is preserved.
- (NSString *)mednafenDeviceNameForPort:(NSInteger)port defaultDevice:(NSString *)defaultName {
    NSString *md5 = [self valueForKey:@"romMD5"];
    if (md5.length == 0) { md5 = @"_"; }
    NSString *coreId = [self valueForKey:@"coreIdentifier"];
    if (coreId.length == 0) { coreId = @"Mednafen"; }
    NSString *key = [NSString stringWithFormat:@"MednafenGameCore.%@.%@.portDeviceType.port%ld",
                     md5, coreId, (long)port];
    NSInteger stored = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    if (stored <= 0) {
        return defaultName;
    }

    // Strip libretro subclass bits (RETRO_DEVICE_MASK = 0xFF) before mapping —
    // matches LibretroDeviceType.deviceMask on the Swift side.
    NSUInteger libretroType = ((NSUInteger)stored) & 0xFF;
    NSString *mapped = nil;
    switch (self.systemType) {
        case MednaSystemSNES:
            switch (libretroType) {
                case 1: mapped = @"gamepad"; break;     // RETRO_DEVICE_JOYPAD
                case 2: mapped = @"mouse"; break;       // RETRO_DEVICE_MOUSE
                case 4: mapped = @"superscope"; break;  // RETRO_DEVICE_LIGHTGUN
                default: break;
            }
            break;
        case MednaSystemNES:
            switch (libretroType) {
                case 1: mapped = @"gamepad"; break;
                case 4: mapped = @"zapper"; break;
                default: break;
            }
            break;
        case MednaSystemPSX:
            switch (libretroType) {
                case 1: mapped = @"gamepad"; break;
                case 5: mapped = @"dualshock"; break;   // RETRO_DEVICE_ANALOG
                case 2: mapped = @"mouse"; break;
                case 4: mapped = @"guncon"; break;
                default: break;
            }
            break;
        case MednaSystemSS:
            switch (libretroType) {
                case 1: mapped = @"gamepad"; break;
                case 5: mapped = @"3dpad"; break;       // 3D Control Pad ("Nights pad")
                case 2: mapped = @"mouse"; break;
                case 4: mapped = @"gun"; break;         // Stunner / Virtua Gun
                default: break;
            }
            break;
        case MednaSystemPCE:
        case MednaSystemPCECD:
            switch (libretroType) {
                case 1: mapped = @"gamepad"; break;
                case 2: mapped = @"mouse"; break;
                default: break;
            }
            break;
        default:
            break;
    }

    if (mapped != nil) {
        NSLog(@"[Mednafen.PortDevices] port %ld override -> %@", (long)port, mapped);
        return mapped;
    }
    return defaultName;
}

@end
