/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2016 - Hans-Kristian Arntzen
 * 
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <string.h>

#include <compat/strl.h>
#include <gfx/scaler/scaler.h>
#include <formats/image.h>
#include <retro_inline.h>
#include <retro_miscellaneous.h>
#include <retro_assert.h>
#include <libretro.h>

#include "../common/vulkan_common.h"

#include "../../driver.h"
#include "../../record/record_driver.h"
#include "../../performance_counters.h"

#include "../../general.h"
#include "../../retroarch.h"

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef HAVE_MENU
#include "../../menu/menu_driver.h"
#endif

#include "../font_driver.h"
#include "../video_context_driver.h"
#include "../video_coord_array.h"

static void vulkan_set_viewport(void *data, unsigned viewport_width,
      unsigned viewport_height, bool force_full, bool allow_rotate);

#ifdef HAVE_OVERLAY
static void vulkan_overlay_free(vk_t *vk);
static void vulkan_render_overlay(vk_t *vk);
#endif
static void vulkan_viewport_info(void *data, struct video_viewport *vp);

static const gfx_ctx_driver_t *vulkan_get_context(vk_t *vk)
{
   unsigned major       = 1;
   unsigned minor       = 0;
   settings_t *settings = config_get_ptr();
   enum gfx_ctx_api api = GFX_CTX_VULKAN_API;

   return video_context_driver_init_first(
         vk, settings->video.context_driver,
         api, major, minor, false);
}

static void vulkan_init_render_pass(
      vk_t *vk)
{
   VkRenderPassCreateInfo rp_info = {
      VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO };
   VkAttachmentDescription attachment = {0};
   VkSubpassDescription subpass       = {0};
   VkAttachmentReference color_ref    = { 0, 
      VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL };

   /* Backbuffer format. */
   attachment.format            = vk->context->swapchain_format;
   /* Not multisampled. */
   attachment.samples           = VK_SAMPLE_COUNT_1_BIT;
   /* When starting the frame, we want tiles to be cleared. */
   attachment.loadOp            = VK_ATTACHMENT_LOAD_OP_CLEAR;
   /* When end the frame, we want tiles to be written out. */
   attachment.storeOp           = VK_ATTACHMENT_STORE_OP_STORE;
   /* Don't care about stencil since we're not using it. */
   attachment.stencilLoadOp     = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
   attachment.stencilStoreOp    = VK_ATTACHMENT_STORE_OP_DONT_CARE;

   /* The image layout will be attachment_optimal 
    * when we're executing the renderpass. */
   attachment.initialLayout     = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
   attachment.finalLayout       = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

   /* We have one subpass.
    * This subpass has 1 color attachment. */
   subpass.pipelineBindPoint    = VK_PIPELINE_BIND_POINT_GRAPHICS;
   subpass.colorAttachmentCount = 1;
   subpass.pColorAttachments    = &color_ref;

   /* Finally, create the renderpass. */
   rp_info.attachmentCount      = 1;
   rp_info.pAttachments         = &attachment;
   rp_info.subpassCount         = 1;
   rp_info.pSubpasses           = &subpass;

   vkCreateRenderPass(vk->context->device,
         &rp_info, NULL, &vk->render_pass);
}

static void vulkan_init_framebuffers(
      vk_t *vk)
{
   unsigned i;

   vulkan_init_render_pass(vk);

   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      VkImageViewCreateInfo view =
      { VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO };
      VkFramebufferCreateInfo info =
      { VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO };

      vk->swapchain[i].backbuffer.image    = vk->context->swapchain_images[i];

      /* Create an image view which we can render into. */
      view.viewType                        = VK_IMAGE_VIEW_TYPE_2D;
      view.format                          = vk->context->swapchain_format;
      view.image                           = vk->swapchain[i].backbuffer.image;
      view.subresourceRange.baseMipLevel   = 0;
      view.subresourceRange.baseArrayLayer = 0;
      view.subresourceRange.levelCount     = 1;
      view.subresourceRange.layerCount     = 1;
      view.subresourceRange.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
      view.components.r                    = VK_COMPONENT_SWIZZLE_R;
      view.components.g                    = VK_COMPONENT_SWIZZLE_G;
      view.components.b                    = VK_COMPONENT_SWIZZLE_B;
      view.components.a                    = VK_COMPONENT_SWIZZLE_A;

      vkCreateImageView(vk->context->device,
            &view, NULL, &vk->swapchain[i].backbuffer.view);

      /* Create the framebuffer */
      info.renderPass      = vk->render_pass;
      info.attachmentCount = 1;
      info.pAttachments    = &vk->swapchain[i].backbuffer.view;
      info.width           = vk->context->swapchain_width;
      info.height          = vk->context->swapchain_height;
      info.layers          = 1;

      vkCreateFramebuffer(vk->context->device,
            &info, NULL, &vk->swapchain[i].backbuffer.framebuffer);
   }
}

static void vulkan_init_pipeline_layout(
      vk_t *vk)
{
   VkDescriptorSetLayoutCreateInfo set_layout_info = { 
      VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO };
   VkPipelineLayoutCreateInfo layout_info          = { 
      VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO };
   VkDescriptorSetLayoutBinding bindings[2]        = {{0}};

   bindings[0].binding            = 0;
   bindings[0].descriptorType     = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
   bindings[0].descriptorCount    = 1;
   bindings[0].stageFlags         = VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT;
   bindings[0].pImmutableSamplers = NULL;

   bindings[1].binding            = 1;
   bindings[1].descriptorType     = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
   bindings[1].descriptorCount    = 1;
   bindings[1].stageFlags         = VK_SHADER_STAGE_FRAGMENT_BIT;
   bindings[1].pImmutableSamplers = NULL;

   set_layout_info.bindingCount   = 2;
   set_layout_info.pBindings      = bindings;

   vkCreateDescriptorSetLayout(vk->context->device,
         &set_layout_info, NULL, &vk->pipelines.set_layout);

   layout_info.setLayoutCount     = 1;
   layout_info.pSetLayouts        = &vk->pipelines.set_layout;

   vkCreatePipelineLayout(vk->context->device,
         &layout_info, NULL, &vk->pipelines.layout);
}

