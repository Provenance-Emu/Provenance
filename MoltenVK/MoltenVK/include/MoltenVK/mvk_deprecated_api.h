/*
 * mvk_deprecated_api.h
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


#ifndef __mvk_deprecated_api_h_
#define __mvk_deprecated_api_h_ 1

#ifdef __cplusplus
extern "C" {
#endif	//  __cplusplus

#include <MoltenVK/mvk_private_api.h>
#include <IOSurface/IOSurfaceRef.h>


#define VK_MVK_MOLTENVK_SPEC_VERSION            37
#define VK_MVK_MOLTENVK_EXTENSION_NAME          "VK_MVK_moltenvk"

/**
 * This header contains obsolete and deprecated MoltenVK functions, that were originally
 * part of the obsolete and deprecated non-standard VK_MVK_moltenvk extension.
 * This header is provided for legacy compatibility only.
 *
 * NOTE: USE OF THE FUNCTIONS BELOW IS NOT RECOMMENDED. THE VK_MVK_moltenvk EXTENSION,
 * AND THE FUNCTIONS BELOW ARE NOT SUPPORTED BY THE VULKAN LOADER AND LAYERS.
 * THE VULKAN OBJECTS PASSED IN THESE FUNCTIONS MUST HAVE BEEN RETRIEVED DIRECTLY
 * FROM MOLTENVK, WITHOUT LINKING THROUGH THE VULKAN LOADER AND LAYERS.
 *
 * To interact with the Metal objects underlying Vulkan objects in MoltenVK,
 * use the standard Vulkan VK_EXT_metal_objects extension.
 * The VK_EXT_metal_objects extension is supported by the Vulkan Loader and Layers.
 */

#pragma mark -
#pragma mark VkPhysicalDevice Metal capabilities

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
 * Features provided by the current implementation of Metal on the current device. You can retrieve
 * a copy of this structure using the deprecated vkGetPhysicalDeviceMetalFeaturesMVK() function.
 *
 * This structure may be extended as new features are added to MoltenVK. If you are linking to
 * an implementation of MoltenVK that was compiled from a different MVK_PRIVATE_API_VERSION
 * than your app was, the size of this structure in your app may be larger or smaller than the
 * struct in MoltenVK. See the description of the vkGetPhysicalDeviceMetalFeaturesMVK() function
 * for information about how to handle this.
 *
 * TO SUPPORT DYNAMIC LINKING TO THIS STRUCTURE AS DESCRIBED ABOVE, THIS STRUCTURE SHOULD NOT BE CHANGED
 * EXCEPT TO ADD ADDITIONAL MEMBERS ON THE END. THE ORDER AND SIZE OF EXISTING MEMBERS SHOULD NOT BE CHANGED.
 */
