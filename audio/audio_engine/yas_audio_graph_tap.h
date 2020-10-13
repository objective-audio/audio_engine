//
//  yas_audio_graph_tap.h
//

#pragma once

#include <audio/yas_audio_graph_node.h>

namespace yas::audio {
struct graph_tap final {
    void set_render_handler(audio::node_render_f);

    audio::graph_node_ptr const &node() const;

    static graph_tap_ptr make_shared();

   private:
    graph_node_ptr const _node;
    std::optional<audio::node_render_f> _render_handler;

    graph_tap();

    graph_tap(graph_tap const &) = delete;
    graph_tap(graph_tap &&) = delete;
    graph_tap &operator=(graph_tap const &) = delete;
    graph_tap &operator=(graph_tap &&) = delete;
};

struct graph_input_tap final {
    void set_render_handler(audio::node_input_render_f);

    audio::graph_node_ptr const &node() const;

    static graph_input_tap_ptr make_shared();

   private:
    graph_node_ptr const _node;
    std::optional<audio::node_input_render_f> _render_handler;

    graph_input_tap();

    graph_input_tap(graph_input_tap const &) = delete;
    graph_input_tap(graph_input_tap &&) = delete;
    graph_input_tap &operator=(graph_input_tap const &) = delete;
    graph_input_tap &operator=(graph_input_tap &&) = delete;
};
}  // namespace yas::audio
