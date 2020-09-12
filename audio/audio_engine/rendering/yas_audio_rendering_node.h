//
//  yas_audio_rendering_node.h
//

#pragma once

#include <unordered_map>
#include <unordered_set>

namespace yas::audio {
class rendering_connection;

struct rendering_node {
    std::unordered_map<uint32_t, rendering_connection *> const input_connections;
};

using rendering_node_set = std::unordered_set<rendering_node>;
}  // namespace yas::audio
