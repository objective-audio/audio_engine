//
//  yas_audio_graph_tap.cpp
//

#include "yas_audio_graph_tap.h"

#include "yas_audio_rendering_connection.h"

using namespace yas;

#pragma mark - audio::graph_tap

audio::graph_tap::graph_tap()
    : _node(graph_node::make_shared(graph_node_args{.input_bus_count = 1, .output_bus_count = 1})) {
    auto const manageable_node = manageable_graph_node::cast(this->_node);

    manageable_node->set_prepare_rendering_handler([this] {
        this->_node->set_render_handler([handler = this->_render_handler](node_render_args args) {
            if (handler) {
                handler.value()(args);
            } else {
                for (auto const &pair : args.source_connections) {
                    pair.second.render(args.buffer, args.time);
                }
            }
        });
    });

    manageable_node->set_will_reset_handler([this] { this->_render_handler = std::nullopt; });
}

void audio::graph_tap::set_render_handler(audio::node_render_f handler) {
    this->_render_handler = std::move(handler);

    renderable_graph_node::cast(this->_node)->update_rendering();
}

audio::graph_node_ptr const &audio::graph_tap::node() const {
    return this->_node;
}

#pragma mark - factory

audio::graph_tap_ptr audio::graph_tap::make_shared() {
    return graph_tap_ptr(new graph_tap{});
}

#pragma mark - audio::graph_input_tap

audio::graph_input_tap::graph_input_tap()
    : _node(graph_node::make_shared(graph_node_args{.input_bus_count = 1, .input_renderable = true})) {
    auto const manageable_node = manageable_graph_node::cast(this->_node);

    manageable_node->set_prepare_rendering_handler([this] {
        this->_node->set_render_handler([handler = this->_render_handler](node_render_args args) {
            if (handler) {
                handler.value()({.buffer = args.buffer, .bus_idx = args.bus_idx, .time = args.time});
            }
        });
    });

    manageable_node->set_will_reset_handler([this] { this->_render_handler = std::nullopt; });
}

void audio::graph_input_tap::set_render_handler(audio::node_input_render_f handler) {
    this->_render_handler = std::move(handler);

    renderable_graph_node::cast(this->_node)->update_rendering();
}

audio::graph_node_ptr const &audio::graph_input_tap::node() const {
    return this->_node;
}

#pragma mark - factory

audio::graph_input_tap_ptr audio::graph_input_tap::make_shared() {
    return graph_input_tap_ptr(new graph_input_tap{});
}
