//
//  yas_audio_rendering_node.cpp
//

#include "yas_audio_rendering_node.h"

using namespace yas;

void audio::rendering_node::render(audio::pcm_buffer *const buffer, uint32_t const bus_idx, audio::time const &time) {
    this->render_handler({.buffer = buffer, .bus_idx = bus_idx, .time = time, .input_nodes = this->input_nodes});
}
