//
//  yas_audio_engine_io_protocol.h
//

#pragma once

#include <memory>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_ptr.h"

namespace yas::audio::engine {
struct manageable_io {
    virtual ~manageable_io() = default;

    virtual void add_raw_io() = 0;
    virtual void remove_raw_io() = 0;
    virtual audio::io_ptr const &raw_io() = 0;
};

using manageable_io_ptr = std::shared_ptr<manageable_io>;
}  // namespace yas::audio::engine

#endif
