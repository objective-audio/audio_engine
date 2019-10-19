//
//  yas_audio_io_kernel.cpp
//

#include "yas_audio_io_kernel.h"

using namespace yas;

audio::io_kernel::io_kernel(std::optional<audio::format> const &input_format,
                            std::optional<audio::format> const &output_format, uint32_t const frame_capacity)
    : input_buffer(input_format ? std::make_optional(std::make_shared<pcm_buffer>(*input_format, frame_capacity)) :
                                  std::nullopt),
      output_buffer(output_format ? std::make_optional(std::make_shared<pcm_buffer>(*output_format, frame_capacity)) :
                                    std::nullopt) {
}

void audio::io_kernel::reset_buffers() {
    if (auto const &buffer = this->input_buffer) {
        buffer.value()->reset_buffer();
    }

    if (auto const &buffer = this->output_buffer) {
        buffer.value()->reset_buffer();
    }
}

audio::io_kernel_ptr audio::io_kernel::make_shared(std::optional<audio::format> const &input_format,
                                                   std::optional<audio::format> const &output_format,
                                                   uint32_t const frame_capacity) {
    return std::shared_ptr<io_kernel>(new io_kernel{input_format, output_format, frame_capacity});
}