static void vulkan_init_pipelines(
      vk_t *vk)
{
   static const uint32_t alpha_blend_vert[] =
#include "vulkan_shaders/alpha_blend.vert.inc"
      ;

   static const uint32_t alpha_blend_frag[] =
#include "vulkan_shaders/alpha_blend.frag.inc"
      ;

   static const uint32_t font_frag[] =
#include "vulkan_shaders/font.frag.inc"
      ;

   static const uint32_t ribbon_vert[] =
#include "vulkan_shaders/ribbon.vert.inc"
      ;

   static const uint32_t ribbon_frag[] =
#include "vulkan_shaders/ribbon.frag.inc"
      ;

   static const uint32_t ribbon_simple_vert[] =
#include "vulkan_shaders/ribbon_simple.vert.inc"
      ;

   static const uint32_t ribbon_simple_frag[] =
#include "vulkan_shaders/ribbon_simple.frag.inc"
      ;

   unsigned i;
   VkPipelineInputAssemblyStateCreateInfo input_assembly = { 
      VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO };
   VkPipelineVertexInputStateCreateInfo vertex_input     = { 
      VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO };
   VkPipelineRasterizationStateCreateInfo raster         = { 
      VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO };
   VkPipelineColorBlendAttachmentState blend_attachment  = {0};
   VkPipelineColorBlendStateCreateInfo blend             = { 
      VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO };
   VkPipelineViewportStateCreateInfo viewport            = { 
      VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO };
   VkPipelineDepthStencilStateCreateInfo depth_stencil   = { 
      VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO };
   VkPipelineMultisampleStateCreateInfo multisample      = { 
      VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO };
   VkPipelineDynamicStateCreateInfo dynamic              = { 
      VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO };

   VkPipelineShaderStageCreateInfo shader_stages[2]      = {
      { VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO },
      { VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO },
   };

   VkGraphicsPipelineCreateInfo pipe                     = { 
      VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO };
   VkShaderModuleCreateInfo module_info                  = { 
      VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO };
   VkVertexInputAttributeDescription attributes[3]       = {{0}};
   VkVertexInputBindingDescription binding               = {0};

   static const VkDynamicState dynamics[] = {
      VK_DYNAMIC_STATE_VIEWPORT,
      VK_DYNAMIC_STATE_SCISSOR,
   };

   vulkan_init_pipeline_layout(vk);

   /* Input assembly */
   input_assembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

   /* VAO state */
   attributes[0].location  = 0;
   attributes[0].binding   = 0;
   attributes[0].format    = VK_FORMAT_R32G32_SFLOAT;
   attributes[0].offset    = 0;
   attributes[1].location  = 1;
   attributes[1].binding   = 0;
   attributes[1].format    = VK_FORMAT_R32G32_SFLOAT;
   attributes[1].offset    = 2 * sizeof(float);
   attributes[2].location  = 2;
   attributes[2].binding   = 0;
   attributes[2].format    = VK_FORMAT_R32G32B32A32_SFLOAT;
   attributes[2].offset    = 4 * sizeof(float);

   binding.binding         = 0;
   binding.stride          = sizeof(struct vk_vertex);
   binding.inputRate       = VK_VERTEX_INPUT_RATE_VERTEX;

   vertex_input.vertexBindingDescriptionCount   = 1;
   vertex_input.pVertexBindingDescriptions      = &binding;
   vertex_input.vertexAttributeDescriptionCount = 3;
   vertex_input.pVertexAttributeDescriptions    = attributes;

   /* Raster state */
   raster.polygonMode                   = VK_POLYGON_MODE_FILL;
   raster.cullMode                      = VK_CULL_MODE_NONE;
   raster.frontFace                     = VK_FRONT_FACE_COUNTER_CLOCKWISE;
   raster.depthClampEnable              = false;
   raster.rasterizerDiscardEnable       = false;
   raster.depthBiasEnable               = false;
   raster.lineWidth                     = 1.0f;

   /* Blend state */
   blend_attachment.blendEnable         = false;
   blend_attachment.colorWriteMask      = 0xf;
   blend.attachmentCount                = 1;
   blend.pAttachments                   = &blend_attachment;

   /* Viewport state */
   viewport.viewportCount               = 1;
   viewport.scissorCount                = 1;

   /* Depth-stencil state */
   depth_stencil.depthTestEnable        = false;
   depth_stencil.depthWriteEnable       = false;
   depth_stencil.depthBoundsTestEnable  = false;
   depth_stencil.stencilTestEnable      = false;
   depth_stencil.minDepthBounds         = 0.0f;
   depth_stencil.maxDepthBounds         = 1.0f;

   /* Multisample state */
   multisample.rasterizationSamples     = VK_SAMPLE_COUNT_1_BIT;

   /* Dynamic state */
   dynamic.pDynamicStates               = dynamics;
   dynamic.dynamicStateCount            = ARRAY_SIZE(dynamics);

   pipe.stageCount                      = 2;
   pipe.pStages                         = shader_stages;
   pipe.pVertexInputState               = &vertex_input;
   pipe.pInputAssemblyState             = &input_assembly;
   pipe.pRasterizationState             = &raster;
   pipe.pColorBlendState                = &blend;
   pipe.pMultisampleState               = &multisample;
   pipe.pViewportState                  = &viewport;
   pipe.pDepthStencilState              = &depth_stencil;
   pipe.pDynamicState                   = &dynamic;
   pipe.renderPass                      = vk->render_pass;
   pipe.layout                          = vk->pipelines.layout;

   module_info.codeSize                 = sizeof(alpha_blend_vert);
   module_info.pCode                    = alpha_blend_vert;
   shader_stages[0].stage               = VK_SHADER_STAGE_VERTEX_BIT;
   shader_stages[0].pName               = "main";
   vkCreateShaderModule(vk->context->device,
         &module_info, NULL, &shader_stages[0].module);

   blend_attachment.blendEnable         = true;
   blend_attachment.colorWriteMask      = 0xf;
   blend_attachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
   blend_attachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
   blend_attachment.colorBlendOp        = VK_BLEND_OP_ADD;
   blend_attachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
   blend_attachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
   blend_attachment.alphaBlendOp        = VK_BLEND_OP_ADD;

   /* Glyph pipeline */
   module_info.codeSize                 = sizeof(font_frag);
   module_info.pCode                    = font_frag;
   shader_stages[1].stage               = VK_SHADER_STAGE_FRAGMENT_BIT;
   shader_stages[1].pName               = "main";
   vkCreateShaderModule(vk->context->device,
         &module_info, NULL, &shader_stages[1].module);

   vkCreateGraphicsPipelines(vk->context->device, vk->pipelines.cache,
         1, &pipe, NULL, &vk->pipelines.font);
   vkDestroyShaderModule(vk->context->device, shader_stages[1].module, NULL);

   /* Alpha-blended pipeline. */
   module_info.codeSize   = sizeof(alpha_blend_frag);
   module_info.pCode      = alpha_blend_frag;
   shader_stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
   shader_stages[1].pName = "main";
   vkCreateShaderModule(vk->context->device,
         &module_info, NULL, &shader_stages[1].module);

   vkCreateGraphicsPipelines(vk->context->device, vk->pipelines.cache,
         1, &pipe, NULL, &vk->pipelines.alpha_blend);

   /* Build display pipelines. */
   for (i = 0; i < 4; i++)
   {
      input_assembly.topology = i & 2 ?
         VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP :
         VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
      blend_attachment.blendEnable = i & 1;
      vkCreateGraphicsPipelines(vk->context->device, vk->pipelines.cache,
            1, &pipe, NULL, &vk->display.pipelines[i]);
   }

   vkDestroyShaderModule(vk->context->device, shader_stages[0].module, NULL);
   vkDestroyShaderModule(vk->context->device, shader_stages[1].module, NULL);

   /* Other menu pipelines. */
   for (i = 0; i < 4; i++)
   {
      if (i & 2)
      {
         module_info.codeSize   = sizeof(ribbon_simple_vert);
         module_info.pCode      = ribbon_simple_vert;
      }
      else
      {
         module_info.codeSize   = sizeof(ribbon_vert);
         module_info.pCode      = ribbon_vert;
      }

      shader_stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
      shader_stages[0].pName = "main";
      vkCreateShaderModule(vk->context->device,
            &module_info, NULL, &shader_stages[0].module);

      if (i & 2)
      {
         module_info.codeSize   = sizeof(ribbon_simple_frag);
         module_info.pCode      = ribbon_simple_frag;
      }
      else
      {
         module_info.codeSize   = sizeof(ribbon_frag);
         module_info.pCode      = ribbon_frag;
      }

      shader_stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
      shader_stages[1].pName = "main";
      vkCreateShaderModule(vk->context->device,
            &module_info, NULL, &shader_stages[1].module);

      input_assembly.topology = i & 1 ?
         VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP :
         VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

      vkCreateGraphicsPipelines(vk->context->device, vk->pipelines.cache,
            1, &pipe, NULL, &vk->display.pipelines[4 + i]);

      vkDestroyShaderModule(vk->context->device, shader_stages[0].module, NULL);
      vkDestroyShaderModule(vk->context->device, shader_stages[1].module, NULL);
   }
}

static void vulkan_init_command_buffers(vk_t *vk)
{
   /* RESET_COMMAND_BUFFER_BIT allows command buffer to be reset. */
   unsigned i;

   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      VkCommandPoolCreateInfo pool_info = { 
         VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO };
      VkCommandBufferAllocateInfo info  = { 
         VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO };

      pool_info.queueFamilyIndex = vk->context->graphics_queue_index;
      pool_info.flags            = 
         VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

      vkCreateCommandPool(vk->context->device,
            &pool_info, NULL, &vk->swapchain[i].cmd_pool);

      info.commandPool           = vk->swapchain[i].cmd_pool;
      info.level                 = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
      info.commandBufferCount    = 1;

      vkAllocateCommandBuffers(vk->context->device,
            &info, &vk->swapchain[i].cmd);
   }
}

static void vulkan_init_samplers(vk_t *vk)
{
   VkSamplerCreateInfo info =
   { VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO };

   info.magFilter               = VK_FILTER_NEAREST;
   info.minFilter               = VK_FILTER_NEAREST;
   info.mipmapMode              = VK_SAMPLER_MIPMAP_MODE_NEAREST;
   info.addressModeU            = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
   info.addressModeV            = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
   info.addressModeW            = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
   info.mipLodBias              = 0.0f;
   info.maxAnisotropy           = 1.0f;
   info.compareEnable           = false;
   info.minLod                  = 0.0f;
   info.maxLod                  = 0.0f;
   info.unnormalizedCoordinates = false;
   info.borderColor             = VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE;
   vkCreateSampler(vk->context->device,
         &info, NULL, &vk->samplers.nearest);

   info.magFilter = VK_FILTER_LINEAR;
   info.minFilter = VK_FILTER_LINEAR;
   vkCreateSampler(vk->context->device,
         &info, NULL, &vk->samplers.linear);

   info.maxLod     = VK_LOD_CLAMP_NONE;
   info.magFilter  = VK_FILTER_NEAREST;
   info.minFilter  = VK_FILTER_NEAREST;
   info.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
   vkCreateSampler(vk->context->device,
         &info, NULL, &vk->samplers.mipmap_nearest);

   info.magFilter  = VK_FILTER_LINEAR;
   info.minFilter  = VK_FILTER_LINEAR;
   info.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
   vkCreateSampler(vk->context->device,
         &info, NULL, &vk->samplers.mipmap_linear);
}

static void vulkan_deinit_samplers(vk_t *vk)
{
   vkDestroySampler(vk->context->device, vk->samplers.nearest, NULL);
   vkDestroySampler(vk->context->device, vk->samplers.linear, NULL);
   vkDestroySampler(vk->context->device, vk->samplers.mipmap_nearest, NULL);
   vkDestroySampler(vk->context->device, vk->samplers.mipmap_linear, NULL);
}

static void vulkan_init_buffers(vk_t *vk)
{
   unsigned i;
   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      vk->swapchain[i].vbo = vulkan_buffer_chain_init(
            VULKAN_BUFFER_BLOCK_SIZE, 16, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
      vk->swapchain[i].ubo = vulkan_buffer_chain_init(
            VULKAN_BUFFER_BLOCK_SIZE,
            vk->context->gpu_properties.limits.minUniformBufferOffsetAlignment,
            VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
   }
}

static void vulkan_deinit_buffers(vk_t *vk)
{
   unsigned i;
   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      vulkan_buffer_chain_free(
            vk->context->device, &vk->swapchain[i].vbo);
      vulkan_buffer_chain_free(
            vk->context->device, &vk->swapchain[i].ubo);
   }
}

static void vulkan_init_descriptor_pool(vk_t *vk)
{
   unsigned i;
   static const VkDescriptorPoolSize pool_sizes[2] = {
      { VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, VULKAN_DESCRIPTOR_MANAGER_BLOCK_SETS },
      { VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, VULKAN_DESCRIPTOR_MANAGER_BLOCK_SETS },
   };

   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      vk->swapchain[i].descriptor_manager = 
         vulkan_create_descriptor_manager(
               vk->context->device,
               pool_sizes, 2, vk->pipelines.set_layout);
   }
}

static void vulkan_deinit_descriptor_pool(vk_t *vk)
{
   unsigned i;
   for (i = 0; i < vk->num_swapchain_images; i++)
      vulkan_destroy_descriptor_manager(
            vk->context->device,
            &vk->swapchain[i].descriptor_manager);
}

static void vulkan_init_textures(vk_t *vk)
{
   unsigned i;
   vulkan_init_samplers(vk);

   if (!vk->hw.enable)
   {
      for (i = 0; i < vk->num_swapchain_images; i++)
      {
         vk->swapchain[i].texture = vulkan_create_texture(vk, NULL,
               vk->tex_w, vk->tex_h, vk->tex_fmt,
               NULL, NULL, VULKAN_TEXTURE_STREAMED);

         vulkan_map_persistent_texture(
               vk->context->device,
               &vk->swapchain[i].texture);

         if (vk->swapchain[i].texture.type == VULKAN_TEXTURE_STAGING)
            vk->swapchain[i].texture_optimal = vulkan_create_texture(vk, NULL,
                  vk->tex_w, vk->tex_h, vk->tex_fmt,
                  NULL, NULL, VULKAN_TEXTURE_DYNAMIC);
      }
   }
}

static void vulkan_deinit_textures(vk_t *vk)
{
   unsigned i;

   vulkan_deinit_samplers(vk);

   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      if (vk->swapchain[i].texture.memory != VK_NULL_HANDLE)
         vulkan_destroy_texture(
               vk->context->device, &vk->swapchain[i].texture);

      if (vk->swapchain[i].texture_optimal.memory != VK_NULL_HANDLE)
         vulkan_destroy_texture(
               vk->context->device, &vk->swapchain[i].texture_optimal);
   }
}

