//
//  yas_audio_rendering_connection.h
//

#pragma once

#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_time.h>

#include <unordered_map>
#include <unordered_set>

namespace yas::audio {
class rendering_node;

struct rendering_connection {
    uint32_t const input_bus_idx;
    rendering_node *const input_node;

    void render(audio::pcm_buffer *const, audio::time const &);
};

using rendering_connection_set = std::unordered_set<rendering_connection>;
}  // namespace yas::audio
