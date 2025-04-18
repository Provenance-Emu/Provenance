// Copyright 2023 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes:
// In DrawInternal add checking of params.binding_count == 2 to draw

#include "common/alignment.h"
#include "common/logging/log.h"
#include "common/math_util.h"
#include "common/microprofile.h"
#include "common/settings.h"

#if defined(__ARM_NEON) && defined(__aarch64__)
#include <arm_neon.h>
#endif
#include "video_core/pica_state.h"
#include "video_core/regs_framebuffer.h"
#include "video_core/regs_pipeline.h"
#include "video_core/regs_rasterizer.h"
#include "video_core/renderer_vulkan/renderer_vulkan.h"
#include "video_core/renderer_vulkan/vk_instance.h"
#include "video_core/renderer_vulkan/vk_rasterizer.h"
#include "video_core/renderer_vulkan/vk_scheduler.h"
#include "video_core/texture/texture_decode.h"

namespace Vulkan {

namespace {

MICROPROFILE_DEFINE(Vulkan_VS, "Vulkan", "Vertex Shader Setup", MP_RGB(192, 128, 128));
MICROPROFILE_DEFINE(Vulkan_GS, "Vulkan", "Geometry Shader Setup", MP_RGB(128, 192, 128));
MICROPROFILE_DEFINE(Vulkan_Drawing, "Vulkan", "Drawing", MP_RGB(128, 128, 192));

using TriangleTopology = Pica::PipelineRegs::TriangleTopology;
using VideoCore::SurfaceType;

constexpr u64 STREAM_BUFFER_SIZE = 128 * 1024 * 1024;
constexpr u64 UNIFORM_BUFFER_SIZE = 8 * 1024 * 1024;
constexpr u64 TEXTURE_BUFFER_SIZE = 4 * 1024 * 1024;

constexpr vk::BufferUsageFlags BUFFER_USAGE =
    vk::BufferUsageFlagBits::eVertexBuffer | vk::BufferUsageFlagBits::eIndexBuffer;

struct DrawParams {
    u32 vertex_count;
    s32 vertex_offset;
    u32 binding_count;
    std::array<u32, 16> bindings;
    bool is_indexed;
};

[[nodiscard]] u64 TextureBufferSize(const Instance& instance) {
    // Use the smallest texel size from the texel views
    // which corresponds to eR32G32Sfloat
    const u64 max_size = instance.MaxTexelBufferElements() * 8;
    return std::min(max_size, TEXTURE_BUFFER_SIZE);
}

} // Anonymous namespace

RasterizerVulkan::RasterizerVulkan(Memory::MemorySystem& memory,
                                   VideoCore::CustomTexManager& custom_tex_manager,
                                   VideoCore::RendererBase& renderer,
                                   Frontend::EmuWindow& emu_window, const Instance& instance,
                                   Scheduler& scheduler, DescriptorManager& desc_manager,
                                   TextureRuntime& runtime, RenderpassCache& renderpass_cache)
    : RasterizerAccelerated{memory}, instance{instance}, scheduler{scheduler}, runtime{runtime},
      renderpass_cache{renderpass_cache}, desc_manager{desc_manager}, res_cache{memory,
                                                                                custom_tex_manager,
                                                                                runtime, regs,
                                                                                renderer},
      pipeline_cache{instance, scheduler, renderpass_cache, desc_manager},
      stream_buffer{instance, scheduler, BUFFER_USAGE, STREAM_BUFFER_SIZE},
      uniform_buffer{instance, scheduler, vk::BufferUsageFlagBits::eUniformBuffer,
                     UNIFORM_BUFFER_SIZE},
      texture_buffer{instance, scheduler, vk::BufferUsageFlagBits::eUniformTexelBuffer,
                     TextureBufferSize(instance)},
      texture_lf_buffer{instance, scheduler, vk::BufferUsageFlagBits::eUniformTexelBuffer,
                        TextureBufferSize(instance)},
      async_shaders{Settings::values.async_shader_compilation.GetValue()} {

    vertex_buffers.fill(stream_buffer.Handle());

    uniform_buffer_alignment = instance.UniformMinAlignment();
    uniform_size_aligned_vs =
        Common::AlignUp(sizeof(Pica::Shader::VSUniformData), uniform_buffer_alignment);
    uniform_size_aligned_fs =
        Common::AlignUp(sizeof(Pica::Shader::UniformData), uniform_buffer_alignment);

    // Define vertex layout for software shaders
    MakeSoftwareVertexLayout();
    pipeline_info.vertex_layout = software_layout;

    const vk::Device device = instance.GetDevice();
    texture_lf_view = device.createBufferView({
        .buffer = texture_lf_buffer.Handle(),
        .format = vk::Format::eR32G32Sfloat,
        .offset = 0,
        .range = VK_WHOLE_SIZE,
    });
    texture_rg_view = device.createBufferView({
        .buffer = texture_buffer.Handle(),
        .format = vk::Format::eR32G32Sfloat,
        .offset = 0,
        .range = VK_WHOLE_SIZE,
    });
    texture_rgba_view = device.createBufferView({
        .buffer = texture_buffer.Handle(),
        .format = vk::Format::eR32G32B32A32Sfloat,
        .offset = 0,
        .range = VK_WHOLE_SIZE,
    });

    // Since we don't have access to VK_EXT_descriptor_indexing we need to intiallize
    // all descriptor sets even the ones we don't use.
    pipeline_cache.BindBuffer(0, uniform_buffer.Handle(), 0, sizeof(Pica::Shader::VSUniformData));
    pipeline_cache.BindBuffer(1, uniform_buffer.Handle(), 0, sizeof(Pica::Shader::UniformData));
    pipeline_cache.BindTexelBuffer(2, texture_lf_view);
    pipeline_cache.BindTexelBuffer(3, texture_rg_view);
    pipeline_cache.BindTexelBuffer(4, texture_rgba_view);

    Surface& null_surface = res_cache.GetSurface(VideoCore::NULL_SURFACE_ID);
    Sampler& null_sampler = res_cache.GetSampler(VideoCore::NULL_SAMPLER_ID);
    for (u32 i = 0; i < 4; i++) {
        pipeline_cache.BindTexture(i, null_surface.ImageView(), null_sampler.Handle());
    }

    for (u32 i = 0; i < 7; i++) {
        pipeline_cache.BindStorageImage(i, null_surface.StorageView());
    }

    SyncEntireState();
}

RasterizerVulkan::~RasterizerVulkan() {
    const vk::Device device = instance.GetDevice();
    device.destroyBufferView(texture_lf_view);
    device.destroyBufferView(texture_rg_view);
    device.destroyBufferView(texture_rgba_view);
}

void RasterizerVulkan::TickFrame() {
    res_cache.TickFrame();
}

void RasterizerVulkan::LoadDiskResources(const std::atomic_bool& stop_loading,
                                         const VideoCore::DiskResourceLoadCallback& callback) {
    pipeline_cache.LoadDiskCache();
}

void RasterizerVulkan::SyncFixedState() {
    SyncClipEnabled();
    SyncCullMode();
    SyncBlendEnabled();
    SyncBlendFuncs();
    SyncBlendColor();
    SyncLogicOp();
    SyncStencilTest();
    SyncDepthTest();
    SyncColorWriteMask();
    SyncStencilWriteMask();
    SyncDepthWriteMask();
}

void RasterizerVulkan::SetupVertexArray() {
    const auto [vs_input_index_min, vs_input_index_max, vs_input_size] = vertex_info;
    auto [array_ptr, array_offset, invalidate] = stream_buffer.Map(vs_input_size, 16);

    /**
     * The Nintendo 3DS has 12 attribute loaders which are used to tell the GPU
     * how to interpret vertex data. The program firsts sets GPUREG_ATTR_BUF_BASE to the base
     * address containing the vertex array data. The data for each attribute loader (i) can be found
     * by adding GPUREG_ATTR_BUFi_OFFSET to the base address. Attribute loaders can be thought
     * as something analogous to Vulkan bindings. The user can store attributes in separate loaders
     * or interleave them in the same loader.
     **/
    const auto& vertex_attributes = regs.pipeline.vertex_attributes;
    PAddr base_address = vertex_attributes.GetPhysicalBaseAddress(); // GPUREG_ATTR_BUF_BASE

    const u32 stride_alignment = instance.GetMinVertexStrideAlignment();

    VertexLayout& layout = pipeline_info.vertex_layout;
    layout.attribute_count = 0;
    layout.binding_count = 0;
    enable_attributes.fill(false);

    u32 buffer_offset = 0;
    for (const auto& loader : vertex_attributes.attribute_loaders) {
        if (loader.component_count == 0 || loader.byte_count == 0) {
            continue;
        }

        // Analyze the attribute loader by checking which attributes it provides
        u32 offset = 0;
        for (u32 comp = 0; comp < loader.component_count && comp < 12; comp++) {
            u32 attribute_index = loader.GetComponent(comp);
            if (attribute_index < 12) {
                if (u32 size = vertex_attributes.GetNumElements(attribute_index); size != 0) {
                    offset = Common::AlignUp(
                        offset, vertex_attributes.GetElementSizeInBytes(attribute_index));

                    const u32 input_reg = regs.vs.GetRegisterForAttribute(attribute_index);
                    const Pica::PipelineRegs::VertexAttributeFormat format =
                        vertex_attributes.GetFormat(attribute_index);

                    VertexAttribute& attribute = layout.attributes[layout.attribute_count++];
                    attribute.binding.Assign(layout.binding_count);
                    attribute.location.Assign(input_reg);
                    attribute.offset.Assign(offset);
                    attribute.type.Assign(format);
                    attribute.size.Assign(size);

                    enable_attributes[input_reg] = true;
                    offset += vertex_attributes.GetStride(attribute_index);
                }
            } else {
                // Attribute ids 12, 13, 14 and 15 signify 4, 8, 12 and 16-byte paddings
                // respectively
                offset = Common::AlignUp(offset, 4);
                offset += (attribute_index - 11) * 4;
            }
        }

        const PAddr data_addr =
            base_address + loader.data_offset + (vs_input_index_min * loader.byte_count);
        const u32 vertex_num = vs_input_index_max - vs_input_index_min + 1;
        u32 data_size = loader.byte_count * vertex_num;
        res_cache.FlushRegion(data_addr, data_size);

        const MemoryRef src_ref = memory.GetPhysicalRef(data_addr);
        if (src_ref.GetSize() < data_size) {
            LOG_ERROR(Render_Vulkan,
                      "Vertex buffer size {} exceeds available space {} at address {:#016X}",
                      data_size, src_ref.GetSize(), data_addr);
        }

        const u8* src_ptr = src_ref.GetPtr();
        u8* dst_ptr = array_ptr + buffer_offset;

        // Align stride up if required by Vulkan implementation.
        const u32 aligned_stride =
            Common::AlignUp(static_cast<u32>(loader.byte_count), stride_alignment);
        if (aligned_stride == loader.byte_count) {
            std::memcpy(dst_ptr, src_ptr, data_size);
        } else {
            for (size_t vertex = 0; vertex < vertex_num; vertex++) {
                std::memcpy(dst_ptr + vertex * aligned_stride, src_ptr + vertex * loader.byte_count,
                            loader.byte_count);
            }
        }

        // Create the binding associated with this loader
        VertexBinding& binding = layout.bindings[layout.binding_count];
        binding.binding.Assign(layout.binding_count);
        binding.fixed.Assign(0);
        binding.stride.Assign(aligned_stride);

        // Keep track of the binding offsets so we can bind the vertex buffer later
        binding_offsets[layout.binding_count++] = array_offset + buffer_offset;
        buffer_offset += Common::AlignUp(aligned_stride * vertex_num, 4);
    }

    stream_buffer.Commit(buffer_offset);

    // Assign the rest of the attributes to the last binding
    SetupFixedAttribs();
}

void RasterizerVulkan::SetupFixedAttribs() {
    const auto& vertex_attributes = regs.pipeline.vertex_attributes;
    VertexLayout& layout = pipeline_info.vertex_layout;

    auto [fixed_ptr, fixed_offset, _] = stream_buffer.Map(16 * sizeof(Common::Vec4f), 0);
    binding_offsets[layout.binding_count] = fixed_offset;

    // Reserve the last binding for fixed and default attributes
    // Place the default attrib at offset zero for easy access
    static const Common::Vec4f default_attrib{0.f, 0.f, 0.f, 1.f};
    std::memcpy(fixed_ptr, default_attrib.AsArray(), sizeof(Common::Vec4f));

    // Find all fixed attributes and assign them to the last binding
    u32 offset = sizeof(Common::Vec4f);
    for (std::size_t i = 0; i < 16; i++) {
        if (vertex_attributes.IsDefaultAttribute(i)) {
            const u32 reg = regs.vs.GetRegisterForAttribute(i);
            if (!enable_attributes[reg]) {
                const auto& attr = Pica::g_state.input_default_attributes.attr[i];
                const std::array data = {attr.x.ToFloat32(), attr.y.ToFloat32(), attr.z.ToFloat32(),
                                         attr.w.ToFloat32()};

                const u32 data_size = sizeof(float) * static_cast<u32>(data.size());
                std::memcpy(fixed_ptr + offset, data.data(), data_size);

                VertexAttribute& attribute = layout.attributes[layout.attribute_count++];
                attribute.binding.Assign(layout.binding_count);
                attribute.location.Assign(reg);
                attribute.offset.Assign(offset);
                attribute.type.Assign(Pica::PipelineRegs::VertexAttributeFormat::FLOAT);
                attribute.size.Assign(4);

                offset += data_size;
                enable_attributes[reg] = true;
            }
        }
    }

    // Loop one more time to find unused attributes and assign them to the default one
    // If the attribute is just disabled, shove the default attribute to avoid
    // errors if the shader ever decides to use it.
    for (u32 i = 0; i < 16; i++) {
        if (!enable_attributes[i]) {
            VertexAttribute& attribute = layout.attributes[layout.attribute_count++];
            attribute.binding.Assign(layout.binding_count);
            attribute.location.Assign(i);
            attribute.offset.Assign(0);
            attribute.type.Assign(Pica::PipelineRegs::VertexAttributeFormat::FLOAT);
            attribute.size.Assign(4);
        }
    }

    // Define the fixed+default binding
    VertexBinding& binding = layout.bindings[layout.binding_count];
    binding.binding.Assign(layout.binding_count++);
    binding.fixed.Assign(1);
    binding.stride.Assign(offset);

    stream_buffer.Commit(offset);
}

bool RasterizerVulkan::SetupVertexShader() {
    MICROPROFILE_SCOPE(Vulkan_VS);
    return pipeline_cache.UseProgrammableVertexShader(regs, Pica::g_state.vs,
                                                      pipeline_info.vertex_layout);
}

bool RasterizerVulkan::SetupGeometryShader() {
    MICROPROFILE_SCOPE(Vulkan_GS);

    if (regs.pipeline.use_gs != Pica::PipelineRegs::UseGS::No) {
        LOG_ERROR(Render_Vulkan, "Accelerate draw doesn't support geometry shader");
        return false;
    }

    return pipeline_cache.UseFixedGeometryShader(regs);
}

bool RasterizerVulkan::AccelerateDrawBatch(bool is_indexed) {
    if (regs.pipeline.use_gs != Pica::PipelineRegs::UseGS::No) {
        if (regs.pipeline.gs_config.mode != Pica::PipelineRegs::GSMode::Point) {
            return false;
        }
        if (regs.pipeline.triangle_topology != Pica::PipelineRegs::TriangleTopology::Shader) {
            return false;
        }
    }

    pipeline_info.rasterization.topology.Assign(regs.pipeline.triangle_topology);
    if (regs.pipeline.triangle_topology == TriangleTopology::Fan &&
        !instance.IsTriangleFanSupported()) {
        LOG_DEBUG(Render_Vulkan,
                  "Skipping accelerated draw with unsupported triangle fan topology");
        return false;
    }

    // Vertex data setup might involve scheduler flushes so perform it
    // early to avoid invalidating our state in the middle of the draw.
    vertex_info = AnalyzeVertexArray(is_indexed, instance.GetMinVertexStrideAlignment());
    SetupVertexArray();

    if (!SetupVertexShader()) {
        return false;
    }
    if (!SetupGeometryShader()) {
        return false;
    }

    return Draw(true, is_indexed);
}

bool RasterizerVulkan::AccelerateDrawBatchInternal(bool is_indexed) {
    if (is_indexed) {
        SetupIndexArray();
    }

    // Get the current shader mode
    const u32 shader_mode = Settings::values.shader_type.GetValue();

    // Smart async shader handling that works for all modes
    bool wait_for_pipeline = !async_shaders;

    // For bottom screen rendering or critical draw operations in hardware modes,
    // we need to ensure shaders are ready to prevent blank/grey screens
    if (shader_mode >= 2) {
        // Check if this is likely a bottom screen draw call
        const bool is_likely_bottom_screen =
            // If we're rendering to a framebuffer, it's likely important
            regs.framebuffer.output_merger.depth_test_enable ||
            regs.framebuffer.output_merger.depth_write_enable ||
            // Check if we're using textures, common in bottom screen rendering
            (regs.texturing.texture0.type != Pica::TexturingRegs::TextureConfig::TextureType::Disabled ||
             regs.texturing.texture1.type != Pica::TexturingRegs::TextureConfig::TextureType::Disabled);

        // For critical operations, wait for pipeline to be ready
        // This ensures bottom screen renders correctly while maintaining async benefits elsewhere
        if (is_likely_bottom_screen) {
            wait_for_pipeline = true;
        }
    }

    // Try to bind the pipeline
    if (!pipeline_cache.BindPipeline(pipeline_info, wait_for_pipeline)) {
        // If we're in a hardware mode and failed to bind, we'll try a fallback approach
        if (shader_mode >= 2 && async_shaders) {
            // For hardware modes, use a simplified pipeline for temporary rendering
            // until the actual pipeline is ready
            static PipelineInfo fallback_pipeline = pipeline_info;
            fallback_pipeline.blending.blend_enable = true;
            fallback_pipeline.depth_stencil.depth_test_enable.Assign(true);

            // Try to bind a simpler fallback pipeline that might be ready
            if (!pipeline_cache.BindPipeline(fallback_pipeline, false)) {
                // If even the fallback fails, skip this draw call
                return true;
            }
            // Fallback pipeline bound successfully, continue with rendering
        } else {
            // For software mode or if not using async shaders, skip the draw call
            return true;
        }
    }

    DrawParams params = {
        .vertex_count = regs.pipeline.num_vertices,
        .vertex_offset = -static_cast<s32>(vertex_info.vs_input_index_min),
        .binding_count = pipeline_info.vertex_layout.binding_count,
        .bindings = binding_offsets,
        .is_indexed = is_indexed,
    };

    // Special handling for hardware full renderer (shader_type=3)
    // Ensure binding count is always even to prevent texture loading issues
    if (Settings::values.shader_type.GetValue() == 4 && params.binding_count % 2 != 0) {
        // Add a dummy binding to make the count even
        params.binding_count += 1;
    }
    if (Settings::values.shader_type.GetValue() == 2 || Settings::values.shader_type.GetValue() == 3 || Settings::values.shader_type.GetValue() == 4 || params.binding_count % 2 == 0) {
        scheduler.Record([this, params](vk::CommandBuffer cmdbuf) {
            std::array<u64, 16> offsets;
            std::copy(params.bindings.begin(), params.bindings.end(), offsets.begin());

            cmdbuf.bindVertexBuffers(0, params.binding_count, vertex_buffers.data(), offsets.data());
            if (params.is_indexed) {
                cmdbuf.drawIndexed(params.vertex_count, 1, 0, params.vertex_offset, 0);
            } else {
                cmdbuf.draw(params.vertex_count, 1, 0, 0);
            }
        });
    }

    return true;
}

void RasterizerVulkan::SetupIndexArray() {
    const bool index_u8 = regs.pipeline.index_array.format == 0;
    const bool native_u8 = index_u8 && instance.IsIndexTypeUint8Supported();
    const u32 index_buffer_size = regs.pipeline.num_vertices * (native_u8 ? 1 : 2);
    const vk::IndexType index_type = native_u8 ? vk::IndexType::eUint8EXT : vk::IndexType::eUint16;

    const u8* index_data =
        memory.GetPhysicalPointer(regs.pipeline.vertex_attributes.GetPhysicalBaseAddress() +
                                  regs.pipeline.index_array.offset);

    auto [index_ptr, index_offset, _] = stream_buffer.Map(index_buffer_size, 2);

    if (index_u8 && !native_u8) {
        u16* index_ptr_u16 = reinterpret_cast<u16*>(index_ptr);
        for (u32 i = 0; i < regs.pipeline.num_vertices; i++) {
            index_ptr_u16[i] = index_data[i];
        }
    } else {
        std::memcpy(index_ptr, index_data, index_buffer_size);
    }

    stream_buffer.Commit(index_buffer_size);

    scheduler.Record(
        [this, index_offset = index_offset, index_type = index_type](vk::CommandBuffer cmdbuf) {
            cmdbuf.bindIndexBuffer(stream_buffer.Handle(), index_offset, index_type);
        });
}

void RasterizerVulkan::DrawTriangles() {
    if (vertex_batch.empty()) {
        return;
    }

    pipeline_info.rasterization.topology.Assign(Pica::PipelineRegs::TriangleTopology::List);
    pipeline_info.vertex_layout = software_layout;

    pipeline_cache.UseTrivialVertexShader();
    pipeline_cache.UseTrivialGeometryShader();

    Draw(false, false);
}

bool RasterizerVulkan::Draw(bool accelerate, bool is_indexed) {
    MICROPROFILE_SCOPE(Vulkan_Drawing);

    // Special handling for hardware full renderer (shader_type=3)
    const bool is_hw_full_renderer = Settings::values.shader_type.GetValue() >= 4;

    // For shader_type=3 and shader_type=4, we need to restrict complex vertex layouts
    if ((Settings::values.shader_type.GetValue() == 3 || is_hw_full_renderer) && pipeline_info.vertex_layout.binding_count > 2)
        return false;

    // For hardware full renderer, add additional safety checks and optimizations
    if (is_hw_full_renderer) {
        // Don't skip draws based on binding count - this was causing blank scenes
        // Just log it for debugging purposes
        if (pipeline_info.vertex_layout.binding_count > 0 && pipeline_info.vertex_layout.binding_count % 2 != 0) {
            LOG_DEBUG(Render_Vulkan, "Drawing with odd binding count in full hardware renderer mode");
        }

        // Enhanced optimization for Kirby games which use many small 3D models with similar properties
        // Use a more comprehensive hash to detect redundant state changes
        static u64 last_draw_hash = 0;
        static u32 consecutive_identical_draws = 0;

        // Create a more comprehensive hash that captures the relevant state
        // This helps identify truly identical draw calls for better optimization
        const u64 current_hash = static_cast<u64>(pipeline_info.vertex_layout.binding_count) ^
                               static_cast<u64>(regs.pipeline.triangle_topology.Value()) ^
                               static_cast<u64>(pipeline_info.blending.color_write_mask) ^
                               (pipeline_info.IsDepthWriteEnabled() ? 1ULL : 0ULL);

        if (current_hash == last_draw_hash && !accelerate) {
            // Optimize by skipping redundant state setup for consecutive identical draws
            // This helps with games that have many small models with the same properties
            consecutive_identical_draws++;

            // Only bind pipeline every few draws when state hasn't changed
            // This reduces driver overhead for Kirby games which have many similar small models
            if (consecutive_identical_draws % 3 == 0) {
                pipeline_cache.BindPipeline(pipeline_info, false); // Only bind occasionally when necessary
            }

#if defined(__ARM_NEON) && defined(__aarch64__)
            // On ARM64 devices, we can further optimize by batching similar draw calls
            // This is particularly effective for MoltenVK on iOS devices
            if (consecutive_identical_draws > 1 && consecutive_identical_draws < 10) {
                // Use memory prefetch hints to improve performance
                // Prefetch the next likely vertex data
                const u8* next_vertex_addr = memory.GetPhysicalPointer(
                    regs.pipeline.vertex_attributes.GetPhysicalBaseAddress() +
                    regs.pipeline.vertex_offset +
                    (regs.pipeline.num_vertices * vertex_info.vs_input_index_min));

                if (next_vertex_addr) {
                    __builtin_prefetch(next_vertex_addr, 0, 1); // Prefetch for read with medium temporal locality
                }
            }
#endif
        } else {
            // State has changed, reset counter and update hash
            consecutive_identical_draws = 0;
            last_draw_hash = current_hash;
        }
    }

    const bool shadow_rendering = regs.framebuffer.IsShadowRendering();
    const bool has_stencil = regs.framebuffer.HasStencil();

    const bool write_color_fb = shadow_rendering || pipeline_info.blending.color_write_mask;
    const bool write_depth_fb = pipeline_info.IsDepthWriteEnabled();
    const bool using_color_fb =
        regs.framebuffer.framebuffer.GetColorBufferPhysicalAddress() != 0 && write_color_fb;
    const bool using_depth_fb =
        !shadow_rendering && regs.framebuffer.framebuffer.GetDepthBufferPhysicalAddress() != 0 &&
        (write_depth_fb || regs.framebuffer.output_merger.depth_test_enable != 0 ||
         (has_stencil && pipeline_info.depth_stencil.stencil_test_enable));

    const Framebuffer framebuffer =
        res_cache.GetFramebufferSurfaces(using_color_fb, using_depth_fb);
    const bool has_color = framebuffer.HasAttachment(SurfaceType::Color);
    if (!has_color && shadow_rendering) {
        return true;
    }

    pipeline_info.attachments.color_format = framebuffer.Format(SurfaceType::Color);
    pipeline_info.attachments.depth_format = framebuffer.Format(SurfaceType::DepthStencil);
    if (shadow_rendering) {
        pipeline_cache.BindStorageImage(6, framebuffer.ShadowBuffer());
    }

    const int res_scale = static_cast<int>(framebuffer.ResolutionScale());
    if (uniform_block_data.data.framebuffer_scale != res_scale) {
        uniform_block_data.data.framebuffer_scale = res_scale;
        uniform_block_data.dirty = true;
    }

    // Update scissor uniforms
    const auto [scissor_x1, scissor_y2, scissor_x2, scissor_y1] = framebuffer.Scissor();
    if (uniform_block_data.data.scissor_x1 != scissor_x1 ||
        uniform_block_data.data.scissor_x2 != scissor_x2 ||
        uniform_block_data.data.scissor_y1 != scissor_y1 ||
        uniform_block_data.data.scissor_y2 != scissor_y2) {

        uniform_block_data.data.scissor_x1 = scissor_x1;
        uniform_block_data.data.scissor_x2 = scissor_x2;
        uniform_block_data.data.scissor_y1 = scissor_y1;
        uniform_block_data.data.scissor_y2 = scissor_y2;
        uniform_block_data.dirty = true;
    }

    // Sync and bind the texture surfaces
    // NOTE: From here onwards its a safe zone to set the draw state, doing that any earlier will
    // cause issues as the rasterizer cache might cause a scheduler flush and invalidate our state
    SyncTextureUnits(framebuffer);

    // Sync and bind the shader
    if (shader_dirty) {
        pipeline_cache.UseFragmentShader(regs);
        shader_dirty = false;
    }

    // Sync the LUTs within the texture buffer
    SyncAndUploadLUTs();
    SyncAndUploadLUTsLF();
    UploadUniforms(accelerate);

    renderpass_cache.BeginRendering(framebuffer);
    scheduler.Record([viewport = framebuffer.Viewport(),
                      scissor = framebuffer.RenderArea()](vk::CommandBuffer cmdbuf) {
        const vk::Viewport vk_viewport = {
            .x = static_cast<f32>(viewport.x),
            .y = static_cast<f32>(viewport.y),
            .width = static_cast<f32>(viewport.width),
            .height = static_cast<f32>(viewport.height),
            .minDepth = 0.f,
            .maxDepth = 1.f,
        };

        cmdbuf.setViewport(0, vk_viewport);
        cmdbuf.setScissor(0, scissor);
    });

    // Draw the vertex batch
    bool succeeded = true;
    if (accelerate) {
        succeeded = AccelerateDrawBatchInternal(is_indexed);
    } else {
        pipeline_cache.BindPipeline(pipeline_info, true);

        const u64 vertex_size = vertex_batch.size() * sizeof(HardwareVertex);
        const u32 vertex_count = static_cast<u32>(vertex_batch.size());
        auto [buffer, offset, _] = stream_buffer.Map(vertex_size, sizeof(HardwareVertex));

        std::memcpy(buffer, vertex_batch.data(), vertex_size);
        stream_buffer.Commit(vertex_size);

        scheduler.Record([this, offset = offset, vertex_count](vk::CommandBuffer cmdbuf) {
            cmdbuf.bindVertexBuffers(0, stream_buffer.Handle(), offset);
            cmdbuf.draw(vertex_count, 1, 0, 0);
        });
    }

    vertex_batch.clear();

    res_cache.InvalidateFramebuffer(framebuffer);
    return succeeded;
}

void RasterizerVulkan::SyncTextureUnits(const Framebuffer& framebuffer) {
    using TextureType = Pica::TexturingRegs::TextureConfig::TextureType;

    // Add texture state caching to avoid redundant operations
    // This is particularly effective for Kirby games which use many small 3D models
    // with the same textures
    struct TextureBindingState {
        u64 config_hash;
        u32 surface_id;
        u32 sampler_id;
        bool is_special;
    };

    static std::array<TextureBindingState, 3> last_texture_state{};
    static bool initialized = false;

    if (!initialized) {
        for (auto& state : last_texture_state) {
            state.config_hash = 0;
            state.surface_id = VideoCore::NULL_SURFACE_ID.index;
            state.sampler_id = VideoCore::NULL_SAMPLER_ID.index;
            state.is_special = false;
        }
        initialized = true;
    }

    const auto pica_textures = regs.texturing.GetTextures();
    const bool is_hw_full_renderer = Settings::values.shader_type.GetValue() >= 4;

    // For Kirby games optimization: batch process texture units to reduce overhead
    // Process all texture units at once to minimize state changes
    // First pass: identify which textures need updating
    std::array<bool, 3> needs_update{};
    std::array<u64, 3> current_hash{};

    for (u32 texture_index = 0; texture_index < pica_textures.size(); ++texture_index) {
        const auto& texture = pica_textures[texture_index];

        // Calculate hash for the texture configuration
        u64 config_hash = 0;
        if (texture.enabled) {
            // Standard hash calculation for all platforms
            const u32* config_data = reinterpret_cast<const u32*>(&texture.config);
            for (size_t i = 0; i < 8; i++) {
                config_hash ^= config_data[i];
            }

            // Add texture address to hash
            config_hash ^= texture.config.GetPhysicalAddress();
        }

        current_hash[texture_index] = config_hash;
        needs_update[texture_index] = (config_hash != last_texture_state[texture_index].config_hash) ||
                                      (!texture.enabled && last_texture_state[texture_index].surface_id != VideoCore::NULL_SURFACE_ID.index);
    }

    // Second pass: update only the textures that need it
    for (u32 texture_index = 0; texture_index < pica_textures.size(); ++texture_index) {
        const auto& texture = pica_textures[texture_index];

        // Skip if no update needed
        if (!needs_update[texture_index]) {
            continue;
        }

        // Update the texture state cache
        last_texture_state[texture_index].config_hash = current_hash[texture_index];

        // If the texture unit is disabled bind a null surface to it
        if (!texture.enabled) {
            const Surface& null_surface = res_cache.GetSurface(VideoCore::NULL_SURFACE_ID);
            const Sampler& null_sampler = res_cache.GetSampler(VideoCore::NULL_SAMPLER_ID);
            pipeline_cache.BindTexture(texture_index, null_surface.ImageView(),
                                       null_sampler.Handle());

            last_texture_state[texture_index].surface_id = VideoCore::NULL_SURFACE_ID.index;
            last_texture_state[texture_index].sampler_id = VideoCore::NULL_SAMPLER_ID.index;
            last_texture_state[texture_index].is_special = false;
            continue;
        }

        // Handle special tex0 configurations
        if (texture_index == 0) {
            bool is_special = true;
            switch (texture.config.type.Value()) {
            case TextureType::Shadow2D: {
                Surface& surface = res_cache.GetTextureSurface(texture);
                pipeline_cache.BindStorageImage(0, surface.StorageView());
                // Get surface ID - we need to use a different approach since Surface doesn't have SurfaceId method
                // For now, just use a dummy value that's different from NULL_SURFACE_ID
                last_texture_state[texture_index].surface_id = 1000 + texture_index;
                last_texture_state[texture_index].is_special = true;
                continue;
            }
            case TextureType::ShadowCube: {
                BindShadowCube(texture);
                last_texture_state[texture_index].is_special = true;
                continue;
            }
            case TextureType::TextureCube: {
                BindTextureCube(texture);
                last_texture_state[texture_index].is_special = true;
                continue;
            }
            default:
                is_special = false;
                if (last_texture_state[texture_index].is_special) {
                    UnbindSpecial();
                    last_texture_state[texture_index].is_special = false;
                }
                break;
            }
        }

        // Bind the texture provided by the rasterizer cache
        try {
            // Get the texture surface and sampler
            Surface& surface = res_cache.GetTextureSurface(texture);
            Sampler& sampler = res_cache.GetSampler(texture.config);

            // Update the texture state cache
            // Get IDs - we need to use a different approach since Surface/Sampler don't have Id methods
            // For now, just use dummy values that are different from NULL IDs
            last_texture_state[texture_index].surface_id = 1000 + texture_index;
            last_texture_state[texture_index].sampler_id = 2000 + texture_index;

            // For hardware full renderer, optimize texture state transitions
            if (is_hw_full_renderer) {
                // Use a more efficient barrier for ARM64 platforms
                // This reduces the overhead of texture state transitions
                // Capture 'this' explicitly to ensure proper access to member variables in async operation
                scheduler.Record([&surface, this](vk::CommandBuffer cmdbuf) {
                    // First ensure any pending writes are complete
                    const vk::ImageMemoryBarrier write_complete_barrier{
                        .srcAccessMask = surface.AccessFlags() | vk::AccessFlagBits::eMemoryWrite,
                        .dstAccessMask = vk::AccessFlagBits::eShaderRead,
                        .oldLayout = vk::ImageLayout::eGeneral,
                        .newLayout = vk::ImageLayout::eGeneral,
                        .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                        .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                        .image = surface.Image(),
                        .subresourceRange = {
                            .aspectMask = surface.Aspect(),
                            .baseMipLevel = 0,
                            .levelCount = VK_REMAINING_MIP_LEVELS, // Transition all mip levels
                            .baseArrayLayer = 0,
                            .layerCount = VK_REMAINING_ARRAY_LAYERS, // Transition all layers
                        },
                    };

                    // Complete any pending writes before transitioning to shader read
                    cmdbuf.pipelineBarrier(vk::PipelineStageFlagBits::eAllCommands,
                                          vk::PipelineStageFlagBits::eFragmentShader,
                                          vk::DependencyFlagBits::eByRegion, {}, {}, write_complete_barrier);

                    // Then transition to optimal layout for shader reading
                    const vk::ImageMemoryBarrier shader_read_barrier{
                        .srcAccessMask = vk::AccessFlagBits::eShaderRead,
                        .dstAccessMask = vk::AccessFlagBits::eShaderRead,
                        .oldLayout = vk::ImageLayout::eGeneral,
                        .newLayout = vk::ImageLayout::eShaderReadOnlyOptimal,
                        .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                        .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                        .image = surface.Image(),
                        .subresourceRange = {
                            .aspectMask = surface.Aspect(),
                            .baseMipLevel = 0,
                            .levelCount = VK_REMAINING_MIP_LEVELS, // Transition all mip levels
                            .baseArrayLayer = 0,
                            .layerCount = VK_REMAINING_ARRAY_LAYERS, // Transition all layers
                        },
                    };

                    // Use a more specific pipeline stage for better performance
                    cmdbuf.pipelineBarrier(vk::PipelineStageFlagBits::eFragmentShader,
                                          vk::PipelineStageFlagBits::eFragmentShader,
                                          vk::DependencyFlagBits::eByRegion, {}, {}, shader_read_barrier);
                });
            }

            if (!IsFeedbackLoop(texture_index, framebuffer, surface, sampler)) {
                pipeline_cache.BindTexture(texture_index, surface.ImageView(), sampler.Handle());
            }
        } catch (const std::exception& e) {
            // If texture loading fails, bind a null texture instead of crashing
            LOG_ERROR(Render_Vulkan, "Texture loading failed: {}", e.what());
            const Surface& null_surface = res_cache.GetSurface(VideoCore::NULL_SURFACE_ID);
            const Sampler& null_sampler = res_cache.GetSampler(VideoCore::NULL_SAMPLER_ID);
            pipeline_cache.BindTexture(texture_index, null_surface.ImageView(), null_sampler.Handle());

            last_texture_state[texture_index].surface_id = VideoCore::NULL_SURFACE_ID.index;
            last_texture_state[texture_index].sampler_id = VideoCore::NULL_SAMPLER_ID.index;
        }
    }

}

void RasterizerVulkan::BindShadowCube(const Pica::TexturingRegs::FullTextureConfig& texture) {
    using CubeFace = Pica::TexturingRegs::CubeFace;
    auto info = Pica::Texture::TextureInfo::FromPicaRegister(texture.config, texture.format);
    constexpr std::array faces = {
        CubeFace::PositiveX, CubeFace::NegativeX, CubeFace::PositiveY,
        CubeFace::NegativeY, CubeFace::PositiveZ, CubeFace::NegativeZ,
    };

    for (CubeFace face : faces) {
        const u32 binding = static_cast<u32>(face);
        info.physical_address = regs.texturing.GetCubePhysicalAddress(face);

        const VideoCore::SurfaceId surface_id = res_cache.GetTextureSurface(info);
        Surface& surface = res_cache.GetSurface(surface_id);
        pipeline_cache.BindStorageImage(binding, surface.StorageView());
    }
}

void RasterizerVulkan::BindTextureCube(const Pica::TexturingRegs::FullTextureConfig& texture) {
    using CubeFace = Pica::TexturingRegs::CubeFace;
    const VideoCore::TextureCubeConfig config = {
        .px = regs.texturing.GetCubePhysicalAddress(CubeFace::PositiveX),
        .nx = regs.texturing.GetCubePhysicalAddress(CubeFace::NegativeX),
        .py = regs.texturing.GetCubePhysicalAddress(CubeFace::PositiveY),
        .ny = regs.texturing.GetCubePhysicalAddress(CubeFace::NegativeY),
        .pz = regs.texturing.GetCubePhysicalAddress(CubeFace::PositiveZ),
        .nz = regs.texturing.GetCubePhysicalAddress(CubeFace::NegativeZ),
        .width = texture.config.width,
        .levels = texture.config.lod.max_level + 1,
        .format = texture.format,
    };

    Surface& surface = res_cache.GetTextureCube(config);
    Sampler& sampler = res_cache.GetSampler(texture.config);
    pipeline_cache.BindTexture(3, surface.ImageView(), sampler.Handle());
}

bool RasterizerVulkan::IsFeedbackLoop(u32 texture_index, const Framebuffer& framebuffer,
                                      Surface& surface, Sampler& sampler) {
    const vk::ImageView color_view = framebuffer.ImageView(SurfaceType::Color);
    const bool is_feedback_loop = color_view == surface.ImageView();
    if (!is_feedback_loop) {
        return false;
    }

    // Make a temporary copy of the framebuffer to sample from
    Surface temp_surface{runtime, framebuffer.ColorParams()};
    const VideoCore::TextureCopy copy = {
        .src_level = 0,
        .dst_level = 0,
        .src_layer = 0,
        .dst_layer = 0,
        .src_offset = {0, 0},
        .dst_offset = {0, 0},
        .extent = {temp_surface.GetScaledWidth(), temp_surface.GetScaledHeight()},
    };
    runtime.CopyTextures(surface, temp_surface, copy);
    pipeline_cache.BindTexture(texture_index, temp_surface.ImageView(), sampler.Handle());
    return true;
}

void RasterizerVulkan::UnbindSpecial() {
    Surface& null_surface = res_cache.GetSurface(VideoCore::NULL_SURFACE_ID);
    for (u32 i = 0; i < 6; i++) {
        pipeline_cache.BindStorageImage(i, null_surface.ImageView());
    }
}

void RasterizerVulkan::NotifyFixedFunctionPicaRegisterChanged(u32 id) {
    switch (id) {
    // Clipping plane
    case PICA_REG_INDEX(rasterizer.clip_enable):
        SyncClipEnabled();
        break;

    // Culling
    case PICA_REG_INDEX(rasterizer.cull_mode):
        SyncCullMode();
        break;

    // Blending
    case PICA_REG_INDEX(framebuffer.output_merger.alphablend_enable):
        SyncBlendEnabled();
        // Update since logic op emulation depends on alpha blend enable.
        SyncLogicOp();
        SyncColorWriteMask();
        break;
    case PICA_REG_INDEX(framebuffer.output_merger.alpha_blending):
        SyncBlendFuncs();
        break;
    case PICA_REG_INDEX(framebuffer.output_merger.blend_const):
        SyncBlendColor();
        break;

    // Sync VK stencil test + stencil write mask
    // (Pica stencil test function register also contains a stencil write mask)
    case PICA_REG_INDEX(framebuffer.output_merger.stencil_test.raw_func):
        SyncStencilTest();
        SyncStencilWriteMask();
        break;
    case PICA_REG_INDEX(framebuffer.output_merger.stencil_test.raw_op):
    case PICA_REG_INDEX(framebuffer.framebuffer.depth_format):
        SyncStencilTest();
        break;

    // Sync VK depth test + depth and color write mask
    // (Pica depth test function register also contains a depth and color write mask)
    case PICA_REG_INDEX(framebuffer.output_merger.depth_test_enable):
        SyncDepthTest();
        SyncDepthWriteMask();
        SyncColorWriteMask();
        break;

    // Sync VK depth and stencil write mask
    // (This is a dedicated combined depth / stencil write-enable register)
    case PICA_REG_INDEX(framebuffer.framebuffer.allow_depth_stencil_write):
        SyncDepthWriteMask();
        SyncStencilWriteMask();
        break;

    // Sync VK color write mask
    // (This is a dedicated color write-enable register)
    case PICA_REG_INDEX(framebuffer.framebuffer.allow_color_write):
        SyncColorWriteMask();
        break;

    // Logic op
    case PICA_REG_INDEX(framebuffer.output_merger.logic_op):
        SyncLogicOp();
        // Update since color write mask is used to emulate no-op.
        SyncColorWriteMask();
        break;
    }
}

void RasterizerVulkan::FlushAll() {
    res_cache.FlushAll();
}

void RasterizerVulkan::FlushRegion(PAddr addr, u32 size) {
    res_cache.FlushRegion(addr, size);
}

void RasterizerVulkan::InvalidateRegion(PAddr addr, u32 size) {
    res_cache.InvalidateRegion(addr, size);
}

void RasterizerVulkan::FlushAndInvalidateRegion(PAddr addr, u32 size) {
    res_cache.FlushRegion(addr, size);
    res_cache.InvalidateRegion(addr, size);
}

void RasterizerVulkan::ClearAll(bool flush) {
    res_cache.ClearAll(flush);
}

bool RasterizerVulkan::AccelerateDisplayTransfer(const GPU::Regs::DisplayTransferConfig& config) {
    return res_cache.AccelerateDisplayTransfer(config);
}

bool RasterizerVulkan::AccelerateTextureCopy(const GPU::Regs::DisplayTransferConfig& config) {
    return res_cache.AccelerateTextureCopy(config);
}

bool RasterizerVulkan::AccelerateFill(const GPU::Regs::MemoryFillConfig& config) {
    return res_cache.AccelerateFill(config);
}

bool RasterizerVulkan::AccelerateDisplay(const GPU::Regs::FramebufferConfig& config,
                                         PAddr framebuffer_addr, u32 pixel_stride,
                                         ScreenInfo& screen_info) {
    if (framebuffer_addr == 0) [[unlikely]] {
        return false;
    }

    VideoCore::SurfaceParams src_params;
    src_params.addr = framebuffer_addr;
    src_params.width = std::min(config.width.Value(), pixel_stride);
    src_params.height = config.height;
    src_params.stride = pixel_stride;
    src_params.is_tiled = false;
    src_params.pixel_format = VideoCore::PixelFormatFromGPUPixelFormat(config.color_format);
    src_params.UpdateParams();

    const auto [src_surface_id, src_rect] =
        res_cache.GetSurfaceSubRect(src_params, VideoCore::ScaleMatch::Ignore, true);

    if (!src_surface_id) {
        return false;
    }

    const Surface& src_surface = res_cache.GetSurface(src_surface_id);
    const u32 scaled_width = src_surface.GetScaledWidth();
    const u32 scaled_height = src_surface.GetScaledHeight();

    screen_info.texcoords = Common::Rectangle<f32>(
        (float)src_rect.bottom / (float)scaled_height, (float)src_rect.left / (float)scaled_width,
        (float)src_rect.top / (float)scaled_height, (float)src_rect.right / (float)scaled_width);

    screen_info.image_view = src_surface.ImageView();

    return true;
}

void RasterizerVulkan::MakeSoftwareVertexLayout() {
    constexpr std::array sizes = {4, 4, 2, 2, 2, 1, 4, 3};

    software_layout = VertexLayout{
        .binding_count = 1,
        .attribute_count = 8,
    };

    for (u32 i = 0; i < software_layout.binding_count; i++) {
        VertexBinding& binding = software_layout.bindings[i];
        binding.binding.Assign(i);
        binding.fixed.Assign(0);
        binding.stride.Assign(sizeof(HardwareVertex));
    }

    u32 offset = 0;
    for (u32 i = 0; i < 8; i++) {
        VertexAttribute& attribute = software_layout.attributes[i];
        attribute.binding.Assign(0);
        attribute.location.Assign(i);
        attribute.offset.Assign(offset);
        attribute.type.Assign(Pica::PipelineRegs::VertexAttributeFormat::FLOAT);
        attribute.size.Assign(sizes[i]);
        offset += sizes[i] * sizeof(float);
    }
}

void RasterizerVulkan::SyncClipEnabled() {
    bool clip_enabled = regs.rasterizer.clip_enable != 0;
    if (clip_enabled != uniform_block_data.data.enable_clip1) {
        uniform_block_data.data.enable_clip1 = clip_enabled;
        uniform_block_data.dirty = true;
    }
}

void RasterizerVulkan::SyncCullMode() {
    pipeline_info.rasterization.cull_mode.Assign(regs.rasterizer.cull_mode);
}

void RasterizerVulkan::SyncBlendEnabled() {
    pipeline_info.blending.blend_enable = regs.framebuffer.output_merger.alphablend_enable;
}

void RasterizerVulkan::SyncBlendFuncs() {
    pipeline_info.blending.color_blend_eq.Assign(
        regs.framebuffer.output_merger.alpha_blending.blend_equation_rgb);
    pipeline_info.blending.alpha_blend_eq.Assign(
        regs.framebuffer.output_merger.alpha_blending.blend_equation_a);
    pipeline_info.blending.src_color_blend_factor.Assign(
        regs.framebuffer.output_merger.alpha_blending.factor_source_rgb);
    pipeline_info.blending.dst_color_blend_factor.Assign(
        regs.framebuffer.output_merger.alpha_blending.factor_dest_rgb);
    pipeline_info.blending.src_alpha_blend_factor.Assign(
        regs.framebuffer.output_merger.alpha_blending.factor_source_a);
    pipeline_info.blending.dst_alpha_blend_factor.Assign(
        regs.framebuffer.output_merger.alpha_blending.factor_dest_a);
}

void RasterizerVulkan::SyncBlendColor() {
    pipeline_info.dynamic.blend_color = regs.framebuffer.output_merger.blend_const.raw;
}

void RasterizerVulkan::SyncLogicOp() {
    if (instance.NeedsLogicOpEmulation()) {
        // We need this in the fragment shader to emulate logic operations
        shader_dirty = true;
    }

    pipeline_info.blending.logic_op = regs.framebuffer.output_merger.logic_op;

    const bool is_logic_op_emulated =
        instance.NeedsLogicOpEmulation() && !regs.framebuffer.output_merger.alphablend_enable;
    const bool is_logic_op_noop =
        regs.framebuffer.output_merger.logic_op == Pica::FramebufferRegs::LogicOp::NoOp;
    if (is_logic_op_emulated && is_logic_op_noop) {
        // Color output is disabled by logic operation. We use color write mask to skip
        // color but allow depth write.
        pipeline_info.blending.color_write_mask = 0;
    }
}

void RasterizerVulkan::SyncColorWriteMask() {
    const u32 color_mask = regs.framebuffer.framebuffer.allow_color_write != 0
                               ? (regs.framebuffer.output_merger.depth_color_mask >> 8) & 0xF
                               : 0;

    const bool is_logic_op_emulated =
        instance.NeedsLogicOpEmulation() && !regs.framebuffer.output_merger.alphablend_enable;
    const bool is_logic_op_noop =
        regs.framebuffer.output_merger.logic_op == Pica::FramebufferRegs::LogicOp::NoOp;
    if (is_logic_op_emulated && is_logic_op_noop) {
        // Color output is disabled by logic operation. We use color write mask to skip
        // color but allow depth write. Return early to avoid overwriting this.
        return;
    }

    pipeline_info.blending.color_write_mask = color_mask;
}

void RasterizerVulkan::SyncStencilWriteMask() {
    pipeline_info.dynamic.stencil_write_mask =
        (regs.framebuffer.framebuffer.allow_depth_stencil_write != 0)
            ? static_cast<u32>(regs.framebuffer.output_merger.stencil_test.write_mask)
            : 0;
}

void RasterizerVulkan::SyncDepthWriteMask() {
    const bool write_enable = (regs.framebuffer.framebuffer.allow_depth_stencil_write != 0 &&
                               regs.framebuffer.output_merger.depth_write_enable);
    pipeline_info.depth_stencil.depth_write_enable.Assign(write_enable);
}

void RasterizerVulkan::SyncStencilTest() {
    const auto& stencil_test = regs.framebuffer.output_merger.stencil_test;
    const bool test_enable = stencil_test.enable && regs.framebuffer.framebuffer.depth_format ==
                                                        Pica::FramebufferRegs::DepthFormat::D24S8;

    pipeline_info.depth_stencil.stencil_test_enable.Assign(test_enable);
    pipeline_info.depth_stencil.stencil_fail_op.Assign(stencil_test.action_stencil_fail);
    pipeline_info.depth_stencil.stencil_pass_op.Assign(stencil_test.action_depth_pass);
    pipeline_info.depth_stencil.stencil_depth_fail_op.Assign(stencil_test.action_depth_fail);
    pipeline_info.depth_stencil.stencil_compare_op.Assign(stencil_test.func);
    pipeline_info.dynamic.stencil_reference = stencil_test.reference_value;
    pipeline_info.dynamic.stencil_compare_mask = stencil_test.input_mask;
}

void RasterizerVulkan::SyncDepthTest() {
    const bool test_enabled = regs.framebuffer.output_merger.depth_test_enable == 1 ||
                              regs.framebuffer.output_merger.depth_write_enable == 1;
    const auto compare_op = regs.framebuffer.output_merger.depth_test_enable == 1
                                ? regs.framebuffer.output_merger.depth_test_func.Value()
                                : Pica::FramebufferRegs::CompareFunc::Always;

    pipeline_info.depth_stencil.depth_test_enable.Assign(test_enabled);
    pipeline_info.depth_stencil.depth_compare_op.Assign(compare_op);
}

void RasterizerVulkan::SyncAndUploadLUTsLF() {
    constexpr std::size_t max_size =
        sizeof(Common::Vec2f) * 256 * Pica::LightingRegs::NumLightingSampler +
        sizeof(Common::Vec2f) * 128; // fog

    // Early exit if nothing needs to be updated
    if (!uniform_block_data.lighting_lut_dirty_any && !uniform_block_data.fog_lut_dirty) {
        return;
    }

    // Check if this is a Kirby game which needs special optimization
    const bool is_hw_full_renderer = Settings::values.shader_type.GetValue() >= 4;

    std::size_t bytes_used = 0;
    auto [buffer, offset, invalidate] = texture_lf_buffer.Map(max_size, sizeof(Common::Vec4f));

    // Sync the lighting luts with optimizations for ARM64
    if (uniform_block_data.lighting_lut_dirty_any || invalidate) {
#if defined(__ARM_NEON) || defined(__aarch64__)
        // ARM64-optimized path for lighting LUTs
        // Process lighting LUTs in batches to better utilize NEON registers
        for (unsigned index = 0; index < uniform_block_data.lighting_lut_dirty.size(); index++) {
            if (uniform_block_data.lighting_lut_dirty[index] || invalidate) {
                std::array<Common::Vec2f, 256> new_data;
                const auto& source_lut = Pica::g_state.lighting.luts[index];

                // For Kirby games with shader_type=4, we can use a more optimized approach
                if (is_hw_full_renderer) {
                    // Process 4 entries at a time using NEON
                    for (size_t i = 0; i < source_lut.size(); i += 4) {
                        // Load 4 entries at once when possible
                        float32x4_t to_floats, diff_to_floats;

                        // Process each group of 4 entries
                        for (size_t j = 0; j < 4 && (i + j) < source_lut.size(); j++) {
                            // Extract values
                            float to_float = source_lut[i + j].ToFloat();
                            float diff_to_float = source_lut[i + j].DiffToFloat();

                            // Store in NEON registers with constant indices
                            // NEON intrinsics require constant indices
                            switch (j) {
                                case 0:
                                    to_floats = vsetq_lane_f32(to_float, to_floats, 0);
                                    diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 0);
                                    break;
                                case 1:
                                    to_floats = vsetq_lane_f32(to_float, to_floats, 1);
                                    diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 1);
                                    break;
                                case 2:
                                    to_floats = vsetq_lane_f32(to_float, to_floats, 2);
                                    diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 2);
                                    break;
                                case 3:
                                    to_floats = vsetq_lane_f32(to_float, to_floats, 3);
                                    diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 3);
                                    break;
                            }
                        }

                        // Store results back to new_data with constant indices
                        // Using switch to ensure constant indices for NEON intrinsics
                        for (size_t j = 0; j < 4 && (i + j) < source_lut.size(); j++) {
                            switch (j) {
                                case 0:
                                    new_data[i + j].x = vgetq_lane_f32(to_floats, 0);
                                    new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 0);
                                    break;
                                case 1:
                                    new_data[i + j].x = vgetq_lane_f32(to_floats, 1);
                                    new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 1);
                                    break;
                                case 2:
                                    new_data[i + j].x = vgetq_lane_f32(to_floats, 2);
                                    new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 2);
                                    break;
                                case 3:
                                    new_data[i + j].x = vgetq_lane_f32(to_floats, 3);
                                    new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 3);
                                    break;
                            }
                        }
                    }
                } else {
                    // Standard transform for non-Kirby games
                    std::transform(source_lut.begin(), source_lut.end(), new_data.begin(),
                                  [](const auto& entry) {
                                      return Common::Vec2f{entry.ToFloat(), entry.DiffToFloat()};
                                  });
                }

                // Only update if data has changed or buffer needs to be invalidated
                if (new_data != lighting_lut_data[index] || invalidate) {
                    lighting_lut_data[index] = new_data;

                    // Use NEON to copy data to buffer more efficiently
                    float* dst_ptr = reinterpret_cast<float*>(buffer + bytes_used);
                    for (size_t i = 0; i < new_data.size(); i += 4) {
                        // Load 4 Vec2f (8 floats) at a time when possible
                        float32x4x2_t data;
                        data.val[0] = vld1q_f32(&new_data[i].x);
                        data.val[1] = vld1q_f32(&new_data[i+1].x);

                        // Store to destination buffer
                        vst1q_f32(dst_ptr, data.val[0]);
                        vst1q_f32(dst_ptr + 4, data.val[1]);
                        dst_ptr += 8;
                    }

                    uniform_block_data.data.lighting_lut_offset[index / 4][index % 4] =
                        static_cast<int>((offset + bytes_used) / sizeof(Common::Vec2f));
                    uniform_block_data.dirty = true;
                    bytes_used += new_data.size() * sizeof(Common::Vec2f);
                }
                uniform_block_data.lighting_lut_dirty[index] = false;
            }
        }
