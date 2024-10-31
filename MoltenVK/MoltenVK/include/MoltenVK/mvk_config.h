/*
 * mvk_config.h
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



#ifndef __mvk_config_h_
#define __mvk_config_h_ 1

#ifdef __cplusplus
extern "C" {
#endif	//  __cplusplus


#include <MoltenVK/mvk_private_api.h>


/**
 * This header is obsolete and deprecated, and is provided for legacy compatibility only.
 *
 * To configure MoltenVK, use one of the following mechanisms,
 * as documented in MoltenVK_Configuration_Parameters.md:
 *
 *   - The standard Vulkan VK_EXT_layer_settings extension (layer name "MoltenVK").
 *   - Application runtime environment variables.
 *   - Build settings at MoltenVK build time.
 *
 * For the private MoltenVK functions, include the mvk_private_api.h header.
 */

#define MVK_CONFIGURATION_API_VERSION   39

#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
