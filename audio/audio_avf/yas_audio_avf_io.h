//
//  yas_audio_avf_io.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include "yas_audio_avf_device.h"
#include "yas_audio_io_kernel.h"
#include "yas_audio_ptr.h"
#include "yas_audio_time.h"
#include "yas_audio_types.h"

namespace yas::audio {
struct avf_io final {
    ~avf_io();

    void set_device(std::optional<avf_device_ptr> const &);
    std::optional<avf_device_ptr> const &device() const;
    bool is_running() const;
    void set_render_handler(io_render_f);
    void set_maximum_frames_per_slice(uint32_t const);
    uint32_t maximum_frames_per_slice() const;

    bool start();
    void stop();

    std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const;
    std::optional<time_ptr> const &input_time_on_render() const;

    static avf_io_ptr make_shared(std::optional<avf_device_ptr> const &);

   private:
    struct impl;

    std::unique_ptr<impl> _impl;

    std::optional<avf_device_ptr> _device = std::nullopt;
    std::optional<pcm_buffer_ptr> _input_buffer_on_render = std::nullopt;
    std::optional<time_ptr> _input_time_on_render = std::nullopt;

    std::weak_ptr<avf_io> _weak_io;
    chaining::observer_pool _pool;

    mutable std::recursive_mutex _mutex;
    io_render_f __render_handler = nullptr;
    uint32_t __maximum_frames = 4096;
    io_kernel_ptr __kernel = nullptr;

    avf_io();

    void _prepare(avf_io_ptr const &);
    void _initialize();
    void _uninitialize();

    io_render_f _render_handler() const;
    void _set_kernel(io_kernel_ptr const &);
    io_kernel_ptr _kernel() const;
    void _update_kernel();
    void _reload();
};
}  // namespace yas::audio

#endif
