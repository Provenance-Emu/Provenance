//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibRetroGLESCore.h"

#include "dynamic.h"
#include "video_driver.h"

#include "core.h"
#include "runloop.h"
@import PVLoggingObjC;
@import PVCoreBridge;

#include <dlfcn.h>
#include <string.h>
#include "dynamic.h"
#include <dynamic/dylib.h>

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

bool inside_loop     = true;
//static bool first_run = true;
volatile bool has_init = false;

extern bool core_frame(retro_ctx_frame_info_t *info);
extern bool runloop_ctl(enum runloop_ctl_state state, void *data);

#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <assert.h>
#include <poll.h>
#include <termios.h>
#include <fcntl.h>
#include <semaphore.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <unistd.h>

// Real-time threading functions are defined in PVSupport - using external declarations
extern void move_pthread_to_realtime_scheduling_class(pthread_t pthread);
extern void MakeCurrentThreadRealTime(void);

@interface PVLibRetroGLESCoreBridge ()
{
    dispatch_semaphore_t glesWaitToBeginFrameSemaphore;
    dispatch_semaphore_t coreWaitToEndFrameSemaphore;
    dispatch_semaphore_t coreWaitForExitSemaphore;

    /// Signaled when runGLESRenderThread fully exits its loop
    dispatch_semaphore_t _renderThreadExitSemaphore;

    dispatch_queue_t _callbackQueue;
    NSMutableDictionary *_callbackHandlers;

    /// Hardware rendering state
    struct retro_hw_render_callback *hw_render_callback;
    enum retro_hw_context_type current_context_type;
    BOOL hardware_context_active;

    /// Core-provided callbacks — stored here because the frontend must not
    /// overwrite the struct fields the core set (per libretro.h spec).
    retro_hw_context_reset_t _coreContextReset;
    retro_hw_context_reset_t _coreContextDestroy;

    /// Tracks whether context_reset has been deferred until FBO is ready
    BOOL _pendingContextReset;

    /// FBO name provided by the render delegate (IOSurface-backed)
    GLuint _presentationFBO;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    EAGLContext *hardware_context;
#else
    NSOpenGLContext *hardware_context;
#endif

    // Vulkan state (when using MoltenVK)
    void *vulkan_library;
    VkInstance vulkan_instance;
    VkDevice vulkan_device;
    VkQueue vulkan_queue;
    VkPhysicalDevice vulkan_physical_device;

    // Vulkan function pointers
    PFN_vkVoidFunction (*vkGetInstanceProcAddr)(VkInstance instance, const char* pName);
    PFN_vkVoidFunction (*vkGetDeviceProcAddr)(VkDevice device, const char* pName);
    VkResult (*vkCreateInstance)(const void* pCreateInfo, const void* pAllocator, VkInstance* pInstance);
    void (*vkDestroyInstance)(VkInstance instance, const void* pAllocator);
    VkResult (*vkEnumeratePhysicalDevices)(VkInstance instance, uint32_t* pPhysicalDeviceCount, VkPhysicalDevice* pPhysicalDevices);
    VkResult (*vkCreateDevice)(VkPhysicalDevice physicalDevice, const void* pCreateInfo, const void* pAllocator, VkDevice* pDevice);
    void (*vkDestroyDevice)(VkDevice device, const void* pAllocator);
    void (*vkGetDeviceQueue)(VkDevice device, uint32_t queueFamilyIndex, uint32_t queueIndex, VkQueue* pQueue);
}
@end

void input_poll(void);

void gl_swap() {
    GET_CURRENT_OR_RETURN();
    [current swapBuffers];
}

// Forward declarations for hardware rendering callbacks (frontend-owned fields)
static uintptr_t hw_get_current_framebuffer(void);
static void* hw_get_proc_address(const char *symbol);

@implementation PVLibRetroGLESCoreBridge

- (instancetype)init {
    if (self = [super init]) {
        glesWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
        coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);
        coreWaitForExitSemaphore       = dispatch_semaphore_create(0);
        _renderThreadExitSemaphore     = dispatch_semaphore_create(0);

        hw_render_callback = NULL;
        current_context_type = RETRO_HW_CONTEXT_NONE;
        hardware_context_active = NO;
        hardware_context = nil;
        _coreContextReset = NULL;
        _coreContextDestroy = NULL;
        _pendingContextReset = NO;
        _presentationFBO = 0;

        vulkan_library = NULL;
        vulkan_instance = NULL;
        vulkan_device = NULL;
        vulkan_queue = NULL;
        vulkan_physical_device = NULL;

        vkGetInstanceProcAddr = NULL;
        vkGetDeviceProcAddr = NULL;
        vkCreateInstance = NULL;
        vkDestroyInstance = NULL;
        vkEnumeratePhysicalDevices = NULL;
        vkCreateDevice = NULL;
        vkDestroyDevice = NULL;
        vkGetDeviceQueue = NULL;
    }
    return self;
}

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
-(EAGLContext*)bestContext {
    EAGLContext* context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    self.glesVersion = GLESVersion3;
    if (context == nil)
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.glesVersion = GLESVersion2;
    }

    return context;
}
#endif

