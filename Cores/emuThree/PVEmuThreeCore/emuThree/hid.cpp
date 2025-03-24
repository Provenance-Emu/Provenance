// Copyright 2015 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes: Check for isReloaded Setting / add Controller Refresh to Reload

#include <algorithm>
#include <cmath>
#include <numeric>
#include <boost/serialization/array.hpp>
#include <boost/serialization/shared_ptr.hpp>
#include <boost/serialization/unique_ptr.hpp>
#include "common/archives.h"
#include "common/logging/log.h"
#include "core/3ds.h"
#include "core/core.h"
#include "core/hle/ipc_helpers.h"
#include "core/hle/kernel/event.h"
#include "core/hle/kernel/handle_table.h"
#include "core/hle/kernel/shared_memory.h"
#include "core/hle/kernel/shared_page.h"
#include "core/hle/service/hid/hid.h"
#include "core/hle/service/hid/hid_spvr.h"
#include "core/hle/service/hid/hid_user.h"
#include "core/hle/service/service.h"
#include "core/movie.h"
#include "video_core/video_core.h"

SERVICE_CONSTRUCT_IMPL(Service::HID::Module)
SERIALIZE_EXPORT_IMPL(Service::HID::Module)

namespace Service::HID {

template <class Archive>
void Module::serialize(Archive& ar, const unsigned int file_version) {
    ar& shared_mem;
    ar& event_pad_or_touch_1;
    ar& event_pad_or_touch_2;
    ar& event_accelerometer;
    ar& event_gyroscope;
    ar& event_debug_pad;
    ar& next_pad_index;
    ar& next_touch_index;
    ar& next_accelerometer_index;
    ar& next_gyroscope_index;
    ar& enable_accelerometer_count;
    ar& enable_gyroscope_count;
    if (Archive::is_loading::value) {
        LoadInputDevices();
    }
    if (file_version >= 1) {
        ar& state.hex;
    }
    // Update events are set in the constructor
    // Devices are set from the implementation (and are stateless afaik)
}
SERIALIZE_IMPL(Module)

constexpr float accelerometer_coef = 512.0f; // measured from hw test result
constexpr float gyroscope_coef = 14.375f; // got from hwtest GetGyroscopeLowRawToDpsCoefficient call

DirectionState GetStickDirectionState(s16 circle_pad_x, s16 circle_pad_y) {
    // 30 degree and 60 degree are angular thresholds for directions
    constexpr float TAN30 = 0.577350269f;
    constexpr float TAN60 = 1 / TAN30;
    // a circle pad radius greater than 40 will trigger circle pad direction
    constexpr int CIRCLE_PAD_THRESHOLD_SQUARE = 40 * 40;
    DirectionState state{false, false, false, false};

    if (circle_pad_x * circle_pad_x + circle_pad_y * circle_pad_y > CIRCLE_PAD_THRESHOLD_SQUARE) {
        float t = std::abs(static_cast<float>(circle_pad_y) / circle_pad_x);

        if (circle_pad_x != 0 && t < TAN60) {
            if (circle_pad_x > 0)
                state.right = true;
            else
                state.left = true;
        }

        if (circle_pad_x == 0 || t > TAN30) {
            if (circle_pad_y > 0)
                state.up = true;
            else
                state.down = true;
        }
    }

    return state;
}

void Module::LoadInputDevices() {
    if (Settings::values.buttons_initialized || Settings::values.skip_buttons) {
        return;
    } else {
        Settings::values.m_buttonA = Input::CreateDevice<Input::ButtonDevice>(
                                                                              Settings::values.current_input_profile.buttons[Settings::NativeButton::A]);
        Settings::values.m_buttonB = Input::CreateDevice<Input::ButtonDevice>(
                                                                              Settings::values.current_input_profile.buttons[Settings::NativeButton::B]);
        Settings::values.m_buttonX = Input::CreateDevice<Input::ButtonDevice>(
                                                                              Settings::values.current_input_profile.buttons[Settings::NativeButton::X]);
        Settings::values.m_buttonY = Input::CreateDevice<Input::ButtonDevice>(
                                                                              Settings::values.current_input_profile.buttons[Settings::NativeButton::Y]);
        Settings::values.m_buttonL = Input::CreateDevice<Input::ButtonDevice>(
                                                                              Settings::values.current_input_profile.buttons[Settings::NativeButton::L]);
        Settings::values.m_buttonR = Input::CreateDevice<Input::ButtonDevice>(
                                                                              Settings::values.current_input_profile.buttons[Settings::NativeButton::R]);
        Settings::values.m_buttonStart = Input::CreateDevice<Input::ButtonDevice>(
                                                                                  Settings::values.current_input_profile.buttons[Settings::NativeButton::Start]);
        Settings::values.m_buttonSelect = Input::CreateDevice<Input::ButtonDevice>(
                                                                                   Settings::values.current_input_profile.buttons[Settings::NativeButton::Select]);
        Settings::values.m_buttonDpadUp = Input::CreateDevice<Input::ButtonDevice>(
                                                                                   Settings::values.current_input_profile.buttons[Settings::NativeButton::Up]);
        Settings::values.m_buttonDpadDown = Input::CreateDevice<Input::ButtonDevice>(
                                                                                     Settings::values.current_input_profile.buttons[Settings::NativeButton::Down]);
        Settings::values.m_buttonDpadLeft = Input::CreateDevice<Input::ButtonDevice>(
                                                                                     Settings::values.current_input_profile.buttons[Settings::NativeButton::Left]);
        Settings::values.m_buttonDpadRight = Input::CreateDevice<Input::ButtonDevice>(
                                                                                      Settings::values.current_input_profile.buttons[Settings::NativeButton::Right]);
        Settings::values.m_buttonDummy = Input::CreateDevice<Input::ButtonDevice>(
                                                                                  Settings::values.current_input_profile.buttons[Settings::NativeButton::Debug]);
        Settings::values.circle_pad = Input::CreateDevice<Input::AnalogDevice>(
            Settings::values.current_input_profile.analogs[Settings::NativeAnalog::CirclePad]);
        Settings::values.motion_device = Input::CreateDevice<Input::MotionDevice>(
            Settings::values.current_input_profile.motion_device);
        Settings::values.touch_device = Input::CreateDevice<Input::TouchDevice>(
            Settings::values.current_input_profile.touch_device);
        if (Settings::values.current_input_profile.use_touch_from_button) {
            Settings::values.touch_btn_device = Input::CreateDevice<Input::TouchDevice>("engine:touch_from_button");
        } else {
            Settings::values.touch_btn_device.reset();
        }
        
        // enable accelerometer
        enable_accelerometer_count=1;
        enable_gyroscope_count=1;
        
        Settings::values.buttons_initialized=true;
    }
}

void Module::UpdatePadCallback(std::uintptr_t user_data, s64 cycles_late) {
    if (Settings::values.isReloading || Settings::values.skip_buttons)
        return;
    
    SharedMem* mem = reinterpret_cast<SharedMem*>(shared_mem->GetPointer());
    if (is_device_reload_pending.exchange(false)) {
        LoadInputDevices();
    }

    using namespace Settings::NativeButton;
    state.a.Assign(Settings::values.m_buttonA->GetStatus());
    state.b.Assign(Settings::values.m_buttonB->GetStatus());
    state.x.Assign(Settings::values.m_buttonX->GetStatus());
    state.y.Assign(Settings::values.m_buttonY->GetStatus());
    state.right.Assign(Settings::values.m_buttonDpadRight->GetStatus());
    state.left.Assign(Settings::values.m_buttonDpadLeft->GetStatus());
    state.up.Assign(Settings::values.m_buttonDpadUp->GetStatus());
    state.down.Assign(Settings::values.m_buttonDpadDown->GetStatus());
    state.l.Assign(Settings::values.m_buttonL->GetStatus());
    state.r.Assign(Settings::values.m_buttonR->GetStatus());
    state.start.Assign(Settings::values.m_buttonStart->GetStatus());
    state.select.Assign(Settings::values.m_buttonSelect->GetStatus());
    //state.debug.Assign(Settings::values.m_buttonDummy->GetStatus());
    //state.gpio14.Assign(Settings::values.m_buttonDummy->GetStatus());

    // Get current circle pad position and update circle pad direction
    float circle_pad_x_f, circle_pad_y_f;
    std::tie(circle_pad_x_f, circle_pad_y_f) = Settings::values.circle_pad->GetStatus();

    // xperia64: 0x9A seems to be the calibrated limit of the circle pad
    // Verified by using Input Redirector with very large-value digital inputs
    // on the circle pad and calibrating using the system settings application
    constexpr int MAX_CIRCLEPAD_POS = 0x9A; // Max value for a circle pad position

    // These are rounded rather than truncated on actual hardware
    s16 circle_pad_new_x = static_cast<s16>(std::roundf(circle_pad_x_f * MAX_CIRCLEPAD_POS));
    s16 circle_pad_new_y = static_cast<s16>(std::roundf(circle_pad_y_f * MAX_CIRCLEPAD_POS));
    s16 circle_pad_x =
        (circle_pad_new_x + std::accumulate(circle_pad_old_x.begin(), circle_pad_old_x.end(), 0)) /
        CIRCLE_PAD_AVERAGING;
    s16 circle_pad_y =
        (circle_pad_new_y + std::accumulate(circle_pad_old_y.begin(), circle_pad_old_y.end(), 0)) /
        CIRCLE_PAD_AVERAGING;
    circle_pad_old_x.erase(circle_pad_old_x.begin());
    circle_pad_old_x.push_back(circle_pad_new_x);
    circle_pad_old_y.erase(circle_pad_old_y.begin());
    circle_pad_old_y.push_back(circle_pad_new_y);

    Core::Movie::GetInstance().HandlePadAndCircleStatus(state, circle_pad_x, circle_pad_y);

    const DirectionState direction = GetStickDirectionState(circle_pad_x, circle_pad_y);
    state.circle_up.Assign(direction.up);
    state.circle_down.Assign(direction.down);
    state.circle_left.Assign(direction.left);
    state.circle_right.Assign(direction.right);

    mem->pad.current_state.hex = state.hex;
    mem->pad.index = next_pad_index;
    next_pad_index = (next_pad_index + 1) % mem->pad.entries.size();

    // Get the previous Pad state
    u32 last_entry_index = (mem->pad.index - 1) % mem->pad.entries.size();
    PadState old_state = mem->pad.entries[last_entry_index].current_state;

    // Compute bitmask with 1s for bits different from the old state
    PadState changed = {{(state.hex ^ old_state.hex)}};

    // Get the current Pad entry
    PadDataEntry& pad_entry = mem->pad.entries[mem->pad.index];

    // Update entry properties
    pad_entry.current_state.hex = state.hex;
    pad_entry.delta_additions.hex = changed.hex & state.hex;
    pad_entry.delta_removals.hex = changed.hex & old_state.hex;
    pad_entry.circle_pad_x = circle_pad_x;
    pad_entry.circle_pad_y = circle_pad_y;

    // If we just updated index 0, provide a new timestamp
    if (mem->pad.index == 0) {
        mem->pad.index_reset_ticks_previous = mem->pad.index_reset_ticks;
        mem->pad.index_reset_ticks = (s64)system.CoreTiming().GetTicks();
    }

    mem->touch.index = next_touch_index;
    next_touch_index = (next_touch_index + 1) % mem->touch.entries.size();

    // Get the current touch entry
    TouchDataEntry& touch_entry = mem->touch.entries[mem->touch.index];
    bool pressed = false;
    float x, y;
    std::tie(x, y, pressed) = Settings::values.touch_device->GetStatus();
    if (!pressed && Settings::values.touch_btn_device) {
        std::tie(x, y, pressed) = Settings::values.touch_btn_device->GetStatus();
    }
    touch_entry.x = static_cast<u16>(x * Core::kScreenBottomWidth);
    touch_entry.y = static_cast<u16>(y * Core::kScreenBottomHeight);
    touch_entry.valid.Assign(pressed ? 1 : 0);

    Core::Movie::GetInstance().HandleTouchStatus(touch_entry);

    // TODO(bunnei): We're not doing anything with offset 0xA8 + 0x18 of HID SharedMemory, which
    // supposedly is "Touch-screen entry, which contains the raw coordinate data prior to being
    // converted to pixel coordinates." (http://3dbrew.org/wiki/HID_Shared_Memory#Offset_0xA8).

    // If we just updated index 0, provide a new timestamp
    if (mem->touch.index == 0) {
        mem->touch.index_reset_ticks_previous = mem->touch.index_reset_ticks;
        mem->touch.index_reset_ticks = (s64)system.CoreTiming().GetTicks();
    }

    // Signal both handles when there's an update to Pad or touch
    event_pad_or_touch_1->Signal();
    event_pad_or_touch_2->Signal();

    // TODO(xperia64): How the 3D Slider is updated by the HID module needs to be RE'd
    // and possibly moved to its own Core::Timing event.
    mem->pad.sliderstate_3d = (Settings::values.factor_3d.GetValue() / 100.0f);
    system.Kernel().GetSharedPageHandler().Set3DSlider(Settings::values.factor_3d.GetValue() /
                                                       100.0f);

    // Reschedule recurrent event
    system.CoreTiming().ScheduleEvent(pad_update_ticks - cycles_late, pad_update_event);
}

void Module::UpdateAccelerometerCallback(std::uintptr_t user_data, s64 cycles_late) {
    if (Settings::values.isReloading || Settings::values.skip_buttons)
        return;
    SharedMem* mem = reinterpret_cast<SharedMem*>(shared_mem->GetPointer());

    mem->accelerometer.index = next_accelerometer_index;
    next_accelerometer_index = (next_accelerometer_index + 1) % mem->accelerometer.entries.size();

    Common::Vec3<float> accel;
    std::tie(accel, std::ignore) = Settings::values.motion_device->GetStatus();
    accel *= accelerometer_coef;
    //if (accel.x != 0 || accel.y != 0 || accel.z != 0)
    //    printf("Accel X %f Y %f Z %f\n", accel.x, accel.y, accel.z);
    // TODO(wwylele): do a time stretch like the one in UpdateGyroscopeCallback
    // The time stretch formula should be like
    // stretched_vector = (raw_vector - gravity) * stretch_ratio + gravity

    AccelerometerDataEntry& accelerometer_entry =
        mem->accelerometer.entries[mem->accelerometer.index];

    accelerometer_entry.x = static_cast<s16>(accel.x);
    accelerometer_entry.y = static_cast<s16>(accel.y);
    accelerometer_entry.z = static_cast<s16>(accel.z);

    Core::Movie::GetInstance().HandleAccelerometerStatus(accelerometer_entry);
    // Make up "raw" entry
    // TODO(wwylele):
    // From hardware testing, the raw_entry values are approximately, but not exactly, as twice as
    // corresponding entries (or with a minus sign). It may caused by system calibration to the
    // accelerometer. Figure out how it works, or, if no game reads raw_entry, the following three
    // lines can be removed and leave raw_entry unimplemented.
    mem->accelerometer.raw_entry.x = -2 * accelerometer_entry.x;
    mem->accelerometer.raw_entry.z = 2 * accelerometer_entry.y;
    mem->accelerometer.raw_entry.y = -2 * accelerometer_entry.z;

    // If we just updated index 0, provide a new timestamp
    if (mem->accelerometer.index == 0) {
        mem->accelerometer.index_reset_ticks_previous = mem->accelerometer.index_reset_ticks;
        mem->accelerometer.index_reset_ticks = (s64)system.CoreTiming().GetTicks();
    }

    event_accelerometer->Signal();

    // Reschedule recurrent event
    system.CoreTiming().ScheduleEvent(accelerometer_update_ticks - cycles_late,
                                      accelerometer_update_event);
}

void Module::UpdateGyroscopeCallback(std::uintptr_t user_data, s64 cycles_late) {
    if (Settings::values.isReloading || Settings::values.skip_buttons)
        return;
    SharedMem* mem = reinterpret_cast<SharedMem*>(shared_mem->GetPointer());

    mem->gyroscope.index = next_gyroscope_index;
    next_gyroscope_index = (next_gyroscope_index + 1) % mem->gyroscope.entries.size();

    GyroscopeDataEntry& gyroscope_entry = mem->gyroscope.entries[mem->gyroscope.index];

    Common::Vec3<float> gyro;
    std::tie(std::ignore, gyro) = Settings::values.motion_device->GetStatus();
    double stretch = system.perf_stats->GetLastFrameTimeScale();
    gyro *= gyroscope_coef * static_cast<float>(stretch);
    //if (gyro.x != 0 || gyro.y != 0 || gyro.z != 0)
    //    printf("Gyro X %f Y %f Z %f\n", gyro.x, gyro.y, gyro.z);
    gyroscope_entry.x = static_cast<s16>(gyro.x);
    gyroscope_entry.y = static_cast<s16>(gyro.y);
    gyroscope_entry.z = static_cast<s16>(gyro.z);

    Core::Movie::GetInstance().HandleGyroscopeStatus(gyroscope_entry);

    // Make up "raw" entry
    mem->gyroscope.raw_entry.x = gyroscope_entry.x;
    mem->gyroscope.raw_entry.z = -gyroscope_entry.y;
    mem->gyroscope.raw_entry.y = gyroscope_entry.z;
    // If we just updated index 0, provide a new timestamp
    if (mem->gyroscope.index == 0) {
        mem->gyroscope.index_reset_ticks_previous = mem->gyroscope.index_reset_ticks;
        mem->gyroscope.index_reset_ticks = (s64)system.CoreTiming().GetTicks();
    }
    event_gyroscope->Signal();

    // Reschedule recurrent event
    system.CoreTiming().ScheduleEvent(gyroscope_update_ticks - cycles_late, gyroscope_update_event);
}

void Module::Interface::GetIPCHandles(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0xA, 0, 0};
    IPC::RequestBuilder rb = rp.MakeBuilder(1, 7);
    rb.Push(RESULT_SUCCESS);
    rb.PushCopyObjects(hid->shared_mem, hid->event_pad_or_touch_1, hid->event_pad_or_touch_2,
                       hid->event_accelerometer, hid->event_gyroscope, hid->event_debug_pad);
}

