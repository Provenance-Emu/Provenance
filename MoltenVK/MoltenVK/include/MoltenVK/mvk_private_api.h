/*
 * mvk_private_api.h
 *
 * Copyright (c) 2015-2026 The Brenwill Workshop Ltd. (http://www.brenwill.com)
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

#ifndef __mvk_private_api_h_
#define __mvk_private_api_h_ 1

#ifdef __cplusplus
extern "C" {
#endif	//  __cplusplus

#include <vulkan/vulkan.h>

#ifdef __OBJC__
#import <Metal/Metal.h>
#else
typedef unsigned long MTLLanguageVersion;
typedef unsigned long MTLArgumentBuffersTier;
#endif


/**
 * This header contains private structures and functions to query MoltenVK about MoltenVK version
 * and configuration,  runtime performance information, and available Metal capabilities.
 *
 * NOTE: THE FUNCTIONS BELOW SHOULD BE USED WITH CARE. THESE FUNCTIONS ARE
 * NOT PART OF VULKAN, AND ARE NOT SUPPORTED BY THE VULKAN LOADER AND LAYERS.
 * THE VULKAN OBJECTS PASSED IN THESE FUNCTIONS MUST HAVE BEEN RETRIEVED
 * DIRECTLY FROM MOLTENVK, WITHOUT LINKING THROUGH THE VULKAN LOADER AND LAYERS.
 */


#define MVK_PRIVATE_API_VERSION   43


#pragma mark -
#pragma mark MoltenVK version

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
#define MVK_VERSION_MINOR   4
#define MVK_VERSION_PATCH   2

#define MVK_MAKE_VERSION(major, minor, patch)  (((major) * 10000) + ((minor) * 100) + (patch))
#define MVK_VERSION              MVK_MAKE_VERSION(MVK_VERSION_MAJOR, MVK_VERSION_MINOR, MVK_VERSION_PATCH)

#define MVK_STRINGIFY_IMPL(val)	 #val
#define MVK_STRINGIFY(val)       MVK_STRINGIFY_IMPL(val)
#define MVK_VERSION_STRING       (MVK_STRINGIFY(MVK_VERSION_MAJOR) "." MVK_STRINGIFY(MVK_VERSION_MINOR) "." MVK_STRINGIFY(MVK_VERSION_PATCH))

#pragma mark -
#pragma mark MoltenVK configuration

/**
 * MoltenVK provides the ability to configure and optimize MoltenVK for your particular
 * application runtime requirements and development-time needs.
 *
 * At runtime, configuration can be helpful in situtations where Metal behavior is different
 * than Vulkan behavior, and the results or performance you receive can depend on how MoltenVK
 * works around those differences, which, in turn, may depend on how you are using Vulkan.
 * Different apps might benefit differently in this handling.
 *
 * Additional configuration parameters can be helpful at development time by providing 
 * you with additional tracing, debugging, and performance measuring capabilities.
 *
 * Each configuration parameter has a name and value, and can be passed to MoltenVK
 * via any of the following mechanisms:
 *
 *   - The standard Vulkan VK_EXT_layer_settings extension (layer name "MoltenVK").
 *   - Application runtime environment variables.
 *   - Build settings at MoltenVK build time.
 *
 * Parameter values configured by build settings at MoltenVK build time can be overridden
 * by values set by environment variables, which, in turn, can be overridden during VkInstance
 * creation via the Vulkan VK_EXT_layer_settings extension.
 */

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
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_NONE      = 0,	/**< No automatic GPU capture. */
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_DEVICE    = 1,	/**< Automatically capture all GPU activity during the lifetime of a VkDevice. */
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_FRAME     = 2,	/**< Automatically capture all GPU activity during the rendering and presentation of the first frame. */
	MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE_ON_DEMAND = 3,	/**< Capture all GPU activity when signaled on a temporary named pipe. */
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
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_FRAME_COUNT                = 0,	/**< Repeatedly log performance after a configured number of frames. */
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_IMMEDIATE                  = 1,	/**< Log immediately after each performance measurement. */
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_DEVICE_LIFETIME            = 2,	/**< Log at the end of the VkDevice lifetime. This is useful for one-shot apps such as testing frameworks. */
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_DEVICE_LIFETIME_ACCUMULATE = 3,	/**< Log at the end of the VkDevice lifetime, but continue to accumulate across mulitiple VkDevices throughout the app process. This is useful for testing frameworks that create many VkDevices serially. */
	MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE_MAX_ENUM                   = 0x7FFFFFFF,
} MVKConfigActivityPerformanceLoggingStyle;

