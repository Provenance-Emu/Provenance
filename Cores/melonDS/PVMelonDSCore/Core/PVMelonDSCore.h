//
//  PVMelonDSCore.h
//  PVMelonDS
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVCoreBridgeRetro/PVCoreBridgeRetro.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

@protocol PVDSSystemResponderClient;
typedef enum PVDSButton: NSInteger PVDSButton;

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
__attribute__((visibility("default")))
@interface PVMelonDSCoreBridge : PVLibRetroCoreBridge <PVDSSystemResponderClient> {
#pragma clang diagnostic pop
@public
    dispatch_queue_t _callbackQueue;
}

@end

NS_HEADER_AUDIT_END(nullability, sendability)
