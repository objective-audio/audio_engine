//
//  yas_audio_rendering_node.h
//

#pragma once

#include <audio/yas_audio_rendering_types.h>

namespace yas::audio {
struct rendering_node {
    rendering_node(node_render_f const &, rendering_connection_map &&);

    node_render_f const &render_handler() const;
    rendering_connection_map const &source_connections() const;

    bool output_render(pcm_buffer *const, audio::time const &) const;
    bool input_render(pcm_buffer *const, audio::time const &) const;

   private:
    rendering_node(rendering_node const &) = delete;
    rendering_node(rendering_node &&) = delete;
    rendering_node &operator=(rendering_node const &) = delete;
    rendering_node &operator=(rendering_node &&) = delete;

    node_render_f _render_handler;
    rendering_connection_map _source_connections;
};

struct rendering_output_node {
    rendering_output_node(rendering_connection_map &&);

    rendering_connection_map const &source_connections() const;

    bool output_render(pcm_buffer *const, audio::time const &) const;

   private:
    rendering_output_node(rendering_output_node const &) = delete;
    rendering_output_node(rendering_output_node &&) = delete;
    rendering_output_node &operator=(rendering_output_node const &) = delete;
    rendering_output_node &operator=(rendering_output_node &&) = delete;

    rendering_connection_map _source_connections;
};

struct rendering_input_node {
    rendering_input_node(audio::format const &, node_render_f const &);
    
    audio::format const &format() const;
    
    bool input_render(pcm_buffer *const, audio::time const &) const;

   private:
    rendering_input_node(rendering_input_node const &) = delete;
    rendering_input_node(rendering_input_node &&) = delete;
    rendering_input_node &operator=(rendering_input_node const &) = delete;
    rendering_input_node &operator=(rendering_input_node &&) = delete;

    node_render_f _render_handler;
    audio::format _format;
};
}  // namespace yas::audio
