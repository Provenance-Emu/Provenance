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
typedef enum PVGenesisButton: NSInteger PVGenesisButton;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVCoreGenesisPlusBridge : PVCoreObjCBridge <ObjCBridgedCoreBridge, PVGenesisSystemResponderClient>
#pragma clang diagnostic pop


- (void)didPushGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