//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error {
//#if !TARGET_OS_MACCATALYST
//    EAGLContext* context = [self bestContext];
//    ILOG(@"%i", context.API);
//#endif
//
//    return [super loadFileAtPath:path error:error];
//}

- (BOOL)rendersToOpenGL { return YES; }
- (BOOL)isDoubleBuffered { return YES; }
// Use dynamic pixel format from base class instead of hardcoded values
// This allows the GLES core to adapt to different pixel formats (RGB565, XRGB8888, etc.)
- (GLenum)pixelFormat { return [super pixelFormat]; }
- (GLenum)pixelType { return [super pixelType]; }
- (GLenum)internalPixelFormat { return GL_RGBA; }
- (GLenum)depthFormat {
        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
    return GL_DEPTH_COMPONENT16;
}
- (const void *)videoBuffer {
    // For hardware rendering, return NULL (core renders directly to OpenGL)
    // For software rendering, delegate to base class to get the actual video buffer
    if (current_context_type != RETRO_HW_CONTEXT_NONE) {
        return NULL; // Hardware rendering
    } else {
        return [super videoBuffer]; // Software rendering
    }
}

- (dispatch_time_t)frameTime {
    float frameTime = 1.0/[self frameInterval];
//    __block BOOL expired = NO;
    dispatch_time_t killTime = dispatch_time(DISPATCH_TIME_NOW, frameTime * NSEC_PER_SEC);
    return killTime;
}

- (void)videoInterrupt {
//    dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
//
//    dispatch_semaphore_wait(glesWaitToBeginFrameSemaphore, [self frameTime]);
}

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
//    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
//
//    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)setPauseEmulation:(BOOL)flag
{
    [super setPauseEmulation:flag];

    if (flag)
    {
        dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
        [self.frontBufferCondition lock];
        [self.frontBufferCondition signal];
        [self.frontBufferCondition unlock];
    }
}

- (void)stopEmulation {
    has_init = false;

    self.shouldStop = YES;
    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);

    /// Wake the render thread from frontBufferCondition so it can see shouldStop
    /// and exit. The emu thread waits for the render thread to exit before
    /// calling contextDestroy, so the render thread must not be blocked here.
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];

    /// Wait for the emu thread to exit — it waits for the render thread,
    /// then calls contextDestroy on the emu thread, then signals this.
    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);

    [super stopEmulation];
}

- (void)resetEmulation {
    [super resetEmulation];
    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
}


- (void)startEmulation {
    if(!self.isRunning) {
        [super startEmulation];
        [NSThread detachNewThreadSelector:@selector(runGLESRenderThread) toTarget:self withObject:nil];
    }
}


void* libPvr_GetRenderTarget() {
    return 0;
}

void* libPvr_GetRenderSurface() {
    return 0;

}

bool gl_init(void*, void*) {
    return true;
}

bool gles_init()
{

    if (!gl_init((void*)libPvr_GetRenderTarget(),
                 (void*)libPvr_GetRenderSurface()))
            return false;

#if defined(GLES) && HOST_OS != OS_DARWIN && !defined(TARGET_NACL32)
    #ifdef TARGET_PANDORA
    fbdev=open("/dev/fb0", O_RDONLY);
    #else
    eglSwapInterval(gl.setup.display,1);
    #endif
#endif

    //clean up all buffers ...
    for (int i=0;i<10;i++)
    {
        glClearColor(0.f, 0.f, 0.f, 0.f);
        glClear(GL_COLOR_BUFFER_BIT);
        gl_swap();
    }

    return true;
}

static bool video_driver_cached_frame(void)
{
   retro_ctx_frame_info_t info;
//   void *recording  = recording_driver_get_data_ptr();

   if (runloop_ctl(RUNLOOP_CTL_IS_IDLE, NULL))
      return false; /* Maybe return false here for indication of idleness? */

   /* Cannot allow recording when pushing duped frames. */
//   recording_driver_clear_data_ptr();

   /* Not 100% safe, since the library might have
    * freed the memory, but no known implementations do this.
    * It would be really stupid at any rate ...
    */
   info.data        = NULL;
   info.width       = video_driver_state.frame_cache.width;
   info.height      = video_driver_state.frame_cache.height;
   info.pitch       = video_driver_state.frame_cache.pitch;

   if (video_driver_state.frame_cache.data != RETRO_HW_FRAME_BUFFER_VALID)
      info.data = video_driver_state.frame_cache.data;

   core_frame(&info);

//   recording_driver_set_data_ptr(recording);

   return true;
}

