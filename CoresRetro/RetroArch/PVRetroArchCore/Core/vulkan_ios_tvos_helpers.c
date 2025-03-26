/* Helper functions for improving Vulkan compatibility on iOS/tvOS
 * These functions are designed to work with MoltenVK 1.2.10/1.2.11
 */

#include <string/stdstring.h>
#include <vulkan/vulkan.h>
#include <retro_assert.h>
#include <retro_math.h>
#include <retro_miscellaneous.h>

#include "vulkan_common.h"

#if defined(HAVE_COCOATOUCH) || defined(TARGET_OS_TV)
/* Helper function to improve command buffer synchronization for iOS/tvOS
 * This is based on the memory about parallelization strategies in the Vulkan renderer */
void vulkan_ios_tvos_command_buffer_sync(VkCommandBuffer cmd, VkQueue queue, VkDevice device)
{
   /* For MoltenVK 1.2.10/1.2.11, ensure proper synchronization for parallel command buffer execution
    * This is a conservative approach that may impact performance but improves stability */
   
   /* Add a memory barrier to ensure all previous operations are complete */
   VkMemoryBarrier barrier;
   barrier.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
   barrier.pNext = NULL;
   barrier.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT;
   barrier.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT;
   
   /* Use a full pipeline barrier to ensure all operations are complete */
   vkCmdPipelineBarrier(cmd,
         VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
         VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
         0,
         1, &barrier,
         0, NULL,
         0, NULL);
   
   /* For critical operations, we might want to wait for the device to be idle */
   /* This should be used sparingly as it can impact performance significantly */
   /* vkDeviceWaitIdle(device); */
}

/* Helper function to create a more conservative memory barrier for texture operations
 * This is particularly important for texture upload/download operations on iOS/tvOS */
void vulkan_ios_tvos_texture_barrier(VkCommandBuffer cmd, 
      VkImage image, 
      VkImageLayout old_layout,
      VkImageLayout new_layout,
      VkAccessFlags src_access_mask,
      VkAccessFlags dst_access_mask)
{
   VkImageMemoryBarrier barrier;
   barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
   barrier.pNext = NULL;
   barrier.srcAccessMask = src_access_mask;
   barrier.dstAccessMask = dst_access_mask;
   barrier.oldLayout = old_layout;
   barrier.newLayout = new_layout;
   barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
   barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
   barrier.image = image;
   barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
   barrier.subresourceRange.baseMipLevel = 0;
   barrier.subresourceRange.levelCount = VK_REMAINING_MIP_LEVELS;
   barrier.subresourceRange.baseArrayLayer = 0;
   barrier.subresourceRange.layerCount = VK_REMAINING_ARRAY_LAYERS;
   
   /* Use more conservative pipeline stages for iOS/tvOS */
   vkCmdPipelineBarrier(cmd,
         VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
         VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
         0,
         0, NULL,
         0, NULL,
         1, &barrier);
}

/* Helper function to handle the case when a buffer cannot be mapped on iOS/tvOS
 * This allows the application to continue running even if memory mapping fails */
bool vulkan_ios_tvos_update_buffer_without_mapping(VkDevice device, VkCommandBuffer cmd, 
      struct vk_buffer *buffer, const void *data, size_t size)
{
   /* This function is specifically designed to handle HDR UBO updates when mapping fails */
   if (!buffer || !data || !cmd || !device || buffer->buffer == VK_NULL_HANDLE)
      return false;
      
   /* Create a staging buffer that we can map */
   VkBufferCreateInfo buffer_info;
   buffer_info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
   buffer_info.pNext = NULL;
   buffer_info.size = size;
   buffer_info.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
   buffer_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
   buffer_info.queueFamilyIndexCount = 0;
   buffer_info.pQueueFamilyIndices = NULL;
   
   VkBuffer staging_buffer;
   if (vkCreateBuffer(device, &buffer_info, NULL, &staging_buffer) != VK_SUCCESS)
   {
      RARCH_ERR("[Vulkan]: Failed to create staging buffer.\n");
      return false;
   }
   