/** Identifies when MTLHeap is used to allocate buffer and image resources. */
typedef enum MVKConfigUseMTLHeap {
	MVK_CONFIG_USE_MTLHEAP_NEVER      = 0,  /**< Do not use MTLHeap for allocating resources. */
	MVK_CONFIG_USE_MTLHEAP_WHERE_SAFE = 1,  /**< Use MTLHeap for allocating resources, where safe to do so. On AMD GPUs, this is the same as MVK_CONFIG_USE_MTLHEAP_NEVER, due to potential challenges with MTLHeap usage on those platforms. On other GPUs this is the same as MVK_CONFIG_USE_MTLHEAP_ALWAYS. */
	MVK_CONFIG_USE_MTLHEAP_ALWAYS     = 2,  /**< Use MTLHeap for allocating resources. */
	MVK_CONFIG_USE_MTLHEAP_MAX_ENUM   = 0x7FFFFFFF
} MVKConfigUseMTLHeap;

/**
 * MoltenVK configuration. You can retrieve a copy of this structure using the vkGetMoltenVKConfigurationMVK() function.
 *
 * This structure may be extended as new configuration options are added to MoltenVK.
 * If you are linking to an implementation of MoltenVK that was compiled from a different
 * MVK_PRIVATE_API_VERSION than your app was, the size of this structure in your app 
 * may be larger or smaller than the struct in MoltenVK. See the description of the
 * vkGetMoltenVKConfigurationMVK() function for information about how to handle this.
 *
 * TO SUPPORT DYNAMIC LINKING TO THIS STRUCTURE AS DESCRIBED ABOVE, THIS STRUCTURE SHOULD NOT BE CHANGED
 * EXCEPT TO ADD ADDITIONAL MEMBERS ON THE END. THE ORDER AND SIZE OF EXISTING MEMBERS SHOULD NOT BE CHANGED.
 */