static void vulkan_deinit_command_buffers(vk_t *vk)
{
   unsigned i;
   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      if (vk->swapchain[i].cmd)
         vkFreeCommandBuffers(vk->context->device,
               vk->swapchain[i].cmd_pool, 1, &vk->swapchain[i].cmd);

      vkDestroyCommandPool(vk->context->device,
            vk->swapchain[i].cmd_pool, NULL);
   }
}

static void vulkan_deinit_pipeline_layout(vk_t *vk)
{
   vkDestroyPipelineLayout(vk->context->device,
         vk->pipelines.layout, NULL);
   vkDestroyDescriptorSetLayout(vk->context->device,
         vk->pipelines.set_layout, NULL);
}

static void vulkan_deinit_pipelines(vk_t *vk)
{
   unsigned i;

   vulkan_deinit_pipeline_layout(vk);
   vkDestroyPipeline(vk->context->device,
         vk->pipelines.alpha_blend, NULL);
   vkDestroyPipeline(vk->context->device,
         vk->pipelines.font, NULL);

   for (i = 0; i < 8; i++)
      vkDestroyPipeline(vk->context->device,
            vk->display.pipelines[i], NULL);
}

static void vulkan_deinit_framebuffers(vk_t *vk)
{
   unsigned i;
   for (i = 0; i < vk->num_swapchain_images; i++)
   {
      vkDestroyFramebuffer(vk->context->device,
            vk->swapchain[i].backbuffer.framebuffer, NULL);
      vkDestroyImageView(vk->context->device,
            vk->swapchain[i].backbuffer.view, NULL);
   }

   vkDestroyRenderPass(vk->context->device, vk->render_pass, NULL);
}

static bool vulkan_init_default_filter_chain(vk_t *vk)
{
   struct vulkan_filter_chain_create_info info;

   memset(&info, 0, sizeof(info));

   info.device                = vk->context->device;
   info.gpu                   = vk->context->gpu;
   info.memory_properties     = &vk->context->memory_properties;
   info.pipeline_cache        = vk->pipelines.cache;
   info.queue                 = vk->context->queue;
   info.command_pool          = vk->swapchain[vk->context->current_swapchain_index].cmd_pool;
   info.max_input_size.width  = vk->tex_w;
   info.max_input_size.height = vk->tex_h;
   info.swapchain.viewport    = vk->vk_vp;
   info.swapchain.format      = vk->context->swapchain_format;
   info.swapchain.render_pass = vk->render_pass;
   info.swapchain.num_indices = vk->context->num_swapchain_images;
   info.original_format       = vk->tex_fmt;

   vk->filter_chain           = vulkan_filter_chain_create_default(
         &info,
         vk->video.smooth ? 
         VULKAN_FILTER_CHAIN_LINEAR : VULKAN_FILTER_CHAIN_NEAREST);

   if (!vk->filter_chain)
   {
      ELOG("Failed to create filter chain.\n");
      return false;
   }

   return true;
}

static bool vulkan_init_filter_chain_preset(vk_t *vk, const char *shader_path)
{
   struct vulkan_filter_chain_create_info info;

   memset(&info, 0, sizeof(info));

   info.device                = vk->context->device;
   info.gpu                   = vk->context->gpu;
   info.memory_properties     = &vk->context->memory_properties;
   info.pipeline_cache        = vk->pipelines.cache;
   info.queue                 = vk->context->queue;
   info.command_pool          = vk->swapchain[vk->context->current_swapchain_index].cmd_pool;
   info.max_input_size.width  = vk->tex_w;
   info.max_input_size.height = vk->tex_h;
   info.swapchain.viewport    = vk->vk_vp;
   info.swapchain.format      = vk->context->swapchain_format;
   info.swapchain.render_pass = vk->render_pass;
   info.swapchain.num_indices = vk->context->num_swapchain_images;
   info.original_format       = vk->tex_fmt;

   vk->filter_chain           = vulkan_filter_chain_create_from_preset(
         &info, shader_path,
         vk->video.smooth ?
         VULKAN_FILTER_CHAIN_LINEAR : VULKAN_FILTER_CHAIN_NEAREST);

   if (!vk->filter_chain)
   {
      RARCH_ERR("[Vulkan]: Failed to create preset: \"%s\".\n", shader_path);
      return false;
   }

   return true;
}

static bool vulkan_init_filter_chain(vk_t *vk)
{
   settings_t *settings = config_get_ptr();
   const char *shader_path = (settings->video.shader_enable && *settings->path.shader) ?
      settings->path.shader : NULL;

   enum rarch_shader_type type = video_shader_parse_type(shader_path, RARCH_SHADER_NONE);

   if (type == RARCH_SHADER_NONE)
   {
      RARCH_LOG("[Vulkan]: Loading stock shader.\n");
      return vulkan_init_default_filter_chain(vk);
   }

   if (type != RARCH_SHADER_SLANG)
   {
      VLOG("[Vulkan]: Only SLANG shaders are supported, falling back to stock.\n");
      return vulkan_init_default_filter_chain(vk);
   }

   if (!shader_path || !vulkan_init_filter_chain_preset(vk, shader_path))
      vulkan_init_default_filter_chain(vk);

   return true;
}

static void vulkan_init_resources(vk_t *vk)
{
   vk->num_swapchain_images = vk->context->num_swapchain_images;
   vulkan_init_framebuffers(vk);
   vulkan_init_pipelines(vk);
   vulkan_init_descriptor_pool(vk);
   vulkan_init_textures(vk);
   vulkan_init_buffers(vk);
   vulkan_init_command_buffers(vk);
}

static void vulkan_init_static_resources(vk_t *vk)
{
   unsigned i;
   uint32_t blank[4 * 4];
   VkCommandPoolCreateInfo pool_info = { 
      VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO };
   /* Create the pipeline cache. */
   VkPipelineCacheCreateInfo cache   = { 
      VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO };

   vkCreatePipelineCache(vk->context->device,
         &cache, NULL, &vk->pipelines.cache);

   pool_info.queueFamilyIndex = vk->context->graphics_queue_index;

   vkCreateCommandPool(vk->context->device,
         &pool_info, NULL, &vk->staging_pool);

   for (i = 0; i < 4 * 4; i++)
      blank[i] = -1u;

   vk->display.blank_texture = vulkan_create_texture(vk, NULL,
         4, 4, VK_FORMAT_B8G8R8A8_UNORM,
         blank, NULL, VULKAN_TEXTURE_STATIC);
}

static void vulkan_deinit_static_resources(vk_t *vk)
{
   unsigned i;
   vkDestroyPipelineCache(vk->context->device,
         vk->pipelines.cache, NULL);
   vulkan_destroy_texture(
         vk->context->device,
         &vk->display.blank_texture);

   vkDestroyCommandPool(vk->context->device,
         vk->staging_pool, NULL);
   free(vk->hw.cmd);
   free(vk->hw.wait_dst_stages);

   for (i = 0; i < VULKAN_MAX_SWAPCHAIN_IMAGES; i++)
      if (vk->readback.staging[i].memory != VK_NULL_HANDLE)
         vulkan_destroy_texture(
               vk->context->device,
               &vk->readback.staging[i]);
}

static void vulkan_deinit_resources(vk_t *vk)
{
   vulkan_deinit_pipelines(vk);
   vulkan_deinit_framebuffers(vk);
   vulkan_deinit_descriptor_pool(vk);
   vulkan_deinit_textures(vk);
   vulkan_deinit_buffers(vk);
   vulkan_deinit_command_buffers(vk);
}

static void vulkan_deinit_menu(vk_t *vk)
{
   unsigned i;
   for (i = 0; i < VULKAN_MAX_SWAPCHAIN_IMAGES; i++)
   {
      if (vk->menu.textures[i].memory)
         vulkan_destroy_texture(
               vk->context->device, &vk->menu.textures[i]);
      if (vk->menu.textures_optimal[i].memory)
         vulkan_destroy_texture(
               vk->context->device, &vk->menu.textures_optimal[i]);
   }
}

static void vulkan_free(void *data)
{
   vk_t *vk = (vk_t*)data;
   if (!vk)
      return;

   if (vk->context && vk->context->device)
   {
      vkQueueWaitIdle(vk->context->queue);
      vulkan_deinit_resources(vk);

      /* No need to init this since textures are create on-demand. */
      vulkan_deinit_menu(vk);
      font_driver_free(NULL);

      vulkan_deinit_static_resources(vk);
#ifdef HAVE_OVERLAY
      vulkan_overlay_free(vk);
#endif
      if (vk->filter_chain)
         vulkan_filter_chain_free(vk->filter_chain);

      video_context_driver_free();
   }

   scaler_ctx_gen_reset(&vk->readback.scaler);
   free(vk);
}

static uint32_t vulkan_get_sync_index(void *handle)
{
   vk_t *vk = (vk_t*)handle;
   return vk->context->current_swapchain_index;
}

static uint32_t vulkan_get_sync_index_mask(void *handle)
{
   vk_t *vk = (vk_t*)handle;
   return (1 << vk->context->num_swapchain_images) - 1;
}

static void vulkan_set_image(void *handle,
      const struct retro_vulkan_image *image,
      uint32_t num_semaphores,
      const VkSemaphore *semaphores,
      uint32_t src_queue_family)
{
   unsigned i;
   vk_t *vk              = (vk_t*)handle;

   vk->hw.image          = image;
   vk->hw.num_semaphores = num_semaphores;
   vk->hw.semaphores     = semaphores;

   if (num_semaphores > 0)
   {
      vk->hw.wait_dst_stages = (VkPipelineStageFlags*)
         realloc(vk->hw.wait_dst_stages,
            sizeof(VkPipelineStageFlags) * vk->hw.num_semaphores);

      /* If this fails, we're screwed anyways. */
      retro_assert(vk->hw.wait_dst_stages);

      for (i = 0; i < vk->hw.num_semaphores; i++)
         vk->hw.wait_dst_stages[i] = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;

      vk->hw.valid_semaphore = true;
      vk->hw.src_queue_family = src_queue_family;
   }
}

static void vulkan_wait_sync_index(void *handle)
{
   (void)handle;
   /* no-op. RetroArch already waits for this
    * in gfx_ctx_swap_buffers(). */
}

static void vulkan_set_command_buffers(void *handle, uint32_t num_cmd,
      const VkCommandBuffer *cmd)
{
   vk_t *vk                   = (vk_t*)handle;
   unsigned required_capacity = num_cmd + 1;
   if (required_capacity > vk->hw.capacity_cmd)
   {
      vk->hw.cmd = (VkCommandBuffer*)realloc(vk->hw.cmd,
            sizeof(VkCommandBuffer) * required_capacity);

      /* If this fails, we're just screwed. */
      retro_assert(vk->hw.cmd);
      vk->hw.capacity_cmd = required_capacity;
   }

   vk->hw.num_cmd = num_cmd;
   memcpy(vk->hw.cmd, cmd, sizeof(VkCommandBuffer) * num_cmd);
}

