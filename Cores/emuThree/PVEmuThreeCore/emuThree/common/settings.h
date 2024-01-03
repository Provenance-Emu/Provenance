// Copyright 2014 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <algorithm>
#include <array>
#include <atomic>
#include <string>
#include <unordered_map>
#include <vector>
#include "audio_core/input_details.h"
#include "audio_core/sink_details.h"
#include "common/common_types.h"
#include "core/hle/service/cam/cam_params.h"
#include "core/frontend/input.h"

namespace Settings {

enum class GraphicsAPI {
    Software = 0,
    OpenGL = 1,
    Vulkan = 2,
};

enum class InitClock : u32 {
    SystemTime = 0,
    FixedTime = 1,
};

enum class LayoutOption : u32 {
    Default,
    SingleScreen,
    LargeScreen,
    SideScreen,
#ifndef ANDROID
    SeparateWindows,
#endif
    // Similiar to default, but better for mobile devices in portrait mode. Top screen in clamped to
    // the top of the frame, and the bottom screen is enlarged to match the top screen.
    MobilePortrait,

    // Similiar to LargeScreen, but better for mobile devices in landscape mode. The screens are
    // clamped to the top of the frame, and the bottom screen is a bit bigger.
    MobileLandscape,
};

enum class StereoRenderOption : u32 {
    Off = 0,
    SideBySide = 1,
    Anaglyph = 2,
    Interlaced = 3,
    ReverseInterlaced = 4,
    CardboardVR = 5
};

// Which eye to render when 3d is off. 800px wide mode could be added here in the future, when
// implemented
enum class MonoRenderOption : u32 {
    LeftEye = 0,
    RightEye = 1,
};

enum class AudioEmulation : u32 {
    HLE = 0,
    LLE = 1,
    LLEMultithreaded = 2,
};

enum class TextureFilter : u32 {
    None = 0,
    Anime4K = 1,
    Bicubic = 2,
    NearestNeighbor = 3,
    ScaleForce = 4,
    xBRZ = 5,
};

namespace NativeButton {

enum Values {
    A,
    B,
    X,
    Y,
    Up,
    Down,
    Left,
    Right,
    L,
    R,
    Start,
    Select,
    Debug,
    Gpio14,

    ZL,
    ZR,

    Home,

    NumButtons,
};

constexpr int BUTTON_HID_BEGIN = A;
constexpr int BUTTON_IR_BEGIN = ZL;
constexpr int BUTTON_NS_BEGIN = Home;

constexpr int BUTTON_HID_END = BUTTON_IR_BEGIN;
constexpr int BUTTON_IR_END = BUTTON_NS_BEGIN;
constexpr int BUTTON_NS_END = NumButtons;

constexpr int NUM_BUTTONS_HID = BUTTON_HID_END - BUTTON_HID_BEGIN;
constexpr int NUM_BUTTONS_IR = BUTTON_IR_END - BUTTON_IR_BEGIN;
constexpr int NUM_BUTTONS_NS = BUTTON_NS_END - BUTTON_NS_BEGIN;

static const std::array<const char*, NumButtons> mapping = {{
    "button_a",
    "button_b",
    "button_x",
    "button_y",
    "button_up",
    "button_down",
    "button_left",
    "button_right",
    "button_l",
    "button_r",
    "button_start",
    "button_select",
    "button_debug",
    "button_gpio14",
    "button_zl",
    "button_zr",
    "button_home",
}};

} // namespace NativeButton

namespace NativeAnalog {
enum Values {
    CirclePad,
    CStick,
    NumAnalogs,
};

constexpr std::array<const char*, NumAnalogs> mapping = {{
    "circle_pad",
    "c_stick",
}};
} // namespace NativeAnalog

/** The Setting class is a simple resource manager. It defines a label and default value alongside
 * the actual value of the setting for simpler and less-error prone use with frontend
 * configurations. Specifying a default value and label is required. A minimum and maximum range can
 * be specified for sanitization.
 */
template <typename Type, bool ranged = false>
class Setting {
protected:
    Setting() = default;

