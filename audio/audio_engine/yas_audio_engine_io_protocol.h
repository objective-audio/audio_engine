//
//  yas_audio_engine_device_io_protocol.h
//

#pragma once

#include <memory>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_ptr.h"

namespace yas::audio {
class device_io;
}

namespace yas::audio::engine {
struct manageable_device_io {
    virtual ~manageable_device_io() = default;

    virtual void add_raw_device_io() = 0;
    virtual void remove_raw_device_io() = 0;
    virtual audio::device_io_ptr const &raw_device_io() = 0;
};

using manageable_device_io_ptr = std::shared_ptr<manageable_device_io>;
}  // namespace yas::audio::engine

#endif