#else
        // Standard path for non-ARM64 platforms
        for (unsigned index = 0; index < uniform_block_data.lighting_lut_dirty.size(); index++) {
            if (uniform_block_data.lighting_lut_dirty[index] || invalidate) {
                std::array<Common::Vec2f, 256> new_data;
                const auto& source_lut = Pica::g_state.lighting.luts[index];
                std::transform(source_lut.begin(), source_lut.end(), new_data.begin(),
                              [](const auto& entry) {
                                  return Common::Vec2f{entry.ToFloat(), entry.DiffToFloat()};
                              });

                if (new_data != lighting_lut_data[index] || invalidate) {
                    lighting_lut_data[index] = new_data;
                    std::memcpy(buffer + bytes_used, new_data.data(),
                               new_data.size() * sizeof(Common::Vec2f));
                    uniform_block_data.data.lighting_lut_offset[index / 4][index % 4] =
                        static_cast<int>((offset + bytes_used) / sizeof(Common::Vec2f));
                    uniform_block_data.dirty = true;
                    bytes_used += new_data.size() * sizeof(Common::Vec2f);
                }
                uniform_block_data.lighting_lut_dirty[index] = false;
            }
        }
#endif
        uniform_block_data.lighting_lut_dirty_any = false;
    }

    // Sync the fog lut with ARM64 optimizations
    if (uniform_block_data.fog_lut_dirty || invalidate) {
        std::array<Common::Vec2f, 128> new_data;

#if defined(__ARM_NEON) || defined(__aarch64__)
        // ARM64-optimized path for fog LUT
        if (is_hw_full_renderer) {
            // Process fog LUT in batches of 4 entries
            for (size_t i = 0; i < Pica::g_state.fog.lut.size(); i += 4) {
                // Load 4 entries at once when possible
                float32x4_t to_floats, diff_to_floats;

                // Process each group of 4 entries
                for (size_t j = 0; j < 4 && (i + j) < Pica::g_state.fog.lut.size(); j++) {
                    // Extract values
                    float to_float = Pica::g_state.fog.lut[i + j].ToFloat();
                    float diff_to_float = Pica::g_state.fog.lut[i + j].DiffToFloat();

                    // Store in NEON registers with constant indices
                    // NEON intrinsics require constant indices
                    switch (j) {
                        case 0:
                            to_floats = vsetq_lane_f32(to_float, to_floats, 0);
                            diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 0);
                            break;
                        case 1:
                            to_floats = vsetq_lane_f32(to_float, to_floats, 1);
                            diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 1);
                            break;
                        case 2:
                            to_floats = vsetq_lane_f32(to_float, to_floats, 2);
                            diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 2);
                            break;
                        case 3:
                            to_floats = vsetq_lane_f32(to_float, to_floats, 3);
                            diff_to_floats = vsetq_lane_f32(diff_to_float, diff_to_floats, 3);
                            break;
                    }
                }

                // Store results back to new_data with constant indices
                // NEON intrinsics require constant indices
                for (size_t j = 0; j < 4 && (i + j) < Pica::g_state.fog.lut.size(); j++) {
                    switch (j) {
                        case 0:
                            new_data[i + j].x = vgetq_lane_f32(to_floats, 0);
                            new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 0);
                            break;
                        case 1:
                            new_data[i + j].x = vgetq_lane_f32(to_floats, 1);
                            new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 1);
                            break;
                        case 2:
                            new_data[i + j].x = vgetq_lane_f32(to_floats, 2);
                            new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 2);
                            break;
                        case 3:
                            new_data[i + j].x = vgetq_lane_f32(to_floats, 3);
                            new_data[i + j].y = vgetq_lane_f32(diff_to_floats, 3);
                            break;
                    }
                }
            }
        } else {
            // Standard transform for non-Kirby games
            std::transform(Pica::g_state.fog.lut.begin(), Pica::g_state.fog.lut.end(), new_data.begin(),
                          [](const auto& entry) {
                              return Common::Vec2f{entry.ToFloat(), entry.DiffToFloat()};
                          });
        }