- (void)runGLESRenderThread {
    @autoreleasepool
    {
        [[NSThread currentThread] setName:@"runGLESRenderThread"];

        /// Ask the render delegate to create the IOSurface-backed FBO and GL contexts
        [self.renderDelegate startRenderingOnAlternateThread];

        /// Capture the presentation FBO that the render delegate just created
        [self captureRenderDelegateFBO];

        /// context_reset is NOT fired here — it must run on the emu thread
        /// because cores assume context_reset and retro_run share the same thread/context.
        /// libretroMain will fire it after making hardware_context current.

        [NSThread detachNewThreadSelector:@selector(runGLESEmuThread) toTarget:self withObject:nil];

        /// Wait for the emu thread to signal initialization. Also bail early if
        /// shouldStop is set to avoid spinning forever on early shutdown.
        while (!has_init && !self.shouldStop) {}
        while ( !self.shouldStop )
        {
            [self.frontBufferCondition lock];
            while (!self.shouldStop && self.isFrontBufferReady) [self.frontBufferCondition wait];
            [self.frontBufferCondition unlock];

            if (self.shouldStop) break;

            while ( !self.shouldStop
                   && !video_driver_cached_frame()
                   ) {}

            if (!self.shouldStop) {
                [self swapBuffers];
            }
        }

        /// Signal that the render thread has fully exited its loop.
        /// The emu thread waits on this before calling contextDestroy.
        dispatch_semaphore_signal(_renderThreadExitSemaphore);
    }
}



- (void)runGLESEmuThread {
    @autoreleasepool
    {
        [[NSThread currentThread] setName:@"runGLESEmuThread"];
        [self libretroMain];
        // Core returns

        // Unlock rendering thread
        dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        [super stopEmulation];
    }
}


- (void)libretroMain {

    MakeCurrentThreadRealTime();

    /// Make the core's dedicated GL context current on the emu thread
    [self makeGLContextCurrent];

    /// Fire any deferred context_reset on the emu thread — cores assume
    /// context_reset and retro_run share the same thread and GL context.
    if (_pendingContextReset && _coreContextReset) {
        ILOG(@"Firing deferred context_reset on emu thread (FBO=%u)", _presentationFBO);
        [self contextReset];
        _pendingContextReset = NO;
    }

    has_init = true;

    do {
        switch (self->core_poll_type)
        {
            case POLL_TYPE_EARLY:
                input_poll();
                break;
            case POLL_TYPE_LATE:
                core_input_polled = false;
                break;
        }

        /// Ensure GL context is current before each retro_run() —
        /// context can be lost if the app was backgrounded/foregrounded
        [self makeGLContextCurrent];

        /// Bind the presentation FBO so the core renders into the IOSurface-backed texture.
        /// Use glIsFramebuffer to guard against binding an FBO created in a different
        /// GL context (FBOs are not shared across EAGLContext sharegroups on iOS).
        if (_presentationFBO > 0 && glIsFramebuffer(_presentationFBO)) {
            glBindFramebuffer(GL_FRAMEBUFFER, _presentationFBO);
        } else if (_presentationFBO > 0) {
            WLOG(@"Presentation FBO %u is not valid in the current GL context — falling back to default framebuffer", _presentationFBO);
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
        }

        if (core->retro_run)
            core->retro_run();
        if (core_poll_type == POLL_TYPE_LATE && !core_input_polled)
            input_poll();
    } while(!self.shouldStop);

    /// Wake the render thread from any frontBufferCondition wait so it can exit
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];

    /// Wait for the render thread to fully exit before tearing down GL resources.
    /// This prevents races where the render thread is mid-frame in
    /// video_driver_cached_frame() or swapBuffers while we destroy the context.
    long renderThreadWaitResult = dispatch_semaphore_wait(_renderThreadExitSemaphore,
                                      dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
    if (renderThreadWaitResult != 0) {
        WLOG(@"Render thread did not exit within 2s — proceeding with context teardown anyway (may race)");
    }

    /// Tear down HW context on the emu thread that owns it, before signaling exit.
    [self contextDestroy];

    has_init = false;

    dispatch_semaphore_signal(coreWaitForExitSemaphore);
}

- (CGSize)bufferSize {
    return CGSizeMake(2048, 2048);
}

#pragma mark - Hardware Rendering Support

