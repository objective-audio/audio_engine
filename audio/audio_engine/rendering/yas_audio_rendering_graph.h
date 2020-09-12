//
//  yas_audio_rendering_graph.h
//

#pragma once

#include <audio/yas_audio_rendering_node.h>

namespace yas::audio {
struct rendering_graph {
    rendering_node_set const nodes;

   private:
    rendering_graph(rendering_graph const &) = delete;
    rendering_graph(rendering_graph &&) = delete;
    rendering_graph &operator=(rendering_graph const &) = delete;
    rendering_graph &operator=(rendering_graph &&) = delete;
};
}  // namespace yas::audio