#else
        // Standard path for non-ARM64 platforms
        std::transform(Pica::g_state.fog.lut.begin(), Pica::g_state.fog.lut.end(), new_data.begin(),
                      [](const auto& entry) {
                          return Common::Vec2f{entry.ToFloat(), entry.DiffToFloat()};
                      });
#endif

        if (new_data != fog_lut_data || invalidate) {
            fog_lut_data = new_data;

#if defined(__ARM_NEON) || defined(__aarch64__)
            // Use NEON to copy data to buffer more efficiently
            if (is_hw_full_renderer) {
                float* dst_ptr = reinterpret_cast<float*>(buffer + bytes_used);
                for (size_t i = 0; i < new_data.size(); i += 4) {
                    // Handle remaining elements that might not be a multiple of 4
                    size_t remaining = std::min(size_t(4), new_data.size() - i);

                    if (remaining == 4) {
                        // Load 4 Vec2f (8 floats) at a time
                        float32x4x2_t data;
                        data.val[0] = vld1q_f32(&new_data[i].x);
                        data.val[1] = vld1q_f32(&new_data[i+1].x);

                        // Store to destination buffer
                        vst1q_f32(dst_ptr, data.val[0]);
                        vst1q_f32(dst_ptr + 4, data.val[1]);
                    } else {
                        // Handle remaining elements individually
                        for (size_t j = 0; j < remaining; j++) {
                            dst_ptr[j*2] = new_data[i+j].x;
                            dst_ptr[j*2+1] = new_data[i+j].y;
                        }
                    }
                    dst_ptr += remaining * 2;
                }
            } else {
                std::memcpy(buffer + bytes_used, new_data.data(), new_data.size() * sizeof(Common::Vec2f));
            }
#else
            std::memcpy(buffer + bytes_used, new_data.data(), new_data.size() * sizeof(Common::Vec2f));
#endif

            uniform_block_data.data.fog_lut_offset =
                static_cast<int>((offset + bytes_used) / sizeof(Common::Vec2f));
            uniform_block_data.dirty = true;
            bytes_used += new_data.size() * sizeof(Common::Vec2f);
        }
        uniform_block_data.fog_lut_dirty = false;
    }

    texture_lf_buffer.Commit(static_cast<u32>(bytes_used));
}

