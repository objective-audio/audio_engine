//
//  yas_audio_route.cpp
//

#include "yas_audio_engine_route.h"
#include "yas_audio_engine_node.h"
#include "yas_result.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - kernel

struct audio::engine::route::kernel : base {
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

struct audio::engine::route::impl : base::impl {
    audio::engine::node _node = {{.input_bus_count = std::numeric_limits<uint32_t>::max(),
                                  .output_bus_count = std::numeric_limits<uint32_t>::max()}};
    route_set_t _routes;
    chaining::any_observer _reset_observer = nullptr;

    virtual ~impl() final = default;

    void prepare(audio::engine::route const &route) {
        auto weak_route = to_weak(route);

        this->_node.set_render_handler([weak_route](auto args) {
            auto &dst_buffer = args.buffer;
            auto const dst_bus_idx = args.bus_idx;

            if (auto route = weak_route.lock()) {
                if (auto kernel = route.node().kernel()) {
                    auto const &routes = yas::cast<audio::engine::route::kernel>(kernel.decorator()).routes();
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

        this->_reset_observer = this->_node.chain(node::method::will_reset)
                                    .perform([weak_route](auto const &) {
                                        if (auto route = weak_route.lock()) {
                                            route.impl_ptr<audio::engine::route::impl>()->_will_reset();
                                        }
                                    })
                                    .end();

        this->_node.set_prepare_kernel_handler([weak_route](audio::engine::kernel &kernel) {
            if (auto route = weak_route.lock()) {
                audio::engine::route::kernel route_kernel{};
                route_kernel.set_routes(route.impl_ptr<impl>()->_routes);
                kernel.set_decorator(std::move(route_kernel));
            }
        });
    }

    audio::route_set_t const &routes() const {
        return _routes;
    }

    void add_route(audio::route &&route) {
        this->_erase_route_if_either_matched(route);
        this->_routes.insert(std::move(route));
        this->_node.manageable().update_kernel();
    }

    void remove_route(audio::route const &route) {
        this->_routes.erase(route);
        this->_node.manageable().update_kernel();
    }

    void remove_route_for_source(audio::route::point const &src_pt) {
        this->_erase_route_if([&src_pt](audio::route const &route_of_set) { return route_of_set.source == src_pt; });
        this->_node.manageable().update_kernel();
    }

    void remove_route_for_destination(audio::route::point const &dst_pt) {
        this->_erase_route_if(
            [&dst_pt](audio::route const &route_of_set) { return route_of_set.destination == dst_pt; });
        this->_node.manageable().update_kernel();
    }

    void set_routes(route_set_t &&routes) {
        this->_routes.clear();
        this->_routes = std::move(routes);
        this->_node.manageable().update_kernel();
    }

    void clear_routes() {
        this->_routes.clear();
        this->_node.manageable().update_kernel();
    }

    audio::engine::node &node() {
        return this->_node;
    }

   private:
    void _will_reset() {
        this->_routes.clear();
    }

    void _erase_route_if_either_matched(audio::route const &route) {
        this->_erase_route_if([&route](audio::route const &route_of_set) {
            return route_of_set.source == route.source || route_of_set.destination == route.destination;
        });
    }

    void _erase_route_if(std::function<bool(audio::route const &)> pred) {
        erase_if(this->_routes, pred);
    }
};

#pragma mark - main

audio::engine::route::route() : base(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::route::route(std::nullptr_t) : base(nullptr) {
}

audio::engine::route::~route() = default;

audio::route_set_t const &audio::engine::route::routes() const {
    return impl_ptr<impl>()->routes();
}

void audio::engine::route::add_route(audio::route route) {
    impl_ptr<impl>()->add_route(std::move(route));
}

void audio::engine::route::remove_route(audio::route const &route) {
    impl_ptr<impl>()->remove_route(route);
}

void audio::engine::route::remove_route_for_source(audio::route::point const &src_pt) {
    impl_ptr<impl>()->remove_route_for_source(src_pt);
}

void audio::engine::route::remove_route_for_destination(audio::route::point const &dst_pt) {
    impl_ptr<impl>()->remove_route_for_destination(dst_pt);
}

void audio::engine::route::set_routes(route_set_t routes) {
    impl_ptr<impl>()->set_routes(std::move(routes));
}

void audio::engine::route::clear_routes() {
    impl_ptr<impl>()->clear_routes();
}

audio::engine::node const &audio::engine::route::node() const {
    return impl_ptr<impl>()->node();
}

audio::engine::node &audio::engine::route::node() {
    return impl_ptr<impl>()->node();
}
