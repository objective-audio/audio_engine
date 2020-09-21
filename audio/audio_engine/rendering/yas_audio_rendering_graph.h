//
//  yas_audio_rendering_graph.h
//

#pragma once

#include <audio/yas_audio_rendering_connection.h>
#include <audio/yas_audio_rendering_node.h>

#include <memory>

namespace yas::audio {
struct rendering_graph {
    rendering_graph(renderable_graph_node_ptr const &output_node);

    std::vector<std::unique_ptr<rendering_node>> const &nodes() const;

   private:
    rendering_graph(rendering_graph const &) = delete;
    rendering_graph(rendering_graph &&) = delete;
    rendering_graph &operator=(rendering_graph const &) = delete;
    rendering_graph &operator=(rendering_graph &&) = delete;

    std::vector<std::unique_ptr<rendering_node>> _nodes;
};
}  // namespace yas::audio