    /**
     * Only sets the setting to the given initializer, leaving the other members to their default
     * initializers.
     *
     * @param global_val Initial value of the setting
     */
    explicit Setting(const Type& val) : value{val} {}

public:
    /**
     * Sets a default value, label, and setting value.
     *
     * @param default_val Intial value of the setting, and default value of the setting
     * @param name Label for the setting
     */
    explicit Setting(const Type& default_val, const std::string& name) requires(!ranged)
        : value{default_val}, default_value{default_val}, label{name} {}
    virtual ~Setting() = default;

    /**
     * Sets a default value, minimum value, maximum value, and label.
     *
     * @param default_val Intial value of the setting, and default value of the setting
     * @param min_val Sets the minimum allowed value of the setting
     * @param max_val Sets the maximum allowed value of the setting
     * @param name Label for the setting
     */
    explicit Setting(const Type& default_val, const Type& min_val, const Type& max_val,
                     const std::string& name) requires(ranged)
        : value{default_val},
          default_value{default_val}, maximum{max_val}, minimum{min_val}, label{name} {}

    /**
     *  Returns a reference to the setting's value.
     *
     * @returns A reference to the setting
     */
    [[nodiscard]] virtual const Type& GetValue() const {
        return value;
    }

    /**
     * Sets the setting to the given value.
     *
     * @param val The desired value
     */
    virtual void SetValue(const Type& val) {
        Type temp{ranged ? std::clamp(val, minimum, maximum) : val};
        std::swap(value, temp);
    }

    /**
     * Returns the value that this setting was created with.
     *
     * @returns A reference to the default value
     */
    [[nodiscard]] const Type& GetDefault() const {
        return default_value;
    }

    /**
     * Returns the label this setting was created with.
     *
     * @returns A reference to the label
     */
    [[nodiscard]] const std::string& GetLabel() const {
        return label;
    }

    /**
     * Assigns a value to the setting.
     *
     * @param val The desired setting value
     *
     * @returns A reference to the setting
     */
    virtual const Type& operator=(const Type& val) {
        Type temp{ranged ? std::clamp(val, minimum, maximum) : val};
        std::swap(value, temp);
        return value;
    }

    /**
     * Returns a reference to the setting.
     *
     * @returns A reference to the setting
     */
    explicit virtual operator const Type&() const {
        return value;
    }

protected:
    Type value{};               ///< The setting
    const Type default_value{}; ///< The default value
    const Type maximum{};       ///< Maximum allowed value of the setting
    const Type minimum{};       ///< Minimum allowed value of the setting
    const std::string label{};  ///< The setting's label
};

/**
 * The SwitchableSetting class is a slightly more complex version of the Setting class. This adds a
 * custom setting to switch to when a guest application specifically requires it. The effect is that
 * other components of the emulator can access the setting's intended value without any need for the
 * component to ask whether the custom or global setting is needed at the moment.
 *
 * By default, the global setting is used.
 */
template <typename Type, bool ranged = false>
class SwitchableSetting : virtual public Setting<Type, ranged> {
public:
    /**
     * Sets a default value, label, and setting value.
     *
     * @param default_val Intial value of the setting, and default value of the setting
     * @param name Label for the setting
     */
    explicit SwitchableSetting(const Type& default_val, const std::string& name) requires(!ranged)
        : Setting<Type>{default_val, name} {}
    virtual ~SwitchableSetting() = default;

    /**
     * Sets a default value, minimum value, maximum value, and label.
     *
     * @param default_val Intial value of the setting, and default value of the setting
     * @param min_val Sets the minimum allowed value of the setting
     * @param max_val Sets the maximum allowed value of the setting
     * @param name Label for the setting
     */
    explicit SwitchableSetting(const Type& default_val, const Type& min_val, const Type& max_val,
                               const std::string& name) requires(ranged)
        : Setting<Type, true>{default_val, min_val, max_val, name} {}

