//
//  PVPlayCore.h
//  PVPlay
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface PVPlayCore : PVEmulatorCore <PVPS2SystemResponderClient>
{
	uint8_t padData[4][PVDreamcastButtonCount];
	int8_t xAxis[4];
	int8_t yAxis[4];
    int videoDepthBitDepth; // eh
    int videoWidth;
    int videoHeight;
    int videoBitDepth;
    int8_t gsPreference;
    int8_t resFactor;

	float sampleRate;

	BOOL isNTSC;
@public
    dispatch_queue_t _callbackQueue;
}

@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int8_t resFactor;

@property (nonatomic, assign) int8_t gsPreference;

-(void)setupControllers;
-(void)executeFrameSkippingFrame:(BOOL)skip;

@end

@interface PVPlayCore (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
@end

extern __weak PVPlayCore *_current;
