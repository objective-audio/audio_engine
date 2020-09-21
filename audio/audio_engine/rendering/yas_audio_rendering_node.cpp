//
//  yas_audio_rendering_node.cpp
//

#include "yas_audio_rendering_node.h"

#include "yas_audio_rendering_connection.h"

using namespace yas;

audio::rendering_node::rendering_node(node_render_f const &handler, rendering_connection_map &&connections)
    : _render_handler(handler), _source_connections(std::move(connections)) {
}

audio::node_render_f const &audio::rendering_node::render_handler() const {
    return this->_render_handler;
}

audio::rendering_connection_map const &audio::rendering_node::source_connections() const {
    return this->_source_connections;
}

bool audio::rendering_node::input_render(pcm_buffer *const buffer, audio::time const &time) const {
    if (!buffer || this->source_connections().empty()) {
        return false;
    }

    auto const &pair = *this->source_connections().begin();
    auto const &connection = pair.second;

    if (connection.format != buffer->format()) {
        return false;
    }

    this->render_handler()({.buffer = buffer, .bus_idx = 0, .time = time, .source_connections = {}});

    return true;
}