static void vulkan_lock_queue(void *handle)
{
   vk_t *vk = (vk_t*)handle;
#ifdef HAVE_THREADS
   slock_lock(vk->context->queue_lock);
#endif
}

static void vulkan_unlock_queue(void *handle)
{
   vk_t *vk = (vk_t*)handle;
#ifdef HAVE_THREADS
   slock_unlock(vk->context->queue_lock);
#endif
}

static void vulkan_set_signal_semaphore(void *handle, VkSemaphore semaphore)
{
   vk_t *vk = (vk_t*)handle;
   vk->hw.signal_semaphore = semaphore;
}

static void vulkan_init_hw_render(vk_t *vk)
{
   struct retro_hw_render_interface_vulkan *iface   =
      &vk->hw.iface;
   struct retro_hw_render_callback *hwr =
      video_driver_get_hw_context();

   if (hwr->context_type != RETRO_HW_CONTEXT_VULKAN)
      return;

   vk->hw.enable               = true;

   iface->interface_type       = RETRO_HW_RENDER_INTERFACE_VULKAN;
   iface->interface_version    = RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION;
   iface->instance             = vk->context->instance;
   iface->gpu                  = vk->context->gpu;
   iface->device               = vk->context->device;

   iface->queue                = vk->context->queue;
   iface->queue_index          = vk->context->graphics_queue_index;

   iface->handle               = vk;
   iface->set_image            = vulkan_set_image;
   iface->get_sync_index       = vulkan_get_sync_index;
   iface->get_sync_index_mask  = vulkan_get_sync_index_mask;
   iface->wait_sync_index      = vulkan_wait_sync_index;
   iface->set_command_buffers  = vulkan_set_command_buffers;
   iface->lock_queue           = vulkan_lock_queue;
   iface->unlock_queue         = vulkan_unlock_queue;
   iface->set_signal_semaphore = vulkan_set_signal_semaphore;

   iface->get_device_proc_addr   = vkGetDeviceProcAddr;
   iface->get_instance_proc_addr = vulkan_symbol_wrapper_instance_proc_addr();
}

static void vulkan_init_readback(vk_t *vk)
{
   /* Only bother with this if we're doing GPU recording.
    * Check recording_is_enabled() and not 
    * driver.recording_data, because recording is 
    * not initialized yet.
    */
   settings_t *settings    = config_get_ptr();
   bool *recording_enabled = recording_is_enabled();
   vk->readback.streamed   = settings->video.gpu_record && *recording_enabled;

   if (!vk->readback.streamed)
      return;

   vk->readback.scaler.in_width    = vk->vp.width;
   vk->readback.scaler.in_height   = vk->vp.height;
   vk->readback.scaler.out_width   = vk->vp.width;
   vk->readback.scaler.out_height  = vk->vp.height;
   vk->readback.scaler.in_fmt      = SCALER_FMT_ARGB8888;
   vk->readback.scaler.out_fmt     = SCALER_FMT_BGR24;
   vk->readback.scaler.scaler_type = SCALER_TYPE_POINT;

   if (!scaler_ctx_gen_filter(&vk->readback.scaler))
   {
      vk->readback.streamed = false;
      ELOG("[Vulkan]: Failed to initialize scaler context.\n");
   }
}

static void *vulkan_init(const video_info_t *video,
      const input_driver_t **input,
      void **input_data)
{
   gfx_ctx_mode_t mode;
   gfx_ctx_input_t inp;
   unsigned interval;
   unsigned full_x, full_y;
   unsigned win_width;
   unsigned win_height;
   unsigned temp_width                = 0;
   unsigned temp_height               = 0;
   const gfx_ctx_driver_t *ctx_driver = NULL;
   settings_t *settings               = config_get_ptr();
   vk_t *vk                           = (vk_t*)calloc(1, sizeof(*vk));
   if (!vk)
      return NULL;

   vk->video = *video;

   ctx_driver = vulkan_get_context(vk);
   if (!ctx_driver)
   {
      ELOG("[Vulkan]: Failed to get Vulkan context.\n");
      goto error;
   }

   video_context_driver_set((const gfx_ctx_driver_t*)ctx_driver);

   video_context_driver_get_video_size(&mode);
   full_x = mode.width;
   full_y = mode.height;
   mode.width  = 0;
   mode.height = 0;

   VLOG("Detecting screen resolution %ux%u.\n", full_x, full_y);
   interval = video->vsync ? settings->video.swap_interval : 0;
   video_context_driver_swap_interval(&interval);

   win_width  = video->width;
   win_height = video->height;

   if (video->fullscreen && (win_width == 0) && (win_height == 0))
   {
      win_width  = full_x;
      win_height = full_y;
   }

   mode.width      = win_width;
   mode.height     = win_height;
   mode.fullscreen = video->fullscreen;

   if (!video_context_driver_set_video_mode(&mode))
   {
      ELOG("[Vulkan]: Failed to set video mode.\n");
      goto error;
   }

   video_context_driver_get_video_size(&mode);
   temp_width  = mode.width;
   temp_height = mode.height;

   if (temp_width != 0 && temp_height != 0)
      video_driver_set_size(&temp_width, &temp_height);
   video_driver_get_size(&temp_width, &temp_height);

   VLOG("Vulkan: Using resolution %ux%u\n", temp_width, temp_height);

   video_context_driver_get_context_data(&vk->context);

   vk->vsync             = video->vsync;
   vk->fullscreen        = video->fullscreen;
   vk->tex_w             = RARCH_SCALE_BASE * video->input_scale;
   vk->tex_h             = RARCH_SCALE_BASE * video->input_scale;
   vk->tex_fmt           = video->rgb32 
      ? VK_FORMAT_B8G8R8A8_UNORM : VK_FORMAT_R5G6B5_UNORM_PACK16;
   vk->keep_aspect       = video->force_aspect;
   VLOG("[Vulkan]: Using %s format.\n", video->rgb32 ? "BGRA8888" : "RGB565");

   /* Set the viewport to fix recording, since it needs to know
    * the viewport sizes before we start running. */
   vulkan_set_viewport(vk, temp_width, temp_height, false, true);

   vulkan_init_hw_render(vk);
   vulkan_init_static_resources(vk);
   vulkan_init_resources(vk);

   if (!vulkan_init_filter_chain(vk))
   {
      ELOG("[Vulkan]: Failed to init filter chain.\n");
      goto error;
   }

   inp.input      = input;
   inp.input_data = input_data;
   video_context_driver_input_driver(&inp);

   if (settings->video.font_enable)
   {
      if (!font_driver_init_first(NULL, NULL, vk, *settings->path.font 
            ? settings->path.font : NULL, settings->video.font_size, false,
            FONT_DRIVER_RENDER_VULKAN_API))
         ELOG("[Vulkan]: Failed to initialize font renderer.\n");
   }

   vulkan_init_readback(vk);
   return vk;

error:
   vulkan_free(vk);
   return NULL;
}

static void vulkan_update_filter_chain(vk_t *vk)
{
   const struct vulkan_filter_chain_swapchain_info info = {
      vk->vk_vp,
      vk->context->swapchain_format,
      vk->render_pass,
      vk->context->num_swapchain_images,
   };

   if (!vulkan_filter_chain_update_swapchain_info(vk->filter_chain, &info))
      ELOG("Failed to update filter chain info. This will probably lead to a crash ...\n");
}

static void vulkan_check_swapchain(vk_t *vk)
{
   if (vk->context->invalid_swapchain)
   {
      vkQueueWaitIdle(vk->context->queue);

      vulkan_deinit_resources(vk);
      vulkan_init_resources(vk);
      vk->context->invalid_swapchain = false;

      vulkan_update_filter_chain(vk);
   }
}

static void vulkan_set_nonblock_state(void *data, bool state)
{
   unsigned interval;
   vk_t *vk             = (vk_t*)data;
   settings_t *settings = config_get_ptr();

   if (!vk)
      return;

   VLOG("[Vulkan]: VSync => %s\n", state ? "off" : "on");

   interval = state ? 0 : settings->video.swap_interval;
   video_context_driver_swap_interval(&interval);

   /* Changing vsync might require recreating the swapchain, which means new VkImages
    * to render into. */
   vulkan_check_swapchain(vk);
}

static bool vulkan_alive(void *data)
{
   gfx_ctx_size_t size_data;
   unsigned temp_width  = 0;
   unsigned temp_height = 0;
   bool ret             = false;
   bool quit            = false;
   bool resize          = false;
   vk_t *vk             = (vk_t*)data;

   video_driver_get_size(&temp_width, &temp_height);

   size_data.quit       = &quit;
   size_data.resize     = &resize;
   size_data.width      = &temp_width;
   size_data.height     = &temp_height;

   if (video_context_driver_check_window(&size_data))
   {
      if (quit)
         vk->quitting      = true;
      else if (resize)
         vk->should_resize = true;

      ret = !vk->quitting;
   }

   if (temp_width != 0 && temp_height != 0)
      video_driver_set_size(&temp_width, &temp_height);

   return ret;
}

static bool vulkan_focus(void *data)
{
   (void)data;
   return video_context_driver_focus();
}

static bool vulkan_suppress_screensaver(void *data, bool enable)
{
   (void)data;
   bool enabled = enable;
   return video_context_driver_suppress_screensaver(&enabled);
}

static bool vulkan_has_windowed(void *data)
{
   (void)data;
   return video_context_driver_has_windowed();
}

static bool vulkan_set_shader(void *data,
      enum rarch_shader_type type, const char *path)
{
   vk_t *vk = (vk_t*)data;
   if (!vk)
      return false;

   if (type != RARCH_SHADER_SLANG && path)
   {
      WLOG("[Vulkan]: Only .slang or .slangp shaders are supported. Falling back to stock.\n");
      path = NULL;
   }

   if (vk->filter_chain)
      vulkan_filter_chain_free(vk->filter_chain);
   vk->filter_chain = NULL;

   if (!path)
   {
      vulkan_init_default_filter_chain(vk);
      return true;
   }

   if (!vulkan_init_filter_chain_preset(vk, path))
   {
      ELOG("[Vulkan]: Failed to create filter chain: \"%s\". Falling back to stock.\n", path);
      vulkan_init_default_filter_chain(vk);
      return false;
   }

