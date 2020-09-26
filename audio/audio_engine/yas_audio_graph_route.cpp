//
//  yas_audio_route.cpp
//

#include "yas_audio_graph_route.h"

#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>

#include "yas_audio_graph_node.h"
#include "yas_audio_rendering_connection.h"

using namespace yas;

#pragma mark - main

audio::graph_route::graph_route()
    : _node(graph_node::make_shared({.input_bus_count = std::numeric_limits<uint32_t>::max(),
                                     .output_bus_count = std::numeric_limits<uint32_t>::max()})) {
    this->_node->chain(graph_node::method::prepare_rendering)
        .perform([this](auto const &) {
            this->_node->set_render_handler([routes = this->_routes](node_render_args const &args) {
                auto &dst_buffer = args.buffer;
                auto const dst_bus_idx = args.bus_idx;
                uint32_t const dst_ch_count = dst_buffer->format().channel_count();

                for (auto const &pair : args.source_connections) {
                    auto const &src_connection = pair.second;
                    if (auto const *node = src_connection.source_node) {
                        auto const &src_format = src_connection.format;
                        auto const &src_bus_idx = pair.first;
                        uint32_t const src_ch_count = src_format.channel_count();
                        if (auto const result =
                                channel_map_from_routes(routes, src_bus_idx, src_ch_count, dst_bus_idx, dst_ch_count)) {
                            pcm_buffer src_buffer(src_format, *dst_buffer, result.value());

                            src_connection.render(&src_buffer, args.time);
                        }
                    }
                }
            });
        })
        .end()
        ->add_to(this->_pool);

    this->_node->chain(graph_node::method::will_reset)
        .perform([this](auto const &) { this->_will_reset(); })
        .end()
        ->add_to(this->_pool);
}

audio::graph_route::~graph_route() = default;

audio::route_set_t const &audio::graph_route::routes() const {
    return _routes;
}

void audio::graph_route::add_route(audio::route route) {
    this->_erase_route_if_either_matched(route);
    this->_routes.insert(std::move(route));
    this->_update_rendering();
}

void audio::graph_route::remove_route(audio::route const &route) {
    this->_routes.erase(route);
    this->_update_rendering();
}

void audio::graph_route::remove_route_for_source(audio::route::point const &src_pt) {
    this->_erase_route_if([&src_pt](audio::route const &route_of_set) { return route_of_set.source == src_pt; });
    this->_update_rendering();
}

void audio::graph_route::remove_route_for_destination(audio::route::point const &dst_pt) {
    this->_erase_route_if([&dst_pt](audio::route const &route_of_set) { return route_of_set.destination == dst_pt; });
    this->_update_rendering();
}

void audio::graph_route::set_routes(route_set_t routes) {
    this->_routes.clear();
    this->_routes = std::move(routes);
    this->_update_rendering();
}

void audio::graph_route::clear_routes() {
    this->_routes.clear();
    this->_update_rendering();
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

void audio::graph_route::_update_rendering(){
#warning todo io_rendering
}

audio::graph_route_ptr audio::graph_route::make_shared() {
    return graph_route_ptr(new graph_route{});
}
