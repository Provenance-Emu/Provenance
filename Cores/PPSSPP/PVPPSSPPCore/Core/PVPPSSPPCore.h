//
//  PVPPSSPPCore.h
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#import <PVSupport/PVSupport.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

#define MASKED_PSP_MEMORY 1
#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface PVPPSSPPCore : PVEmulatorCore
<PVPSPSystemResponderClient>
{
	uint8_t padData[4][PVPSPButtonCount];
	int8_t xAxis[4];
	int8_t yAxis[4];
	int videoWidth;
	int videoHeight;
	int videoBitDepth;
	int videoDepthBitDepth; // eh
	int8_t gsPreference;
	int8_t resFactor;
	int8_t cpuType;
	int8_t taOption;
	int8_t tuOption;
	int8_t tfOption;
	int8_t tutypeOption;
	int8_t msaa;
    int8_t volume;
    BOOL stretchOption;
	BOOL fastMemory;
	float sampleRate;
	BOOL isNTSC;
	BOOL isPaused;
	BOOL _isInitialized;
	UIViewController *m_view_controller;
	EAGLContext* m_gl_context;
	CAMetalLayer* m_metal_layer;
	CAEAGLLayer *m_gl_layer;
@public
	dispatch_queue_t _callbackQueue;
}
@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int videoBitDepth;
@property (nonatomic, assign) int8_t gsPreference;
@property (nonatomic, assign) int8_t resFactor;
@property (nonatomic, assign) int8_t cpuType;
@property (nonatomic, assign) int8_t taOption;
@property (nonatomic, assign) int8_t tuOption;
@property (nonatomic, assign) int8_t tutypeOption;
@property (nonatomic, assign) int8_t tfOption;
@property (nonatomic, assign) int volume;
@property (nonatomic, assign) bool stretchOption;
@property (nonatomic, assign) int8_t msaa;
@property (nonatomic, assign) bool fastMemory;
@property (nonatomic, assign) bool isPaused;
@property (nonatomic, assign) bool isViewReady;
@property (nonatomic, assign) bool isGFXReady;
@property (nonatomic, assign) int8_t buttonPref;
- (void) runVM;
- (void) stopVM:(bool)deinitViews;
- (void) setupVideo;
- (void) setupView;
- (void) setupEmulation;
- (void) refreshScreenSize;
- (void) startVM:(UIView *)view;
- (void) setupControllers;
- (void) pollControllers;
- (void) gamepadEventOnPad:(int)player button:(int)button action:(int)action;
- (void) gamepadEventIrRecenter:(int)action;
- (BOOL) setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
-(void) optionUpdated:(NSNotification *)notification;
@end
@interface CLLocationManager : NSObject
@end
static __weak PVPPSSPPCore *_current;
