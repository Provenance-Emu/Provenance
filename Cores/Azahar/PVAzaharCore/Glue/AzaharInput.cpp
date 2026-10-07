#include <array>
#include <atomic>
#include <memory>
#include <tuple>
#include "AzaharInput.h"
#include "common/param_package.h"
#include "common/settings.h"
#include "core/frontend/input.h"

namespace {
std::array<std::atomic<bool>, Settings::NativeButton::NumButtons> g_buttons{};
std::array<std::atomic<float>, Settings::NativeAnalog::NumAnalogs> g_axis_x{};
std::array<std::atomic<float>, Settings::NativeAnalog::NumAnalogs> g_axis_y{};

class Button final : public Input::ButtonDevice {
public:
    explicit Button(int index) : index_(index) {}
    bool GetStatus() const override { return g_buttons[index_].load(std::memory_order_relaxed); }
private:
    int index_;
};

class Analog final : public Input::AnalogDevice {
public:
    explicit Analog(int index) : index_(index) {}
    std::tuple<float, float> GetStatus() const override {
        return {g_axis_x[index_].load(std::memory_order_relaxed), g_axis_y[index_].load(std::memory_order_relaxed)};
    }
private:
    int index_;
};

class ButtonFactory final : public Input::Factory<Input::ButtonDevice> {
public:
    std::unique_ptr<Input::ButtonDevice> Create(const Common::ParamPackage& params) override {
        return std::make_unique<Button>(params.Get("button", 0));
    }
};
class AnalogFactory final : public Input::Factory<Input::AnalogDevice> {
public:
    std::unique_ptr<Input::AnalogDevice> Create(const Common::ParamPackage& params) override {
        return std::make_unique<Analog>(params.Get("axis", 0));
    }
};
constexpr const char* kEngine = "provenance";
} // namespace

namespace AzaharInput {
void RegisterFactories() {
    Input::RegisterFactory<Input::ButtonDevice>(kEngine, std::make_shared<ButtonFactory>());
    Input::RegisterFactory<Input::AnalogDevice>(kEngine, std::make_shared<AnalogFactory>());
}
void UnregisterFactories() {
    Input::UnregisterFactory<Input::ButtonDevice>(kEngine);
    Input::UnregisterFactory<Input::AnalogDevice>(kEngine);
}
void ApplyProfile() {
    auto& profile = Settings::values.current_input_profile;
    for (int i = 0; i < Settings::NativeButton::NumButtons; ++i)
        profile.buttons[i] = Common::ParamPackage{{"engine", kEngine}, {"button", std::to_string(i)}}.Serialize();
    for (int i = 0; i < Settings::NativeAnalog::NumAnalogs; ++i)
        profile.analogs[i] = Common::ParamPackage{{"engine", kEngine}, {"axis", std::to_string(i)}}.Serialize();
    profile.motion_device = "engine:motion_emu";
    profile.touch_device = "engine:emu_window";
}
void SetButton(int b, bool pressed) {
    if (b >= 0 && b < Settings::NativeButton::NumButtons) g_buttons[b].store(pressed, std::memory_order_relaxed);
}
void SetAnalog(int a, float x, float y) {
    if (a >= 0 && a < Settings::NativeAnalog::NumAnalogs) {
        g_axis_x[a].store(x, std::memory_order_relaxed);
        g_axis_y[a].store(y, std::memory_order_relaxed);
    }
}
} // namespace AzaharInput