typedef struct {
    VkBool32 debugMode;                                                        /**< MVK_CONFIG_DEBUG */
    VkBool32 shaderConversionFlipVertexY;                                      /**< MVK_CONFIG_SHADER_CONVERSION_FLIP_VERTEX_Y */
	VkBool32 synchronousQueueSubmits;                                          /**< MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS */
	MVKPrefillMetalCommandBuffersStyle prefillMetalCommandBuffers;             /**< MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS */
	uint32_t maxActiveMetalCommandBuffersPerQueue;                             /**< MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE */
	VkBool32 supportLargeQueryPools;                                           /**< Obsolete, deprecated, and ignored. */
	VkBool32 presentWithCommandBuffer;                                         /**< Obsolete, deprecated, and ignored. */
	VkBool32 swapchainMinMagFilterUseNearest;                                  /**< MVK_CONFIG_SWAPCHAIN_MIN_MAG_FILTER_USE_NEAREST */
	uint64_t metalCompileTimeout;                                              /**< MVK_CONFIG_METAL_COMPILE_TIMEOUT */
	VkBool32 performanceTracking;                                              /**< MVK_CONFIG_PERFORMANCE_TRACKING */
	uint32_t performanceLoggingFrameCount;                                     /**< MVK_CONFIG_PERFORMANCE_LOGGING_FRAME_COUNT */
	VkBool32 displayWatermark;                                                 /**< MVK_CONFIG_DISPLAY_WATERMARK */
	VkBool32 specializedQueueFamilies;                                         /**< MVK_CONFIG_SPECIALIZED_QUEUE_FAMILIES */
	VkBool32 switchSystemGPU;                                                  /**< MVK_CONFIG_SWITCH_SYSTEM_GPU */
	VkBool32 fullImageViewSwizzle;                                             /**< Obsolete, deprecated, and ignored. */
	uint32_t defaultGPUCaptureScopeQueueFamilyIndex;                           /**< MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_FAMILY_INDEX */
	uint32_t defaultGPUCaptureScopeQueueIndex;                                 /**< MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_INDEX */
	MVKConfigFastMath fastMathEnabled;                                         /**< MVK_CONFIG_FAST_MATH_ENABLED */
	MVKConfigLogLevel logLevel;                                                /**< MVK_CONFIG_LOG_LEVEL */
	MVKConfigTraceVulkanCalls traceVulkanCalls;                                /**< MVK_CONFIG_TRACE_VULKAN_CALLS */
	VkBool32 forceLowPowerGPU;                                                 /**< MVK_CONFIG_FORCE_LOW_POWER_GPU */
	VkBool32 semaphoreUseMTLFence;                                             /**< Obsolete, deprecated, and ignored. */
	MVKVkSemaphoreSupportStyle semaphoreSupportStyle;                          /**< MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE */
	MVKConfigAutoGPUCaptureScope autoGPUCaptureScope;                          /**< MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE */
	const char* autoGPUCaptureOutputFilepath;                                  /**< MVK_CONFIG_AUTO_GPU_CAPTURE_OUTPUT_FILE */
	VkBool32 texture1DAs2D;                                                    /**< MVK_CONFIG_TEXTURE_1D_AS_2D */
	VkBool32 preallocateDescriptors;                                           /**< Obsolete, deprecated, and ignored. */
	VkBool32 useCommandPooling;                                                /**< MVK_CONFIG_USE_COMMAND_POOLING */
	MVKConfigUseMTLHeap useMTLHeap;                                            /**< MVK_CONFIG_USE_MTLHEAP */
	MVKConfigActivityPerformanceLoggingStyle activityPerformanceLoggingStyle;  /**< MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE */
	uint32_t apiVersionToAdvertise;                                            /**< MVK_CONFIG_API_VERSION_TO_ADVERTISE */
	MVKConfigAdvertiseExtensions advertiseExtensions;                          /**< MVK_CONFIG_ADVERTISE_EXTENSIONS */
	VkBool32 resumeLostDevice;                                                 /**< MVK_CONFIG_RESUME_LOST_DEVICE */
	VkBool32 useMetalArgumentBuffers;                                          /**< MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS */
	MVKConfigCompressionAlgorithm shaderSourceCompressionAlgorithm;            /**< MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM */
	VkBool32 shouldMaximizeConcurrentCompilation;                              /**< MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION */
	float timestampPeriodLowPassAlpha;                                         /**< MVK_CONFIG_TIMESTAMP_PERIOD_LOWPASS_ALPHA */
	VkBool32 useMetalPrivateAPI;                                               /**< MVK_CONFIG_USE_METAL_PRIVATE_API */
	const char* shaderDumpDir;                                                 /**< MVK_CONFIG_SHADER_DUMP_DIR */
	VkBool32 shaderLogEstimatedGLSL;                                           /**< MVK_CONFIG_SHADER_LOG_ESTIMATED_GLSL */
	VkBool32 liveCheckAllResources;                                            /**< MVK_CONFIG_LIVE_CHECK_ALL_RESOURCES */
} MVKConfiguration;

// Legacy support for renamed struct elements.
#define swapchainMagFilterUseNearest swapchainMinMagFilterUseNearest
#define semaphoreUseMTLEvent semaphoreSupportStyle
#define logActivityPerformanceInline activityPerformanceLoggingStyle


#pragma mark -
#pragma mark Performance statistics

/**
 * MoltenVK performance of a particular type of activity.
 * Durations are recorded in milliseconds. Memory sizes are recorded in kilobytes.
 */
