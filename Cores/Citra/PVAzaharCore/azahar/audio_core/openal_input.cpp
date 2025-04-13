// Copyright 2023 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include <utility>
#include <vector>
#include <AL/al.h>
#include <AL/alc.h>
#include "audio_core/input.h"
#include "audio_core/openal_input.h"
#include "audio_core/sink.h"
#include "common/logging/log.h"

namespace AudioCore {

struct OpenALInput::Impl {
    ALCdevice* device = nullptr;
    u8 sample_size_in_bytes = 0;

    // Counter for warning messages to reduce spam
    int warning_count = 0;
};

OpenALInput::OpenALInput(std::string device_id)
    : impl(std::make_unique<Impl>()), device_id(std::move(device_id)) {
    LOG_INFO(Audio, "OpenALInput created with device_id: {}", device_id);
}

OpenALInput::~OpenALInput() {
    LOG_INFO(Audio, "OpenALInput destructor called");
    StopSampling();
}

void OpenALInput::StartSampling(const InputParameters& params) {
    LOG_INFO(Audio, "OpenALInput starting sampling: sample_rate={}, sample_size={}, buffer_size={}",
             params.sample_rate, params.sample_size, params.buffer_size);
    if (IsSampling()) {
        LOG_INFO(Audio, "OpenALInput already sampling, ignoring StartSampling call");
        return;
    }

    // OpenAL supports unsigned 8-bit and signed 16-bit PCM.
    // TODO: Re-sample the stream.
    if ((params.sample_size == 8 && params.sign == Signedness::Signed) ||
        (params.sample_size == 16 && params.sign == Signedness::Unsigned)) {
        LOG_WARNING(Audio, "Application requested unsupported unsigned PCM format. Falling back to "
                           "supported format.");
    }

    parameters = params;
    impl->sample_size_in_bytes = params.sample_size / 8;

    auto format = params.sample_size == 16 ? AL_FORMAT_MONO16 : AL_FORMAT_MONO8;
    LOG_INFO(Audio, "Opening OpenAL capture device: {}, format={}, rate={}",
             (device_id != auto_device_name && !device_id.empty()) ? device_id : "default",
             (format == AL_FORMAT_MONO16) ? "MONO16" : "MONO8", params.sample_rate);

    impl->device = alcCaptureOpenDevice(
        device_id != auto_device_name && !device_id.empty() ? device_id.c_str() : nullptr,
        params.sample_rate, format, static_cast<ALsizei>(params.buffer_size));
    auto open_error = alcGetError(impl->device);
    if (impl->device == nullptr || open_error != ALC_NO_ERROR) {
        LOG_CRITICAL(Audio, "alcCaptureOpenDevice failed: {}", open_error);
        LOG_INFO(Audio, "Will use static silence as fallback");
        is_sampling = true; // Set to true even though device failed, we'll use static samples
        return;
    }

    LOG_INFO(Audio, "Starting OpenAL capture");
    alcCaptureStart(impl->device);
    auto capture_error = alcGetError(impl->device);
    if (capture_error != ALC_NO_ERROR) {
        LOG_CRITICAL(Audio, "alcCaptureStart failed: {}", capture_error);
        LOG_INFO(Audio, "Will use static silence as fallback");
        is_sampling = true; // Set to true even though capture failed, we'll use static samples
        return;
    }

    LOG_INFO(Audio, "OpenAL capture started successfully");
    is_sampling = true;
}

void OpenALInput::StopSampling() {
    LOG_INFO(Audio, "OpenALInput stopping sampling");
    if (impl->device) {
        LOG_INFO(Audio, "Stopping and closing OpenAL capture device");
        alcCaptureStop(impl->device);
        alcCaptureCloseDevice(impl->device);
        impl->device = nullptr;
    }
    is_sampling = false;
    LOG_INFO(Audio, "OpenALInput sampling stopped");
}

bool OpenALInput::IsSampling() {
    LOG_TRACE(Audio, "OpenALInput::IsSampling() = {}", is_sampling);
    return is_sampling;
}

void OpenALInput::AdjustSampleRate(u32 sample_rate) {
    LOG_INFO(Audio, "OpenALInput adjusting sample rate to: {}", sample_rate);
    if (!IsSampling()) {
        LOG_INFO(Audio, "Not currently sampling, ignoring sample rate adjustment");
        return;
    }

    auto new_params = parameters;
    new_params.sample_rate = sample_rate;
    StopSampling();
    StartSampling(new_params);
}

Samples OpenALInput::Read() {
    LOG_TRACE(Audio, "OpenALInput::Read() called");
    if (!IsSampling()) {
        LOG_TRACE(Audio, "Not sampling, returning empty buffer");
        return {};
    }

    // If device is null, return static silence
    if (impl->device == nullptr) {
        LOG_TRACE(Audio, "No OpenAL device, returning static silence");
        return {};
    }

    ALCint samples_captured = 0;
    alcGetIntegerv(impl->device, ALC_CAPTURE_SAMPLES, 1, &samples_captured);
    auto error = alcGetError(impl->device);
    if (error != ALC_NO_ERROR) {
        // Only log every 100th warning to reduce spam
        if (impl->warning_count++ % 100 == 0) {
            LOG_WARNING(Audio, "alcGetIntegerv(ALC_CAPTURE_SAMPLES) failed: {}", error);
        }
        LOG_TRACE(Audio, "Using static noise as fallback");
        return {};
    }

    // If no samples are available, return static noise
    if (samples_captured <= 0) {
        LOG_TRACE(Audio, "No samples captured, returning static noise");
        return {};
    }

    auto num_samples = std::min(samples_captured, static_cast<ALsizei>(parameters.buffer_size /
                                                                       impl->sample_size_in_bytes));
    Samples samples(num_samples * impl->sample_size_in_bytes);

    alcCaptureSamples(impl->device, samples.data(), num_samples);
    error = alcGetError(impl->device);
    if (error != ALC_NO_ERROR) {
        // Only log every 100th warning to reduce spam
        if (impl->warning_count++ % 100 == 0) {
            LOG_WARNING(Audio, "alcCaptureSamples failed: {}", error);
        }
        LOG_TRACE(Audio, "Using static silence as fallback");
        return {};
    }

    // Check if we have actual audio data (non-zero)
    // Use a more efficient sampling approach
    bool has_data = false;

    // First check every 8th byte for efficiency
    for (size_t i = 0; i < samples.size(); i += 8) {
        if (samples[i] != 0) {
            has_data = true;
            break;
        }
    }

    // If we still don't have data, do a more thorough check on a portion of the buffer
    if (!has_data && samples.size() > 64) {
        // Check the first 64 bytes more thoroughly
        for (size_t i = 0; i < 64; i++) {
            if (samples[i] != 0) {
                has_data = true;
                break;
            }
        }
    }

    if (!has_data) {
        // Only log every 100th warning to reduce spam
        if (impl->warning_count++ % 100 == 0) {
            LOG_WARNING(Audio, "No actual audio data captured, using static silence as fallback");
        }
        return {};
    }

    LOG_TRACE(Audio, "Returning {} bytes of captured audio data", samples.size());
    return samples;
}

std::vector<std::string> ListOpenALInputDevices() {
    const char* devices_str;
    if (alcIsExtensionPresent(nullptr, "ALC_ENUMERATION_EXT") != AL_FALSE) {
        devices_str = alcGetString(nullptr, ALC_CAPTURE_DEVICE_SPECIFIER);
    } else {
        LOG_WARNING(Audio, "Missing OpenAL device enumeration extensions, cannot list audio capture devices.");
        return {};
    }

    if (!devices_str || *devices_str == '\0') {
        return {};
    }

    std::vector<std::string> device_list;
    while (*devices_str != '\0') {
        device_list.emplace_back(devices_str);
        devices_str += strlen(devices_str) + 1;
    }
    return device_list;
}

} // namespace AudioCore
