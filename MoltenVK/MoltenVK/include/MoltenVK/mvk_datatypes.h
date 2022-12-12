/*
 * mvk_datatypes.h
 *
 * Copyright (c) 2015-2022 The Brenwill Workshop Ltd. (http://www.brenwill.com)
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


/* 
 * This file contains functions for converting between Vulkan and Metal data types.
 *
 * The functions here are used internally by MoltenVK, and are exposed here 
 * as a convenience for use elsewhere within applications using MoltenVK.
 */

#ifndef __mvkDataTypes_h_
#define __mvkDataTypes_h_ 1

#ifdef __cplusplus
extern "C" {
#endif	//  __cplusplus
	
#include "mvk_vulkan.h"

#import <Metal/Metal.h>
#import <CoreGraphics/CoreGraphics.h>


#pragma mark -
#pragma mark Image properties

#pragma mark Texture formats

/** Enumerates the data type of a format. */
typedef enum {
    kMVKFormatNone,             /**< Format type is unknown. */
	kMVKFormatColorHalf,		/**< A 16-bit floating point color. */
    kMVKFormatColorFloat,		/**< A 32-bit floating point color. */
	kMVKFormatColorInt8,        /**< A signed 8-bit integer color. */
	kMVKFormatColorUInt8,		/**< An unsigned 8-bit integer color. */
	kMVKFormatColorInt16,       /**< A signed 16-bit integer color. */
	kMVKFormatColorUInt16,		/**< An unsigned 16-bit integer color. */
    kMVKFormatColorInt32,       /**< A signed 32-bit integer color. */
    kMVKFormatColorUInt32,		/**< An unsigned 32-bit integer color. */
    kMVKFormatDepthStencil,     /**< A depth and stencil value. */
    kMVKFormatCompressed,       /**< A block-compressed color. */
} MVKFormatType;

/** Returns whether the VkFormat is supported by this implementation. */
bool mvkVkFormatIsSupported(VkFormat vkFormat);

/** Returns whether the MTLPixelFormat is supported by this implementation. */
bool mvkMTLPixelFormatIsSupported(MTLPixelFormat mtlFormat);

/** Returns the format type corresponding to the specified Vulkan VkFormat, */
MVKFormatType mvkFormatTypeFromVkFormat(VkFormat vkFormat);

/** Returns the format type corresponding to the specified Metal MTLPixelFormat, */
MVKFormatType mvkFormatTypeFromMTLPixelFormat(MTLPixelFormat mtlFormat);

/**
 * Returns the Metal MTLPixelFormat corresponding to the specified Vulkan VkFormat,
 * or returns MTLPixelFormatInvalid if no corresponding MTLPixelFormat exists.
 *
 * Not all MTLPixelFormats returned by this function are supported by all GPU's, 
 * and, internally, MoltenVK may substitute and use a different MTLPixelFormat than
 * is returned by this function for a particular Vulkan VkFormat value.
 *
 * Not all macOS GPU's support the MTLPixelFormatDepth24Unorm_Stencil8 pixel format.
 * Even though this function will return that value when passed the corresponding 
 * VkFormat value, internally, MoltenVK will use the MTLPixelFormatDepth32Float_Stencil8
 * instead when a GPU does not support the MTLPixelFormatDepth24Unorm_Stencil8 pixel format.
 * On an macOS device that has more than one GPU, one of the GPU's may support the
 * MTLPixelFormatDepth24Unorm_Stencil8 pixel format while another may not.
 */
MTLPixelFormat mvkMTLPixelFormatFromVkFormat(VkFormat vkFormat);

/**
 * Returns the Vulkan VkFormat corresponding to the specified Metal MTLPixelFormat,
 * or returns VK_FORMAT_UNDEFINED if no corresponding VkFormat exists.
 */
VkFormat mvkVkFormatFromMTLPixelFormat(MTLPixelFormat mtlFormat);

/**
 * Returns the size, in bytes, of a texel block of the specified Vulkan format.
 * For uncompressed formats, the returned value corresponds to the size in bytes of a single texel.
 */
uint32_t mvkVkFormatBytesPerBlock(VkFormat vkFormat);

/** 
 * Returns the size, in bytes, of a texel block of the specified Metal format.
 * For uncompressed formats, the returned value corresponds to the size in bytes of a single texel.
 */
uint32_t mvkMTLPixelFormatBytesPerBlock(MTLPixelFormat mtlFormat);

/**
 * Returns the size of the compression block, measured in texels for a Vulkan format.
 * The returned value will be {1, 1} for non-compressed formats.
 */
VkExtent2D mvkVkFormatBlockTexelSize(VkFormat vkFormat);

/**
 * Returns the size of the compression block, measured in texels for a Metal format.
 * The returned value will be {1, 1} for non-compressed formats.
 */
VkExtent2D mvkMTLPixelFormatBlockTexelSize(MTLPixelFormat mtlFormat);

/**
 * Returns the size, in bytes, of a texel of the specified Vulkan format.
 * The returned value may be fractional for certain compressed formats.
 */
float mvkVkFormatBytesPerTexel(VkFormat vkFormat);

/**
 * Returns the size, in bytes, of a texel of the specified Metal format.
 * The returned value may be fractional for certain compressed formats.
 */
float mvkMTLPixelFormatBytesPerTexel(MTLPixelFormat mtlFormat);

/**
 * Returns the size, in bytes, of a row of texels of the specified Vulkan format.
 *
 * For compressed formats, this takes into consideration the compression block size,
 * and texelsPerRow should specify the width in texels, not blocks. The result is rounded
 * up if texelsPerRow is not an integer multiple of the compression block width.
 */
size_t mvkVkFormatBytesPerRow(VkFormat vkFormat, uint32_t texelsPerRow);

/**
 * Returns the size, in bytes, of a row of texels of the specified Metal format.
 *
 * For compressed formats, this takes into consideration the compression block size,
 * and texelsPerRow should specify the width in texels, not blocks. The result is rounded
 * up if texelsPerRow is not an integer multiple of the compression block width.
 */
size_t mvkMTLPixelFormatBytesPerRow(MTLPixelFormat mtlFormat, uint32_t texelsPerRow);

/**
 * Returns the size, in bytes, of a texture layer of the specified Vulkan format.
 *
 * For compressed formats, this takes into consideration the compression block size,
 * and texelRowsPerLayer should specify the height in texels, not blocks. The result is
 * rounded up if texelRowsPerLayer is not an integer multiple of the compression block height.
 */
size_t mvkVkFormatBytesPerLayer(VkFormat vkFormat, size_t bytesPerRow, uint32_t texelRowsPerLayer);

/**
 * Returns the size, in bytes, of a texture layer of the specified Metal format.
 * For compressed formats, this takes into consideration the compression block size,
 * and texelRowsPerLayer should specify the height in texels, not blocks. The result is
 * rounded up if texelRowsPerLayer is not an integer multiple of the compression block height.
 */
size_t mvkMTLPixelFormatBytesPerLayer(MTLPixelFormat mtlFormat, size_t bytesPerRow, uint32_t texelRowsPerLayer);

/** Returns the default properties for the specified Vulkan format. */
VkFormatProperties mvkVkFormatProperties(VkFormat vkFormat);

/** Returns the name of the specified Vulkan format. */
const char* mvkVkFormatName(VkFormat vkFormat);

/** Returns the name of the specified Metal pixel format. */
const char* mvkMTLPixelFormatName(MTLPixelFormat mtlFormat);

/**
 * Returns the MTLClearColor value corresponding to the color value in the VkClearValue,
 * extracting the color value that is VkFormat for the VkFormat.
 */
MTLClearColor mvkMTLClearColorFromVkClearValue(VkClearValue vkClearValue,
											   VkFormat vkFormat);

/** Returns the Metal depth value corresponding to the depth value in the specified VkClearValue. */
double mvkMTLClearDepthFromVkClearValue(VkClearValue vkClearValue);

/** Returns the Metal stencil value corresponding to the stencil value in the specified VkClearValue. */
uint32_t mvkMTLClearStencilFromVkClearValue(VkClearValue vkClearValue);

/** Returns whether the specified Metal MTLPixelFormat can be used as a depth format. */
bool mvkMTLPixelFormatIsDepthFormat(MTLPixelFormat mtlFormat);

/** Returns whether the specified Metal MTLPixelFormat can be used as a stencil format. */
bool mvkMTLPixelFormatIsStencilFormat(MTLPixelFormat mtlFormat);

/** Returns whether the specified Metal MTLPixelFormat is a PVRTC format. */
bool mvkMTLPixelFormatIsPVRTCFormat(MTLPixelFormat mtlFormat);

/** Returns the Metal texture type from the specified Vulkan image properties. */
MTLTextureType mvkMTLTextureTypeFromVkImageType(VkImageType vkImageType,
												uint32_t arraySize,
												bool isMultisample);

/** Returns the Vulkan image type from the Metal texture type. */
VkImageType mvkVkImageTypeFromMTLTextureType(MTLTextureType mtlTextureType);

/** Returns the Metal MTLTextureType corresponding to the Vulkan VkImageViewType. */
MTLTextureType mvkMTLTextureTypeFromVkImageViewType(VkImageViewType vkImageViewType, bool isMultisample);

/** Returns the Metal texture usage from the Vulkan image usage taking into considertion usage limits for the pixel format. */
MTLTextureUsage mvkMTLTextureUsageFromVkImageUsageFlags(VkImageUsageFlags vkImageUsageFlags, MTLPixelFormat mtlPixFmt);

/** Returns the Vulkan image usage from the Metal texture usage and format. */
VkImageUsageFlags mvkVkImageUsageFlagsFromMTLTextureUsage(MTLTextureUsage mtlUsage, MTLPixelFormat mtlFormat);

/**
 * Returns the numeric sample count corresponding to the specified Vulkan sample count flag.
 *
 * The specified flags value should have only one bit set, otherwise an invalid numeric value will be returned.
 */
uint32_t mvkSampleCountFromVkSampleCountFlagBits(VkSampleCountFlagBits vkSampleCountFlag);

/** Returns the Vulkan bit flags corresponding to the numeric sample count, which must be a PoT value. */
VkSampleCountFlagBits mvkVkSampleCountFlagBitsFromSampleCount(NSUInteger sampleCount);

/** Returns the Metal texture swizzle from the Vulkan component swizzle. */
MTLTextureSwizzle mvkMTLTextureSwizzleFromVkComponentSwizzle(VkComponentSwizzle vkSwizzle);

/** Returns all four Metal texture swizzles from the Vulkan component mapping. */
MTLTextureSwizzleChannels mvkMTLTextureSwizzleChannelsFromVkComponentMapping(VkComponentMapping vkMapping);


#pragma mark Mipmaps

/**
 * Returns the number of mipmap levels available to an image with the specified side dimension.
 * 
 * If the specified dimension is a power-of-two, the value returned is (log2(dim) + 1).
 * If the specified dimension is NOT a power-of-two, the value returned is 0, indicating
 * that the image cannot support mipmaps.
 */
uint32_t mvkMipmapLevels(uint32_t dim);

/**
 * Returns the number of mipmap levels available to an image with the specified extent.
 *
 * If each dimension in the specified extent is a power-of-two, the value returned
 * is MAX(log2(dim) + 1) across both dimensions. If either dimension in the specified 
 * extent is NOT a power-of-two, the value returned is 1, indicating that the image 
 * cannot support mipmaps, and that only the base mip level can be used.
 */
uint32_t mvkMipmapLevels2D(VkExtent2D extent);

/**
 * Returns the number of mipmap levels available to an image with the specified extent.
 *
 * If each dimension in the specified extent is a power-of-two, the value returned
 * is MAX(log2(dim) + 1) across all dimensions. If either dimension in the specified
 * extent is NOT a power-of-two, the value returned is 1, indicating that the image
 * cannot support mipmaps, and that only the base mip level can be used.
 */
uint32_t mvkMipmapLevels3D(VkExtent3D extent);

/** 
 * Returns the size of the specified zero-based mipmap level, 
 * when the size of the base level is the specified size. 
 */
VkExtent2D mvkMipmapLevelSizeFromBaseSize2D(VkExtent2D baseSize, uint32_t level);

/**
 * Returns the size of the specified zero-based mipmap level,
 * when the size of the base level is the specified size.
 */
VkExtent3D mvkMipmapLevelSizeFromBaseSize3D(VkExtent3D baseSize, uint32_t level);

/** 
 * Returns the size of the mipmap base level, when the size of 
 * the specified zero-based mipmap level is the specified size.
 */
VkExtent2D mvkMipmapBaseSizeFromLevelSize2D(VkExtent2D levelSize, uint32_t level);

/**
 * Returns the size of the mipmap base level, when the size of
 * the specified zero-based mipmap level is the specified size.
 */
VkExtent3D mvkMipmapBaseSizeFromLevelSize3D(VkExtent3D levelSize, uint32_t level);


#pragma mark Samplers

/** Returns the Metal MTLSamplerAddressMode corresponding to the specified Vulkan VkSamplerAddressMode. */
MTLSamplerAddressMode mvkMTLSamplerAddressModeFromVkSamplerAddressMode(VkSamplerAddressMode vkMode);

#if MVK_MACOS_OR_IOS
/**
 * Returns the Metal MTLSamplerBorderColor corresponding to the specified Vulkan VkBorderColor,
 * or returns MTLSamplerBorderColorTransparentBlack if no corresponding MTLSamplerBorderColor exists.
 */
MTLSamplerBorderColor mvkMTLSamplerBorderColorFromVkBorderColor(VkBorderColor vkColor);
#endif

/**
 * Returns the Metal MTLSamplerMinMagFilter corresponding to the specified Vulkan VkFilter,
 * or returns MTLSamplerMinMagFilterNearest if no corresponding MTLSamplerMinMagFilter exists.
 */
MTLSamplerMinMagFilter mvkMTLSamplerMinMagFilterFromVkFilter(VkFilter vkFilter);

/**
 * Returns the Metal MTLSamplerMipFilter corresponding to the specified Vulkan VkSamplerMipmapMode,
 * or returns MTLSamplerMipFilterNotMipmapped if no corresponding MTLSamplerMipFilter exists.
 */
MTLSamplerMipFilter mvkMTLSamplerMipFilterFromVkSamplerMipmapMode(VkSamplerMipmapMode vkMode);


#pragma mark -
#pragma mark Render pipeline

/** Identifies a particular shading stage in a pipeline. */
typedef enum {
	kMVKShaderStageVertex = 0,
	kMVKShaderStageTessCtl,
	kMVKShaderStageTessEval,
	kMVKShaderStageFragment,
	kMVKShaderStageCompute,
	kMVKShaderStageCount,
	kMVKShaderStageMax = kMVKShaderStageCount	// Public API legacy value
} MVKShaderStage;

/** Returns the Metal MTLColorWriteMask corresponding to the specified Vulkan VkColorComponentFlags. */
MTLColorWriteMask mvkMTLColorWriteMaskFromVkChannelFlags(VkColorComponentFlags vkWriteFlags);

/** Returns the Metal MTLBlendOperation corresponding to the specified Vulkan VkBlendOp. */
MTLBlendOperation mvkMTLBlendOperationFromVkBlendOp(VkBlendOp vkBlendOp);

/** Returns the Metal MTLBlendFactor corresponding to the specified Vulkan VkBlendFactor. */
MTLBlendFactor mvkMTLBlendFactorFromVkBlendFactor(VkBlendFactor vkBlendFactor);

/**
 * Returns the Metal MTLVertexFormat corresponding to the specified
 * Vulkan VkFormat as used as a vertex attribute format.
 */
MTLVertexFormat mvkMTLVertexFormatFromVkFormat(VkFormat vkFormat);

/** Returns the Metal MTLVertexStepFunction corresponding to the specified Vulkan VkVertexInputRate. */
MTLVertexStepFunction mvkMTLVertexStepFunctionFromVkVertexInputRate(VkVertexInputRate vkVtxStep);

/** Returns the Metal MTLStepFunction corresponding to the specified Vulkan VkVertexInputRate. */
MTLStepFunction mvkMTLStepFunctionFromVkVertexInputRate(VkVertexInputRate vkVtxStep, bool forTess = false);

/** Returns the Metal MTLPrimitiveType corresponding to the specified Vulkan VkPrimitiveTopology. */
MTLPrimitiveType mvkMTLPrimitiveTypeFromVkPrimitiveTopology(VkPrimitiveTopology vkTopology);

/** Returns the Metal MTLPrimitiveTopologyClass corresponding to the specified Vulkan VkPrimitiveTopology. */
MTLPrimitiveTopologyClass mvkMTLPrimitiveTopologyClassFromVkPrimitiveTopology(VkPrimitiveTopology vkTopology);

/** Returns the Metal MTLTriangleFillMode corresponding to the specified Vulkan VkPolygonMode, */
MTLTriangleFillMode mvkMTLTriangleFillModeFromVkPolygonMode(VkPolygonMode vkFillMode);

/** Returns the Metal MTLLoadAction corresponding to the specified Vulkan VkAttachmentLoadOp. */
MTLLoadAction mvkMTLLoadActionFromVkAttachmentLoadOp(VkAttachmentLoadOp vkLoadOp);

/** Returns the Metal MTLStoreAction corresponding to the specified Vulkan VkAttachmentStoreOp. */
MTLStoreAction mvkMTLStoreActionFromVkAttachmentStoreOp(VkAttachmentStoreOp vkStoreOp, bool hasResolveAttachment, bool canResolveFormat = true);

/** Returns the Metal MTLMultisampleDepthResolveFilter corresponding to the specified Vulkan VkResolveModeFlagBits. */
MTLMultisampleDepthResolveFilter mvkMTLMultisampleDepthResolveFilterFromVkResolveModeFlagBits(VkResolveModeFlagBits vkResolveMode);

#if MVK_MACOS_OR_IOS
/** Returns the Metal MTLMultisampleStencilResolveFilter corresponding to the specified Vulkan VkResolveModeFlagBits. */
MTLMultisampleStencilResolveFilter mvkMTLMultisampleStencilResolveFilterFromVkResolveModeFlagBits(VkResolveModeFlagBits vkResolveMode);
#endif

/** Returns the Metal MTLViewport corresponding to the specified Vulkan VkViewport. */
MTLViewport mvkMTLViewportFromVkViewport(VkViewport vkViewport);

/** Returns the Metal MTLScissorRect corresponding to the specified Vulkan VkRect2D. */
MTLScissorRect mvkMTLScissorRectFromVkRect2D(VkRect2D vkRect);

/** Returns the Metal MTLCompareFunction corresponding to the specified Vulkan VkCompareOp, */
MTLCompareFunction mvkMTLCompareFunctionFromVkCompareOp(VkCompareOp vkOp);

/** Returns the Metal MTLStencilOperation corresponding to the specified Vulkan VkStencilOp, */
MTLStencilOperation mvkMTLStencilOperationFromVkStencilOp(VkStencilOp vkOp);

/** Returns the Metal MTLCullMode corresponding to the specified Vulkan VkCullModeFlags, */
MTLCullMode mvkMTLCullModeFromVkCullModeFlags(VkCullModeFlags vkCull);

/** Returns the Metal MTLWinding corresponding to the specified Vulkan VkFrontFace, */
MTLWinding mvkMTLWindingFromVkFrontFace(VkFrontFace vkWinding);

/** Returns the Metal MTLIndexType corresponding to the specified Vulkan VkIndexType, */
MTLIndexType mvkMTLIndexTypeFromVkIndexType(VkIndexType vkIdxType);

/** Returns the size, in bytes, of a vertex index of the specified type. */
size_t mvkMTLIndexTypeSizeInBytes(MTLIndexType mtlIdxType);

/** Returns the MoltenVK MVKShaderStage corresponding to the specified Vulkan VkShaderStageFlagBits. */
MVKShaderStage mvkShaderStageFromVkShaderStageFlagBits(VkShaderStageFlagBits vkStage);

/** Returns the Vulkan VkShaderStageFlagBits corresponding to the specified MoltenVK MVKShaderStage. */
VkShaderStageFlagBits mvkVkShaderStageFlagBitsFromMVKShaderStage(MVKShaderStage mvkStage);

/** Returns the Metal MTLWinding corresponding to the specified SPIR-V spv::ExecutionMode. */
MTLWinding mvkMTLWindingFromSpvExecutionMode(uint32_t spvMode);

/** Returns the Metal MTLTessellationPartitionMode corresponding to the specified SPIR-V spv::ExecutionMode. */
MTLTessellationPartitionMode mvkMTLTessellationPartitionModeFromSpvExecutionMode(uint32_t spvMode);

/**
 * Returns the combination of Metal MTLRenderStage bits corresponding to the specified Vulkan VkPiplineStageFlags,
 * taking into consideration whether the barrier is to be placed before or after the specified pipeline stages.
 */
MTLRenderStages mvkMTLRenderStagesFromVkPipelineStageFlags(VkPipelineStageFlags vkStages, bool placeBarrierBefore);

/** Returns the combination of Metal MTLBarrierScope bits corresponding to the specified Vulkan VkAccessFlags. */
MTLBarrierScope mvkMTLBarrierScopeFromVkAccessFlags(VkAccessFlags vkAccess);

#pragma mark -
#pragma mark Geometry conversions

/** Returns a VkExtent2D that corresponds to the specified CGSize. */
static inline VkExtent2D mvkVkExtent2DFromCGSize(CGSize cgSize) {
	VkExtent2D vkExt;
	vkExt.width = cgSize.width;
	vkExt.height = cgSize.height;
	return vkExt;
}

/** Returns a CGSize that corresponds to the specified VkExtent2D. */
static inline CGSize mvkCGSizeFromVkExtent2D(VkExtent2D vkExtent) {
	CGSize cgSize;
	cgSize.width = vkExtent.width;
	cgSize.height = vkExtent.height;
	return cgSize;
}

/** Returns a Metal MTLOrigin constructed from a VkOffset3D. */
static inline MTLOrigin mvkMTLOriginFromVkOffset3D(VkOffset3D vkOffset) {
	return MTLOriginMake(vkOffset.x, vkOffset.y, vkOffset.z);
}

/** Returns a Vulkan VkOffset3D constructed from a Metal MTLOrigin. */
static inline VkOffset3D mvkVkOffset3DFromMTLSize(MTLOrigin mtlOrigin) {
	return { (int32_t)mtlOrigin.x, (int32_t)mtlOrigin.y, (int32_t)mtlOrigin.z };
}

/** Returns a Metal MTLSize constructed from a VkExtent3D. */
static inline MTLSize mvkMTLSizeFromVkExtent3D(VkExtent3D vkExtent) {
	return MTLSizeMake(vkExtent.width, vkExtent.height, vkExtent.depth);
}

/** Returns a Vulkan VkExtent3D  constructed from a Metal MTLSize. */
static inline VkExtent3D mvkVkExtent3DFromMTLSize(MTLSize mtlSize) {
	return { (uint32_t)mtlSize.width, (uint32_t)mtlSize.height, (uint32_t)mtlSize.depth };
}


#pragma mark -
#pragma mark Memory options

/** Macro indicating the Vulkan memory type bits corresponding to Metal private memory (not host visible). */
#define MVK_VK_MEMORY_TYPE_METAL_PRIVATE	(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)

/** Macro indicating the Vulkan memory type bits corresponding to Metal shared memory (host visible and coherent). */
#define MVK_VK_MEMORY_TYPE_METAL_SHARED		(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT | VK_MEMORY_PROPERTY_HOST_CACHED_BIT)

/** Macro indicating the Vulkan memory type bits corresponding to Metal managed memory (host visible and non-coherent). */
#define MVK_VK_MEMORY_TYPE_METAL_MANAGED	(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_CACHED_BIT)

/** Macro indicating the Vulkan memory type bits corresponding to Metal memoryless memory (not host visible and lazily allocated). */
#define MVK_VK_MEMORY_TYPE_METAL_MEMORYLESS	(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | VK_MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT)

/** Returns the Metal storage mode corresponding to the specified Vulkan memory flags. */
MTLStorageMode mvkMTLStorageModeFromVkMemoryPropertyFlags(VkMemoryPropertyFlags vkFlags);

/** Returns the Metal CPU cache mode corresponding to the specified Vulkan memory flags. */
MTLCPUCacheMode mvkMTLCPUCacheModeFromVkMemoryPropertyFlags(VkMemoryPropertyFlags vkFlags);

/** Returns the Metal resource option flags corresponding to the Metal storage mode and cache mode. */
MTLResourceOptions mvkMTLResourceOptions(MTLStorageMode mtlStorageMode, MTLCPUCacheMode mtlCPUCacheMode);


#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