typedef struct {
    uint32_t mslVersion;                        	/**< The version of the Metal Shading Language available on this device. The format of the integer is MMmmpp, with two decimal digts each for Major, minor, and patch version values (eg. MSL 3.2 would appear as 030200). */
	VkBool32 indirectDrawing;                   	/**< If true, draw calls support parameters held in a GPU buffer. */
	VkBool32 baseVertexInstanceDrawing;         	/**< If true, draw calls support specifiying the base vertex and instance. */
    uint32_t dynamicMTLBufferSize;              	/**< If greater than zero, dynamic MTLBuffers for setting vertex, fragment, and compute bytes are supported, and their content must be below this value. */
    VkBool32 shaderSpecialization;              	/**< If true, shader specialization (aka Metal function constants) is supported. Deprecated. Will always be true on all platforms. */
    VkBool32 ioSurfaces;                        	/**< If true, VkImages can be underlaid by IOSurfaces via the vkUseIOSurfaceMVK() function, to support inter-process image transfers. Deprecated. Will always be true on all platforms. */
    VkBool32 texelBuffers;                      	/**< If true, texel buffers are supported, allowing the contents of a buffer to be interpreted as an image via a VkBufferView. Deprecated. Will always be true on all platforms. */
	VkBool32 layeredRendering;                  	/**< If true, layered rendering to multiple cube or texture array layers is supported. */
	VkBool32 presentModeImmediate;              	/**< If true, immediate surface present mode (VK_PRESENT_MODE_IMMEDIATE_KHR), allowing a swapchain image to be presented immediately, without waiting for the vertical sync period of the display, is supported. */
	VkBool32 stencilViews;                      	/**< If true, stencil aspect views are supported through the MTLPixelFormatX24_Stencil8 and MTLPixelFormatX32_Stencil8 formats. Deprecated. Will always be true on all platforms. */
	VkBool32 multisampleArrayTextures;          	/**< If true, MTLTextureType2DMultisampleArray is supported. */
	VkBool32 samplerClampToBorder;              	/**< If true, the border color set when creating a sampler will be respected. */
	uint32_t maxTextureDimension; 	     	  		/**< The maximum size of each texture dimension (width or height). */
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
	VkBool32 events;								/**< If true, Metal synchronization events (MTLEvent) are supported. Deprecated. Will always be true on all platforms. */
	VkBool32 memoryBarriers;						/**< If true, full memory barriers within Metal render passes are supported. */
	VkBool32 multisampleLayeredRendering;       	/**< If true, layered rendering to multiple multi-sampled cube or texture array layers is supported. */
	VkBool32 stencilFeedback;						/**< If true, fragment shaders that write to [[stencil]] outputs are supported. */
	VkBool32 textureBuffers;						/**< If true, textures of type MTLTextureTypeBuffer are supported. Deprecated. Will always be true on all platforms. */
	VkBool32 postDepthCoverage;						/**< If true, coverage masks in fragment shaders post-depth-test are supported. */
	VkBool32 fences;								/**< If true, Metal synchronization fences (MTLFence) are supported. Deprecated. Will always be true on all platforms. */
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
	VkBool32 renderWithoutAttachments;          	/**< If true, we don't have to create a dummy attachment for a render pass if there isn't one. Deprecated. Will always be true on all platforms. */
	VkBool32 deferredStoreActions;					/**< If true, render pass store actions can be specified after the render encoder is created. Deprecated. Will always be true on all platforms. */
	VkBool32 sharedLinearTextures;					/**< If true, linear textures and texture buffers can be created from buffers in Shared storage. Deprecated. Will always be true on all platforms. */
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
    VkBool32 textureBarriers;                   	/**< If true, texture barriers are supported within Metal render passes. Deprecated. Will always be false on all platforms. */
    VkBool32 tileBasedDeferredRendering;        	/**< If true, this device uses tile-based deferred rendering. */
	VkBool32 argumentBuffers;						/**< If true, Metal argument buffers are supported on the platform. Deprecated. Will always be true on all platforms. */
	VkBool32 descriptorSetArgumentBuffers;			/**< If true, Metal argument buffers can be used for descriptor sets. */
	MVKFloatRounding clearColorFloatRounding;		/**< Identifies the type of rounding Metal uses for MTLClearColor float to integer conversions. */
	MVKCounterSamplingFlags counterSamplingPoints;	/**< Identifies the points where pipeline GPU counter sampling may occur. */
	VkBool32 programmableSamplePositions;			/**< If true, programmable MSAA sample positions are supported. */
	VkBool32 shaderBarycentricCoordinates;			/**< If true, fragment shader barycentric coordinates are supported. */
	MTLArgumentBuffersTier argumentBuffersTier;		/**< The argument buffer tier available on this device, as a Metal enumeration. */
	VkBool32 needsSampleDrefLodArrayWorkaround;		/**< If true, sampling from arrayed depth images with explicit LoD is broken and needs a workaround. */
	VkDeviceSize hostMemoryPageSize;				/**< The size of a page of host memory on this platform. */
	VkBool32 dynamicVertexStride;					/**< If true, VK_DYNAMIC_STATE_VERTEX_INPUT_BINDING_STRIDE is supported. */
	VkBool32 needsCubeGradWorkaround;				/**< If true, sampling from cube textures with explicit gradients is broken and needs a workaround. */
	VkBool32 nativeTextureAtomics;                  /**< If true, atomic operations on textures are supported natively. */
	VkBool32 needsArgumentBufferEncoders;			/**< If true, Metal argument buffer encoders are needed to populate argument buffer content. */
    VkBool32 residencySets;                         /**< If true, the device supports creating residency sets. */
    VkBool32 subgroupUniformControlFlow;            /**< If true, subgroup invocations will reconverge if they were uniform upon entry to a block and exit via the corresponding merge block. */
    VkBool32 maximalReconvergence;                  /**< If true, shader invocations that diverge will reconverge as soon as possible. */
    VkBool32 quadControlFlow;                       /**< If true, derivatives are calculated on a per-quad basis, and full quads are spawned for fragment shaders using helper invocations. */
    VkBool32 samplerMipLodBias;                     /**< If true, a mip lod bias can be set on a sampler. */
    VkSampleCountFlags supportedSamplePosCounts;    /**< A bitmask identifying the sample counts for which the device supports sample positions. */
    VkBool32 depthBoundsTest;                       /**< If true, depth bounds test is supported. */
	VkDeviceSize mtlConstantBufferAlignment;		/**< Minimum Metal constant buffer offset alignment (in bytes). */
} MVKPhysicalDeviceMetalFeatures;