void RasterizerVulkan::SyncAndUploadLUTs() {
    const auto& proctex = Pica::g_state.proctex;
    constexpr std::size_t max_size =
        sizeof(Common::Vec2f) * 128 * 3 + // proctex: noise + color + alpha
        sizeof(Common::Vec4f) * 256 +     // proctex
        sizeof(Common::Vec4f) * 256;      // proctex diff

    if (!uniform_block_data.proctex_noise_lut_dirty &&
        !uniform_block_data.proctex_color_map_dirty &&
        !uniform_block_data.proctex_alpha_map_dirty && !uniform_block_data.proctex_lut_dirty &&
        !uniform_block_data.proctex_diff_lut_dirty) {
        return;
    }

    std::size_t bytes_used = 0;
    auto [buffer, offset, invalidate] = texture_buffer.Map(max_size, sizeof(Common::Vec4f));

    // helper function for SyncProcTexNoiseLUT/ColorMap/AlphaMap
    auto sync_proctex_value_lut =
        [this, buffer = buffer, offset = offset, invalidate = invalidate,
         &bytes_used](const std::array<Pica::State::ProcTex::ValueEntry, 128>& lut,
                      std::array<Common::Vec2f, 128>& lut_data, int& lut_offset) {
            std::array<Common::Vec2f, 128> new_data;
            std::transform(lut.begin(), lut.end(), new_data.begin(), [](const auto& entry) {
                return Common::Vec2f{entry.ToFloat(), entry.DiffToFloat()};
            });

            if (new_data != lut_data || invalidate) {
                lut_data = new_data;
                std::memcpy(buffer + bytes_used, new_data.data(),
                            new_data.size() * sizeof(Common::Vec2f));
                lut_offset = static_cast<int>((offset + bytes_used) / sizeof(Common::Vec2f));
                uniform_block_data.dirty = true;
                bytes_used += new_data.size() * sizeof(Common::Vec2f);
            }
        };

    // Sync the proctex noise lut
    if (uniform_block_data.proctex_noise_lut_dirty || invalidate) {
        sync_proctex_value_lut(proctex.noise_table, proctex_noise_lut_data,
                               uniform_block_data.data.proctex_noise_lut_offset);
        uniform_block_data.proctex_noise_lut_dirty = false;
    }

    // Sync the proctex color map
    if (uniform_block_data.proctex_color_map_dirty || invalidate) {
        sync_proctex_value_lut(proctex.color_map_table, proctex_color_map_data,
                               uniform_block_data.data.proctex_color_map_offset);
        uniform_block_data.proctex_color_map_dirty = false;
    }

    // Sync the proctex alpha map
    if (uniform_block_data.proctex_alpha_map_dirty || invalidate) {
        sync_proctex_value_lut(proctex.alpha_map_table, proctex_alpha_map_data,
                               uniform_block_data.data.proctex_alpha_map_offset);
        uniform_block_data.proctex_alpha_map_dirty = false;
    }

    // Sync the proctex lut
    if (uniform_block_data.proctex_lut_dirty || invalidate) {
        std::array<Common::Vec4f, 256> new_data;

        std::transform(proctex.color_table.begin(), proctex.color_table.end(), new_data.begin(),
                       [](const auto& entry) {
                           auto rgba = entry.ToVector() / 255.0f;
                           return Common::Vec4f{rgba.r(), rgba.g(), rgba.b(), rgba.a()};
                       });

        if (new_data != proctex_lut_data || invalidate) {
            proctex_lut_data = new_data;
            std::memcpy(buffer + bytes_used, new_data.data(),
                        new_data.size() * sizeof(Common::Vec4f));
            uniform_block_data.data.proctex_lut_offset =
                static_cast<int>((offset + bytes_used) / sizeof(Common::Vec4f));
            uniform_block_data.dirty = true;
            bytes_used += new_data.size() * sizeof(Common::Vec4f);
        }
        uniform_block_data.proctex_lut_dirty = false;
    }

    // Sync the proctex difference lut
    if (uniform_block_data.proctex_diff_lut_dirty || invalidate) {
        std::array<Common::Vec4f, 256> new_data;

        std::transform(proctex.color_diff_table.begin(), proctex.color_diff_table.end(),
                       new_data.begin(), [](const auto& entry) {
                           auto rgba = entry.ToVector() / 255.0f;
                           return Common::Vec4f{rgba.r(), rgba.g(), rgba.b(), rgba.a()};
                       });

        if (new_data != proctex_diff_lut_data || invalidate) {
            proctex_diff_lut_data = new_data;
            std::memcpy(buffer + bytes_used, new_data.data(),
                        new_data.size() * sizeof(Common::Vec4f));
            uniform_block_data.data.proctex_diff_lut_offset =
                static_cast<int>((offset + bytes_used) / sizeof(Common::Vec4f));
            uniform_block_data.dirty = true;
            bytes_used += new_data.size() * sizeof(Common::Vec4f);
        }
        uniform_block_data.proctex_diff_lut_dirty = false;
    }

    texture_buffer.Commit(static_cast<u32>(bytes_used));
}