/// Called from the environment callback when a core requests hardware rendering.
/// Per libretro.h, context_reset and context_destroy are set by the core and
/// invoked by the frontend — we must NOT overwrite them. We store the core's
/// callbacks and only set the frontend-owned fields (get_current_framebuffer,
/// get_proc_address). The core's context_reset is deferred until the render
/// delegate creates the FBO (in runGLESRenderThread).
- (BOOL)setHardwareRenderCallback:(NSValue *)callbackValue {
    if (!callbackValue) {
        ELOG(@"Hardware render callback value is NULL");
        return NO;
    }

    hw_render_callback = (struct retro_hw_render_callback *)[callbackValue pointerValue];
    if (!hw_render_callback) {
        ELOG(@"Hardware render callback pointer is NULL");
        return NO;
    }

    current_context_type = hw_render_callback->context_type;

    ILOG(@"Libretro core requesting hardware context type: %d (depth=%d, stencil=%d, bottom_left=%d)",
         current_context_type,
         hw_render_callback->depth,
         hw_render_callback->stencil,
         hw_render_callback->bottom_left_origin);

    /// Store core-provided callbacks before touching the struct
    _coreContextReset = hw_render_callback->context_reset;
    _coreContextDestroy = hw_render_callback->context_destroy;

    /// Only set the fields the frontend is responsible for providing
    hw_render_callback->get_current_framebuffer = hw_get_current_framebuffer;
    hw_render_callback->get_proc_address = (retro_hw_get_proc_address_t)hw_get_proc_address;

    [self setupHardwareContext:current_context_type];

    /// Defer context_reset: the FBO doesn't exist yet because
    /// startRenderingOnAlternateThread hasn't run.
    /// runGLESRenderThread will fire context_reset after the FBO is ready.
    if (hardware_context_active) {
        _pendingContextReset = YES;
        ILOG(@"Hardware context created; context_reset deferred until FBO is ready");
    }

    return YES;
}

- (void)setupHardwareContext:(enum retro_hw_context_type)contextType {
    switch (contextType) {
        case RETRO_HW_CONTEXT_OPENGLES2:
        case RETRO_HW_CONTEXT_OPENGLES3:
        case RETRO_HW_CONTEXT_OPENGLES_VERSION:
            [self setupOpenGLESContext:contextType];
            break;

        case RETRO_HW_CONTEXT_OPENGL:
        case RETRO_HW_CONTEXT_OPENGL_CORE:
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
            [self setupOpenGLContext:contextType];
#else
            ELOG(@"Desktop OpenGL not supported on iOS/tvOS");
#endif
            break;

        case RETRO_HW_CONTEXT_VULKAN:
            [self setupVulkanContext];
            break;

        case RETRO_HW_CONTEXT_NONE:
            ILOG(@"Using software rendering (RETRO_HW_CONTEXT_NONE)");
            // Software rendering - no special context setup needed
            // The core will render to the video buffer directly
            break;

        default:
            ELOG(@"Unsupported or unknown hardware context type: %d", contextType);
            break;
    }
}

/// Creates an EAGLContext for the requested GL ES version. If the render
/// delegate already has a GL context, share its sharegroup so the core's
/// GL objects are visible to the IOSurface-backed FBO context.
- (void)setupOpenGLESContext:(enum retro_hw_context_type)contextType {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    EAGLRenderingAPI api;

    switch (contextType) {
        case RETRO_HW_CONTEXT_OPENGLES2:
            api = kEAGLRenderingAPIOpenGLES2;
            self.glesVersion = GLESVersion2;
            break;
        case RETRO_HW_CONTEXT_OPENGLES3:
        case RETRO_HW_CONTEXT_OPENGLES_VERSION:
        default:
            api = kEAGLRenderingAPIOpenGLES3;
            self.glesVersion = GLESVersion3;
            break;
    }

    ILOG(@"Attempting to create OpenGL ES context with API: %ld", (long)api);

    /// Try to share the render delegate's GL sharegroup so the core
    /// can render directly into the IOSurface-backed FBO
    EAGLContext *delegateContext = nil;
    if ([self.renderDelegate respondsToSelector:@selector(glContext)]) {
        delegateContext = [self.renderDelegate glContext];
    }

    if (delegateContext) {
        hardware_context = [[EAGLContext alloc] initWithAPI:api
                                                sharegroup:delegateContext.sharegroup];
        if (hardware_context) {
            ILOG(@"Created shared GL ES context with render delegate sharegroup");
        }
    }

    if (!hardware_context) {
        hardware_context = [[EAGLContext alloc] initWithAPI:api];
    }

    if (!hardware_context) {
        ELOG(@"Failed to create OpenGL ES context for API: %ld", (long)api);
        return;
    }

    hardware_context_active = YES;
    ILOG(@"OpenGL ES hardware context created successfully with API: %ld", (long)api);
#endif
}