   return true;
}

static void vulkan_set_projection(vk_t *vk,
      struct video_ortho *ortho, bool allow_rotate)
{
   math_matrix_4x4 rot;

   /* Calculate projection. */
   matrix_4x4_ortho(&vk->mvp_no_rot, ortho->left, ortho->right,
         ortho->bottom, ortho->top, ortho->znear, ortho->zfar);

   if (!allow_rotate)
   {
      vk->mvp = vk->mvp_no_rot;
      return;
   }

   matrix_4x4_rotate_z(&rot, M_PI * vk->rotation / 180.0f);
   matrix_4x4_multiply(&vk->mvp, &rot, &vk->mvp_no_rot);
}

static void vulkan_set_rotation(void *data, unsigned rotation)
{
   vk_t *vk               = (vk_t*)data;
   struct video_ortho ortho = {0, 1, 0, 1, -1, 1};

   if (!vk)
      return;

   vk->rotation = 90 * rotation;
   vulkan_set_projection(vk, &ortho, true);
}

static void vulkan_set_video_mode(void *data,
      unsigned width, unsigned height,
      bool fullscreen)
{
   (void)data;
   gfx_ctx_mode_t mode;

   mode.width      = width;
   mode.height     = height;
   mode.fullscreen = fullscreen;

   video_context_driver_set_video_mode(&mode);
}

static void vulkan_set_viewport(void *data, unsigned viewport_width,
      unsigned viewport_height, bool force_full, bool allow_rotate)
{
   gfx_ctx_aspect_t aspect_data;
   unsigned width, height;
   int x                  = 0;
   int y                  = 0;
   float device_aspect    = (float)viewport_width / viewport_height;
   struct video_ortho ortho = {0, 1, 0, 1, -1, 1};
   settings_t *settings   = config_get_ptr();
   vk_t *vk               = (vk_t*)data;

   video_driver_get_size(&width, &height);

   aspect_data.aspect     = &device_aspect;
   aspect_data.width      = viewport_width;
   aspect_data.height     = viewport_height;

   video_context_driver_translate_aspect(&aspect_data);

   if (settings->video.scale_integer && !force_full)
   {
      video_viewport_get_scaled_integer(&vk->vp,
            viewport_width, viewport_height,
            video_driver_get_aspect_ratio(), vk->keep_aspect);
      viewport_width  = vk->vp.width;
      viewport_height = vk->vp.height;
   }
   else if (vk->keep_aspect && !force_full)
   {
      float desired_aspect = video_driver_get_aspect_ratio();

#if defined(HAVE_MENU)
      if (settings->video.aspect_ratio_idx == ASPECT_RATIO_CUSTOM)
      {
         const struct video_viewport *custom = video_viewport_get_custom();

         /* Vukan has top-left origin viewport. */
         x               = custom->x;
         y               = custom->y;
         viewport_width  = custom->width;
         viewport_height = custom->height;
      }
      else
#endif
      {
         float delta;

         if (fabsf(device_aspect - desired_aspect) < 0.0001f)
         {
            /* If the aspect ratios of screen and desired aspect 
             * ratio are sufficiently equal (floating point stuff), 
             * assume they are actually equal.
             */
         }
         else if (device_aspect > desired_aspect)
         {
            delta          = (desired_aspect / device_aspect - 1.0f) 
               / 2.0f + 0.5f;
            x              = (int)roundf(viewport_width * (0.5f - delta));
            viewport_width = (unsigned)roundf(2.0f * viewport_width * delta);
         }
         else
         {
            delta           = (device_aspect / desired_aspect - 1.0f) 
               / 2.0f + 0.5f;
            y               = (int)roundf(viewport_height * (0.5f - delta));
            viewport_height = (unsigned)roundf(2.0f * viewport_height * delta);
         }
      }

      vk->vp.x      = x;
      vk->vp.y      = y;
      vk->vp.width  = viewport_width;
      vk->vp.height = viewport_height;
   }
   else
   {
      vk->vp.x      = 0;
      vk->vp.y      = 0;
      vk->vp.width  = viewport_width;
      vk->vp.height = viewport_height;
   }

#if defined(RARCH_MOBILE)
   /* In portrait mode, we want viewport to gravitate to top of screen. */
   if (device_aspect < 1.0f)
      vk->vp.y = 0;
#endif

   vulkan_set_projection(vk, &ortho, allow_rotate);

   /* Set last backbuffer viewport. */
   if (!force_full)
   {
      vk->vp_out_width  = viewport_width;
      vk->vp_out_height = viewport_height;
   }

   vk->vk_vp.x          = (float)vk->vp.x;
   vk->vk_vp.y          = (float)vk->vp.y;
   vk->vk_vp.width      = (float)vk->vp.width;
   vk->vk_vp.height     = (float)vk->vp.height;
   vk->vk_vp.minDepth   = 0.0f;
   vk->vk_vp.maxDepth   = 1.0f;

   vk->tracker.dirty |= VULKAN_DIRTY_DYNAMIC_BIT;

#if 0
   VLOG("Setting viewport @ %ux%u\n", viewport_width, viewport_height);
#endif
}

static void vulkan_readback(vk_t *vk)
{
   VkImageCopy region;
   struct vk_texture *staging;
   struct video_viewport vp;

   vulkan_viewport_info(vk, &vp);
   memset(&region, 0, sizeof(region));
   region.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
   region.srcSubresource.layerCount = 1;
   region.dstSubresource            = region.srcSubresource;

   region.srcOffset.x               = vp.x;
   region.srcOffset.y               = vp.y;
   region.extent.width              = vp.width;
   region.extent.height             = vp.height;
   region.extent.depth              = 1;

   /* FIXME: We won't actually get format conversion with vkCmdCopyImage, so have to check
    * properly for this. BGRA seems to be the default for all swapchains. */
   if (vk->context->swapchain_format != VK_FORMAT_B8G8R8A8_UNORM)
      WLOG("[Vulkan]: Backbuffer is not BGRA8888, readbacks might not work properly.\n");

   staging  = &vk->readback.staging[vk->context->current_swapchain_index];
   *staging = vulkan_create_texture(vk,
         staging->memory != VK_NULL_HANDLE ? staging : NULL,
         vk->vp.width, vk->vp.height,
         VK_FORMAT_B8G8R8A8_UNORM,
         NULL, NULL, VULKAN_TEXTURE_READBACK);

   /* Go through the long-winded dance of remapping image layouts. */
   vulkan_image_layout_transition(vk, vk->cmd, staging->image,
         VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
         0, VK_ACCESS_TRANSFER_WRITE_BIT,
         VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
         VK_PIPELINE_STAGE_TRANSFER_BIT);

   vkCmdCopyImage(vk->cmd, vk->chain->backbuffer.image,
         VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
         staging->image,
         VK_IMAGE_LAYOUT_GENERAL,
         1, &region);

   /* Make the data visible to host. */
   vulkan_image_layout_transition(vk, vk->cmd, staging->image,
         VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL,
         VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_HOST_READ_BIT,
         VK_PIPELINE_STAGE_TRANSFER_BIT,
         VK_PIPELINE_STAGE_HOST_BIT);
}