typedef struct {
    uint32_t count;       /**< The number of activities of this type. */
	double latest;        /**< The latest (most recent) value of the activity. */
	double previous;      /**< The previous (second most recent) value of the activity. */
    double average;       /**< The average value of the activity. */
    double minimum;       /**< The minimum value of the activity. */
    double maximum;       /**< The maximum value of the activity. */
} MVKPerformanceTracker;

/** MoltenVK performance of shader compilation activities. */
typedef struct {
	MVKPerformanceTracker hashShaderCode;				/** Create a hash from the incoming shader code, in milliseconds. */
    MVKPerformanceTracker spirvToMSL;					/** Convert SPIR-V to MSL source code, in milliseconds. */
    MVKPerformanceTracker mslCompile;					/** Compile MSL source code into a MTLLibrary, in milliseconds. */
    MVKPerformanceTracker mslLoad;						/** Load pre-compiled MSL code into a MTLLibrary, in milliseconds. */
	MVKPerformanceTracker mslCompress;					/** Compress MSL source code after compiling a MTLLibrary, to hold it in a pipeline cache, in milliseconds. */
	MVKPerformanceTracker mslDecompress;				/** Decompress MSL source code to write the MSL when serializing a pipeline cache, in milliseconds. */
	MVKPerformanceTracker shaderLibraryFromCache;		/** Retrieve a shader library from the cache, lazily creating it if needed, in milliseconds. */
    MVKPerformanceTracker functionRetrieval;			/** Retrieve a MTLFunction from a MTLLibrary, in milliseconds. */
    MVKPerformanceTracker functionSpecialization;		/** Specialize a retrieved MTLFunction, in milliseconds. */
    MVKPerformanceTracker pipelineCompile;				/** Compile MTLFunctions into a pipeline, in milliseconds. */
	MVKPerformanceTracker glslToSPRIV;					/** Convert GLSL to SPIR-V code, in milliseconds. */
} MVKShaderCompilationPerformance;

/** MoltenVK performance of pipeline cache activities. */
typedef struct {
	MVKPerformanceTracker sizePipelineCache;			/** Calculate the size of cache data required to write MSL to pipeline cache data stream, in milliseconds. */
	MVKPerformanceTracker writePipelineCache;			/** Write MSL to pipeline cache data stream, in milliseconds. */
	MVKPerformanceTracker readPipelineCache;			/** Read MSL from pipeline cache data stream, in milliseconds. */
} MVKPipelineCachePerformance;

/** MoltenVK performance of queue activities. */
typedef struct {
	MVKPerformanceTracker retrieveMTLCommandBuffer;     /** Retrieve a MTLCommandBuffer from a MTLQueue, in milliseconds. */
	MVKPerformanceTracker commandBufferEncoding;        /** Encode a single VkCommandBuffer to a MTLCommandBuffer (excludes MTLCommandBuffer encoding from configured immediate prefilling), in milliseconds. */
	MVKPerformanceTracker waitSubmitCommandBuffers;		/** Wait time from vkQueueSubmit() call to starting the encoding of the command buffers to the GPU, in milliseconds. Useful when MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS is disabled. */
	MVKPerformanceTracker submitCommandBuffers;         /** Submit and encode all VkCommandBuffers in a vkQueueSubmit() operation to MTLCommandBuffers (including both prefilled and deferred encoding), in milliseconds. */
	MVKPerformanceTracker mtlCommandBufferExecution;    /** Execute a MTLCommandBuffer on the GPU, from commit to completion callback, in milliseconds. */
	MVKPerformanceTracker retrieveCAMetalDrawable;      /** Retrieve next CAMetalDrawable from a CAMetalLayer, in milliseconds. */
	MVKPerformanceTracker waitPresentSwapchains;		/** Wait time from vkQueuePresentKHR() call to starting the encoding of the swapchains to the GPU, in milliseconds. Useful when MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS is disabled. */
	MVKPerformanceTracker presentSwapchains;            /** Present the swapchains in a vkQueuePresentKHR() on the GPU, from commit to presentation callback, in milliseconds. */
	MVKPerformanceTracker frameInterval;                /** Frame presentation interval (1000/FPS), in milliseconds. */
} MVKQueuePerformance;

