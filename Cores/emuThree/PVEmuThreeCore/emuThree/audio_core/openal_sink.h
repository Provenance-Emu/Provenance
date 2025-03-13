// Copyright 2023 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <cstddef>
#include <memory>
#include <string>
#include "audio_core/sink.h"

namespace AudioCore {

class OpenALSink final : public Sink {
public:
    explicit OpenALSink(std::string device_id);
    ~OpenALSink() override;

    unsigned int GetNativeSampleRate() const override;

    void SetCallback(std::function<void(s16*, std::size_t)> cb) override;

private:
    struct Impl;
    std::unique_ptr<Impl> impl;

    void Close();
};

std::vector<std::string> ListOpenALSinkDevices();

} // namespace AudioCore