#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
- (void)setupOpenGLContext:(enum retro_hw_context_type)contextType {
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 16,
        0
    };

    if (contextType == RETRO_HW_CONTEXT_OPENGL_CORE) {
        // Add core profile attributes for modern OpenGL
        NSOpenGLPixelFormatAttribute coreAttrs[] = {
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAColorSize, 24,
            NSOpenGLPFAAlphaSize, 8,
            NSOpenGLPFADepthSize, 16,
            NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
            0
        };
        memcpy(attrs, coreAttrs, sizeof(coreAttrs));
    }

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    if (!pixelFormat) {
        ELOG(@"Failed to create OpenGL pixel format");
        return;
    }

    hardware_context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    if (!hardware_context) {
        ELOG(@"Failed to create OpenGL context");
        return;
    }

    hardware_context_active = YES;
    ILOG(@"OpenGL hardware context created successfully");
}
#endif

- (void)setupVulkanContext {
    ILOG(@"Setting up Vulkan context via MoltenVK");

    // Load MoltenVK library with multiple fallback paths
    if (![self loadMoltenVKLibrary]) {
        ELOG(@"Failed to load MoltenVK library");
        return;
    }

    // Load essential Vulkan function pointers
    if (![self loadVulkanFunctions]) {
        ELOG(@"Failed to load Vulkan functions");
        [self unloadMoltenVKLibrary];
        return;
    }

    // Create Vulkan instance
    if (![self createVulkanInstance]) {
        ELOG(@"Failed to create Vulkan instance");
        [self unloadMoltenVKLibrary];
        return;
    }

    // Select physical device
    if (![self selectVulkanPhysicalDevice]) {
        ELOG(@"Failed to select Vulkan physical device");
        [self destroyVulkanInstance];
        [self unloadMoltenVKLibrary];
        return;
    }

    // Create logical device
    if (![self createVulkanDevice]) {
        ELOG(@"Failed to create Vulkan device");
        [self destroyVulkanInstance];
        [self unloadMoltenVKLibrary];
        return;
    }

    // Get device queue
    [self getVulkanDeviceQueue];

    hardware_context_active = YES;
    ILOG(@"Vulkan hardware context created successfully via MoltenVK");
}

- (void)destroyHardwareContext {
    if (!hardware_context_active) {
        return;
    }

    switch (current_context_type) {
        case RETRO_HW_CONTEXT_OPENGLES2:
        case RETRO_HW_CONTEXT_OPENGLES3:
        case RETRO_HW_CONTEXT_OPENGLES_VERSION:
        case RETRO_HW_CONTEXT_OPENGL:
        case RETRO_HW_CONTEXT_OPENGL_CORE:
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
            if ([EAGLContext currentContext] == hardware_context) {
                [EAGLContext setCurrentContext:nil];
            }
#endif
            hardware_context = nil;
            break;

        case RETRO_HW_CONTEXT_VULKAN:
            [self destroyVulkanDevice];
            [self destroyVulkanInstance];
            [self unloadMoltenVKLibrary];
            break;

        default:
            break;
    }

    hardware_context_active = NO;
    current_context_type = RETRO_HW_CONTEXT_NONE;
    hw_render_callback = NULL;
    _coreContextReset = NULL;
    _coreContextDestroy = NULL;
    _presentationFBO = 0;
    _pendingContextReset = NO;

    ILOG(@"Hardware context destroyed");
}

#pragma mark - Hardware Rendering Callbacks

// C callback functions set on the hw_render_callback struct (frontend-owned)
static uintptr_t hw_get_current_framebuffer(void) {
    GET_CURRENT_OR_RETURN(0);
    if ([current isKindOfClass:[PVLibRetroGLESCoreBridge class]]) {
        PVLibRetroGLESCoreBridge *glesCore = (PVLibRetroGLESCoreBridge *)current;
        return [glesCore getCurrentFramebuffer];
    }
    return 0;
}

static void* hw_get_proc_address(const char *symbol) {
    GET_CURRENT_OR_RETURN(NULL);
    if ([current isKindOfClass:[PVLibRetroGLESCoreBridge class]]) {
        PVLibRetroGLESCoreBridge *glesCore = (PVLibRetroGLESCoreBridge *)current;
        return [glesCore getProcAddress:symbol];
    }
    return NULL;
}

/// Called when the GL/Vulkan context has been created or recreated.
/// Performs frontend housekeeping (make context current, bind FBO) then
/// invokes the core's stored context_reset so it can create its GL resources.
- (void)contextReset {
    ILOG(@"Hardware context reset called (context_type=%d, FBO=%u)", current_context_type, _presentationFBO);

    switch (current_context_type) {
        case RETRO_HW_CONTEXT_OPENGLES2:
        case RETRO_HW_CONTEXT_OPENGLES3:
        case RETRO_HW_CONTEXT_OPENGLES_VERSION:
        case RETRO_HW_CONTEXT_OPENGL:
        case RETRO_HW_CONTEXT_OPENGL_CORE:
            [self makeGLContextCurrent];
            if (_presentationFBO > 0 && glIsFramebuffer(_presentationFBO)) {
                glBindFramebuffer(GL_FRAMEBUFFER, _presentationFBO);
            }
            break;

        case RETRO_HW_CONTEXT_VULKAN:
            ILOG(@"Vulkan context reset");
            break;

        default:
            break;
    }

    /// Invoke the core's context_reset so it can initialize its GL/Vulkan resources
    if (_coreContextReset) {
        ILOG(@"Invoking core's context_reset callback");
        _coreContextReset();
    }
}

