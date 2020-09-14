//
//  yas_audio_rendering_node.cpp
//

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

audio::rendering_node::rendering_node(render_f &&handler, connection_map &&connections)
    : _render_handler(std::move(handler)), _source_connections(std::move(connections)) {
}

audio::rendering_node::render_f const &audio::rendering_node::render_handler() const {
    return this->_render_handler;
}

audio::rendering_node::connection_map const &audio::rendering_node::source_connections() const {
    return this->_source_connections;
}
