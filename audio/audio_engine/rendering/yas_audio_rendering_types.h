//
//  yas_audio_rendering_types.h
//

#pragma once

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
}  // namespace yas::audio
