//
//  coreaudio_sink.hpp
//  emuThreeDS
//
//  Created by Antique on 22/5/2023.
//

#pragma once

#include <AudioUnit/AudioUnit.h>
#include <cstddef>
#include <vector>

#include "audio_core/sink.h"

namespace AudioCore {
class CoreAudioSink final : public Sink {
public:
    explicit CoreAudioSink(std::string device_id);
    ~CoreAudioSink() override;

    unsigned int GetNativeSampleRate() const override;

    void SetCallback(std::function<void(s16*, std::size_t)> cb) override;

private:
    AudioUnit audio_unit;
    std::function<void(s16*, std::size_t)> cb = nullptr;

    static OSStatus NativeCallback(void* ref_con, AudioUnitRenderActionFlags* action_flags, const AudioTimeStamp* timestamp, UInt32 bus_number, UInt32 number_frames, AudioBufferList* data);
};

std::vector<std::string> ListCoreAudioSinkDevices();
}
