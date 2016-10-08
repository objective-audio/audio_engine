//
//  yas_audio_route_node.cpp
//

#include "yas_audio_node.h"
#include "yas_audio_route_node.h"
#include "yas_result.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - kernel

struct audio::engine::route_node::kernel : base {
    struct impl : base::impl {
        route_set_t _routes;
    };

    kernel() : base(std::make_shared<impl>()) {
    }

    kernel(std::nullptr_t) : base(nullptr) {
    }

    void set_routes(route_set_t routes) {
        impl_ptr<impl>()->_routes = std::move(routes);
    }

    route_set_t const &routes() {
        return impl_ptr<impl>()->_routes;
    }
};

#pragma mark - impl

struct audio::engine::route_node::impl : base::impl {
    audio::engine::node _node = {{.input_bus_count = std::numeric_limits<uint32_t>::max(),
                                  .output_bus_count = std::numeric_limits<uint32_t>::max()}};
    route_set_t _routes;
    audio::engine::node::observer_t _reset_observer;

    virtual ~impl() final = default;

    void prepare(audio::engine::route_node const &node) {
        auto weak_node = to_weak(node);

        _node.set_render_handler([weak_node](auto args) {
            auto &dst_buffer = args.buffer;
            auto const dst_bus_idx = args.bus_idx;

            if (auto node = weak_node.lock()) {
                if (auto kernel = node.node().kernel()) {
                    auto const &routes = yas::cast<audio::engine::route_node::kernel>(kernel.decorator()).routes();
                    auto output_connection = kernel.output_connection(dst_bus_idx);
                    auto input_connections = kernel.input_connections();
                    uint32_t const dst_ch_count = dst_buffer.format().channel_count();

                    for (auto const &pair : input_connections) {
                        if (auto const &input_connection = pair.second) {
                            if (auto node = input_connection.source_node()) {
                                auto const &src_format = input_connection.format();
                                auto const &src_bus_idx = pair.first;
                                uint32_t const src_ch_count = src_format.channel_count();
                                if (auto const result = channel_map_from_routes(routes, src_bus_idx, src_ch_count,
                                                                                dst_bus_idx, dst_ch_count)) {
                                    pcm_buffer src_buffer(src_format, dst_buffer, result.value());
                                    node.render({.buffer = src_buffer, .bus_idx = src_bus_idx, .when = args.when});
                                }
                            }
                        }
                    }
                }
            }
        });

        _reset_observer =
            _node.subject().make_observer(audio::engine::node::method::will_reset, [weak_node](auto const &) {
                if (auto node = weak_node.lock()) {
                    node.impl_ptr<audio::engine::route_node::impl>()->_will_reset();
                }
            });

        _node.set_prepare_kernel_handler([weak_node](audio::engine::kernel &kernel) {
            if (auto node = weak_node.lock()) {
                audio::engine::route_node::kernel route_kernel{};
                route_kernel.set_routes(node.impl_ptr<impl>()->_routes);
                kernel.set_decorator(std::move(route_kernel));
            }
        });
    }

    audio::route_set_t const &routes() const {
        return _routes;
    }

    void add_route(route &&route) {
        _erase_route_if_either_matched(route);
        _routes.insert(std::move(route));
        _node.manageable().update_kernel();
    }

    void remove_route(route const &route) {
        _routes.erase(route);
        _node.manageable().update_kernel();
    }

    void remove_route_for_source(route::point const &src_pt) {
        _erase_route_if([&src_pt](route const &route_of_set) { return route_of_set.source == src_pt; });
        _node.manageable().update_kernel();
    }

    void remove_route_for_destination(route::point const &dst_pt) {
        _erase_route_if([&dst_pt](route const &route_of_set) { return route_of_set.destination == dst_pt; });
        _node.manageable().update_kernel();
    }

    void set_routes(route_set_t &&routes) {
        _routes.clear();
        _routes = std::move(routes);
        _node.manageable().update_kernel();
    }

    void clear_routes() {
        _routes.clear();
        _node.manageable().update_kernel();
    }

    audio::engine::node &node() {
        return _node;
    }

   private:
    void _will_reset() {
        _routes.clear();
    }

    void _erase_route_if_either_matched(route const &route) {
        _erase_route_if([&route](audio::route const &route_of_set) {
            return route_of_set.source == route.source || route_of_set.destination == route.destination;
        });
    }

    void _erase_route_if(std::function<bool(route const &)> pred) {
        erase_if(_routes, pred);
    }
};

#pragma mark - main

audio::engine::route_node::route_node() : base(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::route_node::route_node(std::nullptr_t) : base(nullptr) {
}

audio::engine::route_node::~route_node() = default;

audio::route_set_t const &audio::engine::route_node::routes() const {
    return impl_ptr<impl>()->routes();
}

void audio::engine::route_node::add_route(route route) {
    impl_ptr<impl>()->add_route(std::move(route));
}

void audio::engine::route_node::remove_route(route const &route) {
    impl_ptr<impl>()->remove_route(route);
}

void audio::engine::route_node::remove_route_for_source(route::point const &src_pt) {
    impl_ptr<impl>()->remove_route_for_source(src_pt);
}

void audio::engine::route_node::remove_route_for_destination(route::point const &dst_pt) {
    impl_ptr<impl>()->remove_route_for_destination(dst_pt);
}

void audio::engine::route_node::set_routes(route_set_t routes) {
    impl_ptr<impl>()->set_routes(std::move(routes));
}

void audio::engine::route_node::clear_routes() {
    impl_ptr<impl>()->clear_routes();
}

audio::engine::node const &audio::engine::route_node::node() const {
    return impl_ptr<impl>()->node();
}

audio::engine::node &audio::engine::route_node::node() {
    return impl_ptr<impl>()->node();
}
