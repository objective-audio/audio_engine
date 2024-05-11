//
//  io_core.h
//

#pragma once

#include <audio-engine/io/io_kernel.h>

#include <observing/yas_observing_umbrella.hpp>

namespace yas::audio {
struct io_core {
    virtual ~io_core() = default;

    virtual void set_render_handler(std::optional<io_render_f>) = 0;
    virtual void set_maximum_frames_per_slice(uint32_t const) = 0;

    virtual bool start() = 0;
    virtual void stop() = 0;
};

using io_core_ptr = std::shared_ptr<io_core>;
}  // namespace yas::audio
