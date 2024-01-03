/*
 * mvk_private_api.h
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
 * This header contains functions to query MoltenVK about
 * available Metal features, and runtime performance information.
 *
 * NOTE: THE FUNCTIONS BELOW SHOULD BE USED WITH CARE. THESE FUNCTIONS ARE
 * NOT PART OF VULKAN, AND ARE NOT SUPPORTED BY THE VULKAN LOADER AND LAYERS.
 * THE VULKAN OBJECTS PASSED IN THESE FUNCTIONS MUST HAVE BEEN RETRIEVED
 * DIRECTLY FROM MOLTENVK, WITHOUT LINKING THROUGH THE VULKAN LOADER AND LAYERS.
 */


#define MVK_PRIVATE_API_VERSION   37


/** Identifies the type of rounding Metal uses for float to integer conversions in particular calculatons. */
typedef enum MVKFloatRounding {
	MVK_FLOAT_ROUNDING_NEAREST     = 0,	 /**< Metal rounds to nearest. */
	MVK_FLOAT_ROUNDING_UP          = 1,	 /**< Metal rounds towards positive infinity. */
	MVK_FLOAT_ROUNDING_DOWN        = 2,	 /**< Metal rounds towards negative infinity. */
	MVK_FLOAT_ROUNDING_UP_MAX_ENUM = 0x7FFFFFFF
} MVKFloatRounding;

/** Identifies the pipeline points where GPU counter sampling can occur. Maps to MTLCounterSamplingPoint. */
typedef enum MVKCounterSamplingBits {
	MVK_COUNTER_SAMPLING_AT_DRAW           = 0x00000001,
	MVK_COUNTER_SAMPLING_AT_DISPATCH       = 0x00000002,
	MVK_COUNTER_SAMPLING_AT_BLIT           = 0x00000004,
	MVK_COUNTER_SAMPLING_AT_PIPELINE_STAGE = 0x00000008,
	MVK_COUNTER_SAMPLING_MAX_ENUM          = 0X7FFFFFFF
} MVKCounterSamplingBits;
typedef VkFlags MVKCounterSamplingFlags;

/**
 * Features provided by the current implementation of Metal on the current device. You can
 * retrieve a copy of this structure using the vkGetPhysicalDeviceMetalFeaturesMVK() function.
 *
 * This structure may be extended as new features are added to MoltenVK. If you are linking to
 * an implementation of MoltenVK that was compiled from a different MVK_PRIVATE_API_VERSION
 * than your app was, the size of this structure in your app may be larger or smaller than the
 * struct in MoltenVK. See the description of the vkGetPhysicalDeviceMetalFeaturesMVK() function
 * for information about how to handle this.
 *
 * TO SUPPORT DYNAMIC LINKING TO THIS STRUCTURE AS DESCRIBED ABOVE, THIS STRUCTURE SHOULD NOT
 * BE CHANGED EXCEPT TO ADD ADDITIONAL MEMBERS ON THE END. EXISTING MEMBERS, AND THEIR ORDER,
 * SHOULD NOT BE CHANGED.
 */
