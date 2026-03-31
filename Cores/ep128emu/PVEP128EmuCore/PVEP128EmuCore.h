//
//  PVEP128EmuCore.h
//  PVEP128Emu
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PVCoreBridgeRetro/PVCoreBridgeRetro.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

@protocol PVEP128SystemResponderClient;

// TODO: Is this the wrong protocol? This should be ZXSpectrum? Is it just the same so I did't bother to make a new one?
// Why am i retarded? @JoeMatt
@protocol PVMSXSystemResponderClient;

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
__attribute__((visibility("default")))
@interface PVEP128EmuCoreBridge : PVLibRetroCoreBridge <PVEP128SystemResponderClient, PVMSXSystemResponderClient>
#pragma clang diagnostic pop
@end