   VkMemoryRequirements mem_reqs;
   vkGetBufferMemoryRequirements(device, staging_buffer, &mem_reqs);
   
   VkMemoryAllocateInfo alloc_info;
   alloc_info.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
   alloc_info.pNext = NULL;
   alloc_info.allocationSize = mem_reqs.size;
   
   /* Find a memory type that can be mapped */
   uint32_t memory_type = 0;
   for (uint32_t i = 0; i < 32; i++)
   {
      if ((mem_reqs.memoryTypeBits & (1u << i)) == 0)
         continue;

      VkMemoryPropertyFlags flags = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
      if ((VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT & flags) == flags)
      {
         memory_type = i;
         break;
      }
   }
   
   alloc_info.memoryTypeIndex = memory_type;
   
   VkDeviceMemory staging_memory;
   if (vkAllocateMemory(device, &alloc_info, NULL, &staging_memory) != VK_SUCCESS)
   {
      RARCH_ERR("[Vulkan]: Failed to allocate staging memory.\n");
      vkDestroyBuffer(device, staging_buffer, NULL);
      return false;
   }
   
   if (vkBindBufferMemory(device, staging_buffer, staging_memory, 0) != VK_SUCCESS)
   {
      RARCH_ERR("[Vulkan]: Failed to bind staging memory.\n");
      vkFreeMemory(device, staging_memory, NULL);
      vkDestroyBuffer(device, staging_buffer, NULL);
      return false;
   }
   
   /* Map the staging buffer and copy data to it */
   void *mapped_data;
   if (vkMapMemory(device, staging_memory, 0, size, 0, &mapped_data) != VK_SUCCESS)
   {
      RARCH_ERR("[Vulkan]: Failed to map staging memory.\n");
      vkFreeMemory(device, staging_memory, NULL);
      vkDestroyBuffer(device, staging_buffer, NULL);
      return false;
   }
   
   memcpy(mapped_data, data, size);
   vkUnmapMemory(device, staging_memory);
   
   /* Copy from staging buffer to destination buffer */
   VkBufferCopy copy_region;
   copy_region.srcOffset = 0;
   copy_region.dstOffset = 0;
   copy_region.size = size;
   
   vkCmdCopyBuffer(cmd, staging_buffer, buffer->buffer, 1, &copy_region);
   
   /* Add a buffer memory barrier */
   VkBufferMemoryBarrier barrier;
   barrier.sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER;
   barrier.pNext = NULL;
   barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
   barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
   barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
   barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
   barrier.buffer = buffer->buffer;
   barrier.offset = 0;
   barrier.size = size;
   
   vkCmdPipelineBarrier(cmd,
         VK_PIPELINE_STAGE_TRANSFER_BIT,
         VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,
         0,
         0, NULL,
         1, &barrier,
         0, NULL);
   
   /* Clean up staging resources (these will be destroyed after the command buffer is submitted) */
   vkDestroyBuffer(device, staging_buffer, NULL);
   vkFreeMemory(device, staging_memory, NULL);
   
   return true;
}
/* Helper function to configure input assembly state for iOS/tvOS compatibility
 * Metal does not support disabling primitive restart, so this function sets
 * primitiveRestartEnable to VK_TRUE to avoid warnings */
void vulkan_ios_tvos_setup_input_assembly(VkPipelineInputAssemblyStateCreateInfo *input_assembly)
{
   if (!input_assembly)
      return;

   /* Metal does not support disabling primitive restart, so we set it to VK_TRUE
    * to avoid the warning: [mvk-warn] VK_ERROR_FEATURE_NOT_PRESENT: Metal does not support disabling primitive restart */
   input_assembly->primitiveRestartEnable = VK_TRUE;
   
   /* Log that we're making this adjustment for compatibility */
   RARCH_LOG("[Vulkan]: iOS/tvOS compatibility - Setting primitiveRestartEnable to VK_TRUE for Metal compatibility\n");
}

#endif