void Module::Interface::EnableAccelerometer(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0x11, 0, 0};

    ++hid->enable_accelerometer_count;

    // Schedules the accelerometer update event if the accelerometer was just enabled
    if (hid->enable_accelerometer_count == 1) {
        hid->system.CoreTiming().ScheduleEvent(accelerometer_update_ticks,
                                               hid->accelerometer_update_event);
    }

    IPC::RequestBuilder rb = rp.MakeBuilder(1, 0);
    rb.Push(RESULT_SUCCESS);

    LOG_DEBUG(Service_HID, "called");
}

void Module::Interface::DisableAccelerometer(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0x12, 0, 0};

    --hid->enable_accelerometer_count;

    // Unschedules the accelerometer update event if the accelerometer was just disabled
    if (hid->enable_accelerometer_count == 0) {
        hid->system.CoreTiming().UnscheduleEvent(hid->accelerometer_update_event, 0);
    }

    IPC::RequestBuilder rb = rp.MakeBuilder(1, 0);
    rb.Push(RESULT_SUCCESS);

    LOG_DEBUG(Service_HID, "called");
}

void Module::Interface::EnableGyroscopeLow(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0x13, 0, 0};

    ++hid->enable_gyroscope_count;

    // Schedules the gyroscope update event if the gyroscope was just enabled
    if (hid->enable_gyroscope_count == 1) {
        hid->system.CoreTiming().ScheduleEvent(gyroscope_update_ticks, hid->gyroscope_update_event);
    }

    IPC::RequestBuilder rb = rp.MakeBuilder(1, 0);
    rb.Push(RESULT_SUCCESS);

    LOG_DEBUG(Service_HID, "called");
}