/// Invokes the core's context_destroy callback then tears down frontend resources.
- (void)contextDestroy {
    ILOG(@"Hardware context destroy called");

    if (_coreContextDestroy) {
        ILOG(@"Invoking core's context_destroy callback");
        _coreContextDestroy();
    }

    [self destroyHardwareContext];
}

/// Returns the FBO the core should render into. For GL paths this is the
/// IOSurface-backed FBO created by PVMetalViewController, which is then
/// blitted to a Metal texture for display (zero-copy via IOSurface).
- (uintptr_t)getCurrentFramebuffer {
    switch (current_context_type) {
        case RETRO_HW_CONTEXT_OPENGLES2:
        case RETRO_HW_CONTEXT_OPENGLES3:
        case RETRO_HW_CONTEXT_OPENGLES_VERSION:
        case RETRO_HW_CONTEXT_OPENGL:
        case RETRO_HW_CONTEXT_OPENGL_CORE: {
            if (_presentationFBO > 0 && glIsFramebuffer(_presentationFBO)) {
                return (uintptr_t)_presentationFBO;
            }
            /// Fallback: try to capture FBO from the render delegate on demand
            [self captureRenderDelegateFBO];
            if (_presentationFBO > 0 && glIsFramebuffer(_presentationFBO)) {
                return (uintptr_t)_presentationFBO;
            }
            /// Last resort: return currently bound FBO
            GLint framebuffer;
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &framebuffer);
            return (uintptr_t)framebuffer;
        }

        case RETRO_HW_CONTEXT_VULKAN:
            return 0; // TODO: Implement Vulkan framebuffer handling (#2634)

        default:
            return 0;
    }
}

#pragma mark - GL Context Helpers

/// Makes the core's dedicated GL context current on the calling thread.
/// Uses hardware_context (sharegroup-linked to the render delegate) rather than
/// alternateThreadGLContext — each EAGLContext must only be current on one
/// thread at a time, and the render thread already owns alternateThreadGLContext.
- (void)makeGLContextCurrent {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    EAGLContext *ctx = hardware_context;
    if (ctx && [EAGLContext currentContext] != ctx) {
        [EAGLContext setCurrentContext:ctx];
    }
#else
    NSOpenGLContext *ctx = hardware_context;
    if (ctx) {
        [ctx makeCurrentContext];
    }
#endif
}

/// Captures the presentation FBO from the render delegate.
/// PVMetalViewController exposes this through the presentationFramebuffer property.
- (void)captureRenderDelegateFBO {
    if ([self.renderDelegate respondsToSelector:@selector(presentationFramebuffer)]) {
        id fbo = [self.renderDelegate presentationFramebuffer];
        if (fbo) {
            _presentationFBO = (GLuint)[fbo unsignedIntValue];
            ILOG(@"Captured presentation FBO from render delegate: %u", _presentationFBO);
            return;
        }
    }

    /// Fallback: read the currently bound FBO (set by startRenderingOnAlternateThread)
    if (_presentationFBO == 0) {
        GLint fbo = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &fbo);
        if (fbo > 0) {
            _presentationFBO = (GLuint)fbo;
            ILOG(@"Captured currently bound FBO as presentation FBO: %u", _presentationFBO);
        }
    }
}

/// Returns function pointers for the active rendering API.
/// For GL ES: statically linked symbols via dlsym.
/// For Vulkan: routes through vkGetInstanceProcAddr / vkGetDeviceProcAddr.
- (void*)getProcAddress:(const char*)symbol {
    if (!symbol) {
        return NULL;
    }

    switch (current_context_type) {
        case RETRO_HW_CONTEXT_OPENGLES2:
        case RETRO_HW_CONTEXT_OPENGLES3:
        case RETRO_HW_CONTEXT_OPENGLES_VERSION:
        case RETRO_HW_CONTEXT_OPENGL:
        case RETRO_HW_CONTEXT_OPENGL_CORE:
            return dlsym(RTLD_DEFAULT, symbol);

        case RETRO_HW_CONTEXT_VULKAN:
            if (vkGetDeviceProcAddr && vulkan_device) {
                PFN_vkVoidFunction fn = vkGetDeviceProcAddr(vulkan_device, symbol);
                if (fn) return (void *)fn;
            }
            if (vkGetInstanceProcAddr && vulkan_instance) {
                PFN_vkVoidFunction fn = vkGetInstanceProcAddr(vulkan_instance, symbol);
                if (fn) return (void *)fn;
            }
            if (vkGetInstanceProcAddr) {
                PFN_vkVoidFunction fn = vkGetInstanceProcAddr(NULL, symbol);
                if (fn) return (void *)fn;
            }
            DLOG(@"Vulkan symbol not found: %s", symbol);
            return NULL;

        default:
            break;
    }

    return NULL;
}