#pragma mark -
#pragma mark Function types

typedef VkResult (VKAPI_PTR *PFN_vkSetMoltenVKConfigurationMVK)(VkInstance ignored, const MVKConfiguration* pConfiguration, size_t* pConfigurationSize);
typedef VkResult (VKAPI_PTR *PFN_vkGetPhysicalDeviceMetalFeaturesMVK)(VkPhysicalDevice physicalDevice, MVKPhysicalDeviceMetalFeatures* pMetalFeatures, size_t* pMetalFeaturesSize);
typedef void (VKAPI_PTR *PFN_vkGetVersionStringsMVK)(char* pMoltenVersionStringBuffer, uint32_t moltenVersionStringBufferLength, char* pVulkanVersionStringBuffer, uint32_t vulkanVersionStringBufferLength);
typedef void (VKAPI_PTR *PFN_vkSetWorkgroupSizeMVK)(VkShaderModule shaderModule, uint32_t x, uint32_t y, uint32_t z);
typedef VkResult (VKAPI_PTR *PFN_vkUseIOSurfaceMVK)(VkImage image, IOSurfaceRef ioSurface);
typedef void (VKAPI_PTR *PFN_vkGetIOSurfaceMVK)(VkImage image, IOSurfaceRef* pIOSurface);

#ifdef __OBJC__
typedef void (VKAPI_PTR *PFN_vkGetMTLDeviceMVK)(VkPhysicalDevice physicalDevice, id<MTLDevice>* pMTLDevice);
typedef VkResult (VKAPI_PTR *PFN_vkSetMTLTextureMVK)(VkImage image, id<MTLTexture> mtlTexture);
typedef void (VKAPI_PTR *PFN_vkGetMTLTextureMVK)(VkImage image, id<MTLTexture>* pMTLTexture);
typedef void (VKAPI_PTR *PFN_vkGetMTLBufferMVK)(VkBuffer buffer, id<MTLBuffer>* pMTLBuffer);
typedef void (VKAPI_PTR *PFN_vkGetMTLCommandQueueMVK)(VkQueue queue, id<MTLCommandQueue>* pMTLCommandQueue);
#endif // __OBJC__


#pragma mark -
#pragma mark Function prototypes

#ifndef VK_NO_PROTOTYPES

#define MVK_DEPRECATED   VKAPI_ATTR [[deprecated]]
#define MVK_DEPRECATED_USE_MTL_OBJS   VKAPI_ATTR [[deprecated("Use the VK_EXT_metal_objects extension instead.")]]


/**
 * DEPRECATED.
 * To set configuration values, use one of the following mechansims:
 *
 *   - The standard Vulkan VK_EXT_layer_settings extension (layer name "MoltenVK").
 *   - Application runtime environment variables.
 *   - Build settings at MoltenVK build time.
 */
VKAPI_ATTR [[deprecated("Use the VK_EXT_layer_settings extension, or environment variables, instead.")]]
VkResult VKAPI_CALL vkSetMoltenVKConfigurationMVK(
    VkInstance                                  instance,
    const MVKConfiguration*                     pConfiguration,
    size_t*                                     pConfigurationSize);

/**
 * DEPRECATED.
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
MVK_DEPRECATED
VKAPI_ATTR VkResult VKAPI_CALL vkGetPhysicalDeviceMetalFeaturesMVK(
	VkPhysicalDevice                            physicalDevice,
	MVKPhysicalDeviceMetalFeatures*             pMetalFeatures,
	size_t*                                     pMetalFeaturesSize);

/**
 * DEPRECATED.
 * Returns a human readable version of the MoltenVK and Vulkan versions.
 *
 * This function is provided as a convenience for reporting. Use the MVK_VERSION, 
 * VK_API_VERSION_1_0, and VK_HEADER_VERSION macros for programmatically accessing
 * the corresponding version numbers.
 */
MVK_DEPRECATED
void VKAPI_CALL vkGetVersionStringsMVK(
    char*                                       pMoltenVersionStringBuffer,
    uint32_t                                    moltenVersionStringBufferLength,
    char*                                       pVulkanVersionStringBuffer,
    uint32_t                                    vulkanVersionStringBufferLength);

