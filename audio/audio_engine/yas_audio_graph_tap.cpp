//
//  yas_audio_graph_tap.cpp
//

#include "yas_audio_graph_tap.h"

#include "yas_audio_rendering_connection.h"

using namespace yas;

#pragma mark - audio::tap

audio::graph_tap::graph_tap(args &&args)
    : _node(graph_node::make_shared(args.is_input ? graph_node_args{.input_bus_count = 1, .input_renderable = true} :
                                                    graph_node_args{.input_bus_count = 1, .output_bus_count = 1})) {
    this->_node->chain(graph_node::method::prepare_rendering)
        .perform([this](auto const &) {
            this->_node->set_render_handler([handler = this->_render_handler](node_render_args args) {
                if (handler) {
                    handler.value()(args);
                } else {
                    for (auto const &pair : args.source_connections) {
                        pair.second.render(args.buffer, args.time);
                    }
                }
            });
        })
        .end()
        ->add_to(this->_pool);

    this->_node->chain(graph_node::method::will_reset)
        .perform([this](auto const &) { this->_render_handler = std::nullopt; })
        .end()
        ->add_to(this->_pool);
}

void audio::graph_tap::set_render_handler(audio::node_render_f handler) {
    this->_render_handler = handler;

    renderable_graph_node::cast(this->_node)->update_rendering();
}

audio::graph_node_ptr const &audio::graph_tap::node() const {
    return this->_node;
}

#pragma mark - factory

audio::graph_tap_ptr audio::graph_tap::make_shared() {
    return graph_tap::make_shared({.is_input = false});
}

audio::graph_tap_ptr audio::graph_tap::make_shared(graph_tap::args args) {
    return graph_tap_ptr(new graph_tap{std::move(args)});
}
