//
//  yas_audio_rendering_graph.h
//

#pragma once

#include <audio/yas_audio_rendering_connection.h>
#include <audio/yas_audio_rendering_node.h>

namespace yas::audio {
struct rendering_graph {
    rendering_node_set const nodes;
    rendering_connection_set const connections;
};
}  // namespace yas::audio
