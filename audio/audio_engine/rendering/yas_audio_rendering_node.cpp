//
//  yas_audio_rendering_node.cpp
//

#include "yas_audio_rendering_node.h"

using namespace yas;

void audio::rendering_connection::render(audio::pcm_buffer *const buffer, audio::time const &time) const {
    this->source_node->render_handler({.buffer = buffer,
                                       .bus_idx = this->source_bus_idx,
                                       .time = time,
                                       .source_connections = this->source_node->source_connections});
}