#pragma mark - MoltenVK/Vulkan Support Methods

- (BOOL)loadMoltenVKLibrary {
    // Try multiple paths to find MoltenVK library as specified by user
    const char* moltenVKPaths[] = {
        "MoltenVK",
        "MoltenVK.framework",
        "MoltenVK.framework/MoltenVK",
        "../Contents/MoltenVK.framework/MoltenVK",
        "/System/Library/Frameworks/MoltenVK.framework/MoltenVK",
        "/usr/local/lib/libMoltenVK.dylib",
        NULL
    };

    for (int i = 0; moltenVKPaths[i] != NULL; i++) {
        vulkan_library = dylib_load(moltenVKPaths[i]);
        if (vulkan_library) {
            ILOG(@"MoltenVK library loaded from: %s", moltenVKPaths[i]);
            return YES;
        }
        DLOG(@"Failed to load MoltenVK from: %s", moltenVKPaths[i]);
    }

    ELOG(@"Failed to load MoltenVK library from any known path");
    return NO;
}

- (void)unloadMoltenVKLibrary {
    if (vulkan_library) {
        dylib_close(vulkan_library);
        vulkan_library = NULL;
        ILOG(@"MoltenVK library unloaded");
    }
}

- (BOOL)loadVulkanFunctions {
    if (!vulkan_library) {
        ELOG(@"Cannot load Vulkan functions: MoltenVK library not loaded");
        return NO;
    }

    // Load essential Vulkan function pointers
    vkGetInstanceProcAddr = (PFN_vkVoidFunction (*)(VkInstance, const char*))dylib_proc(vulkan_library, "vkGetInstanceProcAddr");
    if (!vkGetInstanceProcAddr) {
        ELOG(@"Failed to load vkGetInstanceProcAddr");
        return NO;
    }

    // Load global functions (don't require instance)
    vkCreateInstance = (VkResult (*)(const void*, const void*, VkInstance*))vkGetInstanceProcAddr(NULL, "vkCreateInstance");
    if (!vkCreateInstance) {
        ELOG(@"Failed to load vkCreateInstance");
        return NO;
    }

    ILOG(@"Essential Vulkan functions loaded successfully");
    return YES;
}

- (BOOL)createVulkanInstance {
    // Minimal VkApplicationInfo structure
    struct {
        int sType;           // VK_STRUCTURE_TYPE_APPLICATION_INFO
        const void* pNext;
        const char* pApplicationName;
        uint32_t applicationVersion;
        const char* pEngineName;
        uint32_t engineVersion;
        uint32_t apiVersion;
    } appInfo = {
        .sType = 0, // VK_STRUCTURE_TYPE_APPLICATION_INFO
        .pNext = NULL,
        .pApplicationName = "PVLibRetro",
        .applicationVersion = 1,
        .pEngineName = "PVLibRetro",
        .engineVersion = 1,
        .apiVersion = 0x00400000 // VK_API_VERSION_1_0
    };

    // Minimal VkInstanceCreateInfo structure
    struct {
        int sType;           // VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
        const void* pNext;
        uint32_t flags;
        const void* pApplicationInfo;
        uint32_t enabledLayerCount;
        const char* const* ppEnabledLayerNames;
        uint32_t enabledExtensionCount;
        const char* const* ppEnabledExtensionNames;
    } createInfo = {
        .sType = 1, // VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
        .pNext = NULL,
        .flags = 0,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = NULL,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = NULL
    };

    VkResult result = vkCreateInstance(&createInfo, NULL, &vulkan_instance);
    if (result != 0) { // VK_SUCCESS = 0
        ELOG(@"Failed to create Vulkan instance, result: %d", result);
        return NO;
    }

    // Load instance-specific functions
    vkDestroyInstance = (void (*)(VkInstance, const void*))vkGetInstanceProcAddr(vulkan_instance, "vkDestroyInstance");
    vkEnumeratePhysicalDevices = (VkResult (*)(VkInstance, uint32_t*, VkPhysicalDevice*))vkGetInstanceProcAddr(vulkan_instance, "vkEnumeratePhysicalDevices");
    vkCreateDevice = (VkResult (*)(VkPhysicalDevice, const void*, const void*, VkDevice*))vkGetInstanceProcAddr(vulkan_instance, "vkCreateDevice");

    if (!vkDestroyInstance || !vkEnumeratePhysicalDevices || !vkCreateDevice) {
        ELOG(@"Failed to load instance-specific Vulkan functions");
        return NO;
    }

    ILOG(@"Vulkan instance created successfully");
    return YES;
}

