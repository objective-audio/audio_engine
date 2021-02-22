//
//  yas_audio_io_kernel.cpp
//

#include "yas_audio_io_kernel.h"

using namespace yas;
using namespace yas::audio;

io_kernel::io_kernel(io_render_f const &render_handler, std::optional<format> const &input_format,
                     std::optional<format> const &output_format, uint32_t const frame_capacity)
    : render_handler(render_handler),
      input_buffer(input_format ? std::make_shared<pcm_buffer>(*input_format, frame_capacity) : nullptr),
      output_buffer(output_format ? std::make_shared<pcm_buffer>(*output_format, frame_capacity) : nullptr) {
}

void io_kernel::reset_buffers() {
    if (auto const &buffer = this->input_buffer) {
        buffer->reset_buffer();
    }

    if (auto const &buffer = this->output_buffer) {
        buffer->reset_buffer();
    }
}

io_kernel_ptr io_kernel::make_shared(io_render_f const &render_handler, std::optional<format> const &input_format,
                                     std::optional<format> const &output_format, uint32_t const frame_capacity) {
    return std::shared_ptr<io_kernel>(new io_kernel{render_handler, input_format, output_format, frame_capacity});
}
