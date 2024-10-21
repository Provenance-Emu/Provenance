/*
 * mvk_deprecated_api.h
 *
 * Copyright (c) 2015-2024 The Brenwill Workshop Ltd. (http://www.brenwill.com)
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
#pragma mark Function types

typedef VkResult (VKAPI_PTR *PFN_vkSetMoltenVKConfigurationMVK)(VkInstance ignored, const MVKConfiguration* pConfiguration, size_t* pConfigurationSize);
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
