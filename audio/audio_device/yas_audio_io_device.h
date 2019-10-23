//
//  yas_audio_io_device.h
//

#pragma once

#include "yas_audio_io_core.h"

namespace yas::audio {
struct io_device {
    virtual std::optional<audio::format> input_format() const = 0;
    virtual std::optional<audio::format> output_format() const = 0;
    virtual uint32_t input_channel_count() const = 0;
    virtual uint32_t output_channel_count() const = 0;

    virtual io_core_ptr make_io_core() const = 0;

    static std::optional<io_device_ptr> default_device();
};
}  // namespace yas::audio
