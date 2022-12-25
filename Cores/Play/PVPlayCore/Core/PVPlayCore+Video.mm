//
//  PVPlay+Video.m
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore+Video.h"
#import "PVPlayCore.h"

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#import <GLKit/GLKit.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLKit/GLKit.h>
#endif
#include "../AppConfig.h"
#include "PreferenceDefs.h"
#include "PH_Generic.h"
#include "PS2VM.h"
#include "CGSH_Provenance_OGL.h"

extern CGSH_Provenance_OGL *gsHandler;
extern CPH_Generic *padHandler;
extern UIView *m_view;
extern CPS2VM *_ps2VM;

//#import "PS2VM.h"
//#import "gs/GSH_OpenGL/GSH_OpenGL.h"
//#import "PadHandler.h"
//#import "SoundHandler.h"
//#import "PS2VM_Preferences.h"
//#import "AppConfig.h"
//#import "StdStream.h"
void MakeCurrentThreadRealTime();

@implementation PVPlayCore (Video)

# pragma mark - Methods


- (void)videoInterrupt {
        //dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        //dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers {
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    // The Play! handles the loop (Set GS Handler constructor to false, will manually step)
    //dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    /*
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MakeCurrentThreadRealTime();
    });
    //dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
    if (_ps2VM
        && _ps2VM->GetStatus() != CVirtualMachine::PAUSED
        && !shouldStop
        && _ps2VM->GetPadHandler()
        && _ps2VM->GetGSHandler()) {
        [self pollControllers];
        if(self.gsPreference == PREFERENCE_VALUE_VIDEO_GS_HANDLER_OPENGL)
            gsHandler->ProcessSingleFrame();
    }
    */
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

# pragma mark - Properties

- (CGSize)bufferSize {
    return CGSizeMake(0,0);
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, self.videoWidth * self.resFactor, self.videoHeight * self.resFactor);
}

- (CGSize)aspectSize {
    return CGSizeMake(self.videoWidth * self.resFactor, self.videoHeight * self.resFactor);
}

- (BOOL)rendersToOpenGL {
    return YES;
}

- (BOOL)isDoubleBuffered {
    return YES;
}

- (const void *)videoBuffer {
    return NULL;
}

- (GLenum)pixelFormat {
    return GL_RGBA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

//- (GLenum)depthFormat {
//        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
//    return GL_DEPTH_COMPONENT24;
//}
@end
