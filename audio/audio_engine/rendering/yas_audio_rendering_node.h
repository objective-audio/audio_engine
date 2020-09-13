//
//  yas_audio_rendering_node.h
//

#pragma once

#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_time.h>

#include <map>

namespace yas::audio {
class rendering_node;

struct rendering_connection {
    uint32_t const source_bus_idx;
    rendering_node const *const source_node;

    void render(audio::pcm_buffer *const, audio::time const &) const;
};

struct rendering_node {
    using connection_map = std::map<uint32_t, rendering_connection>;

    struct render_args {
        audio::pcm_buffer *const buffer;
        uint32_t const bus_idx;
        audio::time const &time;

        connection_map const &source_connections;
    };

    using render_f = std::function<void(render_args const &)>;

    rendering_node(render_f &&, connection_map &&);
    rendering_node(rendering_node &&);

    render_f const &render_handler() const;
    connection_map const &source_connections() const;

   private:
    rendering_node(rendering_node const &) = delete;
    rendering_node &operator=(rendering_node const &) = delete;
    rendering_node &operator=(rendering_node &&) = delete;

    render_f _render_handler;
    connection_map _source_connections;
};
}  // namespace yas::audio
