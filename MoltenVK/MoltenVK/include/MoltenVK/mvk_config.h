/*
 * mvk_config.h
 *
 * Copyright (c) 2015-2023 The Brenwill Workshop Ltd. (http://www.brenwill.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */



#ifndef __mvk_config_h_
#define __mvk_config_h_ 1

#ifdef __cplusplus
extern "C" {
#endif	//  __cplusplus
	
#include <vulkan/vulkan.h>


/** This header contains the public configuration API for MoltenVK. */


/**
 * The version number of MoltenVK is a single integer value, derived from the Major, Minor,
 * and Patch version values, where each of the Major, Minor, and Patch components is allocated
 * two decimal digits, in the format MjMnPt. This creates a version number that is both human
 * readable and allows efficient computational comparisons to a single integer number.
 *
 * The following examples illustrate how the MoltenVK version number is built from its components:
 *   - 002000    (version 0.20.0)
 *   - 010000    (version 1.0.0)
 *   - 030104    (version 3.1.4)
 *   - 401215    (version 4.12.15)
 */
#define MVK_VERSION_MAJOR   1
#define MVK_VERSION_MINOR   2
#define MVK_VERSION_PATCH   4

#define MVK_MAKE_VERSION(major, minor, patch)    (((major) * 10000) + ((minor) * 100) + (patch))
#define MVK_VERSION     MVK_MAKE_VERSION(MVK_VERSION_MAJOR, MVK_VERSION_MINOR, MVK_VERSION_PATCH)


#define MVK_CONFIGURATION_API_VERSION   37

/** Identifies the level of logging MoltenVK should be limited to outputting. */
typedef enum MVKConfigLogLevel {
	MVK_CONFIG_LOG_LEVEL_NONE     = 0,	/**< No logging. */
	MVK_CONFIG_LOG_LEVEL_ERROR    = 1,	/**< Log errors only. */
	MVK_CONFIG_LOG_LEVEL_WARNING  = 2,	/**< Log errors and warning messages. */
	MVK_CONFIG_LOG_LEVEL_INFO     = 3,	/**< Log errors, warnings and informational messages. */
	MVK_CONFIG_LOG_LEVEL_DEBUG    = 4,	/**< Log errors, warnings, infos and debug messages. */
	MVK_CONFIG_LOG_LEVEL_MAX_ENUM = 0x7FFFFFFF
} MVKConfigLogLevel;

/** Identifies the level of Vulkan call trace logging MoltenVK should perform. */
typedef enum MVKConfigTraceVulkanCalls {
	MVK_CONFIG_TRACE_VULKAN_CALLS_NONE                 = 0,	/**< No Vulkan call logging. */
	MVK_CONFIG_TRACE_VULKAN_CALLS_ENTER                = 1,	/**< Log the name of each Vulkan call when the call is entered. */
	MVK_CONFIG_TRACE_VULKAN_CALLS_ENTER_THREAD_ID      = 2,	/**< Log the name and thread ID of each Vulkan call when the call is entered. */
	MVK_CONFIG_TRACE_VULKAN_CALLS_ENTER_EXIT           = 3,	/**< Log the name of each Vulkan call when the call is entered and exited. This effectively brackets any other logging activity within the scope of the Vulkan call. */
	MVK_CONFIG_TRACE_VULKAN_CALLS_ENTER_EXIT_THREAD_ID = 4,	/**< Log the name and thread ID of each Vulkan call when the call is entered and name when exited. This effectively brackets any other logging activity within the scope of the Vulkan call. */
	MVK_CONFIG_TRACE_VULKAN_CALLS_DURATION             = 5,	/**< Same as MVK_CONFIG_TRACE_VULKAN_CALLS_ENTER_EXIT, plus logs the time spent inside the Vulkan function. */
	MVK_CONFIG_TRACE_VULKAN_CALLS_DURATION_THREAD_ID   = 6,	/**< Same as MVK_CONFIG_TRACE_VULKAN_CALLS_ENTER_EXIT_THREAD_ID, plus logs the time spent inside the Vulkan function. */
	MVK_CONFIG_TRACE_VULKAN_CALLS_MAX_ENUM             = 0x7FFFFFFF
} MVKConfigTraceVulkanCalls;

/** Identifies the scope for Metal to run an automatic GPU capture for diagnostic debugging purposes. */
typedef enum MVKConfigAutoGPUCaptureScope {
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_NONE     = 0,	/**< No automatic GPU capture. */
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_DEVICE   = 1,	/**< Automatically capture all GPU activity during the lifetime of a VkDevice. */
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_FRAME    = 2,	/**< Automatically capture all GPU activity during the rendering and presentation of the first frame. */
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_MAX_ENUM = 0x7FFFFFFF
} MVKConfigAutoGPUCaptureScope;

/** Identifies extensions to advertise as part of MoltenVK configuration. */
typedef enum MVKConfigAdvertiseExtensionBits {
	MVK_CONFIG_ADVERTISE_EXTENSIONS_ALL         = 0x00000001,	/**< All supported extensions. */
	MVK_CONFIG_ADVERTISE_EXTENSIONS_WSI         = 0x00000002,	/**< WSI extensions supported on the platform. */
	MVK_CONFIG_ADVERTISE_EXTENSIONS_PORTABILITY = 0x00000004,	/**< Vulkan Portability Subset extensions. */
	MVK_CONFIG_ADVERTISE_EXTENSIONS_MAX_ENUM    = 0x7FFFFFFF
} MVKConfigAdvertiseExtensionBits;
typedef VkFlags MVKConfigAdvertiseExtensions;

/** Identifies the use of Metal Argument Buffers. */
typedef enum MVKUseMetalArgumentBuffers {
	MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS_NEVER               = 0,	/**< Don't use Metal Argument Buffers. */
	MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS_ALWAYS              = 1,	/**< Use Metal Argument Buffers for all pipelines. */
	MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS_DESCRIPTOR_INDEXING = 2,	/**< Use Metal Argument Buffers only if VK_EXT_descriptor_indexing extension is enabled. */
	MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS_MAX_ENUM            = 0x7FFFFFFF
} MVKUseMetalArgumentBuffers;

/** Identifies the Metal functionality used to support Vulkan semaphore functionality (VkSemaphore). */
typedef enum MVKVkSemaphoreSupportStyle {
	MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_SINGLE_QUEUE            = 0,	/**< Limit Vulkan to a single queue, with no explicit semaphore synchronization, and use Metal's implicit guarantees that all operations submitted to a queue will give the same result as if they had been run in submission order. */
	MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_METAL_EVENTS_WHERE_SAFE = 1,	/**< Use Metal events (MTLEvent) when available on the platform, and where safe. This will revert to same as MVK_CONFIG_VK_SEMAPHORE_USE_SINGLE_QUEUE on some NVIDIA GPUs and Rosetta2, due to potential challenges with MTLEvents on those platforms, or in older environments where MTLEvents are not supported. */
	MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_METAL_EVENTS            = 2,	/**< Always use Metal events (MTLEvent) when available on the platform. This will revert to same as MVK_CONFIG_VK_SEMAPHORE_USE_SINGLE_QUEUE in older environments where MTLEvents are not supported. */
	MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_CALLBACK                = 3,	/**< Use CPU callbacks upon GPU submission completion. This is the slowest technique, but allows multiple queues, compared to MVK_CONFIG_VK_SEMAPHORE_USE_SINGLE_QUEUE. */
	MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_MAX_ENUM                = 0x7FFFFFFF
} MVKVkSemaphoreSupportStyle;

/** Identifies the style of Metal command buffer pre-filling to be used. */
typedef enum MVKPrefillMetalCommandBuffersStyle {
	MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_NO_PREFILL                        = 0,	/**< During Vulkan command buffer filling, do not prefill a Metal command buffer for each Vulkan command buffer. A single Metal command buffer is created and encoded for all the Vulkan command buffers included when vkQueueSubmit() is called. MoltenVK automatically creates and drains a single Metal object autorelease pool when vkQueueSubmit() is called. This is the fastest option, but potentially has the largest memory footprint. */
	MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_DEFERRED_ENCODING                 = 1,	/**< During Vulkan command buffer filling, encode to the Metal command buffer when vkEndCommandBuffer() is called. MoltenVK automatically creates and drains a single Metal object autorelease pool when vkEndCommandBuffer() is called. This option has the fastest performance, and the largest memory footprint, of the prefilling options using autorelease pools. */
	MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_IMMEDIATE_ENCODING                = 2,	/**< During Vulkan command buffer filling, immediately encode to the Metal command buffer, as each command is submitted to the Vulkan command buffer, and do not retain any command content in the Vulkan command buffer. MoltenVK automatically creates and drains a Metal object autorelease pool for each and every command added to the Vulkan command buffer. This option has the smallest memory footprint, and the slowest performance, of the prefilling options using autorelease pools. */
	MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_IMMEDIATE_ENCODING_NO_AUTORELEASE = 3,	/**< During Vulkan command buffer filling, immediately encode to the Metal command buffer, as each command is submitted to the Vulkan command buffer, do not retain any command content in the Vulkan command buffer, and assume the app will ensure that each thread that fills commands into a Vulkan command buffer has a Metal autorelease pool. MoltenVK will not create and drain any autorelease pools during encoding. This is the fastest prefilling option, and generally has a small memory footprint, depending on when the app-provided autorelease pool drains. */
	MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_MAX_ENUM                          = 0x7FFFFFFF
} MVKPrefillMetalCommandBuffersStyle;

/** Identifies when Metal shaders will be compiled with the fast math option. */
typedef enum MVKConfigFastMath {
	MVK_CONFIG_FAST_MATH_NEVER     = 0,  /**< Metal shaders will never be compiled with the fast math option. */
	MVK_CONFIG_FAST_MATH_ALWAYS    = 1,  /**< Metal shaders will always be compiled with the fast math option. */
	MVK_CONFIG_FAST_MATH_ON_DEMAND = 2,  /**< Metal shaders will be compiled with the fast math option, unless the shader includes execution modes that require it to be compiled without fast math. */
	MVK_CONFIG_FAST_MATH_MAX_ENUM  = 0x7FFFFFFF
} MVKConfigFastMath;

/** Identifies available system data compression algorithms. */
typedef enum MVKConfigCompressionAlgorithm {
	MVK_CONFIG_COMPRESSION_ALGORITHM_NONE     = 0,	/**< No compression. */
	MVK_CONFIG_COMPRESSION_ALGORITHM_LZFSE    = 1,	/**< Apple proprietary. Good balance of high performance and small compression size, particularly for larger data content. */
	MVK_CONFIG_COMPRESSION_ALGORITHM_ZLIB     = 2,	/**< Open cross-platform ZLib format. For smaller data content, has better performance and smaller size than LZFSE. */
	MVK_CONFIG_COMPRESSION_ALGORITHM_LZ4      = 3,	/**< Fastest performance. Largest compression size. */
	MVK_CONFIG_COMPRESSION_ALGORITHM_LZMA     = 4,	/**< Slowest performance. Smallest compression size, particular with larger content. */
	MVK_CONFIG_COMPRESSION_ALGORITHM_MAX_ENUM = 0x7FFFFFFF,
} MVKConfigCompressionAlgorithm;

/** Identifies the style of activity performance logging to use. */
typedef enum MVKConfigActivityPerformanceLoggingStyle {
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_FRAME_COUNT     = 0,	/**< Repeatedly log performance after a configured number of frames. */
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_IMMEDIATE       = 1,	/**< Log immediately after each performance measurement. */
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_DEVICE_LIFETIME = 2,	/**< Log at the end of the VkDevice lifetime. This is useful for one-shot apps such as testing frameworks. */
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_MAX_ENUM        = 0x7FFFFFFF,
} MVKConfigActivityPerformanceLoggingStyle;

/**
 * MoltenVK configuration settings.
 *
 * To be active, some configuration settings must be set before a VkDevice is created.
 * See the description of the individual configuration structure members for more information.
 *
 * There are three mechanisms for setting the values of the MoltenVK configuration parameters:
 *   - Runtime API via the vkGetMoltenVKConfigurationMVK()/vkSetMoltenVKConfigurationMVK() functions.
 *   - Application runtime environment variables.
 *   - Build settings at MoltenVK build time.
 *
 * To change the MoltenVK configuration settings at runtime using a programmatic API,
 * use the vkGetMoltenVKConfigurationMVK() and vkSetMoltenVKConfigurationMVK() functions
 * to retrieve, modify, and set a copy of the MVKConfiguration structure. To be active,
 * some configuration settings must be set before a VkInstance or VkDevice is created.
 * See the description of each member for more information.
 *
 * The initial value of each of the configuration settings can established at runtime
 * by a corresponding environment variable, or if the environment variable is not set,
 * by a corresponding build setting at the time MoltenVK is compiled. The environment
 * variable and build setting for each configuration parameter share the same name.
 *
 * For example, the initial value of the shaderConversionFlipVertexY configuration setting
 * is set by the MVK_CONFIG_SHADER_CONVERSION_FLIP_VERTEX_Y at runtime, or by the
 * MVK_CONFIG_SHADER_CONVERSION_FLIP_VERTEX_Y build setting when MoltenVK is compiled.
 *
 * This structure may be extended as new features are added to MoltenVK. If you are linking to
 * an implementation of MoltenVK that was compiled from a different MVK_CONFIGURATION_API_VERSION
 * than your app was, the size of this structure in your app may be larger or smaller than the
 * struct in MoltenVK. See the description of the vkGetMoltenVKConfigurationMVK() and
 * vkSetMoltenVKConfigurationMVK() functions for information about how to handle this.
 *
 * TO SUPPORT DYNAMIC LINKING TO THIS STRUCTURE AS DESCRIBED ABOVE, THIS STRUCTURE SHOULD NOT
 * BE CHANGED EXCEPT TO ADD ADDITIONAL MEMBERS ON THE END. EXISTING MEMBERS, AND THEIR ORDER,
 * SHOULD NOT BE CHANGED.
 */
typedef struct {

	/**
	 * If enabled, debugging capabilities will be enabled, including logging
	 * shader code during runtime shader conversion.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_DEBUG
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter is false if MoltenVK was
	 * built in Release mode, and true if MoltenVK was built in Debug mode.
	 */
    VkBool32 debugMode;

	/**
	 * If enabled, MSL vertex shader code created during runtime shader conversion will
	 * flip the Y-axis of each vertex, as the Vulkan Y-axis is the inverse of OpenGL.
	 *
	 * An alternate way to reverse the Y-axis is to employ a negative Y-axis value on
	 * the viewport, in which case this parameter can be disabled.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 * Specifically, this parameter can be enabled when compiling some pipelines,
	 * and disabled when compiling others. Existing pipelines are not automatically
	 * re-compiled when this parameter is changed.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_SHADER_CONVERSION_FLIP_VERTEX_Y
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to true.
	 */
    VkBool32 shaderConversionFlipVertexY;

	/**
	 * If enabled, queue command submissions (vkQueueSubmit() & vkQueuePresentKHR()) will be
	 * processed on the thread that called the submission function. If disabled, processing
	 * will be dispatched to a GCD dispatch_queue whose priority is determined by
	 * VkDeviceQueueCreateInfo::pQueuePriorities during vkCreateDevice().
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to true for macOS 10.14
	 * and above or iOS 12 and above, and false otherwise. The reason for this distinction
	 * is that this feature should be disabled when emulation is required to support VkEvents
	 * because native support for events (MTLEvent) is not available.
	 */
	VkBool32 synchronousQueueSubmits;

	/**
	 * If set to MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_NO_PREFILL, a single Metal
	 * command buffer will be created and filled when the Vulkan command buffers are submitted
	 * to the Vulkan queue. This allows a single Metal command buffer to be used for all of the
	 * Vulkan command buffers in a queue submission. The Metal command buffer is filled on the
	 * thread that processes the command queue submission.
	 *
	 * If set to any value other than MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_NO_PREFILL,
	 * where possible, a Metal command buffer will be created and filled when each Vulkan
	 * command buffer is filled. For applications that parallelize the filling of Vulkan
	 * commmand buffers across multiple threads, this allows the Metal command buffers to also
	 * be filled on the same parallel thread. Because each command buffer is filled separately,
	 * this requires that each Vulkan command buffer have a dedicated Metal command buffer.
	 *
	 * See the definition of the MVKPrefillMetalCommandBuffersStyle enumeration above for
	 * descriptions of the various values that can be used for this setting. The differences
	 * are primarily distinguished by how memory recovery is handled for autoreleased Metal
	 * objects that are created under the covers as the commands added to the Vulkan command
	 * buffer are encoded into the corresponding Metal command buffer. You can decide whether
	 * your app will recover all autoreleased Metal objects, or how agressively MoltenVK should
	 * recover autoreleased Metal objects, based on your approach to command buffer filling.
	 *
	 * Depending on the nature of your application, you may find performance is improved by filling
	 * the Metal command buffers on parallel threads, or you may find that performance is improved by
	 * consolidating all Vulkan command buffers onto a single Metal command buffer during queue submission.
	 *
	 * When enabling this feature, be aware that one Metal command buffer is required for each Vulkan
	 * command buffer. Depending on the number of command buffers that you use, you may also need to
	 * change the value of the maxActiveMetalCommandBuffersPerQueue setting.
	 *
	 * If this feature is enabled, be aware that if you have recorded commands to a Vulkan command buffer,
	 * and then choose to reset that command buffer instead of submitting it, the corresponding prefilled
	 * Metal command buffer will still be submitted. This is because Metal command buffers do not support
	 * the concept of being reset after being filled. Depending on when and how often you do this,
	 * it may cause unexpected visual artifacts and unnecessary GPU load.
	 *
	 * Prefilling of a Metal command buffer will not occur during the filling of secondary command
	 * buffers (VK_COMMAND_BUFFER_LEVEL_SECONDARY), or for primary command buffers that are intended
	 * to be submitted to multiple queues concurrently (VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT).
	 *
	 * This feature is incompatible with updating descriptors after binding. If any of the
	 * *UpdateAfterBind feature flags of VkPhysicalDeviceDescriptorIndexingFeatures or
	 * VkPhysicalDeviceInlineUniformBlockFeatures have been enabled, the value of this
	 * setting will be ignored and treated as if it is false.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 * Specifically, this parameter can be enabled when filling some command buffers,
	 * and disabled when later filling others.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to
	 * MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS_STYLE_NO_PREFILL.
	 */
	MVKPrefillMetalCommandBuffersStyle prefillMetalCommandBuffers;

	/**
	 * The maximum number of Metal command buffers that can be concurrently active per Vulkan queue.
	 * The number of active Metal command buffers required depends on the prefillMetalCommandBuffers
	 * setting. If prefillMetalCommandBuffers is enabled, one Metal command buffer is required per
	 * Vulkan command buffer. If prefillMetalCommandBuffers is disabled, one Metal command buffer
	 * is required per command buffer queue submission, which may be significantly less than the
	 * number of Vulkan command buffers.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to 64.
	 */
	uint32_t maxActiveMetalCommandBuffersPerQueue;

	/**
	 * Depending on the GPU, Metal allows 8192 or 32768 occlusion queries per MTLBuffer.
	 * If enabled, MoltenVK allocates a MTLBuffer for each query pool, allowing each query
	 * pool to support that permitted number of queries. This may slow performance or cause
	 * unexpected behaviour if the query pool is not established prior to a Metal renderpass,
	 * or if the query pool is changed within a renderpass. If disabled, one MTLBuffer will
	 * be shared by all query pools, which improves performance, but limits the total device
	 * queries to the permitted number.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 * Specifically, this parameter can be enabled when creating some query pools,
	 * and disabled when creating others.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_SUPPORT_LARGE_QUERY_POOLS
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to true.
	 */
	VkBool32 supportLargeQueryPools;

	/** Obsolete, ignored, and deprecated. All surface presentations are performed with a command buffer. */
	VkBool32 presentWithCommandBuffer;

	/**
	 * If enabled, swapchain images will use simple Nearest sampling when minifying or magnifying
	 * the swapchain image to fit a physical display surface. If disabled, swapchain images will
	 * use Linear sampling when magnifying the swapchain image to fit a physical display surface.
	 * Enabling this setting avoids smearing effects when swapchain images are simple interger
	 * multiples of display pixels (eg- macOS Retina, and typical of graphics apps and games),
	 * but may cause aliasing effects when using non-integer display scaling.
	 *
	 * The value of this parameter must be changed before creating a VkSwapchain,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_SWAPCHAIN_MIN_MAG_FILTER_USE_NEAREST
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to true.
	 */
	VkBool32 swapchainMinMagFilterUseNearest;
#define swapchainMagFilterUseNearest swapchainMinMagFilterUseNearest

	/**
	 * The maximum amount of time, in nanoseconds, to wait for a Metal library, function, or
	 * pipeline state object to be compiled and created by the Metal compiler. An internal error
	 * within the Metal compiler can stall the thread for up to 30 seconds. Setting this value
	 * limits that delay to a specified amount of time, allowing shader compilations to fail fast.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_METAL_COMPILE_TIMEOUT
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to infinite.
	 */
	uint64_t metalCompileTimeout;

	/**
	 * If enabled, performance statistics, as defined by the MVKPerformanceStatistics structure,
	 * are collected, and can be retrieved via the vkGetPerformanceStatisticsMVK() function.
	 *
	 * You can also use the activityPerformanceLoggingStyle and performanceLoggingFrameCount
	 * parameters to configure when to log the performance statistics collected by this parameter.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_PERFORMANCE_TRACKING
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to false.
	 */
	VkBool32 performanceTracking;

	/**
	 * If non-zero, performance statistics, frame-based statistics will be logged, on a
	 * repeating cycle, once per this many frames. The performanceTracking parameter must
	 * also be enabled. If this parameter is zero, or the performanceTracking parameter
	 * is disabled, no frame-based performance statistics will be logged.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_PERFORMANCE_LOGGING_FRAME_COUNT
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to zero.
	 */
	uint32_t performanceLoggingFrameCount;

	/**
	 * If enabled, a MoltenVK logo watermark will be rendered on top of the scene.
	 * This can be enabled for publicity during demos.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_DISPLAY_WATERMARK
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to false.
	 */
	VkBool32 displayWatermark;

	/**
	 * Metal does not distinguish functionality between queues, which would normally mean only
	 * a single general-purpose queue family with multiple queues is needed. However, Vulkan
	 * associates command buffers with a queue family, whereas Metal associates command buffers
	 * with a specific Metal queue. In order to allow a Metal command buffer to be prefilled
	 * before is is formally submitted to a Vulkan queue, each Vulkan queue family can support
	 * only a single Metal queue. As a result, in order to provide parallel queue operations,
	 * MoltenVK provides multiple queue families, each with a single queue.
	 *
	 * If this parameter is disabled, all queue families will be advertised as having general-purpose
	 * graphics + compute + transfer functionality, which is how the actual Metal queues behave.
	 *
	 * If this parameter is enabled, one queue family will be advertised as having general-purpose
	 * graphics + compute + transfer functionality, and the remaining queue families will be advertised
	 * as having specialized graphics OR compute OR transfer functionality, to make it easier for some
	 * apps to select a queue family with the appropriate requirements.
	 *
	 * The value of this parameter must be changed before creating a VkDevice, and before
	 * querying a VkPhysicalDevice for queue family properties, for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_SPECIALIZED_QUEUE_FAMILIES
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to false.
	 */
	VkBool32 specializedQueueFamilies;

	/**
	 * If enabled, when the app creates a VkDevice from a VkPhysicalDevice (GPU) that is neither
	 * headless nor low-power, and is different than the GPU used by the windowing system, the
	 * windowing system will be forced to switch to use the GPU selected by the Vulkan app.
	 * When the Vulkan app is ended, the windowing system will automatically switch back to
	 * using the previous GPU, depending on the usage requirements of other running apps.
	 *
	 * If disabled, the Vulkan app will render using its selected GPU, and if the windowing
	 * system uses a different GPU, the windowing system compositor will automatically copy
	 * framebuffer content from the app GPU to the windowing system GPU.
	 *
	 * The value of this parmeter has no effect on systems with a single GPU, or when the
	 * Vulkan app creates a VkDevice from a low-power or headless VkPhysicalDevice (GPU).
	 *
	 * Switching the windowing system GPU to match the Vulkan app GPU maximizes app performance,
	 * because it avoids the windowing system compositor from having to copy framebuffer content
	 * between GPUs on each rendered frame. However, doing so forces the entire system to
	 * potentially switch to using a GPU that may consume more power while the app is running.
	 *
	 * Some Vulkan apps may want to render using a high-power GPU, but leave it up to the
	 * system window compositor to determine how best to blend content with the windowing
	 * system, and as a result, may want to disable this parameter.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_SWITCH_SYSTEM_GPU
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to true.
	 */
	VkBool32 switchSystemGPU;

	/**
	 * Older versions of Metal do not natively support per-texture swizzling. When running on
	 * such a system, and this parameter is enabled, arbitrary VkImageView component swizzles
	 * are supported, as defined in VkImageViewCreateInfo::components when creating a VkImageView.
	 *
	 * If disabled, and native Metal per-texture swizzling is not available on the platform,
	 * a very limited set of VkImageView component swizzles are supported via format substitutions.
	 *
	 * If Metal supports native per-texture swizzling, this parameter is ignored.
	 *
	 * When running on an older version of Metal that does not support native per-texture
	 * swizzling, if this parameter is enabled, both when a VkImageView is created, and
	 * when any pipeline that uses that VkImageView is compiled, VkImageView swizzling is
	 * automatically performed in the converted Metal shader code during all texture sampling
	 * and reading operations, regardless of whether a swizzle is required for the VkImageView
	 * associated with the Metal texture. This may result in reduced performance.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 * Specifically, this parameter can be enabled when creating VkImageViews that need it,
	 * and compiling pipelines that use those VkImageViews, and can be disabled when creating
	 * VkImageViews that don't need it, and compiling pipelines that use those VkImageViews.
	 *
	 * Existing pipelines are not automatically re-compiled when this parameter is changed.
	 *
	 * An error is logged and returned during VkImageView creation if that VkImageView
	 * requires full image view swizzling and this feature is not enabled. An error is
	 * also logged when a pipeline that was not compiled with full image view swizzling
	 * is presented with a VkImageView that is expecting it.
	 *
	 * An error is also retuned and logged when a VkPhysicalDeviceImageFormatInfo2KHR is passed
	 * in a call to vkGetPhysicalDeviceImageFormatProperties2KHR() to query for an VkImageView
	 * format that will require full swizzling to be enabled, and this feature is not enabled.
	 *
	 * If this parameter is disabled, and native Metal per-texture swizzling is not available
	 * on the platform, the following limited set of VkImageView swizzles are supported by
	 * MoltenVK, via automatic format substitution:
	 *
	 * Texture format			       Swizzle
	 * --------------                  -------
	 * VK_FORMAT_R8_UNORM              ZERO, ANY, ANY, RED
	 * VK_FORMAT_A8_UNORM              ALPHA, ANY, ANY, ZERO
	 * VK_FORMAT_R8G8B8A8_UNORM        BLUE, GREEN, RED, ALPHA
	 * VK_FORMAT_R8G8B8A8_SRGB         BLUE, GREEN, RED, ALPHA
	 * VK_FORMAT_B8G8R8A8_UNORM        BLUE, GREEN, RED, ALPHA
	 * VK_FORMAT_B8G8R8A8_SRGB         BLUE, GREEN, RED, ALPHA
	 * VK_FORMAT_D32_SFLOAT_S8_UINT    RED, ANY, ANY, ANY (stencil only)
	 * VK_FORMAT_D24_UNORM_S8_UINT     RED, ANY, ANY, ANY (stencil only)
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_FULL_IMAGE_VIEW_SWIZZLE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to false.
	 */
	VkBool32 fullImageViewSwizzle;

	/**
	 * The index of the queue family whose presentation submissions will
	 * be used as the default GPU Capture Scope during debugging in Xcode.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_FAMILY_INDEX
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to zero (the first queue family).
	 */
	uint32_t defaultGPUCaptureScopeQueueFamilyIndex;

	/**
	 * The index of the queue, within the queue family identified by the
	 * defaultGPUCaptureScopeQueueFamilyIndex parameter, whose presentation submissions
	 * will be used as the default GPU Capture Scope during debugging in Xcode.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_INDEX
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to zero (the first queue).
	 */
	uint32_t defaultGPUCaptureScopeQueueIndex;

	/**
	 * Identifies when Metal shaders will be compiled with the Metal fastMathEnabled property
	 * enabled. For shaders compiled with the Metal fastMathEnabled property enabled, shader
	 * floating point math is significantly faster, but it may cause the Metal Compiler to
	 * optimize floating point operations in ways that may violate the IEEE 754 standard.
	 *
	 * Enabling Metal fast math can dramatically improve shader performance, and has little
	 * practical effect on the numerical accuracy of most shaders. As such, disabling fast
	 * math should be done carefully and deliberately. For most applications, always enabling
	 * fast math, by setting the value of this property to MVK_CONFIG_FAST_MATH_ALWAYS,
	 * is the preferred choice.
	 *
	 * Apps that have specific accuracy and handling needs for particular shaders, may elect to
	 * set the value of this property to MVK_CONFIG_FAST_MATH_ON_DEMAND, so that fast math will
	 * be disabled when compiling shaders that request capabilities such as SignedZeroInfNanPreserve.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will be applied to future Metal shader compilations.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_FAST_MATH_ENABLED
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to MVK_CONFIG_FAST_MATH_ALWAYS.
	 */
	MVKConfigFastMath fastMathEnabled;

	/**
	 * Controls the level of logging performned by MoltenVK.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_LOG_LEVEL
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, errors and informational messages are logged.
	 */
	MVKConfigLogLevel logLevel;

	/**
	 * Causes MoltenVK to log the name of each Vulkan call made by the application,
	 * along with the Mach thread ID, global system thread ID, and thread name.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect subsequent MoltenVK behaviour.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_TRACE_VULKAN_CALLS
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, no Vulkan call logging will occur.
	 */
	MVKConfigTraceVulkanCalls traceVulkanCalls;

	/**
	 * Force MoltenVK to use a low-power GPU, if one is availble on the device.
	 *
	 * The value of this parameter must be changed before creating a VkInstance,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_FORCE_LOW_POWER_GPU
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is disabled by default, allowing both
	 * low-power and high-power GPU's to be used.
	 */
	VkBool32 forceLowPowerGPU;

	/** Deprecated. Vulkan sempphores using MTLFence are no longer supported. Use semaphoreSupportStyle instead. */
	VkBool32 semaphoreUseMTLFence;

	/**
	 * Determines the style used to implement Vulkan semaphore (VkSemaphore) functionality in Metal.
	 * See the documentation of the MVKVkSemaphoreSupportStyle for the options.
	 *
	 * In the special case of VK_SEMAPHORE_TYPE_TIMELINE semaphores, MoltenVK will always use
	 * MTLSharedEvent if it is available on the platform, regardless of the value of this parameter.
	 *
	 * The value of this parameter must be changed before creating a VkInstance,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is set to
	 * MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_METAL_EVENTS_WHERE_SAFE by default,
	 * and MoltenVK will use MTLEvent, except on NVIDIA GPU and Rosetta2 environments,
	 * or where MTLEvents are not supported, where it will use a single queue with
	 * implicit synchronization (as if this parameter was set to
	 * MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_SINGLE_QUEUE).
	 *
	 * This parameter interacts with the deprecated legacy parameters semaphoreUseMTLEvent
	 * and semaphoreUseMTLFence. If semaphoreUseMTLEvent is enabled, this parameter will be
	 * set to MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_METAL_EVENTS_WHERE_SAFE.
	 * If semaphoreUseMTLEvent is disabled, this parameter will be set to
	 * MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_SINGLE_QUEUE if semaphoreUseMTLFence is enabled,
	 * or MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE_CALLBACK if semaphoreUseMTLFence is disabled.
	 * Structurally, this parameter replaces, and is aliased by, semaphoreUseMTLEvent.
	 */
	MVKVkSemaphoreSupportStyle semaphoreSupportStyle;
#define semaphoreUseMTLEvent semaphoreSupportStyle

	/**
	 * Controls whether Metal should run an automatic GPU capture without the user having to
	 * trigger it manually via the Xcode user interface, and controls the scope under which
	 * that GPU capture will occur. This is useful when trying to capture a one-shot GPU trace,
	 * such as when running a Vulkan CTS test case. For the automatic GPU capture to occur, the
	 * Xcode scheme under which the app is run must have the Metal GPU capture option enabled.
	 * This parameter should not be set to manually trigger a GPU capture via the Xcode user interface.
	 *
	 * When the value of this parameter is MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_FRAME,
	 * the queue for which the GPU activity is captured is identifed by the values of
	 * the defaultGPUCaptureScopeQueueFamilyIndex and defaultGPUCaptureScopeQueueIndex
	 * configuration parameters.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, no automatic GPU capture will occur.
	 */
	MVKConfigAutoGPUCaptureScope autoGPUCaptureScope;

	/**
	 * The path to a file where the automatic GPU capture should be saved, if autoGPUCaptureScope
	 * is enabled. In this case, the Xcode scheme need not have Metal GPU capture enabled, and in
	 * fact the app need not be run under Xcode's control at all. This is useful in case the app
	 * cannot be run under Xcode's control. A path starting with '~' can be used to place it in a
	 * user's home directory, as in the shell. This feature requires Metal 3.0 (macOS 10.15, iOS 13).
	 *
	 * If this parameter is NULL or an empty string, and autoGPUCaptureScope is enabled, automatic
	 * GPU capture will be handled by the Xcode user interface.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_AUTO_GPU_CAPTURE_OUTPUT_FILE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, automatic GPU capture will be handled by the Xcode user interface.
	 */
	const char* autoGPUCaptureOutputFilepath;

	/**
	 * Controls whether MoltenVK should use a Metal 2D texture with a height of 1 for a
	 * Vulkan 1D image, or use a native Metal 1D texture. Metal imposes significant restrictions
	 * on native 1D textures, including not being renderable, clearable, or permitting mipmaps.
	 * Using a Metal 2D texture allows Vulkan 1D textures to support this additional functionality.
	 *
	 * The value of this parameter should only be changed before creating the VkInstance.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_TEXTURE_1D_AS_2D
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is enabled by default, and MoltenVK will
	 * use a Metal 2D texture for each Vulkan 1D image.
	 */
	VkBool32 texture1DAs2D;

	/**
	 * Controls whether MoltenVK should preallocate memory in each VkDescriptorPool according
	 * to the values of the VkDescriptorPoolSize parameters. Doing so may improve descriptor set
	 * allocation performance and memory stability at a cost of preallocated application memory.
	 * If this setting is disabled, the descriptors required for a descriptor set will be individually
	 * dynamically allocated in application memory when the descriptor set itself is allocated.
	 *
	 * The value of this parameter may be changed at any time during application runtime, and the
	 * changed value will affect the behavior of VkDescriptorPools created after the value is changed.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_PREALLOCATE_DESCRIPTORS
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is enabled by default, and MoltenVK will
	 * allocate a pool of descriptors when a VkDescriptorPool is created.
	 */
	VkBool32 preallocateDescriptors;

	/**
	 * Controls whether MoltenVK should use pools to manage memory used when adding commands
	 * to command buffers. If this setting is enabled, MoltenVK will use a pool to hold command
	 * resources for reuse during command execution. If this setting is disabled, command memory
	 * is allocated and destroyed each time a command is executed. This is a classic time-space
	 * trade off. When command pooling is active, the memory in the pool can be cleared via a
	 * call to the vkTrimCommandPoolKHR() command.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will immediately effect behavior of VkCommandPools created
	 * after the setting is changed.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_USE_COMMAND_POOLING
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is enabled by default, and MoltenVK will pool command memory.
	 */
	VkBool32 useCommandPooling;

	/**
	 * Controls whether MoltenVK should use MTLHeaps for allocating textures and buffers
	 * from device memory. If this setting is enabled, and placement MTLHeaps are
	 * available on the platform, MoltenVK will allocate a placement MTLHeap for each VkDeviceMemory
	 * instance, and allocate textures and buffers from that placement heap. If this environment
	 * variable is disabled, MoltenVK will allocate textures and buffers from general device memory.
	 *
	 * Apple recommends that MTLHeaps should only be used for specific requirements such as aliasing
	 * or hazard tracking, and MoltenVK testing has shown that allocating multiple textures of
	 * different types or usages from one MTLHeap can occassionally cause corruption issues under
	 * certain circumstances.
	 *
	 * The value of this parameter must be changed before creating a VkInstance,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_USE_MTLHEAP
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is disabled by default, and MoltenVK
	 * will allocate texures and buffers from general device memory.
	 */
	VkBool32 useMTLHeap;

	/**
	 * Controls when MoltenVK should log activity performance events.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is set to
	 * MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_FRAME_COUNT by default,
	 * and activity performance will be logged when frame activity is logged.
	 */
	MVKConfigActivityPerformanceLoggingStyle activityPerformanceLoggingStyle;
#define logActivityPerformanceInline activityPerformanceLoggingStyle

	/**
	 * Controls the Vulkan API version that MoltenVK should advertise in vkEnumerateInstanceVersion().
	 * When reading this value, it will be one of the VK_API_VERSION_1_* values, including the latest
	 * VK_HEADER_VERSION component. When setting this value, it should be set to one of:
	 *
	 *   VK_API_VERSION_1_2  (equivalent decimal number 4202496)
	 *   VK_API_VERSION_1_1  (equivalent decimal number 4198400)
	 *   VK_API_VERSION_1_0  (equivalent decimal number 4194304)
	 *
	 * MoltenVK will automatically add the VK_HEADER_VERSION component.
	 *
	 * The value of this parameter must be changed before creating a VkInstance,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_API_VERSION_TO_ADVERTISE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this parameter defaults to the highest API version
	 * currently supported by MoltenVK, including the latest VK_HEADER_VERSION component.
	 */
	uint32_t apiVersionToAdvertise;

	/**
	 * Controls which extensions MoltenVK should advertise it supports in
	 * vkEnumerateInstanceExtensionProperties() and vkEnumerateDeviceExtensionProperties().
	 * The value of this parameter is a bitwise OR of values from the MVKConfigAdvertiseExtensionBits
	 * enumeration. Any prerequisite extensions are also advertised.
	 * If the flag MVK_CONFIG_ADVERTISE_EXTENSIONS_ALL is included, all supported extensions
	 * will be advertised. A value of zero means no extensions will be advertised.
	 *
	 * The value of this parameter must be changed before creating a VkInstance,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_ADVERTISE_EXTENSIONS
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, the value of this setting defaults to
	 * MVK_CONFIG_ADVERTISE_EXTENSIONS_ALL, and all supported extensions will be advertised.
	 */
	MVKConfigAdvertiseExtensions advertiseExtensions;

	/**
	 * Controls whether MoltenVK should treat a lost VkDevice as resumable, unless the
	 * corresponding VkPhysicalDevice has also been lost. The VK_ERROR_DEVICE_LOST error has
	 * a broad definitional range, and can mean anything from a GPU hiccup on the current
	 * command buffer submission, to a physically removed GPU. In the case where this error does
	 * not impact the VkPhysicalDevice, Vulkan requires that the app destroy and re-create a new
	 * VkDevice. However, not all apps (including CTS) respect that requirement, leading to what
	 * might be a transient command submission failure causing an unexpected catastrophic app failure.
	 *
	 * If this setting is enabled, in the case of a VK_ERROR_DEVICE_LOST error that does NOT impact
	 * the VkPhysicalDevice, MoltenVK will log the error, but will not mark the VkDevice as lost,
	 * allowing the VkDevice to continue to be used. If this setting is disabled, MoltenVK will
	 * mark the VkDevice as lost, and subsequent use of that VkDevice will be reduced or prohibited.
	 *
	 * The value of this parameter may be changed at any time during application runtime,
	 * and the changed value will affect the error behavior of subsequent command submissions.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_RESUME_LOST_DEVICE
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is disabled by default, and MoltenVK
	 * will mark the VkDevice as lost when a command submission failure occurs.
	 */
	VkBool32 resumeLostDevice;

	/**
	 * Controls whether MoltenVK should use Metal argument buffers for resources defined in
	 * descriptor sets, if Metal argument buffers are supported on the platform. Using Metal
	 * argument buffers dramatically increases the number of buffers, textures and samplers
	 * that can be bound to a pipeline shader, and in most cases improves performance.
	 * This setting is an enumeration that specifies the conditions under which MoltenVK
	 * will use Metal argument buffers.
	 *
	 * NOTE: Currently, Metal argument buffer support is in beta stage, and is only supported
	 * on macOS 11.0 (Big Sur) or later, or on older versions of macOS using an Intel GPU.
	 * Metal argument buffers support is not available on iOS. Development to support iOS
	 * and a wider combination of GPU's on older macOS versions is under way.
	 *
	 * The value of this parameter must be changed before creating a VkDevice,
	 * for the change to take effect.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is set to
	 * MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS_NEVER by default,
	 * and MoltenVK will not use Metal argument buffers.
	 */
	MVKUseMetalArgumentBuffers useMetalArgumentBuffers;

	/**
	 * Controls the type of compression to use on the MSL source code that is stored in memory
	 * for use in a pipeline cache. After being converted from SPIR-V, or loaded directly into
	 * a VkShaderModule, and then compiled into a MTLLibrary, the MSL source code is no longer
	 * needed for operation, but it is retained so it can be written out as part of a pipeline
	 * cache export. When a large number of shaders are loaded, this can consume significant
	 * memory. In such a case, this parameter can be used to compress the MSL source code that
	 * is awaiting export as part of a pipeline cache.
	 *
	 * Pipeline cache compression is available for macOS 10.15 and above, and iOS/tvOS 13.0 and above.
	 *
	 * The value of this parameter can be changed at any time, and will affect the size of
	 * the cached MSL from subsequent shader compilations.
	 *
	 * The initial value or this parameter is set by the
	 * MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM
	 * runtime environment variable or MoltenVK compile-time build setting.
	 * If neither is set, this setting is set to
	 * MVK_CONFIG_COMPRESSION_ALGORITHM_NONE by default,
	 * and MoltenVK will not compress the MSL source code after compilation into a MTLLibrary.
	 */
	MVKConfigCompressionAlgorithm shaderSourceCompressionAlgorithm;

} MVKConfiguration;



#pragma mark -
#pragma mark Function types

	typedef VkResult (VKAPI_PTR *PFN_vkGetMoltenVKConfigurationMVK)(VkInstance ignored, MVKConfiguration* pConfiguration, size_t* pConfigurationSize);
	typedef VkResult (VKAPI_PTR *PFN_vkSetMoltenVKConfigurationMVK)(VkInstance ignored, const MVKConfiguration* pConfiguration, size_t* pConfigurationSize);


#pragma mark -
#pragma mark Function prototypes

#ifndef VK_NO_PROTOTYPES

/**
 * Populates the pConfiguration structure with the current MoltenVK configuration settings.
 *
 * To change a specific configuration value, call vkGetMoltenVKConfigurationMVK() to retrieve
 * the current configuration, make changes, and call  vkSetMoltenVKConfigurationMVK() to
 * update all of the values.
 *
 * The VkInstance object you provide here is ignored, and a VK_NULL_HANDLE value can be provided.
 * This function can be called before the VkInstance has been created. It is safe to call this function
 * with a VkInstance retrieved from a different layer in the Vulkan SDK Loader and Layers framework.
 *
 * To be active, some configuration settings must be set before a VkInstance or VkDevice
 * is created. See the description of the MVKConfiguration members for more information.
 *
 * If you are linking to an implementation of MoltenVK that was compiled from a different
 * MVK_CONFIGURATION_API_VERSION than your app was, the size of the MVKConfiguration structure
 * in your app may be larger or smaller than the same struct as expected by MoltenVK.
 *
 * When calling this function, set the value of *pConfigurationSize to sizeof(MVKConfiguration),
 * to tell MoltenVK the limit of the size of your MVKConfiguration structure. Upon return from
 * this function, the value of *pConfigurationSize will hold the actual number of bytes copied
 * into your passed MVKConfiguration structure, which will be the smaller of what your app
 * thinks is the size of MVKConfiguration, and what MoltenVK thinks it is. This represents the
 * safe access area within the structure for both MoltenVK and your app.
 *
 * If the size that MoltenVK expects for MVKConfiguration is different than the value passed in
 * *pConfigurationSize, this function will return VK_INCOMPLETE, otherwise it will return VK_SUCCESS.
 *
 * Although it is not necessary, you can use this function to determine in advance the value
 * that MoltenVK expects the size of MVKConfiguration to be by setting the value of pConfiguration
 * to NULL. In that case, this function will set *pConfigurationSize to the size that MoltenVK
 * expects MVKConfiguration to be.
 */
VKAPI_ATTR VkResult VKAPI_CALL vkGetMoltenVKConfigurationMVK(
	VkInstance                                  ignored,
	MVKConfiguration*                           pConfiguration,
	size_t*                                     pConfigurationSize);

/**
 * Sets the MoltenVK configuration settings to those found in the pConfiguration structure.
 *
 * To change a specific configuration value, call vkGetMoltenVKConfigurationMVK()
 * to retrieve the current configuration, make changes, and call
 * vkSetMoltenVKConfigurationMVK() to update all of the values.
 *
 * The VkInstance object you provide here is ignored, and a VK_NULL_HANDLE value can be provided.
 * This function can be called before the VkInstance has been created. It is safe to call this function
 * with a VkInstance retrieved from a different layer in the Vulkan SDK Loader and Layers framework.
 *
 * To be active, some configuration settings must be set before a VkInstance or VkDevice
 * is created. See the description of the MVKConfiguration members for more information.
 *
 * If you are linking to an implementation of MoltenVK that was compiled from a different
 * MVK_CONFIGURATION_API_VERSION than your app was, the size of the MVKConfiguration structure
 * in your app may be larger or smaller than the same struct as expected by MoltenVK.
 *
 * When calling this function, set the value of *pConfigurationSize to sizeof(MVKConfiguration),
 * to tell MoltenVK the limit of the size of your MVKConfiguration structure. Upon return from
 * this function, the value of *pConfigurationSize will hold the actual number of bytes copied
 * out of your passed MVKConfiguration structure, which will be the smaller of what your app
 * thinks is the size of MVKConfiguration, and what MoltenVK thinks it is. This represents the
 * safe access area within the structure for both MoltenVK and your app.
 *
 * If the size that MoltenVK expects for MVKConfiguration is different than the value passed in
 * *pConfigurationSize, this function will return VK_INCOMPLETE, otherwise it will return VK_SUCCESS.
 *
 * Although it is not necessary, you can use this function to determine in advance the value
 * that MoltenVK expects the size of MVKConfiguration to be by setting the value of pConfiguration
 * to NULL. In that case, this function will set *pConfigurationSize to the size that MoltenVK
 * expects MVKConfiguration to be.
 */
VKAPI_ATTR VkResult VKAPI_CALL vkSetMoltenVKConfigurationMVK(
	VkInstance                                  ignored,
	const MVKConfiguration*                     pConfiguration,
	size_t*                                     pConfigurationSize);


#pragma mark -
#pragma mark Shaders

	/**
	 * NOTE: Shader code should be submitted as SPIR-V. Although some simple direct MSL shaders may work,
	 * direct loading of MSL source code or compiled MSL code is not officially supported at this time.
	 * Future versions of MoltenVK may support direct MSL submission again.
	 *
	 * Enumerates the magic number values to set in the MVKMSLSPIRVHeader when
	 * submitting a SPIR-V stream that contains either Metal Shading Language source
	 * code or Metal Shading Language compiled binary code in place of SPIR-V code.
	 */
	typedef enum {
		kMVKMagicNumberSPIRVCode        = 0x07230203,    /**< SPIR-V stream contains standard SPIR-V code. */
		kMVKMagicNumberMSLSourceCode    = 0x19960412,    /**< SPIR-V stream contains Metal Shading Language source code. */
		kMVKMagicNumberMSLCompiledCode  = 0x19981215,    /**< SPIR-V stream contains Metal Shading Language compiled binary code. */
	} MVKMSLMagicNumber;

	/**
	 * NOTE: Shader code should be submitted as SPIR-V. Although some simple direct MSL shaders may work,
	 * direct loading of MSL source code or compiled MSL code is not officially supported at this time.
	 * Future versions of MoltenVK may support direct MSL submission again.
	 *
	 * Describes the header at the start of an SPIR-V stream, when it contains either
	 * Metal Shading Language source code or Metal Shading Language compiled binary code.
	 *
	 * To submit MSL source code to the vkCreateShaderModule() function in place of SPIR-V
	 * code, prepend a MVKMSLSPIRVHeader containing the kMVKMagicNumberMSLSourceCode magic
	 * number to the MSL source code. The MSL source code must be null-terminated.
	 *
	 * To submit MSL compiled binary code to the vkCreateShaderModule() function in place of
	 * SPIR-V code, prepend a MVKMSLSPIRVHeader containing the kMVKMagicNumberMSLCompiledCode
	 * magic number to the MSL compiled binary code.
	 *
	 * In both cases, the pCode element of VkShaderModuleCreateInfo should pointer to the
	 * location of the MVKMSLSPIRVHeader, and the MSL code should start at the byte immediately
	 * after the MVKMSLSPIRVHeader.
	 *
	 * The codeSize element of VkShaderModuleCreateInfo should be set to the entire size of
	 * the submitted code memory, including the additional sizeof(MVKMSLSPIRVHeader) bytes
	 * taken up by the MVKMSLSPIRVHeader, and, in the case of MSL source code, including
	 * the null-terminator byte.
	 */
	typedef uint32_t MVKMSLSPIRVHeader;


#endif // VK_NO_PROTOTYPES

#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