/** MoltenVK performance of device activities. */
typedef struct {
	MVKPerformanceTracker gpuMemoryAllocated;		/** GPU memory allocated, in kilobytes. */
} MVKDevicePerformance;

/**
 * MoltenVK performance. You can retrieve a copy of this structure using the vkGetPerformanceStatisticsMVK() function.
 *
 * This structure may be extended as new features are added to MoltenVK. If you are linking to
 * an implementation of MoltenVK that was compiled from a different MVK_PRIVATE_API_VERSION
 * than your app was, the size of this structure in your app may be larger or smaller than the
 * struct in MoltenVK. See the description of the vkGetPerformanceStatisticsMVK() function for
 * information about how to handle this.
 */
typedef struct {
	MVKShaderCompilationPerformance shaderCompilation;	/** Shader compilations activities. */
	MVKPipelineCachePerformance pipelineCache;			/** Pipeline cache activities. */
	MVKQueuePerformance queue;          				/** Queue activities. */
	MVKDevicePerformance device;          				/** Device activities. */
} MVKPerformanceStatistics;


#pragma mark -
#pragma mark Function types

typedef VkResult (VKAPI_PTR *PFN_vkGetMoltenVKConfigurationMVK)(VkInstance ignored, MVKConfiguration* pConfiguration, size_t* pConfigurationSize);
typedef VkResult (VKAPI_PTR *PFN_vkGetPerformanceStatisticsMVK)(VkDevice device, MVKPerformanceStatistics* pPerf, size_t* pPerfSize);


#pragma mark -
#pragma mark Function prototypes

#ifndef VK_NO_PROTOTYPES

/**
 * Populates the pConfiguration structure with the current global MoltenVK configuration settings.
 *
 * The VkInstance object you provide here is ignored, and a VK_NULL_HANDLE value can be provided.
 * This function can be called before the VkInstance has been created. It is safe to call this function
 * with a VkInstance retrieved from a different layer in the Vulkan SDK Loader and Layers framework.
 *
 * If you are linking to an implementation of MoltenVK that was compiled from a different
 * MVK_PRIVATE_API_VERSION than your app was, the size of the MVKConfiguration structure
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
 * Populates the pPerf structure with the current performance statistics for the device.
 *
 * If you are linking to an implementation of MoltenVK that was compiled from a different
 * MVK_PRIVATE_API_VERSION than your app was, the size of the MVKPerformanceStatistics
 * structure in your app may be larger or smaller than the same struct as expected by MoltenVK.
 *
 * When calling this function, set the value of *pPerfSize to sizeof(MVKPerformanceStatistics),
 * to tell MoltenVK the limit of the size of your MVKPerformanceStatistics structure. Upon return
 * from this function, the value of *pPerfSize will hold the actual number of bytes copied into
 * your passed MVKPerformanceStatistics structure, which will be the smaller of what your app
 * thinks is the size of MVKPerformanceStatistics, and what MoltenVK thinks it is.
 *
 * If the size that MoltenVK expects for MVKPerformanceStatistics is different than the value passed
 * in *pPerfSize, this function will return VK_INCOMPLETE, otherwise it will return VK_SUCCESS.
 * This indicates that the data returned from this function will likely be incorrect, as the structures
 * nested under MVKPerformanceStatistics may be different.
 *
 * Although it is not necessary, you can use this function to determine in advance the value
 * that MoltenVK expects the size of MVKPerformanceStatistics to be by setting the value of
 * pPerf to NULL. In that case, this function will set *pPerfSize to the size that MoltenVK
 * expects MVKPerformanceStatistics to be.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
VKAPI_ATTR VkResult VKAPI_CALL vkGetPerformanceStatisticsMVK(
	VkDevice                                    device,
	MVKPerformanceStatistics*            		pPerf,
	size_t*                                     pPerfSize);


#endif // VK_NO_PROTOTYPES


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


#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
