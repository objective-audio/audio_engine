//
//  yas_audio_engine_io_protocol.h
//

#pragma once

#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct manageable_io {
    virtual ~manageable_io() = default;

    virtual audio::io_ptr const &raw_io() = 0;
    virtual void start() = 0;
    virtual void stop() = 0;

    static manageable_io_ptr cast(manageable_io_ptr const &io) {
        return io;
    }
};
}  // namespace yas::audio::engine