    /**
     * Tells this setting to represent either the global or custom setting when other member
     * functions are used.
     *
     * @param to_global Whether to use the global or custom setting.
     */
    void SetGlobal(bool to_global) {
        use_global = to_global;
    }

    /**
     * Returns whether this setting is using the global setting or not.
     *
     * @returns The global state
     */
    [[nodiscard]] bool UsingGlobal() const {
        return use_global;
    }

    /**
     * Returns either the global or custom setting depending on the values of this setting's global
     * state or if the global value was specifically requested.
     *
     * @param need_global Request global value regardless of setting's state; defaults to false
     *
     * @returns The required value of the setting
     */
    [[nodiscard]] virtual const Type& GetValue() const override {
        if (use_global) {
            return this->value;
        }
        return custom;
    }
    [[nodiscard]] virtual const Type& GetValue(bool need_global) const {
        if (use_global || need_global) {
            return this->value;
        }
        return custom;
    }

    /**
     * Sets the current setting value depending on the global state.
     *
     * @param val The new value
     */
    void SetValue(const Type& val) override {
        Type temp{ranged ? std::clamp(val, this->minimum, this->maximum) : val};
        if (use_global) {
            std::swap(this->value, temp);
        } else {
            std::swap(custom, temp);
        }
    }

    /**
     * Assigns the current setting value depending on the global state.
     *
     * @param val The new value
     *
     * @returns A reference to the current setting value
     */
    const Type& operator=(const Type& val) override {
        Type temp{ranged ? std::clamp(val, this->minimum, this->maximum) : val};
        if (use_global) {
            std::swap(this->value, temp);
            return this->value;
        }
        std::swap(custom, temp);
        return custom;
    }

    /**
     * Returns the current setting value depending on the global state.
     *
     * @returns A reference to the current setting value
     */
    virtual explicit operator const Type&() const override {
        if (use_global) {
            return this->value;
        }
        return custom;
    }

protected:
    bool use_global{true}; ///< The setting's global state
    Type custom{};         ///< The custom value of the setting
};

struct InputProfile {
    std::string name;
    std::array<std::string, NativeButton::NumButtons> buttons;
    std::array<std::string, NativeAnalog::NumAnalogs> analogs;
    std::string motion_device;
    std::string touch_device;
    bool use_touch_from_button;
    int touch_from_button_map_index;
    std::string udp_input_address;
    u16 udp_input_port;
    u8 udp_pad_index;
};

struct TouchFromButtonMap {
    std::string name;
    std::vector<std::string> buttons;
};

/// A special region value indicating that citra will automatically select a region
/// value to fit the region lockout info of the game
static constexpr s32 REGION_VALUE_AUTO_SELECT = -1;

struct Values {
    // Controls
    InputProfile current_input_profile;       ///< The current input profile
    int current_input_profile_index;          ///< The current input profile index
    std::vector<InputProfile> input_profiles; ///< The list of input profiles
    std::vector<TouchFromButtonMap> touch_from_button_maps;

    // Core
    Setting<bool> use_cpu_jit{true, "use_cpu_jit"};
    SwitchableSetting<s32, true> cpu_clock_percentage{100, 5, 400, "cpu_clock_percentage"};
    SwitchableSetting<bool> is_new_3ds{true, "is_new_3ds"};

    // Data Storage
    Setting<bool> use_virtual_sd{true, "use_virtual_sd"};
    Setting<bool> use_custom_storage{false, "use_custom_storage"};

    // System
    SwitchableSetting<s32> region_value{REGION_VALUE_AUTO_SELECT, "region_value"};
    Setting<InitClock> init_clock{InitClock::SystemTime, "init_clock"};
    Setting<u64> init_time{946681277ULL, "init_time"};
    Setting<s64> init_time_offset{0, "init_time_offset"};
    Setting<bool> plugin_loader_enabled{false, "plugin_loader"};
    Setting<bool> allow_plugin_loader{true, "allow_plugin_loader"};

