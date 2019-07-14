//
//  yas_audio_engine_device_io_protocol.h
//

#pragma once

#include <memory>

namespace yas::audio {
class device_io;
}

namespace yas::audio::engine {
struct manageable_device_io {
    virtual ~manageable_device_io() = default;

    virtual void add_raw_device_io() = 0;
    virtual void remove_raw_device_io() = 0;
    virtual std::shared_ptr<audio::device_io> &raw_device_io() = 0;
};
}  // namespace yas::audio::engine
