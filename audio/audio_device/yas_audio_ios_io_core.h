//
//  yas_audio_ios_io_core.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include <chaining/yas_chaining_umbrella.h>

#include "yas_audio_format.h"
#include "yas_audio_io_core.h"
#include "yas_audio_io_kernel.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct ios_io_core final : io_core {
    ~ios_io_core();

    void initialize() override;
    void uninitialize() override;

    void set_render_handler(std::optional<io_render_f>) override;
    void set_maximum_frames_per_slice(uint32_t const) override;

    bool start() override;
    void stop() override;

    [[nodiscard]] pcm_buffer const *input_buffer_on_render() const override;

    [[nodiscard]] static ios_io_core_ptr make_shared(ios_device_ptr const &);

   private:
    class impl;

    std::unique_ptr<impl> _impl;
    std::weak_ptr<ios_io_core> _weak_core;

    audio::ios_device_ptr _device;

    std::optional<pcm_buffer_ptr> _input_buffer_on_render = std::nullopt;
    std::optional<time_ptr> _input_time_on_render = std::nullopt;

    mutable std::recursive_mutex _kernel_mutex;

    std::optional<io_render_f> __render_handler = std::nullopt;
    uint32_t __maximum_frames = 4096;
    std::optional<io_kernel_ptr> __kernel = std::nullopt;

    ios_io_core(ios_device_ptr const &);

    void _prepare(ios_io_core_ptr const &shared);

    void _set_kernel(std::optional<io_kernel_ptr> const &);
    std::optional<io_kernel_ptr> _kernel() const;
    void _update_kernel();
    bool _is_intialized() const;

    void _create_engine();
    void _dispose_engine();
    bool _start_engine();
    void _stop_engine();

    bool _is_started = false;
    bool _is_initialized = false;
};
}  // namespace yas::audio

#endif
