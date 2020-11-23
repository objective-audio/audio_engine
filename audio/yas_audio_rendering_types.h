//
//  yas_audio_rendering_types.h
//

#pragma once

#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_time.h>

#include <map>

namespace yas::audio {
class rendering_connection;

using rendering_connection_map = std::map<uint32_t, rendering_connection>;

struct node_render_args {
    audio::pcm_buffer *const buffer;
    uint32_t const bus_idx;
    audio::time const &time;

    rendering_connection_map const &source_connections;
};

using node_render_f = std::function<void(node_render_args const &)>;

struct node_input_render_args {
    audio::pcm_buffer const *const buffer;
    uint32_t const bus_idx;
    audio::time const &time;
};

using node_input_render_f = std::function<void(node_input_render_args const &)>;
}  // namespace yas::audio