typedef struct {
    uint32_t mslVersion;                        	/**< The version of the Metal Shading Language available on this device. The format of the integer is MMmmpp, with two decimal digts each for Major, minor, and patch version values (eg. MSL 1.2 would appear as 010200). */
	VkBool32 indirectDrawing;                   	/**< If true, draw calls support parameters held in a GPU buffer. */
	VkBool32 baseVertexInstanceDrawing;         	/**< If true, draw calls support specifiying the base vertex and instance. */
    uint32_t dynamicMTLBufferSize;              	/**< If greater than zero, dynamic MTLBuffers for setting vertex, fragment, and compute bytes are supported, and their content must be below this value. */
    VkBool32 shaderSpecialization;              	/**< If true, shader specialization (aka Metal function constants) is supported. */
    VkBool32 ioSurfaces;                        	/**< If true, VkImages can be underlaid by IOSurfaces via the vkUseIOSurfaceMVK() function, to support inter-process image transfers. */
    VkBool32 texelBuffers;                      	/**< If true, texel buffers are supported, allowing the contents of a buffer to be interpreted as an image via a VkBufferView. */
	VkBool32 layeredRendering;                  	/**< If true, layered rendering to multiple cube or texture array layers is supported. */
	VkBool32 presentModeImmediate;              	/**< If true, immediate surface present mode (VK_PRESENT_MODE_IMMEDIATE_KHR), allowing a swapchain image to be presented immediately, without waiting for the vertical sync period of the display, is supported. */
	VkBool32 stencilViews;                      	/**< If true, stencil aspect views are supported through the MTLPixelFormatX24_Stencil8 and MTLPixelFormatX32_Stencil8 formats. */
	VkBool32 multisampleArrayTextures;          	/**< If true, MTLTextureType2DMultisampleArray is supported. */
	VkBool32 samplerClampToBorder;              	/**< If true, the border color set when creating a sampler will be respected. */
	uint32_t maxTextureDimension; 	     	  		/**< The maximum size of each texture dimension (width, height, or depth). */
	uint32_t maxPerStageBufferCount;            	/**< The total number of per-stage Metal buffers available for shader uniform content and attributes. */
    uint32_t maxPerStageTextureCount;           	/**< The total number of per-stage Metal textures available for shader uniform content. */
    uint32_t maxPerStageSamplerCount;           	/**< The total number of per-stage Metal samplers available for shader uniform content. */
    VkDeviceSize maxMTLBufferSize;              	/**< The max size of a MTLBuffer (in bytes). */
    VkDeviceSize mtlBufferAlignment;            	/**< The alignment used when allocating memory for MTLBuffers. Must be PoT. */
    VkDeviceSize maxQueryBufferSize;            	/**< The maximum size of an occlusion query buffer (in bytes). */
	VkDeviceSize mtlCopyBufferAlignment;        	/**< The alignment required during buffer copy operations (in bytes). */
    VkSampleCountFlags supportedSampleCounts;   	/**< A bitmask identifying the sample counts supported by the device. */
	uint32_t minSwapchainImageCount;	 	  		/**< The minimum number of swapchain images that can be supported by a surface. */
	uint32_t maxSwapchainImageCount;	 	  		/**< The maximum number of swapchain images that can be supported by a surface. */
	VkBool32 combinedStoreResolveAction;			/**< If true, the device supports VK_ATTACHMENT_STORE_OP_STORE with a simultaneous resolve attachment. */
	VkBool32 arrayOfTextures;			 	  		/**< If true, arrays of textures is supported. */
	VkBool32 arrayOfSamplers;			 	  		/**< If true, arrays of texture samplers is supported. */
	MTLLanguageVersion mslVersionEnum;				/**< The version of the Metal Shading Language available on this device, as a Metal enumeration. */
	VkBool32 depthSampleCompare;					/**< If true, depth texture samplers support the comparison of the pixel value against a reference value. */
	VkBool32 events;								/**< If true, Metal synchronization events (MTLEvent) are supported. */
	VkBool32 memoryBarriers;						/**< If true, full memory barriers within Metal render passes are supported. */
	VkBool32 multisampleLayeredRendering;       	/**< If true, layered rendering to multiple multi-sampled cube or texture array layers is supported. */
	VkBool32 stencilFeedback;						/**< If true, fragment shaders that write to [[stencil]] outputs are supported. */
	VkBool32 textureBuffers;						/**< If true, textures of type MTLTextureTypeBuffer are supported. */
	VkBool32 postDepthCoverage;						/**< If true, coverage masks in fragment shaders post-depth-test are supported. */
	VkBool32 fences;								/**< If true, Metal synchronization fences (MTLFence) are supported. */
	VkBool32 rasterOrderGroups;						/**< If true, Raster order groups in fragment shaders are supported. */
	VkBool32 native3DCompressedTextures;			/**< If true, 3D compressed images are supported natively, without manual decompression. */
	VkBool32 nativeTextureSwizzle;					/**< If true, component swizzle is supported natively, without manual swizzling in shaders. */
	VkBool32 placementHeaps;						/**< If true, MTLHeap objects support placement of resources. */
	VkDeviceSize pushConstantSizeAlignment;			/**< The alignment used internally when allocating memory for push constants. Must be PoT. */
	uint32_t maxTextureLayers;						/**< The maximum number of layers in an array texture. */
    uint32_t maxSubgroupSize;			        	/**< The maximum number of threads in a SIMD-group. */
	VkDeviceSize vertexStrideAlignment;         	/**< The alignment used for the stride of vertex attribute bindings. */
	VkBool32 indirectTessellationDrawing;			/**< If true, tessellation draw calls support parameters held in a GPU buffer. */
	VkBool32 nonUniformThreadgroups;				/**< If true, the device supports arbitrary-sized grids in compute workloads. */
	VkBool32 renderWithoutAttachments;          	/**< If true, we don't have to create a dummy attachment for a render pass if there isn't one. */
	VkBool32 deferredStoreActions;					/**< If true, render pass store actions can be specified after the render encoder is created. */
	VkBool32 sharedLinearTextures;					/**< If true, linear textures and texture buffers can be created from buffers in Shared storage. */
	VkBool32 depthResolve;							/**< If true, resolving depth textures with filters other than Sample0 is supported. */
	VkBool32 stencilResolve;						/**< If true, resolving stencil textures with filters other than Sample0 is supported. */
	uint32_t maxPerStageDynamicMTLBufferCount;		/**< The maximum number of inline buffers that can be set on a command buffer. */
	uint32_t maxPerStageStorageTextureCount;    	/**< The total number of per-stage Metal textures with read-write access available for writing to from a shader. */
	VkBool32 astcHDRTextures;						/**< If true, ASTC HDR pixel formats are supported. */
	VkBool32 renderLinearTextures;					/**< If true, linear textures are renderable. */
	VkBool32 pullModelInterpolation;				/**< If true, explicit interpolation functions are supported. */
	VkBool32 samplerMirrorClampToEdge;				/**< If true, the mirrored clamp to edge address mode is supported in samplers. */
	VkBool32 quadPermute;							/**< If true, quadgroup permutation functions (vote, ballot, shuffle) are supported in shaders. */
	VkBool32 simdPermute;							/**< If true, SIMD-group permutation functions (vote, ballot, shuffle) are supported in shaders. */
	VkBool32 simdReduction;							/**< If true, SIMD-group reduction functions (arithmetic) are supported in shaders. */
    uint32_t minSubgroupSize;			        	/**< The minimum number of threads in a SIMD-group. */
    VkBool32 textureBarriers;                   	/**< If true, texture barriers are supported within Metal render passes. */
    VkBool32 tileBasedDeferredRendering;        	/**< If true, this device uses tile-based deferred rendering. */
	VkBool32 argumentBuffers;						/**< If true, Metal argument buffers are supported. */
	VkBool32 descriptorSetArgumentBuffers;			/**< If true, a Metal argument buffer can be assigned to a descriptor set, and used on any pipeline and pipeline stage. If false, a different Metal argument buffer must be used for each pipeline-stage/descriptor-set combination. */
	MVKFloatRounding clearColorFloatRounding;		/**< Identifies the type of rounding Metal uses for MTLClearColor float to integer conversions. */
	MVKCounterSamplingFlags counterSamplingPoints;	/**< Identifies the points where pipeline GPU counter sampling may occur. */
	VkBool32 programmableSamplePositions;			/**< If true, programmable MSAA sample positions are supported. */
	VkBool32 shaderBarycentricCoordinates;			/**< If true, fragment shader barycentric coordinates are supported. */
	MTLArgumentBuffersTier argumentBuffersTier;		/**< The argument buffer tier available on this device, as a Metal enumeration. */
	VkBool32 needsSampleDrefLodArrayWorkaround;		/**< If true, sampling from arrayed depth images with explicit LoD is broken and needs a workaround. */
	VkDeviceSize hostMemoryPageSize;				/**< The size of a page of host memory on this platform. */
} MVKPhysicalDeviceMetalFeatures;

