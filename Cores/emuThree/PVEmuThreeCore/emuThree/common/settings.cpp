// Copyright 2014 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes: Add Buttons, isReloaded state, shaderType

#include <string_view>
#include <utility>
#include "audio_core/dsp_interface.h"
#include "common/settings.h"
#include "core/core.h"
#include "core/gdbstub/gdbstub.h"
#include "core/hle/kernel/shared_page.h"
#include "core/hle/service/cam/cam.h"
#include "core/hle/service/hid/hid.h"
#include "core/hle/service/ir/ir_rst.h"
#include "core/hle/service/ir/ir_user.h"
#include "core/hle/service/mic_u.h"
#include "core/hle/service/plgldr/plgldr.h"
#include "video_core/renderer_base.h"
#include "video_core/video_core.h"

namespace Settings {

namespace {

std::string_view GetAudioEmulationName(AudioEmulation emulation) {
    switch (emulation) {
    case AudioEmulation::HLE:
        return "HLE";
    case AudioEmulation::LLE:
        return "LLE";
    case AudioEmulation::LLEMultithreaded:
        return "LLE Multithreaded";
    default:
        return "Invalid";
    }
    UNREACHABLE();
};

std::string_view GetGraphicsAPIName(GraphicsAPI api) {
    switch (api) {
    case GraphicsAPI::Software:
        return "Software";
    case GraphicsAPI::OpenGL:
        return "OpenGL";
    default:
        return "Invalid";
    }
    UNREACHABLE();
}

std::string_view GetTextureFilterName(TextureFilter filter) {
    switch (filter) {
    case TextureFilter::None:
        return "None";
    case TextureFilter::Anime4K:
        return "Anime4K";
    case TextureFilter::Bicubic:
        return "Bicubic";
    case TextureFilter::NearestNeighbor:
        return "NearestNeighbor";
    case TextureFilter::ScaleForce:
        return "ScaleForce";
    case TextureFilter::xBRZ:
        return "xBRZ";
    default:
        return "Invalid";
    }
    UNREACHABLE();
}

} // Anonymous namespace

Values values = {};
static bool configuring_global = true;

void Apply() {
    GDBStub::SetServerPort(values.gdbstub_port.GetValue());
    GDBStub::ToggleServer(values.use_gdbstub.GetValue());

    VideoCore::g_shader_jit_enabled = values.use_shader_jit.GetValue();
    VideoCore::g_hw_shader_enabled = values.use_hw_shader.GetValue();
    VideoCore::g_hw_shader_accurate_mul = values.shaders_accurate_mul.GetValue();

#ifndef ANDROID
   if (VideoCore::g_renderer) {
        VideoCore::g_renderer->UpdateCurrentFramebufferLayout();
   }
#endif

    if (VideoCore::g_renderer) {
        auto& settings = VideoCore::g_renderer->Settings();
        settings.bg_color_update_requested = true;
        settings.sampler_update_requested = true;
        settings.shader_update_requested = true;
        settings.texture_filter_update_requested = true;
    }

    auto& system = Core::System::GetInstance();
    if (system.IsPoweredOn()) {
        system.CoreTiming().UpdateClockSpeed(values.cpu_clock_percentage.GetValue());
        Core::DSP().SetSink(values.output_type.GetValue(), values.output_device.GetValue());
        Core::DSP().EnableStretching(values.enable_audio_stretching.GetValue());

        auto hid = Service::HID::GetModule(system);
        if (hid) {
            hid->ReloadInputDevices();
        }

        auto apt = Service::APT::GetModule(system);
        if (apt) {
            apt->GetAppletManager()->ReloadInputDevices();
        }

        auto sm = system.ServiceManager();
        auto ir_user = sm.GetService<Service::IR::IR_USER>("ir:USER");
        if (ir_user)
            ir_user->ReloadInputDevices();
        auto ir_rst = sm.GetService<Service::IR::IR_RST>("ir:rst");
        if (ir_rst)
            ir_rst->ReloadInputDevices();

        auto cam = Service::CAM::GetModule(system);
        if (cam) {
            cam->ReloadCameraDevices();
        }

        Service::MIC::ReloadMic(system);
    }

    Service::PLGLDR::PLG_LDR::SetEnabled(values.plugin_loader_enabled.GetValue());
    Service::PLGLDR::PLG_LDR::SetAllowGameChangeState(values.allow_plugin_loader.GetValue());
}

void LogSettings() {
    const auto log_setting = [](std::string_view name, const auto& value) {
        LOG_INFO(Config, "{}: {}", name, value);
    };

    LOG_INFO(Config, "Citra Configuration:");
    log_setting("Core_UseCpuJit", values.use_cpu_jit.GetValue());
    log_setting("Core_CPUClockPercentage", values.cpu_clock_percentage.GetValue());
    log_setting("Renderer_UseGLES", values.use_gles.GetValue());
    log_setting("Renderer_GraphicsAPI", GetGraphicsAPIName(values.graphics_api.GetValue()));
    log_setting("Renderer_AsyncShaders", values.async_shader_compilation.GetValue());
    log_setting("Renderer_AsyncPresentation", values.async_presentation.GetValue());
    log_setting("Renderer_SpirvShaderGen", values.spirv_shader_gen.GetValue());
    log_setting("Renderer_Debug", values.renderer_debug.GetValue());
    log_setting("Renderer_UseHwShader", values.use_hw_shader.GetValue());
    log_setting("Renderer_ShadersAccurateMul", values.shaders_accurate_mul.GetValue());
    log_setting("Renderer_UseShaderJit", values.use_shader_jit.GetValue());
    log_setting("Renderer_UseResolutionFactor", values.resolution_factor.GetValue());
    log_setting("Renderer_FrameLimit", values.frame_limit.GetValue());
    log_setting("Renderer_VSyncNew", values.use_vsync_new.GetValue());
    log_setting("Renderer_PostProcessingShader", values.pp_shader_name.GetValue());
    log_setting("Renderer_FilterMode", values.filter_mode.GetValue());
    log_setting("Renderer_TextureFilter", GetTextureFilterName(values.texture_filter.GetValue()));
    log_setting("Stereoscopy_Render3d", values.render_3d.GetValue());
    log_setting("Stereoscopy_Factor3d", values.factor_3d.GetValue());
    log_setting("Stereoscopy_MonoRenderOption", values.mono_render_option.GetValue());
    if (values.render_3d.GetValue() == StereoRenderOption::Anaglyph) {
        log_setting("Renderer_AnaglyphShader", values.anaglyph_shader_name.GetValue());
    }
    log_setting("Layout_LayoutOption", values.layout_option.GetValue());
    log_setting("Layout_SwapScreen", values.swap_screen.GetValue());
    log_setting("Layout_UprightScreen", values.upright_screen.GetValue());
    log_setting("Layout_LargeScreenProportion", values.large_screen_proportion.GetValue());
    log_setting("Utility_DumpTextures", values.dump_textures.GetValue());
    log_setting("Utility_CustomTextures", values.custom_textures.GetValue());
    log_setting("Utility_PreloadTextures", values.preload_textures.GetValue());
    log_setting("Utility_AsyncCustomLoading", values.async_custom_loading.GetValue());
    log_setting("Utility_UseDiskShaderCache", values.use_disk_shader_cache.GetValue());
    log_setting("Audio_Emulation", GetAudioEmulationName(values.audio_emulation.GetValue()));
    log_setting("Audio_OutputType", values.output_type.GetValue());
    log_setting("Audio_OutputDevice", values.output_device.GetValue());
    log_setting("Audio_InputType", values.input_type.GetValue());
    log_setting("Audio_InputDevice", values.input_device.GetValue());
    log_setting("Audio_EnableAudioStretching", values.enable_audio_stretching.GetValue());
    using namespace Service::CAM;
    log_setting("Camera_OuterRightName", values.camera_name[OuterRightCamera]);
    log_setting("Camera_OuterRightConfig", values.camera_config[OuterRightCamera]);
    log_setting("Camera_OuterRightFlip", values.camera_flip[OuterRightCamera]);
    log_setting("Camera_InnerName", values.camera_name[InnerCamera]);
    log_setting("Camera_InnerConfig", values.camera_config[InnerCamera]);
    log_setting("Camera_InnerFlip", values.camera_flip[InnerCamera]);
    log_setting("Camera_OuterLeftName", values.camera_name[OuterLeftCamera]);
    log_setting("Camera_OuterLeftConfig", values.camera_config[OuterLeftCamera]);
    log_setting("Camera_OuterLeftFlip", values.camera_flip[OuterLeftCamera]);
    log_setting("DataStorage_UseVirtualSd", values.use_virtual_sd.GetValue());
    log_setting("DataStorage_UseCustomStorage", values.use_custom_storage.GetValue());
    if (values.use_custom_storage) {
        log_setting("DataStorage_SdmcDir", FileUtil::GetUserPath(FileUtil::UserPath::SDMCDir));
        log_setting("DataStorage_NandDir", FileUtil::GetUserPath(FileUtil::UserPath::NANDDir));
    }
    log_setting("System_IsNew3ds", values.is_new_3ds.GetValue());
    log_setting("System_RegionValue", values.region_value.GetValue());
    log_setting("System_PluginLoader", values.plugin_loader_enabled.GetValue());
    log_setting("System_PluginLoaderAllowed", values.allow_plugin_loader.GetValue());
    log_setting("Debugging_UseGdbstub", values.use_gdbstub.GetValue());
    log_setting("Debugging_GdbstubPort", values.gdbstub_port.GetValue());
}

bool IsConfiguringGlobal() {
    return configuring_global;
}

void SetConfiguringGlobal(bool is_global) {
    configuring_global = is_global;
}

float Volume() {
    if (values.audio_muted) {
        return 0.0f;
    }
    return values.volume.GetValue();
}

void RestoreGlobalState(bool is_powered_on) {
    // If a game is running, DO NOT restore the global settings state
    if (is_powered_on) {
        return;
    }
    
    // Audio
    values.audio_emulation.SetGlobal(true);
    values.enable_audio_stretching.SetGlobal(true);
    values.volume.SetGlobal(true);
    
    // Core
    values.cpu_clock_percentage.SetGlobal(true);
    values.is_new_3ds.SetGlobal(true);
    
    // Renderer
    values.graphics_api.SetGlobal(true);
    values.physical_device.SetGlobal(true);
    values.spirv_shader_gen.SetGlobal(true);
    values.async_shader_compilation.SetGlobal(true);
    values.async_presentation.SetGlobal(true);
    values.use_hw_shader.SetGlobal(true);
    values.use_disk_shader_cache.SetGlobal(true);
    values.shaders_accurate_mul.SetGlobal(true);
    values.use_vsync_new.SetGlobal(true);
    values.resolution_factor.SetGlobal(true);
    values.frame_limit.SetGlobal(true);
    values.texture_filter.SetGlobal(true);
    values.layout_option.SetGlobal(true);
    values.swap_screen.SetGlobal(true);
    values.upright_screen.SetGlobal(true);
    values.large_screen_proportion.SetGlobal(true);
    values.bg_red.SetGlobal(true);
    values.bg_green.SetGlobal(true);
    values.bg_blue.SetGlobal(true);
    values.render_3d.SetGlobal(true);
    values.factor_3d.SetGlobal(true);
    values.filter_mode.SetGlobal(true);
    values.pp_shader_name.SetGlobal(true);
    values.anaglyph_shader_name.SetGlobal(true);
    values.dump_textures.SetGlobal(true);
    values.custom_textures.SetGlobal(true);
    values.preload_textures.SetGlobal(true);
    values.isReloading.SetGlobal(true);
    values.shader_type.SetGlobal(true);
    values.color_attachment.SetGlobal(true);
}

void LoadProfile(int index) {
    Settings::values.current_input_profile = Settings::values.input_profiles[index];
    Settings::values.current_input_profile_index = index;
}

void SaveProfile(int index) {
    Settings::values.input_profiles[index] = Settings::values.current_input_profile;
}

void CreateProfile(std::string name) {
    Settings::InputProfile profile = values.current_input_profile;
    profile.name = std::move(name);
    Settings::values.input_profiles.push_back(std::move(profile));
    Settings::values.current_input_profile_index =
        static_cast<int>(Settings::values.input_profiles.size()) - 1;
    Settings::LoadProfile(Settings::values.current_input_profile_index);
}

void DeleteProfile(int index) {
    Settings::values.input_profiles.erase(Settings::values.input_profiles.begin() + index);
    Settings::LoadProfile(0);
}

void RenameCurrentProfile(std::string new_name) {
    Settings::values.current_input_profile.name = std::move(new_name);
}

} // namespace Settings
