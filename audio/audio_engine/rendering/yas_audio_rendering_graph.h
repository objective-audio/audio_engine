//
//  yas_audio_rendering_graph.h
//

#pragma once

#include <audio/yas_audio_graph_connection.h>
#include <audio/yas_audio_graph_node.h>
#include <audio/yas_audio_rendering_node.h>

namespace yas::audio {
struct rendering_graph {
    std::vector<rendering_node> const nodes;

    rendering_graph(graph_node_set const &, graph_connection_set const &);

   private:
    rendering_graph(rendering_graph const &) = delete;
    rendering_graph(rendering_graph &&) = delete;
    rendering_graph &operator=(rendering_graph const &) = delete;
    rendering_graph &operator=(rendering_graph &&) = delete;
};
}  // namespace yas::audio
