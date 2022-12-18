/*
 * mvk_vulkan.h
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


/** 
 * This is a convenience header file that loads vulkan.h with the appropriate Vulkan platform extensions.
 *
 * This header automatically enables the VK_EXT_metal_surface Vulkan extension.
 *
 * When building for iOS, this header also automatically enables the obsolete VK_MVK_ios_surface Vulkan extension.
 * When building for macOS, this header also automatically enables the obsolete VK_MVK_macos_surface Vulkan extension.
 * Both of these extensions are obsolete. Consider using the portable VK_EXT_metal_surface extension instead.
 */

#ifndef __mvk_vulkan_h_
#define __mvk_vulkan_h_ 1


#include <Availability.h>

#define VK_USE_PLATFORM_METAL_EXT				1

#define VK_ENABLE_BETA_EXTENSIONS				1		// VK_KHR_portability_subset

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
#	define VK_USE_PLATFORM_IOS_MVK				1
#endif

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
#	define VK_USE_PLATFORM_MACOS_MVK			1
#endif

#include <vulkan/vulkan.h>

#endif
