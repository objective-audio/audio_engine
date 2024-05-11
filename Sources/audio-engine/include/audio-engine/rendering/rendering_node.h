//
//  rendering_node.h
//

#pragma once

#include <audio-engine/rendering/rendering_connection.h>

#include "rendering_types.h"

namespace yas::audio {
struct rendering_node {
    rendering_node(node_render_f const &, rendering_connection_map &&);

    node_render_f const render_handler;
    rendering_connection_map const source_connections;

    bool output_render(pcm_buffer *const, audio::time const &) const;
    bool input_render(pcm_buffer *const, audio::time const &) const;

   private:
    rendering_node(rendering_node const &) = delete;
    rendering_node(rendering_node &&) = delete;
    rendering_node &operator=(rendering_node const &) = delete;
    rendering_node &operator=(rendering_node &&) = delete;
};

struct rendering_output_node {
    explicit rendering_output_node(std::vector<std::unique_ptr<rendering_node>> &&, rendering_connection &&);

    std::vector<std::unique_ptr<rendering_node>> const source_nodes;
    rendering_connection const source_connection;

    bool render(pcm_buffer *const, audio::time const &) const;

   private:
    rendering_output_node(rendering_output_node const &) = delete;
    rendering_output_node(rendering_output_node &&) = delete;
    rendering_output_node &operator=(rendering_output_node const &) = delete;
    rendering_output_node &operator=(rendering_output_node &&) = delete;
};

struct rendering_input_node {
    rendering_input_node(audio::format const &, node_render_f const &);

    audio::format const format;

    bool render(pcm_buffer *const, audio::time const &) const;

   private:
    rendering_input_node(rendering_input_node const &) = delete;
    rendering_input_node(rendering_input_node &&) = delete;
    rendering_input_node &operator=(rendering_input_node const &) = delete;
    rendering_input_node &operator=(rendering_input_node &&) = delete;

    node_render_f _render_handler;
};
}  // namespace yas::audio
