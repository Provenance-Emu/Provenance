/*
 * vk_mvk_moltenvk.h
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

/**
 * This header is provided for legacy compatibility only. This header contains obsolete and
 * deprecated MoltenVK functions, that were originally part of the obsolete and deprecated
 * non-standard VK_MVK_moltenvk extension, and use of this header is not recommended.
 *
 * Instead, in your application, use the following header file:
 *
 *     #include <MoltenVK/mvk_vulkan.h>
 *
 * And if you require the MoltenVK Configuration API, also include the following header file:
 *
 *     #include <MoltenVK/mvk_config.h>
 *
 * If you require access to Metal objects underlying equivalent Vulkan objects,
 * use the standard Vulkan VK_EXT_metal_objects extension.
 */

#include "mvk_vulkan.h"
#include "mvk_config.h"

#include "mvk_private_api.h"
#include "mvk_deprecated_api.h"