    // Renderer
    SwitchableSetting<GraphicsAPI, true> graphics_api{GraphicsAPI::OpenGL, GraphicsAPI::Software,
                                                      GraphicsAPI::Vulkan, "graphics_api"};
    SwitchableSetting<u32> physical_device{0, "physical_device"};
    Setting<bool> use_gles{false, "use_gles"};
    Setting<bool> renderer_debug{false, "renderer_debug"};
    Setting<bool> dump_command_buffers{false, "dump_command_buffers"};
    SwitchableSetting<bool> spirv_shader_gen{true, "spirv_shader_gen"};
    SwitchableSetting<bool> async_shader_compilation{false, "async_shader_compilation"};
    SwitchableSetting<bool> async_presentation{true, "async_presentation"};
    SwitchableSetting<bool> use_hw_shader{true, "use_hw_shader"};
    SwitchableSetting<u32> shader_type{3, "shader_type"};
    SwitchableSetting<bool> use_disk_shader_cache{true, "use_disk_shader_cache"};
    SwitchableSetting<bool> shaders_accurate_mul{true, "shaders_accurate_mul"};
    SwitchableSetting<bool> use_vsync_new{true, "use_vsync_new"};
    Setting<bool> use_shader_jit{true, "use_shader_jit"};
    SwitchableSetting<u32, true> resolution_factor{1, 0, 10, "resolution_factor"};
    SwitchableSetting<u16, true> frame_limit{100, 0, 1000, "frame_limit"};
    SwitchableSetting<TextureFilter> texture_filter{TextureFilter::None, "texture_filter"};

    SwitchableSetting<LayoutOption> layout_option{LayoutOption::Default, "layout_option"};
    SwitchableSetting<bool> swap_screen{false, "swap_screen"};
    SwitchableSetting<bool> upright_screen{false, "upright_screen"};
    SwitchableSetting<float, true> large_screen_proportion{4.f, 1.f, 16.f,
                                                           "large_screen_proportion"};
    Setting<bool> custom_layout{false, "custom_layout"};
    Setting<u16> custom_top_left{0, "custom_top_left"};
    Setting<u16> custom_top_top{0, "custom_top_top"};
    Setting<u16> custom_top_right{400, "custom_top_right"};
    Setting<u16> custom_top_bottom{240, "custom_top_bottom"};
    Setting<u16> custom_bottom_left{40, "custom_bottom_left"};
    Setting<u16> custom_bottom_top{240, "custom_bottom_top"};
    Setting<u16> custom_bottom_right{360, "custom_bottom_right"};
    Setting<u16> custom_bottom_bottom{480, "custom_bottom_bottom"};
    Setting<u16> custom_second_layer_opacity{100, "custom_second_layer_opacity"};

    SwitchableSetting<float> bg_red{0.f, "bg_red"};
    SwitchableSetting<float> bg_green{0.f, "bg_green"};
    SwitchableSetting<float> bg_blue{0.f, "bg_blue"};

    SwitchableSetting<StereoRenderOption> render_3d{StereoRenderOption::Off, "render_3d"};
    SwitchableSetting<u32> factor_3d{0, "factor_3d"};
    SwitchableSetting<MonoRenderOption> mono_render_option{MonoRenderOption::LeftEye,
                                                           "mono_render_option"};

    Setting<u32> cardboard_screen_size{85, "cardboard_screen_size"};
    Setting<s32> cardboard_x_shift{0, "cardboard_x_shift"};
    Setting<s32> cardboard_y_shift{0, "cardboard_y_shift"};

    SwitchableSetting<bool> filter_mode{true, "filter_mode"};
    SwitchableSetting<std::string> pp_shader_name{"none (builtin)", "pp_shader_name"};
    SwitchableSetting<std::string> anaglyph_shader_name{"dubois (builtin)", "anaglyph_shader_name"};

    SwitchableSetting<bool> dump_textures{false, "dump_textures"};
    SwitchableSetting<bool> custom_textures{false, "custom_textures"};
    SwitchableSetting<bool> preload_textures{false, "preload_textures"};
    SwitchableSetting<bool> async_custom_loading{true, "async_custom_loading"};