- (void)destroyVulkanInstance {
    if (vulkan_instance && vkDestroyInstance) {
        vkDestroyInstance(vulkan_instance, NULL);
        vulkan_instance = NULL;
        ILOG(@"Vulkan instance destroyed");
    }
}

- (BOOL)selectVulkanPhysicalDevice {
    if (!vulkan_instance || !vkEnumeratePhysicalDevices) {
        ELOG(@"Cannot select physical device: Vulkan instance not created");
        return NO;
    }

    uint32_t deviceCount = 0;
    VkResult result = vkEnumeratePhysicalDevices(vulkan_instance, &deviceCount, NULL);
    if (result != 0 || deviceCount == 0) {
        ELOG(@"No Vulkan physical devices found, result: %d, count: %d", result, deviceCount);
        return NO;
    }

    // Just use the first available device for simplicity
    VkPhysicalDevice devices[1];
    uint32_t requestCount = 1;
    result = vkEnumeratePhysicalDevices(vulkan_instance, &requestCount, devices);
    if (result != 0 || requestCount == 0) {
        ELOG(@"Failed to get Vulkan physical device, result: %d", result);
        return NO;
    }

    vulkan_physical_device = devices[0];
    ILOG(@"Vulkan physical device selected");
    return YES;
}

- (BOOL)createVulkanDevice {
    if (!vulkan_physical_device || !vkCreateDevice) {
        ELOG(@"Cannot create device: Physical device not selected");
        return NO;
    }

    // Minimal queue create info
    float queuePriority = 1.0f;
    struct {
        int sType;           // VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
        const void* pNext;
        uint32_t flags;
        uint32_t queueFamilyIndex;
        uint32_t queueCount;
        const float* pQueuePriorities;
    } queueCreateInfo = {
        .sType = 2, // VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
        .pNext = NULL,
        .flags = 0,
        .queueFamilyIndex = 0, // Assume graphics queue family 0
        .queueCount = 1,
        .pQueuePriorities = &queuePriority
    };

    // Minimal device create info
    struct {
        int sType;           // VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
        const void* pNext;
        uint32_t flags;
        uint32_t queueCreateInfoCount;
        const void* pQueueCreateInfos;
        uint32_t enabledLayerCount;
        const char* const* ppEnabledLayerNames;
        uint32_t enabledExtensionCount;
        const char* const* ppEnabledExtensionNames;
        const void* pEnabledFeatures;
    } createInfo = {
        .sType = 3, // VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
        .pNext = NULL,
        .flags = 0,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queueCreateInfo,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = NULL,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = NULL,
        .pEnabledFeatures = NULL
    };

    VkResult result = vkCreateDevice(vulkan_physical_device, &createInfo, NULL, &vulkan_device);
    if (result != 0) {
        ELOG(@"Failed to create Vulkan device, result: %d", result);
        return NO;
    }

    // Load device-specific functions
    vkGetDeviceProcAddr = (PFN_vkVoidFunction (*)(VkDevice, const char*))vkGetInstanceProcAddr(vulkan_instance, "vkGetDeviceProcAddr");
    vkDestroyDevice = (void (*)(VkDevice, const void*))vkGetDeviceProcAddr(vulkan_device, "vkDestroyDevice");
    vkGetDeviceQueue = (void (*)(VkDevice, uint32_t, uint32_t, VkQueue*))vkGetDeviceProcAddr(vulkan_device, "vkGetDeviceQueue");

    if (!vkGetDeviceProcAddr || !vkDestroyDevice || !vkGetDeviceQueue) {
        ELOG(@"Failed to load device-specific Vulkan functions");
        return NO;
    }

    ILOG(@"Vulkan device created successfully");
    return YES;
}

- (void)destroyVulkanDevice {
    if (vulkan_device && vkDestroyDevice) {
        vkDestroyDevice(vulkan_device, NULL);
        vulkan_device = NULL;
        vulkan_queue = NULL;
        ILOG(@"Vulkan device destroyed");
    }
}

- (void)getVulkanDeviceQueue {
    if (vulkan_device && vkGetDeviceQueue) {
        vkGetDeviceQueue(vulkan_device, 0, 0, &vulkan_queue); // Queue family 0, queue index 0
        ILOG(@"Vulkan device queue obtained");
    }
}

@end

#pragma clang diagnostic pop