static void vulkan_inject_black_frame(vk_t *vk)
{
   VkCommandBufferBeginInfo begin_info           = {
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
   VkSubmitInfo submit_info                      = {
      VK_STRUCTURE_TYPE_SUBMIT_INFO };

   const VkClearColorValue clear_color = {{ 0.0f, 0.0f, 0.0f, 1.0f }};
   const VkImageSubresourceRange range = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
   unsigned frame_index                = vk->context->current_swapchain_index;
   struct vk_per_frame *chain          = &vk->swapchain[frame_index];
   vk->chain                           = chain;
   vk->cmd                             = chain->cmd;
   begin_info.flags                    = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
   vkResetCommandBuffer(vk->cmd, 0);
   vkBeginCommandBuffer(vk->cmd, &begin_info);

   vulkan_image_layout_transition(vk, vk->cmd, chain->backbuffer.image,
         VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
         0, VK_ACCESS_TRANSFER_WRITE_BIT,
         VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
         VK_PIPELINE_STAGE_TRANSFER_BIT);

   vkCmdClearColorImage(vk->cmd, chain->backbuffer.image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
         &clear_color, 1, &range);

   vulkan_image_layout_transition(vk, vk->cmd, chain->backbuffer.image,
         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
         VK_ACCESS_TRANSFER_WRITE_BIT, 0,
         VK_PIPELINE_STAGE_TRANSFER_BIT,
         VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT);

   vkEndCommandBuffer(vk->cmd);

   submit_info.commandBufferCount   = 1;
   submit_info.pCommandBuffers      = &vk->cmd;
   if (vk->context->swapchain_semaphores[frame_index] != VK_NULL_HANDLE)
   {
      submit_info.signalSemaphoreCount = 1;
      submit_info.pSignalSemaphores = &vk->context->swapchain_semaphores[frame_index];
   }

#ifdef HAVE_THREADS
   slock_lock(vk->context->queue_lock);
#endif
   vkQueueSubmit(vk->context->queue, 1,
         &submit_info, vk->context->swapchain_fences[frame_index]);
#ifdef HAVE_THREADS
   slock_unlock(vk->context->queue_lock);
#endif

   video_context_driver_swap_buffers();
}

static bool vulkan_frame(void *data, const void *frame,
      unsigned frame_width, unsigned frame_height,
      uint64_t frame_count,
      unsigned pitch, const char *msg)
{
   struct vk_per_frame *chain;
   unsigned width, height;
   VkClearValue clear_value;
   vk_t *vk                                      = (vk_t*)data;
   settings_t *settings                          = config_get_ptr();
   static struct retro_perf_counter frame_run    = {0};
   static struct retro_perf_counter begin_cmd    = {0};
   static struct retro_perf_counter build_cmd    = {0};
   static struct retro_perf_counter end_cmd      = {0};
   static struct retro_perf_counter copy_frame   = {0};
   static struct retro_perf_counter swapbuffers  = {0};
   static struct retro_perf_counter queue_submit = {0};
   bool waits_for_semaphores                     = false;
   VkSemaphore signal_semaphores[2];

   VkCommandBufferBeginInfo begin_info           = { 
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
   VkRenderPassBeginInfo rp_info                 = { 
      VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO };
   VkSubmitInfo submit_info                      = { 
      VK_STRUCTURE_TYPE_SUBMIT_INFO };
   unsigned frame_index                          = 
      vk->context->current_swapchain_index;

   performance_counter_init(&frame_run, "frame_run");
   performance_counter_init(&copy_frame, "copy_frame");
   performance_counter_init(&swapbuffers, "swapbuffers");
   performance_counter_init(&queue_submit, "queue_submit");
   performance_counter_init(&begin_cmd, "begin_command");
   performance_counter_init(&build_cmd, "build_command");
   performance_counter_init(&end_cmd, "end_command");
   performance_counter_start(&frame_run);

   video_driver_get_size(&width, &height);

   /* Bookkeeping on start of frame. */
   chain     = &vk->swapchain[frame_index];
   vk->chain = chain;

   vulkan_descriptor_manager_restart(&chain->descriptor_manager);
   vulkan_buffer_chain_discard(&chain->vbo);
   vulkan_buffer_chain_discard(&chain->ubo);

   performance_counter_start(&begin_cmd);
   /* Start recording the command buffer. */
   vk->cmd          = chain->cmd;
   begin_info.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
   vkResetCommandBuffer(vk->cmd, 0);

   vkBeginCommandBuffer(vk->cmd, &begin_info);
   performance_counter_stop(&begin_cmd);

   memset(&vk->tracker, 0, sizeof(vk->tracker));

   waits_for_semaphores = vk->hw.enable && frame &&
                          !vk->hw.num_cmd && vk->hw.valid_semaphore;

   if (waits_for_semaphores &&
       vk->hw.src_queue_family != VK_QUEUE_FAMILY_IGNORED &&
       vk->hw.src_queue_family != vk->context->graphics_queue_index)
   {
      retro_assert(vk->hw.image);

      /* Acquire ownership of image from other queue family. */
      vulkan_transfer_image_ownership(vk->cmd,
            vk->hw.image->create_info.image,
            vk->hw.image->image_layout,
            /* Create a dependency chain from semaphore wait. */
            VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT |
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            vk->hw.src_queue_family, vk->context->graphics_queue_index);
   }

   /* Upload texture */
   performance_counter_start(&copy_frame);
   if (frame && !vk->hw.enable)
   {
      unsigned y;
      uint8_t *dst        = NULL;
      const uint8_t *src  = (const uint8_t*)frame;
      unsigned bpp        = vk->video.rgb32 ? 4 : 2;

      if (     chain->texture.width != frame_width 
            || chain->texture.height != frame_height)
      {
         chain->texture = vulkan_create_texture(vk, &chain->texture,
               frame_width, frame_height, chain->texture.format, NULL, NULL,
               chain->texture_optimal.memory 
               ? VULKAN_TEXTURE_STAGING : VULKAN_TEXTURE_STREAMED);

         vulkan_map_persistent_texture(
               vk->context->device, &chain->texture);

         if (chain->texture.type == VULKAN_TEXTURE_STAGING)
         {
            chain->texture_optimal = vulkan_create_texture(
                  vk,
                  &chain->texture_optimal,
                  frame_width, frame_height, chain->texture_optimal.format,
                  NULL, NULL, VULKAN_TEXTURE_DYNAMIC);
         }
      }

      if (frame != chain->texture.mapped)
      {
         dst = (uint8_t*)chain->texture.mapped;
         if (chain->texture.stride == pitch && pitch == frame_width * bpp)
            memcpy(dst, src, frame_width * frame_height * bpp);
         else
            for (y = 0; y < frame_height; y++, 
                  dst += chain->texture.stride, src += pitch)
               memcpy(dst, src, frame_width * bpp);
      }

      /* If we have an optimal texture, copy to that now. */
      if (chain->texture_optimal.memory != VK_NULL_HANDLE)
      {
         vulkan_copy_staging_to_dynamic(vk, vk->cmd,
               &chain->texture_optimal, &chain->texture);
      }
      else
         vulkan_sync_texture_to_gpu(vk, &chain->texture);

      vk->last_valid_index = frame_index;
   }
   performance_counter_stop(&copy_frame);

   /* Notify filter chain about the new sync index. */
   vulkan_filter_chain_notify_sync_index(vk->filter_chain, frame_index);
   vulkan_filter_chain_set_frame_count(vk->filter_chain, frame_count);

   performance_counter_start(&build_cmd);
   /* Render offscreen filter chain passes. */
   {
      /* Set the source texture in the filter chain */
      struct vulkan_filter_chain_texture input;

      if (vk->hw.enable)
      {
         /* Does this make that this can happen at all? */
         if (!vk->hw.image)
         {
            ELOG("[Vulkan]: HW image is not set. Buggy core?\n");
            return false;
         }

         input.image        = vk->hw.image->create_info.image;
         input.view         = vk->hw.image->image_view;
         input.layout       = vk->hw.image->image_layout;

         if (frame)
         {
            input.width     = frame_width;
            input.height    = frame_height;
         }
         else
         {
            input.width     = vk->hw.last_width;
            input.height    = vk->hw.last_height;
         }

         vk->hw.last_width  = input.width;
         vk->hw.last_height = input.height;
      }
      else
      {
         struct vk_texture *tex = &vk->swapchain[vk->last_valid_index].texture;
         if (vk->swapchain[vk->last_valid_index].texture_optimal.memory != VK_NULL_HANDLE)
            tex = &vk->swapchain[vk->last_valid_index].texture_optimal;
         else
            vulkan_transition_texture(vk, tex);

         input.image  = tex->image;
         input.view   = tex->view;
         input.layout = tex->layout;
         input.width  = tex->width;
         input.height = tex->height;
      }

      vulkan_filter_chain_set_input_texture(vk->filter_chain, &input);
   }

   vulkan_set_viewport(vk, width, height, false, true);

   vulkan_filter_chain_build_offscreen_passes(
         vk->filter_chain, vk->cmd, &vk->vk_vp);
   /* Render to backbuffer. */
   clear_value.color.float32[0]     = 0.0f;
   clear_value.color.float32[1]     = 0.0f;
   clear_value.color.float32[2]     = 0.0f;
   clear_value.color.float32[3]     = 1.0f;
   rp_info.renderPass               = vk->render_pass;
   rp_info.framebuffer              = chain->backbuffer.framebuffer;
   rp_info.renderArea.extent.width  = vk->context->swapchain_width;
   rp_info.renderArea.extent.height = vk->context->swapchain_height;
   rp_info.clearValueCount          = 1;
   rp_info.pClearValues             = &clear_value;

   /* Prepare backbuffer for rendering. We don't use WSI semaphores here. */
   vulkan_image_layout_transition(vk, vk->cmd, chain->backbuffer.image,
         VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
         0, VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_COLOR_ATTACHMENT_READ_BIT,
         VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
         VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

   /* Begin render pass and set up viewport */
   vkCmdBeginRenderPass(vk->cmd, &rp_info, VK_SUBPASS_CONTENTS_INLINE);

   vulkan_filter_chain_build_viewport_pass(vk->filter_chain, vk->cmd,
         &vk->vk_vp, vk->mvp.data);

#if defined(HAVE_MENU)
   if (vk->menu.enable)
   {
      menu_driver_ctl(RARCH_MENU_CTL_FRAME, NULL);

      if (vk->menu.textures[vk->menu.last_index].image != VK_NULL_HANDLE)
      {
         struct vk_draw_quad quad;
         struct vk_texture *optimal = &vk->menu.textures_optimal[vk->menu.last_index];
         vulkan_set_viewport(vk, width, height, vk->menu.full_screen, false);

         quad.pipeline = vk->pipelines.alpha_blend;
         quad.texture = &vk->menu.textures[vk->menu.last_index];

         if (optimal->memory != VK_NULL_HANDLE)
         {
            if (vk->menu.dirty[vk->menu.last_index])
            {
               vulkan_copy_staging_to_dynamic(vk, vk->cmd,
                     optimal,
                     quad.texture);
               vk->menu.dirty[vk->menu.last_index] = false;
            }
            quad.texture = optimal;
         }

         quad.sampler = optimal->mipmap ?
            vk->samplers.mipmap_linear : vk->samplers.linear;

         quad.mvp     = &vk->mvp_no_rot;
         quad.color.r = 1.0f;
         quad.color.g = 1.0f;
         quad.color.b = 1.0f;
         quad.color.a = vk->menu.alpha;
         vulkan_draw_quad(vk, &quad);
      }
   }
#endif

   if (msg)
      font_driver_render_msg(NULL, msg, NULL);

#ifdef HAVE_OVERLAY
   if (vk->overlay.enable)
      vulkan_render_overlay(vk);
#endif
   performance_counter_stop(&build_cmd);

   /* End the render pass. We're done rendering to backbuffer now. */
   vkCmdEndRenderPass(vk->cmd);

   /* End the filter chain frame.
    * This must happen outside a render pass.
    */
   vulkan_filter_chain_end_frame(vk->filter_chain, vk->cmd);

   if (vk->readback.pending || vk->readback.streamed)
   {
      /* We cannot safely read back from an image which 
       * has already been presented as we need to 
       * maintain the PRESENT_SRC_KHR layout.
       *
       * If we're reading back, perform the readback before presenting.
       */
      vulkan_image_layout_transition(vk,
            vk->cmd, chain->backbuffer.image,
            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            VK_ACCESS_TRANSFER_READ_BIT,
            VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,
            VK_PIPELINE_STAGE_TRANSFER_BIT);

      vulkan_readback(vk);

      /* Prepare for presentation after transfers are complete. */
      vulkan_image_layout_transition(vk, vk->cmd,
            chain->backbuffer.image,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            0,
            0,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT);

      vk->readback.pending = false;
   }
   else
   {
      /* Prepare backbuffer for presentation. */
      vulkan_image_layout_transition(vk, vk->cmd,
            chain->backbuffer.image,
            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            0,
            VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,
            VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT);
   }

   if (waits_for_semaphores &&
       vk->hw.src_queue_family != VK_QUEUE_FAMILY_IGNORED &&
       vk->hw.src_queue_family != vk->context->graphics_queue_index)
   {
      retro_assert(vk->hw.image);

      /* Release ownership of image back to other queue family. */
      vulkan_transfer_image_ownership(vk->cmd,
            vk->hw.image->create_info.image,
            vk->hw.image->image_layout,
            VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,
            VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            vk->context->graphics_queue_index, vk->hw.src_queue_family);
   }

   performance_counter_start(&end_cmd);
   vkEndCommandBuffer(vk->cmd);
   performance_counter_stop(&end_cmd);

   /* Submit command buffers to GPU. */

   if (vk->hw.num_cmd)
   {
      /* vk->hw.cmd has already been allocated for this. */
      vk->hw.cmd[vk->hw.num_cmd]     = vk->cmd;

      submit_info.commandBufferCount = vk->hw.num_cmd + 1;
      submit_info.pCommandBuffers    = vk->hw.cmd;

      vk->hw.num_cmd                 = 0;
   }
   else
   {
      submit_info.commandBufferCount = 1;
      submit_info.pCommandBuffers    = &vk->cmd;
   }

   if (waits_for_semaphores)
   {
      submit_info.waitSemaphoreCount = vk->hw.num_semaphores;
      submit_info.pWaitSemaphores    = vk->hw.semaphores;
      submit_info.pWaitDstStageMask  = vk->hw.wait_dst_stages;

      /* Consume the semaphores. */
      vk->hw.valid_semaphore = false;
   }

   submit_info.signalSemaphoreCount = 0;

   if (vk->context->swapchain_semaphores[frame_index] != VK_NULL_HANDLE)
      signal_semaphores[submit_info.signalSemaphoreCount++] = vk->context->swapchain_semaphores[frame_index];

   if (vk->hw.signal_semaphore != VK_NULL_HANDLE)
   {
      signal_semaphores[submit_info.signalSemaphoreCount++] = vk->hw.signal_semaphore;
      vk->hw.signal_semaphore = VK_NULL_HANDLE;
   }
   submit_info.pSignalSemaphores = submit_info.signalSemaphoreCount ? signal_semaphores : NULL;

   performance_counter_stop(&frame_run);

   performance_counter_start(&queue_submit);

#ifdef HAVE_THREADS
   slock_lock(vk->context->queue_lock);
#endif
   vkQueueSubmit(vk->context->queue, 1,
         &submit_info, vk->context->swapchain_fences[frame_index]);
#ifdef HAVE_THREADS
   slock_unlock(vk->context->queue_lock);
#endif
   performance_counter_stop(&queue_submit);

   performance_counter_start(&swapbuffers);
   video_context_driver_swap_buffers();
   performance_counter_stop(&swapbuffers);

   if (!vk->context->swap_interval_emulation_lock)
      video_context_driver_update_window_title();

   /* Handle spurious swapchain invalidations as soon as we can,
    * i.e. right after swap buffers. */
   if (vk->should_resize)
   {
      gfx_ctx_mode_t mode;
      mode.width  = width;
      mode.height = height;
      video_context_driver_set_resize(&mode);

      vk->should_resize = false;
   }
   vulkan_check_swapchain(vk);

   /* Disable BFI during fast forward, slow-motion,
    * and pause to prevent flicker. */
   if (
         settings->video.black_frame_insertion
         && !input_driver_is_nonblock_state()
         && !runloop_ctl(RUNLOOP_CTL_IS_SLOWMOTION, NULL)
         && !runloop_ctl(RUNLOOP_CTL_IS_PAUSED, NULL))
   {
      vulkan_inject_black_frame(vk);
   }

   /* Vulkan doesn't directly support swap_interval > 1, so we fake it by duping out more frames. */
   if (vk->context->swap_interval > 1 && !vk->context->swap_interval_emulation_lock)
   {
      unsigned i;
      vk->context->swap_interval_emulation_lock = true;
      for (i = 1; i < vk->context->swap_interval; i++)
      {
         if (!vulkan_frame(vk, NULL, 0, 0, frame_count, 0, msg))
         {
            vk->context->swap_interval_emulation_lock = false;
            return false;
         }
      }
      vk->context->swap_interval_emulation_lock = false;
   }

   return true;
}

static void vulkan_set_aspect_ratio(void *data, unsigned aspect_ratio_idx)
{
   vk_t *vk = (vk_t*)data;

   switch (aspect_ratio_idx)
   {
      case ASPECT_RATIO_SQUARE:
         video_driver_set_viewport_square_pixel();
         break;

      case ASPECT_RATIO_CORE:
         video_driver_set_viewport_core();
         break;

      case ASPECT_RATIO_CONFIG:
         video_driver_set_viewport_config();
         break;

      default:
         break;
   }

   video_driver_set_aspect_ratio_value(
         aspectratio_lut[aspect_ratio_idx].value);

   if (!vk)
      return;

   vk->keep_aspect = true;
   vk->should_resize = true;
}

static void vulkan_apply_state_changes(void *data)
{
   vk_t *vk = (vk_t*)data;
   if (vk)
      vk->should_resize = true;
}

static void vulkan_show_mouse(void *data, bool state)
{
   (void)data;
   video_context_driver_show_mouse(&state);
}

static struct video_shader *vulkan_get_current_shader(void *data)
{
   vk_t *vk = (vk_t*)data;
   if (!vk || !vk->filter_chain)
      return NULL;

   return vulkan_filter_chain_get_preset(vk->filter_chain);
}

static bool vulkan_get_current_sw_framebuffer(void *data,
      struct retro_framebuffer *framebuffer)
{
   struct vk_per_frame *chain = NULL;
   vk_t *vk                   = (vk_t*)data;
   vk->chain                  = 
      &vk->swapchain[vk->context->current_swapchain_index];
   chain                      = vk->chain;

   if (chain->texture.width != framebuffer->width ||
         chain->texture.height != framebuffer->height)
   {
      chain->texture   = vulkan_create_texture(vk, &chain->texture,
            framebuffer->width, framebuffer->height, chain->texture.format,
            NULL, NULL, VULKAN_TEXTURE_STREAMED);
      vulkan_map_persistent_texture(
            vk->context->device, &chain->texture);

      if (chain->texture.type == VULKAN_TEXTURE_STAGING)
      {
         chain->texture_optimal = vulkan_create_texture(
               vk,
               &chain->texture_optimal,
               framebuffer->width,
               framebuffer->height,
               chain->texture_optimal.format,
               NULL, NULL, VULKAN_TEXTURE_DYNAMIC);
      }
   }

   framebuffer->data         = chain->texture.mapped;
   framebuffer->pitch        = chain->texture.stride;
   framebuffer->format       = vk->video.rgb32 
      ? RETRO_PIXEL_FORMAT_XRGB8888 : RETRO_PIXEL_FORMAT_RGB565;
   framebuffer->memory_flags = 0;

   if (vk->context->memory_properties.memoryTypes[
         chain->texture.memory_type].propertyFlags &
         VK_MEMORY_PROPERTY_HOST_CACHED_BIT)
      framebuffer->memory_flags |= RETRO_MEMORY_TYPE_CACHED;

   return true;
}

static bool vulkan_get_hw_render_interface(void *data,
      const struct retro_hw_render_interface **iface)
{
   vk_t *vk = (vk_t*)data;
   *iface   = (const struct retro_hw_render_interface*)&vk->hw.iface;
   return vk->hw.enable;
}

#if defined(HAVE_MENU)
static void vulkan_set_texture_frame(void *data,
      const void *frame, bool rgb32, unsigned width, unsigned height,
      float alpha)
{
   unsigned y, stride;
   uint8_t *ptr                       = NULL;
   uint8_t *dst                       = NULL;
   const uint8_t *src                 = NULL;
   vk_t *vk                           = (vk_t*)data;
   unsigned index                     = vk->context->current_swapchain_index;
   struct vk_texture *texture         = &vk->menu.textures[index];
   struct vk_texture *texture_optimal = &vk->menu.textures_optimal[index];
   const VkComponentMapping br_swizzle = {
      VK_COMPONENT_SWIZZLE_B,
      VK_COMPONENT_SWIZZLE_G,
      VK_COMPONENT_SWIZZLE_R,
      VK_COMPONENT_SWIZZLE_A,
   };

   if (!vk)
      return;

   /* B4G4R4A4 must be supported, but R4G4B4A4 is optional,
    * just apply the swizzle in the image view instead. */
   *texture = vulkan_create_texture(vk,
         texture->memory ? texture : NULL,
         width, height,
         rgb32 ? VK_FORMAT_B8G8R8A8_UNORM : VK_FORMAT_B4G4R4A4_UNORM_PACK16,
         NULL, rgb32 ? NULL : &br_swizzle,
         texture_optimal->memory ? VULKAN_TEXTURE_STAGING : VULKAN_TEXTURE_STREAMED);

   vkMapMemory(vk->context->device, texture->memory,
         texture->offset, texture->size, 0, (void**)&ptr);

   dst       = ptr;
   src       = (const uint8_t*)frame;
   stride    = (rgb32 ? sizeof(uint32_t) : sizeof(uint16_t)) * width;

   for (y = 0; y < height; y++, dst += texture->stride, src += stride)
      memcpy(dst, src, stride);

   vulkan_sync_texture_to_gpu(vk, texture);
   vkUnmapMemory(vk->context->device, texture->memory);

   vk->menu.alpha      = alpha;
   vk->menu.last_index = index;

   if (texture->type == VULKAN_TEXTURE_STAGING)
   {
      *texture_optimal = vulkan_create_texture(vk,
            texture_optimal->memory ? texture_optimal : NULL,
            width, height,
            rgb32 ? VK_FORMAT_B8G8R8A8_UNORM : VK_FORMAT_B4G4R4A4_UNORM_PACK16,
            NULL, rgb32 ? NULL : &br_swizzle,
            VULKAN_TEXTURE_DYNAMIC);
   }

   vk->menu.dirty[index] = true;
}

static void vulkan_set_texture_enable(void *data, bool state, bool full_screen)
{
   vk_t *vk = (vk_t*)data;
   if (!vk)
      return;

   vk->menu.enable = state;
   vk->menu.full_screen = full_screen;
}

static void vulkan_set_osd_msg(void *data, const char *msg,
      const struct font_params *params, void *font)
{
   (void)data;
   font_driver_render_msg(font, msg, params);
}
#endif

static uintptr_t vulkan_load_texture(void *video_data, void *data,
      bool threaded, enum texture_filter_type filter_type)
{
   vk_t *vk                    = (vk_t*)video_data;
   struct texture_image *image = (struct texture_image*)data;
   struct vk_texture *texture = (struct vk_texture*)calloc(1, sizeof(*texture));
   if (!texture)
      return 0;

   *texture = vulkan_create_texture(vk, NULL,
         image->width, image->height, VK_FORMAT_B8G8R8A8_UNORM,
         image->pixels, NULL, VULKAN_TEXTURE_STATIC);

   texture->default_smooth =
      filter_type == TEXTURE_FILTER_MIPMAP_LINEAR || filter_type == TEXTURE_FILTER_LINEAR;
   texture->mipmap = filter_type == TEXTURE_FILTER_MIPMAP_LINEAR;

   return (uintptr_t)texture;
}

static void vulkan_unload_texture(void *data, uintptr_t handle)
{
   vk_t *vk                         = (vk_t*)data;
   struct vk_texture *texture       = (struct vk_texture*)handle;
   if (!texture)
      return;

   /* TODO: We really want to defer this deletion instead,
    * but this will do for now. */
   vkQueueWaitIdle(vk->context->queue);
   vulkan_destroy_texture(
         vk->context->device, texture);
   free(texture);
}

static const video_poke_interface_t vulkan_poke_interface = {
   vulkan_load_texture,
   vulkan_unload_texture,
   vulkan_set_video_mode,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   vulkan_set_aspect_ratio,
   vulkan_apply_state_changes,
#if defined(HAVE_MENU)
   vulkan_set_texture_frame,
   vulkan_set_texture_enable,
#else
   NULL,
   NULL,
#endif
#ifdef HAVE_MENU
   vulkan_set_osd_msg,
#endif
   vulkan_show_mouse,
   NULL,
   vulkan_get_current_shader,
   vulkan_get_current_sw_framebuffer,
   vulkan_get_hw_render_interface,
};

static void vulkan_get_poke_interface(void *data,
      const video_poke_interface_t **iface)
{
   (void)data;
   *iface = &vulkan_poke_interface;
}

static void vulkan_viewport_info(void *data, struct video_viewport *vp)
{
   unsigned width, height;
   vk_t *vk = (vk_t*)data;

   video_driver_get_size(&width, &height);

   /* Make sure we get the correct viewport. */
   vulkan_set_viewport(vk, width, height, false, true);

   *vp             = vk->vp;
   vp->full_width  = width;
   vp->full_height = height;
}

static bool vulkan_read_viewport(void *data, uint8_t *buffer)
{
   struct vk_texture *staging       = NULL;
   vk_t *vk                         = (vk_t*)data;

   if (!vk)
      return false;

   staging = &vk->readback.staging[vk->context->current_swapchain_index];

   if (vk->readback.streamed)
   {
      const uint8_t *src;
      static struct retro_perf_counter stream_readback = {0};

      if (staging->memory == VK_NULL_HANDLE)
         return false;

      performance_counter_init(&stream_readback, "stream_readback");
      performance_counter_start(&stream_readback);

      buffer += 3 * (vk->vp.height - 1) * vk->vp.width;
      vkMapMemory(vk->context->device, staging->memory,
            staging->offset, staging->size, 0, (void**)&src);

      vulkan_sync_texture_to_cpu(vk, staging);

      vk->readback.scaler.in_stride  = staging->stride;
      vk->readback.scaler.out_stride = -(int)vk->vp.width * 3;
      scaler_ctx_scale(&vk->readback.scaler, buffer, src);

      vkUnmapMemory(vk->context->device, staging->memory);

      performance_counter_stop(&stream_readback);
   }
   else
   {
      /* Synchronous path only for now. */
      /* TODO: How will we deal with format conversion?
       * For now, take the simplest route and use image blitting
       * with conversion. */

      vk->readback.pending = true;
      video_driver_cached_frame_render();
      vkQueueWaitIdle(vk->context->queue);

      if (!staging->mapped)
         vulkan_map_persistent_texture(
               vk->context->device, staging);

      vulkan_sync_texture_to_cpu(vk, staging);

      {
         unsigned x, y;
         const uint8_t *src  = (const uint8_t*)staging->mapped;
         buffer             += 3 * (vk->vp.height - 1) 
            * vk->vp.width;

         for (y = 0; y < vk->vp.height; y++,
               src += staging->stride, buffer -= 3 * vk->vp.width)
         {
            for (x = 0; x < vk->vp.width; x++)
            {
               buffer[3 * x + 0] = src[4 * x + 0];
               buffer[3 * x + 1] = src[4 * x + 1];
               buffer[3 * x + 2] = src[4 * x + 2];
            }
         }
      }
      vulkan_destroy_texture(
            vk->context->device, staging);
   }
   return true;
}

#ifdef HAVE_OVERLAY
static void vulkan_overlay_enable(void *data, bool enable)
{
   vk_t *vk = (vk_t*)data;
   if (!vk)
      return;

   vk->overlay.enable = enable;
   if (vk->fullscreen)
      video_context_driver_show_mouse(&enable);
}

static void vulkan_overlay_full_screen(void *data, bool enable)
{
   vk_t *vk = (vk_t*)data;
   if (!vk)
      return;

   vk->overlay.full_screen = enable;
}

static void vulkan_overlay_free(vk_t *vk)
{
   unsigned i;
   if (!vk)
      return;

   free(vk->overlay.vertex);
   for (i = 0; i < vk->overlay.count; i++)
      if (vk->overlay.images[i].memory != VK_NULL_HANDLE)
         vulkan_destroy_texture(
               vk->context->device,
               &vk->overlay.images[i]);

   memset(&vk->overlay, 0, sizeof(vk->overlay));
}

static void vulkan_overlay_set_alpha(void *data,
      unsigned image, float mod)
{
   unsigned i;
   struct vk_vertex *pv;
   vk_t *vk = (vk_t*)data;

   if (!vk)
      return;

   pv = &vk->overlay.vertex[image * 4];
   for (i = 0; i < 4; i++)
   {
      pv[i].color.r = 1.0f;
      pv[i].color.g = 1.0f;
      pv[i].color.b = 1.0f;
      pv[i].color.a = mod;
   }
}

static void vulkan_render_overlay(vk_t *vk)
{
   unsigned width, height;
   unsigned i;
   struct video_viewport vp;

   if (!vk)
      return;

   video_driver_get_size(&width, &height);
   vp = vk->vp;
   vulkan_set_viewport(vk, width, height, vk->overlay.full_screen, false);

   for (i = 0; i < vk->overlay.count; i++)
   {
      struct vk_draw_triangles call;
      struct vk_buffer_range range;
      if (!vulkan_buffer_chain_alloc(vk->context, &vk->chain->vbo,
               4 * sizeof(struct vk_vertex), &range))
         break;

      memcpy(range.data, &vk->overlay.vertex[i * 4],
            4 * sizeof(struct vk_vertex));

      memset(&call, 0, sizeof(call));
      call.pipeline     = vk->display.pipelines[3]; /* Strip with blend */
      call.texture      = &vk->overlay.images[i];
      call.sampler      = call.texture->mipmap ?
         vk->samplers.mipmap_linear : vk->samplers.linear;
      call.uniform      = &vk->mvp;
      call.uniform_size = sizeof(vk->mvp);
      call.vbo          = &range;
      call.vertices     = 4;
      vulkan_draw_triangles(vk, &call);
   }

   /* Restore the viewport so we don't mess with recording. */
   vk->vp = vp;
}

static void vulkan_overlay_vertex_geom(void *data, unsigned image,
      float x, float y,
      float w, float h)
{
   struct vk_vertex *pv = NULL;
   vk_t             *vk = (vk_t*)data;
   if (!vk)
      return;

   pv      = &vk->overlay.vertex[4 * image];

   pv[0].x = x;
   pv[0].y = y;
   pv[1].x = x;
   pv[1].y = y + h;
   pv[2].x = x + w;
   pv[2].y = y;
   pv[3].x = x + w;
   pv[3].y = y + h;
}

static void vulkan_overlay_tex_geom(void *data, unsigned image,
      float x, float y,
      float w, float h)
{
   struct vk_vertex *pv = NULL;
   vk_t *vk             = (vk_t*)data;
   if (!vk)
      return;

   pv          = &vk->overlay.vertex[4 * image];

   pv[0].tex_x = x;
   pv[0].tex_y = y;
   pv[1].tex_x = x;
   pv[1].tex_y = y + h;
   pv[2].tex_x = x + w;
   pv[2].tex_y = y;
   pv[3].tex_x = x + w;
   pv[3].tex_y = y + h;
}

static bool vulkan_overlay_load(void *data,
      const void *image_data, unsigned num_images)
{
   unsigned i, j;
   const struct texture_image *images = 
      (const struct texture_image*)image_data;
   vk_t *vk                           = (vk_t*)data;
   static const struct vk_color white = {
      1.0f, 1.0f, 1.0f, 1.0f,
   };

   if (!vk)
      return false;

#ifdef HAVE_THREADS
   slock_lock(vk->context->queue_lock);
#endif
   vkQueueWaitIdle(vk->context->queue);
#ifdef HAVE_THREADS
   slock_unlock(vk->context->queue_lock);
#endif
   vulkan_overlay_free(vk);

   vk->overlay.images = (struct vk_texture*)
      calloc(num_images, sizeof(*vk->overlay.images));

   if (!vk->overlay.images)
      goto error;
   vk->overlay.count  = num_images;

   vk->overlay.vertex = (struct vk_vertex*)
      calloc(4 * num_images, sizeof(*vk->overlay.vertex));
   if (!vk->overlay.vertex)
      goto error;

   for (i = 0; i < num_images; i++)
   {
      vk->overlay.images[i] = vulkan_create_texture(vk, NULL,
            images[i].width, images[i].height,
            VK_FORMAT_B8G8R8A8_UNORM, images[i].pixels,
            NULL, VULKAN_TEXTURE_STATIC);

      vulkan_overlay_tex_geom(vk, i, 0, 0, 1, 1);
      vulkan_overlay_vertex_geom(vk, i, 0, 0, 1, 1);
      for (j = 0; j < 4; j++)
         vk->overlay.vertex[4 * i + j].color = white;
   }

   return true;

error:
   vulkan_overlay_free(vk);
   return false;
}

static const video_overlay_interface_t vulkan_overlay_interface = {
   vulkan_overlay_enable,
   vulkan_overlay_load,
   vulkan_overlay_tex_geom,
   vulkan_overlay_vertex_geom,
   vulkan_overlay_full_screen,
   vulkan_overlay_set_alpha,
};

static void vulkan_get_overlay_interface(void *data,
      const video_overlay_interface_t **iface)
{
   (void)data;
   *iface = &vulkan_overlay_interface;
}
#endif

video_driver_t video_vulkan = {
   vulkan_init,
   vulkan_frame,
   vulkan_set_nonblock_state,
   vulkan_alive,
   vulkan_focus,
   vulkan_suppress_screensaver,
   vulkan_has_windowed,
   vulkan_set_shader,
   vulkan_free,
   "vulkan",
   vulkan_set_viewport,
   vulkan_set_rotation,
   vulkan_viewport_info,
   vulkan_read_viewport,
   NULL,                           /* vulkan_read_frame_raw */

#ifdef HAVE_OVERLAY
   vulkan_get_overlay_interface,
#else
   NULL,
#endif
   vulkan_get_poke_interface,
   NULL,                           /* vulkan_wrap_type_to_enum */
};

