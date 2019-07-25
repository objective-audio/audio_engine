//
//  yas_audio_route.cpp
//

#include "yas_audio_engine_route.h"
#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_engine_node.h"

using namespace yas;

#pragma mark - kernel

struct audio::engine::route::kernel {
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

audio::engine::route::route()
    : _node(make_node({.input_bus_count = std::numeric_limits<uint32_t>::max(),
                       .output_bus_count = std::numeric_limits<uint32_t>::max()})) {
}

audio::engine::route::~route() = default;

void audio::engine::route::_prepare() {
    auto weak_route = to_weak(shared_from_this());

    this->_node->set_render_handler([weak_route](auto args) {
        auto &dst_buffer = args.buffer;
        auto const dst_bus_idx = args.bus_idx;

        if (auto route = weak_route.lock()) {
            if (auto kernel = route->node().kernel()) {
                auto const &routes =
                    std::any_cast<std::shared_ptr<audio::engine::route::kernel>>(kernel->decorator)->routes;
                auto output_connection = kernel->output_connection(dst_bus_idx);
                auto input_connections = kernel->input_connections();
                uint32_t const dst_ch_count = dst_buffer.format().channel_count();

                for (auto const &pair : input_connections) {
                    if (auto const &input_connection = pair.second) {
                        if (auto node = input_connection->source_node()) {
                            auto const &src_format = input_connection->format;
                            auto const &src_bus_idx = pair.first;
                            uint32_t const src_ch_count = src_format.channel_count();
                            if (auto const result = channel_map_from_routes(routes, src_bus_idx, src_ch_count,
                                                                            dst_bus_idx, dst_ch_count)) {
                                pcm_buffer src_buffer(src_format, dst_buffer, result.value());
                                node->render({.buffer = src_buffer, .bus_idx = src_bus_idx, .when = args.when});
                            }
                        }
                    }
                }
            }
        }
    });

    this->_reset_observer = this->_node->chain(node::method::will_reset)
                                .perform([weak_route](auto const &) {
                                    if (auto route = weak_route.lock()) {
                                        route->_will_reset();
                                    }
                                })
                                .end();

    this->_node->set_prepare_kernel_handler([weak_route](audio::engine::kernel &kernel) {
        if (auto route = weak_route.lock()) {
            auto route_kernel = std::make_shared<audio::engine::route::kernel>();
            route_kernel->routes = route->_routes;
            kernel.decorator = std::move(route_kernel);
        }
    });
}

audio::route_set_t const &audio::engine::route::routes() const {
    return _routes;
}

void audio::engine::route::add_route(audio::route route) {
    this->_erase_route_if_either_matched(route);
    this->_routes.insert(std::move(route));
    this->_node->manageable()->update_kernel();
}

void audio::engine::route::remove_route(audio::route const &route) {
    this->_routes.erase(route);
    this->_node->manageable()->update_kernel();
}

void audio::engine::route::remove_route_for_source(audio::route::point const &src_pt) {
    this->_erase_route_if([&src_pt](audio::route const &route_of_set) { return route_of_set.source == src_pt; });
    this->_node->manageable()->update_kernel();
}

void audio::engine::route::remove_route_for_destination(audio::route::point const &dst_pt) {
    this->_erase_route_if([&dst_pt](audio::route const &route_of_set) { return route_of_set.destination == dst_pt; });
    this->_node->manageable()->update_kernel();
}

void audio::engine::route::set_routes(route_set_t routes) {
    this->_routes.clear();
    this->_routes = std::move(routes);
    this->_node->manageable()->update_kernel();
}

void audio::engine::route::clear_routes() {
    this->_routes.clear();
    this->_node->manageable()->update_kernel();
}

audio::engine::node const &audio::engine::route::node() const {
    return *this->_node;
}

audio::engine::node &audio::engine::route::node() {
    return *this->_node;
}

void audio::engine::route::_will_reset() {
    this->_routes.clear();
}

void audio::engine::route::_erase_route_if_either_matched(audio::route const &route) {
    this->_erase_route_if([&route](audio::route const &route_of_set) {
        return route_of_set.source == route.source || route_of_set.destination == route.destination;
    });
}

void audio::engine::route::_erase_route_if(std::function<bool(audio::route const &)> pred) {
    erase_if(this->_routes, pred);
}

std::shared_ptr<audio::engine::route> audio::engine::make_route() {
    auto shared = std::shared_ptr<route>(new route{});
    shared->_prepare();
    return shared;
}
