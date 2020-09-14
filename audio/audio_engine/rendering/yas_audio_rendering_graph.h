//
//  yas_audio_rendering_graph.h
//

#pragma once

#include <audio/yas_audio_graph_connection.h>
#include <audio/yas_audio_graph_node.h>
#include <audio/yas_audio_rendering_node.h>

#include <memory>

namespace yas::audio {
struct rendering_graph {
    std::vector<std::unique_ptr<rendering_node>> const nodes;

    rendering_graph(graph_node_ptr const &end_node);

   private:
    rendering_graph(rendering_graph const &) = delete;
    rendering_graph(rendering_graph &&) = delete;
    rendering_graph &operator=(rendering_graph const &) = delete;
    rendering_graph &operator=(rendering_graph &&) = delete;
};
}  // namespace yas::audio
