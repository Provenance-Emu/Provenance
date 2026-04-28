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
@end

@interface PVCoreGenesisPlusBridge (LightGun)
/// The port index used for the active light gun device (0 for port A, 4 for port B when using Justifiers).
@property (nonatomic, readonly) NSInteger lightGunPort;
@end

@interface PVCoreGenesisPlusBridge (RetroAchievements)
/// Pointer to libretro RETRO_MEMORY_SYSTEM_RAM (Genesis 68K RAM, SMS/GG/SG-1000 work RAM).
@property (nonatomic, readonly, nullable) void *systemRAMPtr;
/// Size in bytes of the active system RAM region.
@property (nonatomic, readonly) NSUInteger systemRAMSize;
@end

@interface PVCoreGenesisPlusBridge (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error;
- (void)resetCheatCodes;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
