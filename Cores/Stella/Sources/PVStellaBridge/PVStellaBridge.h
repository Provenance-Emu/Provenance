/*
 Copyright (c) 2009, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

@import Foundation;
@import PVStellaCPP;
@import PVCoreObjCBridge;

#if !__swift__
@import PVEmulatorCore;
@import PVCoreBridge;
#else
@protocol ObjCBridgedCoreBridge;
@protocol PV2600SystemResponderClient;
@protocol EmulatorCoreVideoDelegate;
typedef enum PV2600Button: NSInteger PV2600Button;
#endif

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

// Callback method to fetch options of NSObject from String
typedef id _Nullable (^PVStellaBridgeOptionHandler)(NSString * _Nonnull option);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
//PVCORE_DIRECT_MEMBERS
@interface PVStellaBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, EmulatorCoreVideoDelegate>
#pragma clang diagnostic pop

-(instancetype)initWithOptionHandler:(PVStellaBridgeOptionHandler) optionHandler NS_DESIGNATED_INITIALIZER;
@property (readonly, nonatomic, copy) PVStellaBridgeOptionHandler optionHandler;

// MARK: Core
- (void)loadFileAtPath:(NSString *)path error:(NSError * __autoreleasing *)error;
- (void)executeFrameSkippingFrame:(BOOL)skip;
- (void)executeFrame;
- (void)swapBuffers;
- (void)stopEmulation;
- (void)resetEmulation;

// MARK: Output
- (CGRect)screenRect;
- (const void *)videoBuffer;
- (NSTimeInterval)frameInterval;
- (BOOL)rendersToOpenGL;

// MARK: Input
- (void)pollControllers;

// MARK: Save States
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *)) __attribute__((noescape)) block;
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *)) __attribute__((noescape)) block;
@end

@interface PVStellaBridge (PV2600SystemResponderClient) <PV2600SystemResponderClient>
- (void)didPushPV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player;
- (void)didReleasePV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
