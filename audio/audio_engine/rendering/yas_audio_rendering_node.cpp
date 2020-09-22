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

bool audio::rendering_node::output_render(pcm_buffer *const buffer, audio::time const &time) const {
    if (!buffer || this->source_connections().empty()) {
        return false;
    }

    auto const &pair = *this->source_connections().begin();
    auto const &connection = pair.second;

    return connection.render(buffer, time);
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

#pragma mark - rendering_output_node

audio::rendering_output_node::rendering_output_node(std::vector<std::unique_ptr<rendering_node>> &&nodes,
                                                    rendering_connection &&connection)
    : _source_nodes(std::move(nodes)), _source_connection(std::move(connection)) {
}

std::vector<std::unique_ptr<audio::rendering_node>> const &audio::rendering_output_node::source_nodes() const {
    return this->_source_nodes;
}

audio::rendering_connection const &audio::rendering_output_node::source_connection() const {
    return this->_source_connection;
}

bool audio::rendering_output_node::output_render(pcm_buffer *const buffer, audio::time const &time) const {
    return this->_source_connection.render(buffer, time);
}

#pragma mark - rendering_input_node

audio::rendering_input_node::rendering_input_node(audio::format const &format, node_render_f const &handler)
    : _format(format), _render_handler(handler) {
}

audio::format const &audio::rendering_input_node::format() const {
    return this->_format;
}

bool audio::rendering_input_node::input_render(pcm_buffer *const buffer, audio::time const &time) const {
    if (!buffer) {
        return false;
    }

    if (this->_format != buffer->format()) {
        return false;
    }

    this->_render_handler({.buffer = buffer, .bus_idx = 0, .time = time, .source_connections = {}});

    return true;
}
