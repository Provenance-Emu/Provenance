/*
 Copyright (c) 2010, OpenEmu Team

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
@import GameController;
@import PVCoreObjCBridge;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

// Forward Declerations (until I can fix importing PVCoreBridge in ObjC
//const NSInteger PVN64ButtonCount = 19;
@protocol ObjCBridgedCoreBridge;
@protocol PVN64SystemResponderClient;
typedef enum PVN64Button: NSInteger PVN64Button;

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVMupenBridge : PVCoreObjCBridge <ObjCBridgedCoreBridge, PVN64SystemResponderClient>
#pragma clang diagnostic pop
{
//@private
    @public
    uint8_t padData[4][19];
    int8_t xAxis[4];
    int8_t yAxis[4];

    int controllerMode[4];
    NSOperationQueue * __nonnull _inputQueue;
}

@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int videoBitDepth;

@property (nonatomic, assign) double mupenSampleRate;
@property (nonatomic, assign) int videoDepthBitDepth;
@property (nonatomic, assign) BOOL isNTSC;
@property (nonatomic, assign) BOOL dualJoystick;

@property (nonatomic) EAGLContext *_externalGLContext;
@property (nonatomic) BOOL _framebufferInitialized;
@property (nonatomic) GLuint _defaultFramebuffer;
@property (nonatomic) int _preferredRefreshRate;
@property (nonatomic) const char * _Nullable * _Nullable _vulkanExtensionNames;

- (void) videoInterrupt;
- (void) setMode:(NSInteger)mode forController:(NSInteger)controller;
- (void) swapBuffers;
- (BOOL) findExternalGLContext;
@end

extern __weak PVMupenBridge * __nullable _current;

NS_HEADER_AUDIT_END(nullability, sendability)
