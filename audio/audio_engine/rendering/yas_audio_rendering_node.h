//
//  yas_audio_rendering_node.h
//

#pragma once

#include <audio/yas_audio_format.h>
#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_rendering_types.h>
#include <audio/yas_audio_time.h>

namespace yas::audio {
class rendering_node;

struct rendering_connection {
    uint32_t const source_bus_idx;
    audio::format const format;

    rendering_connection(uint32_t const src_bus_idx, rendering_node const *const src_node, audio::format const format);

    bool render(audio::pcm_buffer *const, audio::time const &) const;

   private:
    rendering_node const *const source_node;
};

struct rendering_node {
    using render_f = std::function<void(node_render_args const &)>;

    rendering_node(render_f &&, rendering_connection_map &&);

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
