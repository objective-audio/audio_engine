//
//  yas_audio_rendering_node.cpp
//

#include "yas_audio_rendering_node.h"

#include "yas_audio_rendering_connection.h"

using namespace yas;

audio::rendering_node::rendering_node(render_f const &handler, rendering_connection_map &&connections)
    : _render_handler(handler), _source_connections(std::move(connections)) {
}

audio::rendering_node::render_f const &audio::rendering_node::render_handler() const {
    return this->_render_handler;
}

audio::rendering_connection_map const &audio::rendering_node::source_connections() const {
    return this->_source_connections;
}
