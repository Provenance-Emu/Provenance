//
//  PVDolphin+Video.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Video.h"
#import "PVDolphinCore.h"

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

#include "VideoCommon/AsyncRequests.h"
#include "VideoCommon/Fifo.h"
#include "VideoCommon/RenderBase.h"
#include "VideoCommon/VertexLoaderManager.h"
#include "VideoCommon/VideoBackendBase.h"
#include "VideoCommon/VideoCommon.h"
#include "VideoCommon/VideoConfig.h"

#include "VideoBackends/Null/NullRender.h"
#include "VideoBackends/OGL/OGLRender.h"
#include "VideoBackends/OGL/VideoBackend.h"
#include "VideoBackends/Vulkan/VideoBackend.h"
#include "VideoBackends/Vulkan/VulkanContext.h"

@implementation PVDolphinCore (Video)

# pragma mark - Methods
- (void)videoInterrupt {
		//dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
		//dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers {
	//[self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
	//	if (![self isEmulationPaused])
	//	 {
	//		 if(!dol_host->CoreRunning()) {
	//		 dol_host->Pause(false);
	//		 }
	//
	//	   dol_host->UpdateFrame();
	//	 }
	//dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	//dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
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