/** MoltenVK performance of a particular type of activity. */
typedef struct {
    uint32_t count;             /**< The number of activities of this type. */
	double latestDuration;      /**< The latest (most recent) duration of the activity, in milliseconds. */
    double averageDuration;     /**< The average duration of the activity, in milliseconds. */
    double minimumDuration;     /**< The minimum duration of the activity, in milliseconds. */
    double maximumDuration;     /**< The maximum duration of the activity, in milliseconds. */
} MVKPerformanceTracker;

/** MoltenVK performance of shader compilation activities. */
typedef struct {
	MVKPerformanceTracker hashShaderCode;				/** Create a hash from the incoming shader code. */
    MVKPerformanceTracker spirvToMSL;					/** Convert SPIR-V to MSL source code. */
    MVKPerformanceTracker mslCompile;					/** Compile MSL source code into a MTLLibrary. */
    MVKPerformanceTracker mslLoad;						/** Load pre-compiled MSL code into a MTLLibrary. */
	MVKPerformanceTracker mslCompress;					/** Compress MSL source code after compiling a MTLLibrary, to hold it in a pipeline cache. */
	MVKPerformanceTracker mslDecompress;				/** Decompress MSL source code to write the MSL when serializing a pipeline cache. */
	MVKPerformanceTracker shaderLibraryFromCache;		/** Retrieve a shader library from the cache, lazily creating it if needed. */
    MVKPerformanceTracker functionRetrieval;			/** Retrieve a MTLFunction from a MTLLibrary. */
    MVKPerformanceTracker functionSpecialization;		/** Specialize a retrieved MTLFunction. */
    MVKPerformanceTracker pipelineCompile;				/** Compile MTLFunctions into a pipeline. */
	MVKPerformanceTracker glslToSPRIV;					/** Convert GLSL to SPIR-V code. */
} MVKShaderCompilationPerformance;

/** MoltenVK performance of pipeline cache activities. */
typedef struct {
	MVKPerformanceTracker sizePipelineCache;			/** Calculate the size of cache data required to write MSL to pipeline cache data stream. */
	MVKPerformanceTracker writePipelineCache;			/** Write MSL to pipeline cache data stream. */
	MVKPerformanceTracker readPipelineCache;			/** Read MSL from pipeline cache data stream. */
} MVKPipelineCachePerformance;

