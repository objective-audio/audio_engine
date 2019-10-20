//
//  yas_audio_io.h
//

#pragma once

#include "yas_audio_io_device.h"
#include "yas_audio_io_kernel.h"
#include "yas_audio_ptr.h"
#include "yas_audio_time.h"
#include "yas_audio_types.h"

namespace yas::audio {
struct io final {
    ~io();

    void set_device(std::optional<io_device_ptr> const &);
    std::optional<io_device_ptr> const &device() const;
    bool is_running() const;
    void set_render_handler(io_render_f);
    void set_maximum_frames_per_slice(uint32_t const);
    uint32_t maximum_frames_per_slice() const;

    bool start();
    void stop();

    std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const;
    std::optional<time_ptr> const &input_time_on_render() const;

    static io_ptr make_shared(std::optional<io_device_ptr> const &);

   private:
    std::weak_ptr<io> _weak_io;
    std::optional<io_device_ptr> _device = std::nullopt;
    std::optional<io_core_ptr> _io_core = std::nullopt;
    bool _is_running = false;
    io_render_f _render_handler = nullptr;
    uint32_t _maximum_frames = 4096;
    std::optional<chaining::any_observer_ptr> _observer;

    io();

    void _initialize();
    void _uninitialize();

    void _reload();
};
}  // namespace yas::audio
