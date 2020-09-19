//
//  yas_audio_rendering_node.h
//

#pragma once

#include <audio/yas_audio_rendering_types.h>

namespace yas::audio {
struct rendering_node {
    using render_f = std::function<void(node_render_args const &)>;

    rendering_node(render_f const &, rendering_connection_map &&);

    render_f const &render_handler() const;
    rendering_connection_map const &source_connections() const;

   private:
    rendering_node(rendering_node const &) = delete;
    rendering_node(rendering_node &&) = delete;
    rendering_node &operator=(rendering_node const &) = delete;
    rendering_node &operator=(rendering_node &&) = delete;

    render_f _render_handler;
    rendering_connection_map _source_connections;
};
}  // namespace yas::audio
