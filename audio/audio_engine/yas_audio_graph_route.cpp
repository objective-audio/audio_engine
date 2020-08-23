//
//  yas_audio_route.cpp
//

#include "yas_audio_graph_route.h"

#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>

#include "yas_audio_graph_node.h"

using namespace yas;

#pragma mark - kernel

struct audio::graph_route::kernel {
    kernel() {
    }

    route_set_t routes;

   private:
    kernel(kernel const &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(kernel const &) = delete;
    kernel &operator=(kernel &&) = delete;
};

#pragma mark - main

audio::graph_route::graph_route()
    : _node(graph_node::make_shared({.input_bus_count = std::numeric_limits<uint32_t>::max(),
                                     .output_bus_count = std::numeric_limits<uint32_t>::max()})) {
}

audio::graph_route::~graph_route() = default;

void audio::graph_route::_prepare(graph_route_ptr const &shared) {
    auto weak_route = to_weak(shared);

    this->_node->set_render_handler([weak_route](auto args) {
        auto &dst_buffer = args.output_buffer;
        auto const dst_bus_idx = args.bus_idx;

        if (auto route = weak_route.lock()) {
            if (auto const kernel_opt = route->node()->kernel()) {
                auto const &kernel = kernel_opt.value();
                auto const &routes = std::any_cast<audio::graph_route::kernel_ptr>(kernel->decorator.value())->routes;
                auto output_connection = kernel->output_connection(dst_bus_idx);
                auto input_connections = kernel->input_connections();
                uint32_t const dst_ch_count = dst_buffer->format().channel_count();

                for (auto const &pair : input_connections) {
                    if (auto const &input_connection = pair.second) {
                        if (auto node = input_connection->source_node()) {
                            auto const &src_format = input_connection->format;
                            auto const &src_bus_idx = pair.first;
                            uint32_t const src_ch_count = src_format.channel_count();
                            if (auto const result = channel_map_from_routes(routes, src_bus_idx, src_ch_count,
                                                                            dst_bus_idx, dst_ch_count)) {
                                auto const src_buffer =
                                    std::make_shared<pcm_buffer>(src_format, *dst_buffer, result.value());
                                node->render({.output_buffer = src_buffer,
                                              .bus_idx = src_bus_idx,
                                              .output_time = args.output_time});
                            }
                        }
                    }
                }
            }
        }
    });

    this->_reset_observer = this->_node->chain(graph_node::method::will_reset)
                                .perform([weak_route](auto const &) {
                                    if (auto route = weak_route.lock()) {
                                        route->_will_reset();
                                    }
                                })
                                .end();

    this->_node->set_prepare_kernel_handler([weak_route](audio::graph_kernel &kernel) {
        if (auto route = weak_route.lock()) {
            auto route_kernel = std::make_shared<audio::graph_route::kernel>();
            route_kernel->routes = route->_routes;
            kernel.decorator = std::move(route_kernel);
        }
    });
}

audio::route_set_t const &audio::graph_route::routes() const {
    return _routes;
}

void audio::graph_route::add_route(audio::route route) {
    this->_erase_route_if_either_matched(route);
    this->_routes.insert(std::move(route));
    manageable_graph_node::cast(this->_node)->update_kernel();
}

void audio::graph_route::remove_route(audio::route const &route) {
    this->_routes.erase(route);
    manageable_graph_node::cast(this->_node)->update_kernel();
}

void audio::graph_route::remove_route_for_source(audio::route::point const &src_pt) {
    this->_erase_route_if([&src_pt](audio::route const &route_of_set) { return route_of_set.source == src_pt; });
    manageable_graph_node::cast(this->_node)->update_kernel();
}

void audio::graph_route::remove_route_for_destination(audio::route::point const &dst_pt) {
    this->_erase_route_if([&dst_pt](audio::route const &route_of_set) { return route_of_set.destination == dst_pt; });
    manageable_graph_node::cast(this->_node)->update_kernel();
}

void audio::graph_route::set_routes(route_set_t routes) {
    this->_routes.clear();
    this->_routes = std::move(routes);
    manageable_graph_node::cast(this->_node)->update_kernel();
}

void audio::graph_route::clear_routes() {
    this->_routes.clear();
    manageable_graph_node::cast(this->_node)->update_kernel();
}

audio::graph_node_ptr const &audio::graph_route::node() const {
    return this->_node;
}

void audio::graph_route::_will_reset() {
    this->_routes.clear();
}

void audio::graph_route::_erase_route_if_either_matched(audio::route const &route) {
    this->_erase_route_if([&route](audio::route const &route_of_set) {
        return route_of_set.source == route.source || route_of_set.destination == route.destination;
    });
}

void audio::graph_route::_erase_route_if(std::function<bool(audio::route const &)> pred) {
    erase_if(this->_routes, pred);
}

audio::graph_route_ptr audio::graph_route::make_shared() {
    auto shared = graph_route_ptr(new graph_route{});
    shared->_prepare(shared);
    return shared;
}
