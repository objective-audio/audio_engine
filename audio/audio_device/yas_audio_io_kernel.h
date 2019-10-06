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
              uint32_t const frame_capacity)
        : _input_buffer(input_format ? std::make_optional(std::make_shared<pcm_buffer>(*input_format, frame_capacity)) :
                                       std::nullopt),
          _output_buffer(output_format ?
                             std::make_optional(std::make_shared<pcm_buffer>(*output_format, frame_capacity)) :
                             std::nullopt) {
    }

    std::optional<pcm_buffer_ptr> const &input_buffer() {
        return this->_input_buffer;
    }

    std::optional<pcm_buffer_ptr> const &output_buffer() {
        return this->_output_buffer;
    }

    void reset_buffers() {
        if (auto const &buffer = this->_input_buffer) {
            buffer.value()->reset();
        }

        if (auto const &buffer = this->_output_buffer) {
            buffer.value()->reset();
        }
    }

   private:
    std::optional<pcm_buffer_ptr> _input_buffer;
    std::optional<pcm_buffer_ptr> _output_buffer;

    io_kernel(io_kernel const &) = delete;
    io_kernel(io_kernel &&) = delete;
    io_kernel &operator=(io_kernel const &) = delete;
    io_kernel &operator=(io_kernel &&) = delete;
};
}  // namespace yas::audio
