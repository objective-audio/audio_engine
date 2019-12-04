//
//  yas_audio_avf_io_core.h
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
struct avf_io_core final : io_core {
    ~avf_io_core();

    void initialize() override;
    void uninitialize() override;

    void set_render_handler(std::optional<io_render_f>) override;
    void set_maximum_frames_per_slice(uint32_t const) override;

    bool start() override;
    void stop() override;

    [[nodiscard]] std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const override;
    [[nodiscard]] std::optional<time_ptr> const &input_time_on_render() const override;

    static avf_io_core_ptr make_shared(avf_device_ptr const &);

   private:
    class impl;

    std::unique_ptr<impl> _impl;
    std::weak_ptr<avf_io_core> _weak_core;

    audio::avf_device_ptr _device;

    std::optional<pcm_buffer_ptr> _input_buffer_on_render = std::nullopt;
    std::optional<time_ptr> _input_time_on_render = std::nullopt;

    mutable std::recursive_mutex _mutex;
    std::optional<io_render_f> __render_handler = std::nullopt;
    uint32_t __maximum_frames = 4096;
    std::optional<io_kernel_ptr> __kernel = std::nullopt;

    avf_io_core(avf_device_ptr const &);

    void _prepare(avf_io_core_ptr const &shared);

    std::optional<io_render_f> _render_handler() const;
    void _set_kernel(std::optional<io_kernel_ptr> const &);
    std::optional<io_kernel_ptr> _kernel() const;
    void _update_kernel();
};
}  // namespace yas::audio

#endif
