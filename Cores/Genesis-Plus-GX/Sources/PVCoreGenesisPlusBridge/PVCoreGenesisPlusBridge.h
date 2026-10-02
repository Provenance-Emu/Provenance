//
//  PVCoreGenesisPlusBridge.h
//  Provenance
//
//  Created by Joseph Mattiello on 09/29/2024.
//  Copyright (c) 2024 Provenance EMU. All rights reserved.
//

@import Foundation;
@import PVCoreObjCBridge;

@protocol ObjCBridgedCoreBridge;
@protocol PVGenesisSystemResponderClient;
@protocol PVSG1000SystemResponderClient;
@protocol LightGunResponder;
typedef enum PVGenesisButton: NSInteger PVGenesisButton;
typedef enum PVSG1000Button: NSInteger PVSG1000Button;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface PVCoreGenesisPlusBridge : PVCoreObjCBridge <ObjCBridgedCoreBridge, PVGenesisSystemResponderClient, PVSG1000SystemResponderClient, LightGunResponder>


- (void)didPushGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;

- (void)didPushSG1000Button:(PVSG1000Button)button forPlayer:(NSInteger)player;
- (void)didReleaseSG1000Button:(PVSG1000Button)button forPlayer:(NSInteger)player;

/// Called on the emulation thread at the end of every emulated frame. The
/// emulation loop runs inside this bridge, so the Swift core's
/// `executeFrame()` is never called.
@property (nonatomic, copy, nullable) void (^frameCompletedHandler)(void);
@end

@interface PVCoreGenesisPlusBridge (LightGun)
/// The port index used for the active light gun device (0 for port A, 4 for port B when using Justifiers).
@property (nonatomic, readonly) NSInteger lightGunPort;
@end

/// Raw emulator memory for RetroAchievements. All buffers are stored exactly as
/// upstream GPGX's libretro port hands them to RetroArch (68K memory keeps its
/// host-swapped 16-bit words), so they are read without any byte swapping.
/// Only meaningful after the game has loaded.
@interface PVCoreGenesisPlusBridge (RetroAchievements)
/// Pointer to libretro RETRO_MEMORY_SYSTEM_RAM (Genesis 68K RAM, SMS/GG/SG-1000 work RAM).
@property (nonatomic, readonly, nullable) void *systemRAMPtr;
/// Size in bytes of the system RAM, computed the way upstream GPGX's
/// `retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM)` does: 64 KiB on 16-bit
/// hardware; 8 KiB on SMS/GG; 1 KiB / 2 KiB on SG-1000 / SG-1000 II, plus any
/// SG-1000 on-board cartridge RAM, which GPGX keeps at work RAM offset 0x2000.
@property (nonatomic, readonly) NSUInteger systemRAMSize;
/// Cartridge RAM (libretro RETRO_MEMORY_SAVE_RAM): MD SRAM or SMS/GG cartridge
/// RAM. NULL when the cartridge has none.
@property (nonatomic, readonly, nullable) void *cartridgeRAMPtr;
/// Capacity in bytes of the cartridge RAM buffer, or 0 when there is none.
@property (nonatomic, readonly) NSUInteger cartridgeRAMSize;
/// Sega CD 512 KiB PRG-RAM. NULL unless Sega CD hardware is emulated.
@property (nonatomic, readonly, nullable) void *segaCDPrgRAMPtr;
/// Size in bytes of the Sega CD PRG-RAM, or 0 without Sega CD hardware.
@property (nonatomic, readonly) NSUInteger segaCDPrgRAMSize;
/// Sega CD Word RAM in its 2M layout (the main CPU's view at $200000). NULL
/// unless Sega CD hardware is emulated. In 1M mode GPGX moves the live data
/// into two separate 128 KiB banks, so this buffer holds the last 2M contents.
@property (nonatomic, readonly, nullable) void *segaCDWordRAMPtr;
/// Size in bytes of the 2M Word RAM buffer, or 0 without Sega CD hardware.
@property (nonatomic, readonly) NSUInteger segaCDWordRAMSize;
@end

@interface PVCoreGenesisPlusBridge (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error;
- (void)resetCheatCodes;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
