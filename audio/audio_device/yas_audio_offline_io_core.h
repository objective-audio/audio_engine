//
//  yas_audio_offline_io_core.h
//

#pragma once

#include <cpp_utils/yas_task.h>

#include "yas_audio_io_core.h"

namespace yas::audio {
struct offline_io_core : io_core {
    ~offline_io_core();

    void set_render_handler(std::optional<io_render_f>) override;
    void set_maximum_frames_per_slice(uint32_t const) override;

    bool start() override;
    void stop() override;

    static offline_io_core_ptr make_shared(offline_device_ptr const &);

   private:
    class render_context;

    offline_device_ptr const _device;
    std::shared_ptr<render_context> _render_context;

    std::optional<io_render_f> _render_handler = std::nullopt;
    uint32_t _maximum_frames = 4096;

    offline_io_core(offline_device_ptr const &);

    std::optional<io_kernel_ptr> _make_kernel() const;
};
}  // namespace yas::audio
