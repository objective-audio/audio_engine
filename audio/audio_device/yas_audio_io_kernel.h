//
//  yas_audio_io_kernel.h
//

#pragma once

#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_ptr.h"
#include "yas_audio_time.h"

namespace yas::audio {
struct io_render_args {
    std::optional<audio::pcm_buffer_ptr> const output_buffer;
    std::optional<audio::time> const when;
};

using io_render_f = std::function<void(io_render_args)>;

struct io_kernel final {
    io_render_f const render_handler;
    std::optional<pcm_buffer_ptr const> const input_buffer;
    std::optional<pcm_buffer_ptr const> const output_buffer;

    void reset_buffers();

    static io_kernel_ptr make_shared(io_render_f const &, std::optional<audio::format> const &input_format,
                                     std::optional<audio::format> const &output_format, uint32_t const frame_capacity);

   private:
    io_kernel(io_render_f const &, std::optional<audio::format> const &input_format,
              std::optional<audio::format> const &output_format, uint32_t const frame_capacity);

    io_kernel(io_kernel const &) = delete;
    io_kernel(io_kernel &&) = delete;
    io_kernel &operator=(io_kernel const &) = delete;
    io_kernel &operator=(io_kernel &&) = delete;
};
}  // namespace yas::audio
