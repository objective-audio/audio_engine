//
//  yas_audio_io_device.h
//

#pragma once

#include "yas_audio_io_core.h"

namespace yas::audio {
struct io_device {
    virtual io_core_ptr make_io_core() const = 0;
};
}  // namespace yas::audio
