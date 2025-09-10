//
//  PVDolphin+Video.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Video.h"

#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>

#include "Common/GL/GLContext.h"
#include "Common/GL/GLUtil.h"
#include "Common/Logging/Log.h"
#include "Common/Version.h"
#include "Core/Config/GraphicsSettings.h"
#include "Core/Config/MainSettings.h"
#include "Core/ConfigManager.h"
#include "Core/Core.h"
#include "Core/Host.h"
#include "Core/System.h"

#include "VideoCommon/AsyncRequests.h"
#include "VideoCommon/Fifo.h"
#include "VideoCommon/VertexLoaderManager.h"
#include "VideoCommon/VideoBackendBase.h"
#include "VideoCommon/VideoCommon.h"
#include "VideoCommon/VideoConfig.h"

#include "VideoBackends/Null/NullGfx.h"
#include "VideoBackends/OGL/VideoBackend.h"
#include "VideoBackends/Vulkan/VideoBackend.h"
#include "VideoBackends/Vulkan/VulkanContext.h"

@implementation PVDolphinCoreBridge (Video)

# pragma mark - Methods
- (void)videoInterrupt {
		//dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
		//dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers {
	//[self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    if (![self isEmulationPaused] && !skip) {
        auto& system = Core::System::GetInstance();

        // Only execute frame if Dolphin is running
        if (Core::GetState(system) == Core::State::Running) {
            // Process any pending host jobs
            Core::HostDispatchJobs(system);

            // Dolphin handles its own frame rendering directly to Metal layer
            // The video output is managed by Dolphin's video backend
            // No frame buffer extraction needed - Dolphin renders directly
        }
    }
}

- (void)executeFrame {
	[self executeFrameSkippingFrame:NO];
}

# pragma mark - Properties

- (CGSize)bufferSize {
	return CGSizeMake(0,0);
}

- (CGRect)screenRect {
	return CGRectMake(0, 0, self.videoWidth * self.resFactor , self.videoHeight * self.resFactor);
}

- (CGSize)aspectSize {
	return CGSizeMake(self.videoWidth, self.videoHeight);
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
@end
