// Copyright 2017 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes: Check for isReloaded/isInitialized state

#include "common/alignment.h"
#include "common/settings.h"
#include "common/string_util.h"
#include "core/core.h"
#include "core/core_timing.h"
#include "core/hle/service/ir/extra_hid.h"
#include "core/movie.h"

namespace Service::IR {

enum class RequestID : u8 {
    /**
     * ConfigureHIDPolling request
     * Starts HID input polling, or changes the polling interval if it is already started.
     *  Inputs:
     *     byte 0: request ID
     *     byte 1: polling interval in ms
     *     byte 2: unknown
     */
    ConfigureHIDPolling = 1,

    /**
     * ReadCalibrationData request
     * Reads the calibration data stored in circle pad pro.
     *  Inputs:
     *     byte 0: request ID
     *     byte 1: expected response time in ms?
     *     byte 2-3: data offset (aligned to 0x10)
     *     byte 4-5: data size (aligned to 0x10)
     */
    ReadCalibrationData = 2,

    // TODO(wwylele): there are three more request types (id = 3, 4 and 5)
};

enum class ResponseID : u8 {

    /**
     * PollHID response
     * Sends current HID status
     *  Output:
     *     byte 0: response ID
     *     byte 1-3: Right circle pad position. This three bytes are two little-endian 12-bit
     *         fields. The first one is for x-axis and the second one is for y-axis.
     *     byte 4: bit[0:4] battery level; bit[5] ZL button; bit[6] ZR button; bit[7] R button
     *         Note that for the three button fields, the bit is set when the button is NOT pressed.
     *     byte 5: unknown
     */
    PollHID = 0x10,

