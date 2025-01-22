//
//  PVBeetlePSXCore.h
//  PVBeetlePSX
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import PVCoreBridge;
#import <PVCoreBridgeRetro/PVCoreBridgeRetro.h>

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

//PVCORE_DIRECT_MEMBERS
@interface PVBeetlePSXCore : PVLibRetroGLESCoreBridge <PVPSXSystemResponderClient> {
//	uint8_t padData[4][PVDOSButtonCount];
//	int8_t xAxis[4];
//	int8_t yAxis[4];
//	//    int videoWidth;
//	//    int videoHeight;
//	//    int videoBitDepth;
//	int videoDepthBitDepth; // eh
//
//	float sampleRate;
//
//	BOOL isNTSC;
//@public
//    dispatch_queue_t _callbackQueue;
}
//
//@property (nonatomic, assign) int videoWidth;
//@property (nonatomic, assign) int videoHeight;
//@property (nonatomic, assign) int videoBitDepth;
//
//- (void) swapBuffers;
//- (const char *) getBundlePath;
//- (void) SetScreenSize:(int)width :(int)height;

@end