void Module::Interface::DisableGyroscopeLow(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0x14, 0, 0};

    --hid->enable_gyroscope_count;

    // Unschedules the gyroscope update event if the gyroscope was just disabled
    if (hid->enable_gyroscope_count == 0) {
        hid->system.CoreTiming().UnscheduleEvent(hid->gyroscope_update_event, 0);
    }

    IPC::RequestBuilder rb = rp.MakeBuilder(1, 0);
    rb.Push(RESULT_SUCCESS);

    LOG_DEBUG(Service_HID, "called");
}

void Module::Interface::GetGyroscopeLowRawToDpsCoefficient(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0x15, 0, 0};

    IPC::RequestBuilder rb = rp.MakeBuilder(2, 0);
    rb.Push(RESULT_SUCCESS);
    rb.Push(gyroscope_coef);
}

void Module::Interface::GetGyroscopeLowCalibrateParam(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0x16, 0, 0};

    IPC::RequestBuilder rb = rp.MakeBuilder(6, 0);
    rb.Push(RESULT_SUCCESS);

    const s16 param_unit = 6700; // an approximate value taken from hw
    GyroscopeCalibrateParam param = {
        {0, param_unit, -param_unit},
        {0, param_unit, -param_unit},
        {0, param_unit, -param_unit},
    };
    rb.PushRaw(param);

    LOG_WARNING(Service_HID, "(STUBBED) called");
}