    /**
     * ReadCalibrationData response
     * Sends the calibration data reads from circle pad pro.
     *  Output:
     *     byte 0: resonse ID
     *     byte 1-2: data offset (aligned to 0x10)
     *     byte 3-4: data size (aligned to 0x10)
     *     byte 5-...: calibration data
     */
    ReadCalibrationData = 0x11,
};

ExtraHID::ExtraHID(SendFunc send_func, Core::Timing& timing) : IRDevice(send_func), timing(timing) {
    LoadInputDevices();

    // The data below was retrieved from a New 3DS
    // TODO(wwylele): this data is probably writable (via request 3?) and thus should be saved to
    // and loaded from somewhere.
    calibration_data = std::array<u8, 0x40>{{
        // 0x00
        0x00,
        0x00,
        0x08,
        0x80,
        0x85,
        0xEB,
        0x11,
        0x3F,
        // 0x08
        0x85,
        0xEB,
        0x11,
        0x3F,
        0xFF,
        0xFF,
        0xFF,
        0xF5,
        // 0x10
        0xFF,
        0x00,
        0x08,
        0x80,
        0x85,
        0xEB,
        0x11,
        0x3F,
        // 0x18
        0x85,
        0xEB,
        0x11,
        0x3F,
        0xFF,
        0xFF,
        0xFF,
        0x65,
        // 0x20
        0xFF,
        0x00,
        0x08,
        0x80,
        0x85,
        0xEB,
        0x11,
        0x3F,
        // 0x28
        0x85,
        0xEB,
        0x11,
        0x3F,
        0xFF,
        0xFF,
        0xFF,
        0x65,
        // 0x30
        0xFF,
        0x00,
        0x08,
        0x80,
        0x85,
        0xEB,
        0x11,
        0x3F,
        // 0x38
        0x85,
        0xEB,
        0x11,
        0x3F,
        0xFF,
        0xFF,
        0xFF,
        0x65,
    }};

    hid_polling_callback_id =
        timing.RegisterEvent("ExtraHID::SendHIDStatus", [this](u64, s64 cycles_late) {
            SendHIDStatus();
            this->timing.ScheduleEvent(msToCycles(hid_period) - cycles_late,
                                       hid_polling_callback_id);
        });
}

ExtraHID::~ExtraHID() {
    OnDisconnect();
}

void ExtraHID::OnConnect() {}

void ExtraHID::OnDisconnect() {
    timing.UnscheduleEvent(hid_polling_callback_id, 0);
}

void ExtraHID::HandleConfigureHIDPollingRequest(const std::vector<u8>& request) {
    if (request.size() != 3) {
        LOG_ERROR(Service_IR, "Wrong request size ({}): {}", request.size(),
                  fmt::format("{:02x}", fmt::join(request, " ")));
        return;
    }

    // Change HID input polling interval
    timing.UnscheduleEvent(hid_polling_callback_id, 0);
    hid_period = request[1];
    timing.ScheduleEvent(msToCycles(hid_period), hid_polling_callback_id);
}

void ExtraHID::HandleReadCalibrationDataRequest(const std::vector<u8>& request_buf) {
    struct ReadCalibrationDataRequest {
        RequestID request_id;
        u8 expected_response_time;
        u16_le offset;
        u16_le size;
    };
    static_assert(sizeof(ReadCalibrationDataRequest) == 6,
                  "ReadCalibrationDataRequest has wrong size");

    if (request_buf.size() != sizeof(ReadCalibrationDataRequest)) {
        LOG_ERROR(Service_IR, "Wrong request size ({}): {}", request_buf.size(),
                  fmt::format("{:02x}", fmt::join(request_buf, " ")));
        return;
    }

    ReadCalibrationDataRequest request;
    std::memcpy(&request, request_buf.data(), sizeof(request));

    const u16 offset = Common::AlignDown(request.offset, 16);
    const u16 size = Common::AlignDown(request.size, 16);

    if (static_cast<std::size_t>(offset + size) > calibration_data.size()) {
        LOG_ERROR(Service_IR, "Read beyond the end of calibration data! (offset={}, size={})",
                  offset, size);
        return;
    }

    std::vector<u8> response(5);
    response[0] = static_cast<u8>(ResponseID::ReadCalibrationData);
    std::memcpy(&response[1], &request.offset, sizeof(request.offset));
    std::memcpy(&response[3], &request.size, sizeof(request.size));
    response.insert(response.end(), calibration_data.begin() + offset,
                    calibration_data.begin() + offset + size);
    Send(response);
}

void ExtraHID::OnReceive(const std::vector<u8>& data) {
    switch (static_cast<RequestID>(data[0])) {
    case RequestID::ConfigureHIDPolling:
        HandleConfigureHIDPollingRequest(data);
        break;
    case RequestID::ReadCalibrationData:
        HandleReadCalibrationDataRequest(data);
        break;
    default:
        LOG_ERROR(Service_IR, "Unknown request: {}", fmt::format("{:02x}", fmt::join(data, " ")));
        break;
    }
}

void ExtraHID::SendHIDStatus() {
    if (Settings::values.isReloading || Settings::values.skip_extra_buttons)
        return;
    
    if (is_device_reload_pending.exchange(false))
        LoadInputDevices();

    constexpr int C_STICK_CENTER = 0x800;
    // TODO(wwylele): this value is not accurately measured. We currently assume that the axis can
    // take values in the whole range of a 12-bit integer.
    constexpr int C_STICK_RADIUS = 0x7FF;

    float x, y;
    std::tie(x, y) = Settings::values.c_stick->GetStatus();

    ExtraHIDResponse response;
    response.c_stick.header.Assign(static_cast<u8>(ResponseID::PollHID));
    response.c_stick.c_stick_x.Assign(static_cast<u32>(C_STICK_CENTER + C_STICK_RADIUS * x));
    response.c_stick.c_stick_y.Assign(static_cast<u32>(C_STICK_CENTER + C_STICK_RADIUS * y));
    response.buttons.battery_level.Assign(0x1F);
    response.buttons.zl_not_held.Assign(!Settings::values.zl->GetStatus());
    response.buttons.zr_not_held.Assign(!Settings::values.zr->GetStatus());
    response.buttons.r_not_held.Assign(1);
    response.unknown = 0;

    Core::Movie::GetInstance().HandleExtraHidResponse(response);

    std::vector<u8> response_buffer(sizeof(response));
    memcpy(response_buffer.data(), &response, sizeof(response));
    Send(response_buffer);
}

void ExtraHID::RequestInputDevicesReload() {
    is_device_reload_pending.store(true);
}

void ExtraHID::LoadInputDevices() {
    if (Settings::values.extra_buttons_initialized || Settings::values.skip_extra_buttons) {
        return;
    } else {
        Settings::values.zl = Input::CreateDevice<Input::ButtonDevice>(
                                                                       Settings::values.current_input_profile.buttons[Settings::NativeButton::ZL]);
        Settings::values.zr = Input::CreateDevice<Input::ButtonDevice>(
                                                                       Settings::values.current_input_profile.buttons[Settings::NativeButton::ZR]);
        Settings::values.c_stick = Input::CreateDevice<Input::AnalogDevice>(
                                                                            Settings::values.current_input_profile.analogs[Settings::NativeAnalog::CStick]);
        Settings::values.extra_buttons_initialized=true;
    }
}

} // namespace Service::IR
