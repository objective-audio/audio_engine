//
//  yas_audio_rendering_node.cpp
//

#include "yas_audio_rendering_node.h"

#include "yas_audio_rendering_connection.h"

using namespace yas;
using namespace yas::audio;

rendering_node::rendering_node(node_render_f const &handler, rendering_connection_map &&connections)
    : render_handler(handler), source_connections(std::move(connections)) {
}

bool rendering_node::output_render(pcm_buffer *const buffer, time const &time) const {
    if (!buffer || this->source_connections.empty()) {
        return false;
    }

    auto const &pair = *this->source_connections.begin();
    auto const &connection = pair.second;

    return connection.render(buffer, time);
}

bool rendering_node::input_render(pcm_buffer *const buffer, time const &time) const {
    if (!buffer || this->source_connections.empty()) {
        return false;
    }

    auto const &pair = *this->source_connections.begin();
    auto const &connection = pair.second;

    if (connection.format != buffer->format()) {
        return false;
    }

    this->render_handler({.buffer = buffer, .bus_idx = 0, .time = time, .source_connections = {}});

    return true;
}

#pragma mark - rendering_output_node

rendering_output_node::rendering_output_node(std::vector<std::unique_ptr<rendering_node>> &&nodes,
                                             rendering_connection &&connection)
    : source_nodes(std::move(nodes)), source_connection(std::move(connection)) {
}

bool rendering_output_node::render(pcm_buffer *const buffer, time const &time) const {
    return this->source_connection.render(buffer, time);
}

#pragma mark - rendering_input_node

rendering_input_node::rendering_input_node(audio::format const &format, node_render_f const &handler)
    : format(format), _render_handler(handler) {
}

bool rendering_input_node::render(pcm_buffer *const buffer, time const &time) const {
    if (!buffer) {
        return false;
    }

    if (this->format != buffer->format()) {
        return false;
    }

    this->_render_handler({.buffer = buffer, .bus_idx = 0, .time = time, .source_connections = {}});

    return true;
}