void Module::Interface::GetSoundVolume(Kernel::HLERequestContext& ctx) {
    IPC::RequestParser rp{ctx, 0x17, 0, 0};

    const u8 volume = static_cast<u8>(0x3F * Settings::values.volume.GetValue());

    IPC::RequestBuilder rb = rp.MakeBuilder(2, 0);
    rb.Push(RESULT_SUCCESS);
    rb.Push(volume);
}

Module::Interface::Interface(std::shared_ptr<Module> hid, const char* name, u32 max_session)
    : ServiceFramework(name, max_session), hid(std::move(hid)) {}

std::shared_ptr<Module> Module::Interface::GetModule() const {
    return hid;
}

Module::Module(Core::System& system) : system(system) {
    using namespace Kernel;

    shared_mem =
        system.Kernel()
            .CreateSharedMemory(nullptr, 0x1000, MemoryPermission::ReadWrite,
                                MemoryPermission::Read, 0, MemoryRegion::BASE, "HID:SharedMemory")
            .Unwrap();

    // Create event handles
    event_pad_or_touch_1 = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventPadOrTouch1");
    event_pad_or_touch_2 = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventPadOrTouch2");
    event_accelerometer = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventAccelerometer");
    event_gyroscope = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventGyroscope");
    event_debug_pad = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventDebugPad");

    // Register update callbacks
    Core::Timing& timing = system.CoreTiming();
    pad_update_event = timing.RegisterEvent("HID::UpdatePadCallback",
                                            [this](std::uintptr_t user_data, s64 cycles_late) {
                                                UpdatePadCallback(user_data, cycles_late);
                                            });
    accelerometer_update_event = timing.RegisterEvent(
        "HID::UpdateAccelerometerCallback", [this](std::uintptr_t user_data, s64 cycles_late) {
            UpdateAccelerometerCallback(user_data, cycles_late);
        });
    gyroscope_update_event = timing.RegisterEvent(
        "HID::UpdateGyroscopeCallback", [this](std::uintptr_t user_data, s64 cycles_late) {
            UpdateGyroscopeCallback(user_data, cycles_late);
        });

    timing.ScheduleEvent(pad_update_ticks, pad_update_event);
    timing.ScheduleEvent(accelerometer_update_ticks, accelerometer_update_event);
    timing.ScheduleEvent(gyroscope_update_ticks, gyroscope_update_event);
}

