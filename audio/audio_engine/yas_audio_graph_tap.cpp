//
//  yas_audio_graph_tap.cpp
//

#include "yas_audio_graph_tap.h"

#include "yas_audio_rendering_connection.h"

using namespace yas;

#pragma mark - audio::tap_kernel

struct audio::graph_tap::kernel {
    kernel() = default;

    std::optional<audio::node_render_f> render_handler = std::nullopt;

   private:
    kernel(kernel const &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(kernel const &) = delete;
    kernel &operator=(kernel &&) = delete;
};

#pragma mark - audio::tap

audio::graph_tap::graph_tap(args &&args)
    : _node(graph_node::make_shared(args.is_input ? graph_node_args{.input_bus_count = 1, .input_renderable = true} :
                                                    graph_node_args{.input_bus_count = 1, .output_bus_count = 1})) {
}

void audio::graph_tap::_prepare(graph_tap_ptr const &shared) {
    auto weak_tap = to_weak(shared);

    this->_node->set_render_handler([weak_tap](node_render_args args) {
        if (auto tap = weak_tap.lock()) {
            if (auto const kernel = tap->_node->kernel()) {
                tap->_kernel_on_render = kernel;

                auto tap_kernel = std::any_cast<graph_tap::kernel_ptr>(kernel.value()->decorator.value());
                auto const &handler = tap_kernel->render_handler;

                if (handler) {
                    handler.value()(args);
                } else {
                    for (auto const &pair : args.source_connections) {
                        pair.second.render(args.buffer, args.time);
                    }
                }

                tap->_kernel_on_render = std::nullopt;
            }
        }
    });

    this->_reset_observer = this->_node->chain(graph_node::method::will_reset)
                                .perform([weak_tap](auto const &) {
                                    if (auto tap = weak_tap.lock()) {
                                        tap->_render_handler = std::nullopt;
                                    }
                                })
                                .end();

    this->_node->set_prepare_kernel_handler([weak_tap](audio::graph_kernel &kernel) {
        if (auto tap = weak_tap.lock()) {
            auto tap_kernel = std::make_shared<audio::graph_tap::kernel>();
            tap_kernel->render_handler = tap->_render_handler;
            kernel.decorator = std::move(tap_kernel);
        }
    });
}

void audio::graph_tap::set_render_handler(audio::node_render_f handler) {
    this->_render_handler = handler;

    manageable_graph_node::cast(this->_node)->update_kernel();
}

audio::graph_node_ptr const &audio::graph_tap::node() const {
    return this->_node;
}

#pragma mark - factory

audio::graph_tap_ptr audio::graph_tap::make_shared() {
    return graph_tap::make_shared({.is_input = false});
}

audio::graph_tap_ptr audio::graph_tap::make_shared(graph_tap::args args) {
    auto shared = graph_tap_ptr(new graph_tap{std::move(args)});
    shared->_prepare(shared);
    return shared;
}
