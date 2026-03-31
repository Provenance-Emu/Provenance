//
//  PVMiniVMacCore.h
//  PVMiniVMac
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVCoreBridgeRetro/PVCoreBridgeRetro.h>

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@protocol PVDOSSystemResponderClient;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
__attribute__((visibility("default")))
@interface PVMiniVMacCore : PVLibRetroCoreBridge <PVDOSSystemResponderClient>
#pragma clang diagnostic pop
@end