/**
 * DEPRECATED.
 * Sets the number of threads in a workgroup for a compute kernel.
 *
 * This needs to be called if you are creating compute shader modules from MSL source code
 * or MSL compiled code. If you are using SPIR-V, workgroup size is determined automatically.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
MVK_DEPRECATED
void VKAPI_CALL vkSetWorkgroupSizeMVK(
    VkShaderModule                              shaderModule,
    uint32_t                                    x,
    uint32_t                                    y,
    uint32_t                                    z);

#ifdef __OBJC__

/**
 * DEPRECATED. Use the VK_EXT_metal_objects extension instead.
 * Returns, in the pMTLDevice pointer, the MTLDevice used by the VkPhysicalDevice.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
MVK_DEPRECATED_USE_MTL_OBJS
void VKAPI_CALL vkGetMTLDeviceMVK(
    VkPhysicalDevice                           physicalDevice,
    id<MTLDevice>*                             pMTLDevice);

/**
 * DEPRECATED. Use the VK_EXT_metal_objects extension instead.
 * Sets the VkImage to use the specified MTLTexture.
 *
 * Any differences in the properties of mtlTexture and this image will modify the
 * properties of this image.
 *
 * If a MTLTexture has already been created for this image, it will be destroyed.
 *
 * Returns VK_SUCCESS.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
MVK_DEPRECATED_USE_MTL_OBJS
VkResult VKAPI_CALL vkSetMTLTextureMVK(
    VkImage                                     image,
    id<MTLTexture>                              mtlTexture);

/**
 * DEPRECATED. Use the VK_EXT_metal_objects extension instead.
 * Returns, in the pMTLTexture pointer, the MTLTexture currently underlaying the VkImage.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
MVK_DEPRECATED_USE_MTL_OBJS
void VKAPI_CALL vkGetMTLTextureMVK(
    VkImage                                     image,
    id<MTLTexture>*                             pMTLTexture);

/**
 * DEPRECATED. Use the VK_EXT_metal_objects extension instead.
* Returns, in the pMTLBuffer pointer, the MTLBuffer currently underlaying the VkBuffer.
*
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
*/
MVK_DEPRECATED_USE_MTL_OBJS
void VKAPI_CALL vkGetMTLBufferMVK(
    VkBuffer                                    buffer,
    id<MTLBuffer>*                              pMTLBuffer);

/**
 * DEPRECATED. Use the VK_EXT_metal_objects extension instead.
* Returns, in the pMTLCommandQueue pointer, the MTLCommandQueue currently underlaying the VkQueue.
*
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
*/
MVK_DEPRECATED_USE_MTL_OBJS
void VKAPI_CALL vkGetMTLCommandQueueMVK(
    VkQueue                                     queue,
    id<MTLCommandQueue>*                        pMTLCommandQueue);

#endif // __OBJC__

/**
 * DEPRECATED. Use the VK_EXT_metal_objects extension instead.
 * Indicates that a VkImage should use an IOSurface to underlay the Metal texture.
 *
 * If ioSurface is not null, it will be used as the IOSurface, and any differences
 * in the properties of that IOSurface will modify the properties of this image.
 *
 * If ioSurface is null, this image will create and use an IOSurface
 * whose properties are compatible with the properties of this image.
 *
 * If a MTLTexture has already been created for this image, it will be destroyed.
 *
 * IOSurfaces are supported on the following platforms:
 *   -  macOS 10.11 and above
 *   -  iOS 11.0 and above
 *
 * To enable IOSurface support, ensure the Deployment Target build setting
 * (MACOSX_DEPLOYMENT_TARGET or IPHONEOS_DEPLOYMENT_TARGET) is set to at least
 * one of the values above when compiling MoltenVK, and any app that uses MoltenVK.
 *
 * Returns:
 *   - VK_SUCCESS.
 *   - VK_ERROR_FEATURE_NOT_PRESENT if IOSurfaces are not supported on the platform.
 *   - VK_ERROR_INITIALIZATION_FAILED if ioSurface is specified and is not compatible with this VkImage.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
MVK_DEPRECATED_USE_MTL_OBJS
VkResult VKAPI_CALL vkUseIOSurfaceMVK(
    VkImage                                     image,
    IOSurfaceRef                                ioSurface);

/**
 * DEPRECATED. Use the VK_EXT_metal_objects extension instead.
 * Returns, in the pIOSurface pointer, the IOSurface currently underlaying the VkImage,
 * as set by the useIOSurfaceMVK() function, or returns null if the VkImage is not using
 * an IOSurface, or if the platform does not support IOSurfaces.
 *
 * This function is not supported by the Vulkan SDK Loader and Layers framework
 * and is unavailable when using the Vulkan SDK Loader and Layers framework.
 */
MVK_DEPRECATED_USE_MTL_OBJS
void VKAPI_CALL vkGetIOSurfaceMVK(
    VkImage                                     image,
    IOSurfaceRef*                               pIOSurface);


#endif // VK_NO_PROTOTYPES


#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
