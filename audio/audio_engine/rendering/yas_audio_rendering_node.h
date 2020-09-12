//
//  yas_audio_rendering_node.h
//

#pragma once

#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_time.h>

#include <unordered_map>
#include <unordered_set>

namespace yas::audio {
struct rendering_node {
    using node_map = std::unordered_map<uint32_t, rendering_node const *>;

    struct render_args {
        audio::pcm_buffer *const buffer;
        uint32_t const bus_idx;
        audio::time const &time;

        node_map const &input_nodes;
    };

    using render_f = std::function<void(render_args const &)>;

    render_f const render_handler;
    node_map const input_nodes;
};

using rendering_node_set = std::unordered_set<rendering_node>;
}  // namespace yas::audio
