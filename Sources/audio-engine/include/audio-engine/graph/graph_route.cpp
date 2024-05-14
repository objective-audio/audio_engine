//
//  route.cpp
//

#include "graph_route.h"

#include <audio-engine/graph/graph_node.h>
#include <audio-engine/rendering/rendering_connection.h>
#include <cpp-utils/result.h>
#include <cpp-utils/stl_utils.h>

using namespace yas;
using namespace yas::audio;

#pragma mark - main

graph_route::graph_route()
    : node(graph_node::make_shared({.input_bus_count = std::numeric_limits<uint32_t>::max(),
                                    .output_bus_count = std::numeric_limits<uint32_t>::max()})) {
    auto const manageable_node = manageable_graph_node::cast(this->node);

    manageable_node->set_prepare_rendering_handler([this] {
        this->node->set_render_handler([routes = this->_routes](node_render_args const &args) {
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
    });

    manageable_node->set_will_reset_handler([this] { this->_will_reset(); });
}

graph_route::~graph_route() = default;

route_set_t const &graph_route::routes() const {
    return _routes;
}

void graph_route::add_route(route route) {
    this->_erase_route_if_either_matched(route);
    this->_routes.insert(std::move(route));
    this->_update_rendering();
}

void graph_route::remove_route(route const &route) {
    this->_routes.erase(route);
    this->_update_rendering();
}

void graph_route::remove_route_for_source(route::point const &src_pt) {
    this->_erase_route_if([&src_pt](route const &route_of_set) { return route_of_set.source == src_pt; });
    this->_update_rendering();
}

void graph_route::remove_route_for_destination(route::point const &dst_pt) {
    this->_erase_route_if([&dst_pt](route const &route_of_set) { return route_of_set.destination == dst_pt; });
    this->_update_rendering();
}

void graph_route::set_routes(route_set_t routes) {
    this->_routes.clear();
    this->_routes = std::move(routes);
    this->_update_rendering();
}

void graph_route::clear_routes() {
    this->_routes.clear();
    this->_update_rendering();
}

void graph_route::_will_reset() {
    this->_routes.clear();
}

void graph_route::_erase_route_if_either_matched(route const &route) {
    this->_erase_route_if([&route](audio::route const &route_of_set) {
        return route_of_set.source == route.source || route_of_set.destination == route.destination;
    });
}

void graph_route::_erase_route_if(std::function<bool(route const &)> pred) {
    std::erase_if(this->_routes, std::move(pred));
}

void graph_route::_update_rendering() {
    renderable_graph_node::cast(this->node)->update_rendering();
}

graph_route_ptr graph_route::make_shared() {
    return graph_route_ptr(new graph_route{});
}
