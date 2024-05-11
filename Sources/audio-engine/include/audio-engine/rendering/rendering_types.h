//
//  rendering_types.h
//

#pragma once

#include <audio-engine/common/time.h>
#include <audio-engine/pcm_buffer/pcm_buffer.h>

#include <map>

namespace yas::audio {
class rendering_connection;

using rendering_connection_map = std::map<uint32_t, rendering_connection>;

struct node_render_args {
    pcm_buffer *const buffer;
    uint32_t const bus_idx;
    time const &time;

    rendering_connection_map const &source_connections;
};

using node_render_f = std::function<void(node_render_args const &)>;

struct node_input_render_args {
    pcm_buffer const *const buffer;
    uint32_t const bus_idx;
    time const &time;
};

using node_input_render_f = std::function<void(node_input_render_args const &)>;
}  // namespace yas::audio
