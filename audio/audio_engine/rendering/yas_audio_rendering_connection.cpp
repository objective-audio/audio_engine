//
//  yas_audio_rendering_connection.cpp
//

#include "yas_audio_rendering_connection.h"

#include "yas_audio_rendering_node.h"

using namespace yas;

audio::rendering_connection::rendering_connection(uint32_t const src_bus_idx, rendering_node const *const src_node,
                                                  audio::format const format)
    : source_bus_idx(src_bus_idx), source_node(src_node), format(std::move(format)) {
}

bool audio::rendering_connection::render(audio::pcm_buffer *const buffer, audio::time const &time) const {
    if (buffer->format() != this->format) {
        return false;
    }

    this->source_node->render_handler()({.buffer = buffer,
                                         .bus_idx = this->source_bus_idx,
                                         .time = time,
                                         .source_connections = this->source_node->source_connections()});

    return true;
}