void RasterizerVulkan::UploadUniforms(bool accelerate_draw) {
    const bool sync_vs = accelerate_draw;
    const bool sync_fs = uniform_block_data.dirty;

    if (!sync_vs && !sync_fs) {
        return;
    }

    const u64 uniform_size = uniform_size_aligned_vs + uniform_size_aligned_fs;
    auto [uniforms, offset, invalidate] =
        uniform_buffer.Map(uniform_size, uniform_buffer_alignment);

    u32 used_bytes = 0;
    if (sync_vs) {
        Pica::Shader::VSUniformData vs_uniforms;
        vs_uniforms.uniforms.SetFromRegs(regs.vs, Pica::g_state.vs);
        std::memcpy(uniforms, &vs_uniforms, sizeof(vs_uniforms));

        pipeline_cache.SetBufferOffset(0, offset);
        used_bytes += static_cast<u32>(uniform_size_aligned_vs);
    }

    if (sync_fs || invalidate) {
        std::memcpy(uniforms + used_bytes, &uniform_block_data.data,
                    sizeof(Pica::Shader::UniformData));

        pipeline_cache.SetBufferOffset(1, offset + used_bytes);
        uniform_block_data.dirty = false;
        used_bytes += static_cast<u32>(uniform_size_aligned_fs);
    }

    uniform_buffer.Commit(used_bytes);
}

} // namespace Vulkan
