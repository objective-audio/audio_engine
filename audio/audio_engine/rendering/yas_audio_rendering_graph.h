//
//  yas_audio_rendering_graph.h
//

#pragma once

#include <audio/yas_audio_rendering_connection.h>
#include <audio/yas_audio_rendering_node.h>

#include <memory>

namespace yas::audio {
struct rendering_graph {
    rendering_graph(renderable_graph_node_ptr const &output_node, renderable_graph_node_ptr const &input_node);

    std::vector<std::unique_ptr<rendering_node>> const &output_nodes() const;
    std::vector<std::unique_ptr<rendering_node>> const &input_nodes() const;
    rendering_input_node const *input_node() const;

   private:
    rendering_graph(rendering_graph const &) = delete;
    rendering_graph(rendering_graph &&) = delete;
    rendering_graph &operator=(rendering_graph const &) = delete;
    rendering_graph &operator=(rendering_graph &&) = delete;

    std::vector<std::unique_ptr<rendering_node>> _nodes;
    std::vector<std::unique_ptr<rendering_node>> _input_nodes;
    std::unique_ptr<rendering_input_node> _input_node;
};
}  // namespace yas::audio
