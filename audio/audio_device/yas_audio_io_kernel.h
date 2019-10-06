//
//  yas_audio_io_kernel.h
//

#pragma once

#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct io_kernel final {
    io_kernel(std::optional<audio::format> const &input_format, std::optional<audio::format> const &output_format,
              uint32_t const frame_capacity);

    std::optional<pcm_buffer_ptr const> const input_buffer;
    std::optional<pcm_buffer_ptr const> const output_buffer;

    void reset_buffers();

   private:
    io_kernel(io_kernel const &) = delete;
    io_kernel(io_kernel &&) = delete;
    io_kernel &operator=(io_kernel const &) = delete;
    io_kernel &operator=(io_kernel &&) = delete;
};
}  // namespace yas::audio
