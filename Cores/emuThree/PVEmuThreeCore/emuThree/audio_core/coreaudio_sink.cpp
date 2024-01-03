//
//  coreaudio_sink.cpp
//  emuThreeDS
//
//  Created by Antique on 22/5/2023.
//

#include "audio_core/audio_types.h"
#include "audio_core/coreaudio_sink.h"
#include "common/logging/log.h"
#include "common/settings.h"

namespace AudioCore {
CoreAudioSink::CoreAudioSink(std::string device_name) {
    OSStatus err;
    AudioComponentDescription acdesc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_RemoteIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };
    AudioComponent component = AudioComponentFindNext(nullptr, &acdesc);
    if (component == nullptr) {
        LOG_CRITICAL(Audio_Sink, "Failed to find Sink AudioComponent");
        return;
    }
    err = AudioComponentInstanceNew(component, &audio_unit);
    if (err != noErr) {
        LOG_CRITICAL(Audio_Sink, "Failed to create new AudioComponent instance");
        return;
    }
    AudioStreamBasicDescription format_desc;
    FillOutASBDForLPCM(format_desc, (Float64)33000, 2, 16, 16, false, false);
    err = AudioUnitSetProperty(audio_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format_desc, sizeof format_desc);
    if (err != noErr) {
        LOG_CRITICAL(Audio_Sink, "Failed to set input property");
        return;
    }

    AURenderCallbackStruct callback {
        .inputProc = NativeCallback,
        .inputProcRefCon = this,
    };
    err = AudioUnitSetProperty(audio_unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof callback);
    if (err != noErr) {
        LOG_CRITICAL(Audio_Sink, "Failed to set render callback");
        return;
    }

    err = AudioUnitInitialize(audio_unit);
    if (err != noErr) {
        LOG_CRITICAL(Audio_Sink, "Failed to initialize AudioUnit");
        return;
    }

    err = AudioOutputUnitStart(audio_unit);
    if (err != noErr) {
        LOG_CRITICAL(Audio_Sink, "Failed to start AudioUnit Output");
        return;
    }
}

CoreAudioSink::~CoreAudioSink() {
    OSStatus err;

    err = AudioOutputUnitStop(audio_unit);
    if (err != noErr) {
        LOG_CRITICAL(Audio_Sink, "Failed to stop AudioUnit Output");
    }

    err = AudioUnitUninitialize(audio_unit);
    if (err != noErr) {
        LOG_CRITICAL(Audio_Sink, "Failed to uninitialize AudioUnit");
        return;
    }
}

void CoreAudioSink::SetCallback(std::function<void(s16*, std::size_t)> cb) {
    this->cb = cb;
}

OSStatus CoreAudioSink::NativeCallback(void* ref_con, AudioUnitRenderActionFlags* action_flags, const AudioTimeStamp* timestamp, UInt32 bus_number, UInt32 number_frames, AudioBufferList* data) {
    CoreAudioSink* cas = (CoreAudioSink*) ref_con;
    if (cas->cb == nullptr) return noErr; // TODO: better error handling

    for (UInt32 i=0; i < data->mNumberBuffers; i++) {
        const AudioBuffer buffer = data->mBuffers[i];
        cas->cb(reinterpret_cast<s16*>(buffer.mData), buffer.mDataByteSize / 4);
    }

    return noErr;
}

unsigned int CoreAudioSink::GetNativeSampleRate() const {
    return native_sample_rate; // TODO: this is stub
}

std::vector<std::string> ListCoreAudioSinkDevices() {
    return {"auto"};
}
}
