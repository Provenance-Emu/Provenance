/* Helper functions for improving Vulkan compatibility on iOS/tvOS
 * These functions are designed to work with MoltenVK 1.2.10/1.2.11
 */

#ifndef __VULKAN_IOS_TVOS_HELPERS_H
#define __VULKAN_IOS_TVOS_HELPERS_H

#include <vulkan/vulkan.h>

#if defined(HAVE_COCOATOUCH) || defined(TARGET_OS_TV)
/* Helper function to improve command buffer synchronization for iOS/tvOS */
void vulkan_ios_tvos_command_buffer_sync(VkCommandBuffer cmd, VkQueue queue, VkDevice device);

/* Helper function to create a more conservative memory barrier for texture operations */
void vulkan_ios_tvos_texture_barrier(VkCommandBuffer cmd, 
      VkImage image, 
      VkImageLayout old_layout,
      VkImageLayout new_layout,
      VkAccessFlags src_access_mask,
      VkAccessFlags dst_access_mask);

/* Helper function to configure input assembly state for iOS/tvOS compatibility
 * Metal does not support disabling primitive restart, so this function sets
 * primitiveRestartEnable to VK_TRUE to avoid warnings */
void vulkan_ios_tvos_setup_input_assembly(VkPipelineInputAssemblyStateCreateInfo *input_assembly);
#endif

#endif /* __VULKAN_IOS_TVOS_HELPERS_H */
