//
//  yas_audio_rendering_node.cpp
//

#include "yas_audio_rendering_node.h"

using namespace yas;

void audio::rendering_connection::render(audio::pcm_buffer *const buffer, audio::time const &time) const {
    this->source_node->render_handler()({.buffer = buffer,
                                         .bus_idx = this->source_bus_idx,
                                         .time = time,
                                         .source_connections = this->source_node->source_connections()});
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
