////
////  PVEmulatorCore.h
////  PVSupport
////
////  Created by Joseph Mattiello on 1/20/19.
////  Copyright © 2019 Provenance Emu. All rights reserved.
////
//
//#import <Foundation/Foundation.h>
//#import <PVSupport/PVSupport-Swift.h>
//
//NS_ASSUME_NONNULL_BEGIN
//
//@interface PVEmulatorCore : NSObject {
//    dispatch_queue_t lockQueue;
//}
//@property (nonatomic, assign) BOOL shouldStop;
//@property (nonatomic, assign) BOOL shouldResyncTime;
//@property (nonatomic, strong) NSDictionary<NSNumber*,OERingBuffer*>  *ringBuffers;
//
//
//@property (nonatomic, assign) double emulationFPS;
//@property (nonatomic, assign) double renderFPS;
//
//@property(weak)     id<PVAudioDelegate>    audioDelegate;
//@property(weak)     id<PVRenderDelegate>   renderDelegate;
//
//@property (nonatomic, assign, assign) BOOL isRunning;
//@property (nonatomic, copy) NSString *romName;
//@property (nonatomic, copy) NSString *saveStatesPath;
//@property (nonatomic, copy) NSString *batterySavesPath;
//@property (nonatomic, copy) NSString *BIOSPath;
//@property (nonatomic, copy) NSString *systemIdentifier;
//@property (nonatomic, copy) NSString *coreIdentifier;
//@property (nonatomic, strong) NSString* romMD5;
//@property (nonatomic, strong) NSString* romSerial;
////@property (nonatomic, assign) BOOL supportsSaveStates;
////@property (nonatomic, readonly) BOOL supportsRumble;
//
//@property (nonatomic, assign) GameSpeed gameSpeed;
////@property (nonatomic, readonly, getter=isSpeedModified) BOOL speedModified;
//
//@property (nonatomic, strong, nullable) GCController *controller1;
//@property (nonatomic, strong, nullable) GCController *controller2;
//@property (nonatomic, strong, nullable) GCController *controller3;
//@property (nonatomic, strong, nullable) GCController *controller4;
//
//@property (nonatomic, strong, readonly, nonnull) NSLock  *emulationLoopThreadLock;
//@property (nonatomic, strong, readonly, nonnull) NSCondition  *frontBufferCondition;
//@property (nonatomic, strong, readonly, nonnull) NSLock  *frontBufferLock;
//@property (nonatomic, assign) BOOL isFrontBufferReady;
//@property (nonatomic, assign) GLESVersion glesVersion;
////@property (nonatomic, readonly) GLenum depthFormat;
//
////@property (nonatomic, readonly) CGRect screenRect;
////@property (nonatomic, readonly) CGSize aspectSize;
////@property (nonatomic, readonly) CGSize bufferSize;
////@property (nonatomic, readonly) BOOL isDoubleBuffered;
////@property (nonatomic, readonly) BOOL rendersToOpenGL;
////@property (nonatomic, readonly) GLenum pixelFormat;
////@property (nonatomic, readonly) GLenum pixelType;
////@property (nonatomic, readonly) GLenum internalPixelFormat;
////@property (nonatomic, readonly) NSTimeInterval frameInterval;
////@property (nonatomic, readonly) double audioSampleRate;
////@property (nonatomic, readonly) NSUInteger channelCount;
////@property (nonatomic, readonly) NSUInteger audioBufferCount;
////@property (nonatomic, readonly) NSUInteger audioBitDepth;
////@property (nonatomic, readonly) BOOL isEmulationPaused;
////@property (nonatomic, readonly, nullable) const void * videoBuffer;
//@end
//
//NS_ASSUME_NONNULL_END
