//
//  yas_audio_io_kernel.h
//

#pragma once

#include <audio/yas_audio_format.h>
#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_ptr.h>
#include <audio/yas_audio_time.h>

namespace yas::audio {
struct io_render_args {
    pcm_buffer *const output_buffer;
    std::optional<audio::time> const &output_time;
    pcm_buffer *const input_buffer;
    std::optional<audio::time> const &input_time;
};

using io_render_f = std::function<void(io_render_args)>;

struct io_kernel final {
    io_render_f const render_handler;
    pcm_buffer_ptr const input_buffer;
    pcm_buffer_ptr const output_buffer;

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