void Module::ReloadInputDevices() {
    is_device_reload_pending.store(true);
    
    using namespace Kernel;

    // Create event handles
    event_pad_or_touch_1 = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventPadOrTouch1");
    event_pad_or_touch_2 = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventPadOrTouch2");
    event_accelerometer = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventAccelerometer");
    event_gyroscope = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventGyroscope");
    event_debug_pad = system.Kernel().CreateEvent(ResetType::OneShot, "HID:EventDebugPad");

    // Register update callbacks
    Core::Timing& timing = system.CoreTiming();
    pad_update_event = timing.RegisterEvent("HID::UpdatePadCallback",
                                            [this](std::uintptr_t user_data, s64 cycles_late) {
                                                UpdatePadCallback(user_data, cycles_late);
                                            });
    accelerometer_update_event = timing.RegisterEvent(
        "HID::UpdateAccelerometerCallback", [this](std::uintptr_t user_data, s64 cycles_late) {
            UpdateAccelerometerCallback(user_data, cycles_late);
        });
    gyroscope_update_event = timing.RegisterEvent(
        "HID::UpdateGyroscopeCallback", [this](std::uintptr_t user_data, s64 cycles_late) {
            UpdateGyroscopeCallback(user_data, cycles_late);
        });

    timing.ScheduleEvent(pad_update_ticks, pad_update_event);
    timing.ScheduleEvent(accelerometer_update_ticks, accelerometer_update_event);
    timing.ScheduleEvent(gyroscope_update_ticks, gyroscope_update_event);
}

const PadState& Module::GetState() const {
    return state;
}

std::shared_ptr<Module> GetModule(Core::System& system) {
    auto hid = system.ServiceManager().GetService<Service::HID::Module::Interface>("hid:USER");
    if (!hid)
        return nullptr;
    return hid->GetModule();
}

void InstallInterfaces(Core::System& system) {
    auto& service_manager = system.ServiceManager();
    auto hid = std::make_shared<Module>(system);
    std::make_shared<User>(hid)->InstallAsService(service_manager);
    std::make_shared<Spvr>(hid)->InstallAsService(service_manager);
}

} // namespace Service::HID
