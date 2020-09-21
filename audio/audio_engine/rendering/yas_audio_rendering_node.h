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

    bool input_render(pcm_buffer *const, audio::time const &) const;

   private:
    rendering_node(rendering_node const &) = delete;
    rendering_node(rendering_node &&) = delete;
    rendering_node &operator=(rendering_node const &) = delete;
    rendering_node &operator=(rendering_node &&) = delete;

    node_render_f _render_handler;
    rendering_connection_map _source_connections;
};
}  // namespace yas::audio
