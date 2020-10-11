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

    [[nodiscard]] static ios_io_core_ptr make_shared(ios_device_ptr const &);

   private:
    class impl;

    std::unique_ptr<impl> _impl;

    audio::ios_device_ptr _device;

    std::optional<io_render_f> _render_handler = std::nullopt;
    uint32_t _maximum_frames = 4096;
    io_kernel_ptr _kernel = nullptr;

    bool _is_started = false;

    ios_io_core(ios_device_ptr const &);

    [[nodiscard]] io_kernel_ptr _make_kernel() const;
    [[nodiscard]] bool _create_engine();
    void _dispose_engine();
    [[nodiscard]] bool _start_engine();
    void _stop_engine();
    void _reload_if_needed();
};
}  // namespace yas::audio

#endif