/** MoltenVK performance of queue activities. */
typedef struct {
	MVKPerformanceTracker mtlQueueAccess;               /** Create an MTLCommandQueue or access an existing cached instance. */
	MVKPerformanceTracker mtlCommandBufferCompletion;   /** Completion of a MTLCommandBuffer on the GPU, from commit to completion callback. */
	MVKPerformanceTracker nextCAMetalDrawable;			/** Retrieve next CAMetalDrawable from CAMetalLayer during presentation. */
	MVKPerformanceTracker frameInterval;				/** Frame presentation interval (1000/FPS). */
} MVKQueuePerformance;

/**
 * MoltenVK performance. You can retrieve a copy of this structure using the vkGetPerformanceStatisticsMVK() function.
 *
 * This structure may be extended as new features are added to MoltenVK. If you are linking to
 * an implementation of MoltenVK that was compiled from a different MVK_PRIVATE_API_VERSION
 * than your app was, the size of this structure in your app may be larger or smaller than the
 * struct in MoltenVK. See the description of the vkGetPerformanceStatisticsMVK() function for
 * information about how to handle this.
 *
 * TO SUPPORT DYNAMIC LINKING TO THIS STRUCTURE AS DESCRIBED ABOVE, THIS STRUCTURE SHOULD NOT
 * BE CHANGED EXCEPT TO ADD ADDITIONAL MEMBERS ON THE END. EXISTING MEMBERS, AND THEIR ORDER,
 * SHOULD NOT BE CHANGED.
 */
typedef struct {
	MVKShaderCompilationPerformance shaderCompilation;	/** Shader compilations activities. */
	MVKPipelineCachePerformance pipelineCache;			/** Pipeline cache activities. */
	MVKQueuePerformance queue;          				/** Queue activities. */
} MVKPerformanceStatistics;


#pragma mark -
#pragma mark Function types

typedef VkResult (VKAPI_PTR *PFN_vkGetPhysicalDeviceMetalFeaturesMVK)(VkPhysicalDevice physicalDevice, MVKPhysicalDeviceMetalFeatures* pMetalFeatures, size_t* pMetalFeaturesSize);
typedef VkResult (VKAPI_PTR *PFN_vkGetPerformanceStatisticsMVK)(VkDevice device, MVKPerformanceStatistics* pPerf, size_t* pPerfSize);


#pragma mark -
#pragma mark Function prototypes

#ifndef VK_NO_PROTOTYPES

/** 
 * Populates the pMetalFeatures structure with the Metal-specific features
 * supported by the specified physical device. 
 *
 * If you are linking to an implementation of MoltenVK that was compiled from a different
 * MVK_PRIVATE_API_VERSION than your app was, the size of the MVKPhysicalDeviceMetalFeatures
 * structure in your app may be larger or smaller than the same struct as expected by MoltenVK.
 *
 * When calling this function, set the value of *pMetalFeaturesSize to sizeof(MVKPhysicalDeviceMetalFeatures),
 * to tell MoltenVK the limit of the size of your MVKPhysicalDeviceMetalFeatures structure. Upon return from
 * this function, the value of *pMetalFeaturesSize will hold the actual number of bytes copied into your
 * passed MVKPhysicalDeviceMetalFeatures structure, which will be the smaller of what your app thinks is the
 * size of MVKPhysicalDeviceMetalFeatures, and what MoltenVK thinks it is. This represents the safe access
 * area within the structure for both MoltenVK and your app.
 *
 * If the size that MoltenVK expects for MVKPhysicalDeviceMetalFeatures is different than the value passed in
 * *pMetalFeaturesSize, this function will return VK_INCOMPLETE, otherwise it will return VK_SUCCESS.
 *
 * Although it is not necessary, you can use this function to determine in advance the value that MoltenVK
 * expects the size of MVKPhysicalDeviceMetalFeatures to be by setting the value of pMetalFeatures to NULL.
 * In that case, this function will set *pMetalFeaturesSize to the size that MoltenVK expects
 * MVKPhysicalDeviceMetalFeatures to be.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
VKAPI_ATTR VkResult VKAPI_CALL vkGetPhysicalDeviceMetalFeaturesMVK(
	VkPhysicalDevice                            physicalDevice,
	MVKPhysicalDeviceMetalFeatures*             pMetalFeatures,
	size_t*                                     pMetalFeaturesSize);

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
 * thinks is the size of MVKPerformanceStatistics, and what MoltenVK thinks it is. This
 * represents the safe access area within the structure for both MoltenVK and your app.
 *
 * If the size that MoltenVK expects for MVKPerformanceStatistics is different than the value passed
 * in *pPerfSize, this function will return VK_INCOMPLETE, otherwise it will return VK_SUCCESS.
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


#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