    // Audio
    bool audio_muted;
    SwitchableSetting<AudioEmulation> audio_emulation{AudioEmulation::HLE, "audio_emulation"};
    SwitchableSetting<bool> enable_audio_stretching{true, "enable_audio_stretching"};
    SwitchableSetting<float, true> volume{1.f, 0.f, 1.f, "volume"};
    Setting<AudioCore::SinkType> output_type{AudioCore::SinkType::CoreAudio, "output_type"};
    Setting<std::string> output_device{"auto", "output_device"};
    Setting<AudioCore::InputType> input_type{AudioCore::InputType::Auto, "input_type"};
    Setting<std::string> input_device{"auto", "input_device"};

    // Camera
    std::array<std::string, Service::CAM::NumCameras> camera_name;
    std::array<std::string, Service::CAM::NumCameras> camera_config;
    std::array<int, Service::CAM::NumCameras> camera_flip;

    // Debugging
    bool record_frame_times;
    std::unordered_map<std::string, bool> lle_modules;
    Setting<bool> use_gdbstub{false, "use_gdbstub"};
    Setting<u16> gdbstub_port{24689, "gdbstub_port"};

    // buttons
    bool buttons_initialized = false;
    bool home_button_initialized = false;
    bool extra_buttons_initialized = false;

    bool skip_buttons = false;
    bool skip_home_button = false;
    bool skip_extra_buttons = false;
    std::unique_ptr<Input::ButtonDevice> m_buttonA;
    std::unique_ptr<Input::ButtonDevice> m_buttonB;
    std::unique_ptr<Input::ButtonDevice> m_buttonX;
    std::unique_ptr<Input::ButtonDevice> m_buttonY;
    std::unique_ptr<Input::ButtonDevice> m_buttonL;
    std::unique_ptr<Input::ButtonDevice> m_buttonR;
    std::unique_ptr<Input::ButtonDevice> m_buttonStart;
    std::unique_ptr<Input::ButtonDevice> m_buttonSelect;
    std::unique_ptr<Input::ButtonDevice> m_buttonDpadUp;
    std::unique_ptr<Input::ButtonDevice> m_buttonDpadDown;
    std::unique_ptr<Input::ButtonDevice> m_buttonDpadLeft;
    std::unique_ptr<Input::ButtonDevice> m_buttonDpadRight;
    std::unique_ptr<Input::ButtonDevice> m_buttonDummy;
    std::unique_ptr<Input::ButtonDevice> m_buttonDummy2;
    std::unique_ptr<Input::AnalogDevice> circle_pad;
    std::unique_ptr<Input::MotionDevice> motion_device;
    std::unique_ptr<Input::TouchDevice> touch_device;
    std::unique_ptr<Input::TouchDevice> touch_btn_device;
    
    std::unique_ptr<Input::ButtonDevice> home_button;
    
    std::unique_ptr<Input::ButtonDevice> zl;
    std::unique_ptr<Input::ButtonDevice> zr;
    std::unique_ptr<Input::AnalogDevice> c_stick;
    
    // Miscellaneous
    SwitchableSetting<bool> isReloading{false, "isReloading"};
    Setting<std::string> log_filter{"*:Info", "log_filter"};
    SwitchableSetting<bool> color_attachment{true, "color_attachment"};
    // Video Dumping
    std::string output_format;
    std::string format_options;

    std::string video_encoder;
    std::string video_encoder_options;
    u64 video_bitrate;

    std::string audio_encoder;
    std::string audio_encoder_options;
    u64 audio_bitrate;
};

extern Values values;

bool IsConfiguringGlobal();
void SetConfiguringGlobal(bool is_global);

float Volume();

void Apply();
void LogSettings();

// Restore the global state of all applicable settings in the Values struct
void RestoreGlobalState(bool is_powered_on);

// Input profiles
void LoadProfile(int index);
void SaveProfile(int index);
void CreateProfile(std::string name);
void DeleteProfile(int index);
void RenameCurrentProfile(std::string new_name);

} // namespace Settings
