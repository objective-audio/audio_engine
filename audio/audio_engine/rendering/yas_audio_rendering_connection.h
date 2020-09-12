//
//  yas_audio_rendering_connection.h
//

#pragma once

#include <unordered_map>
#include <unordered_set>

namespace yas::audio {
class rendering_node;

struct rendering_connection {
    uint32_t const input_bus_idx;
    rendering_node *const input_node;
};

using rendering_connection_set = std::unordered_set<rendering_connection>;
}  // namespace yas::audio
