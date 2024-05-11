//
//  yas_audio_rendering_graph.h
//

#pragma once

#include <audio-engine/rendering/yas_audio_rendering_connection.h>
#include <audio-engine/rendering/yas_audio_rendering_node.h>

#include <memory>

namespace yas::audio {
struct rendering_graph {
    rendering_graph(renderable_graph_node_ptr const &output_node, renderable_graph_node_ptr const &input_node);

    [[nodiscard]] rendering_output_node const *output_node() const;
    [[nodiscard]] rendering_input_node const *input_node() const;

   private:
    rendering_graph(rendering_graph const &) = delete;
    rendering_graph(rendering_graph &&) = delete;
    rendering_graph &operator=(rendering_graph const &) = delete;
    rendering_graph &operator=(rendering_graph &&) = delete;

    std::unique_ptr<rendering_output_node> _output_node;
    std::unique_ptr<rendering_input_node> _input_node;
};
}  // namespace yas::audio
