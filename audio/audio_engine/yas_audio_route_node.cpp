//
//  yas_audio_route_node.cpp
//

#include "yas_audio_route_node.h"
#include "yas_result.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - kernel

struct audio::route_node::kernel : node::kernel {
    struct impl : node::kernel::impl {
        route_set_t routes;
    };

    kernel() : node::kernel(std::make_shared<impl>()) {
    }

    kernel(std::nullptr_t) : node::kernel(nullptr) {
    }

    void set_routes(route_set_t routes) {
        impl_ptr<impl>()->routes = std::move(routes);
    }

    route_set_t const &routes() {
        return impl_ptr<impl>()->routes;
    }
};

#pragma mark - impl

struct audio::route_node::impl : node::impl {
    struct core {
        route_set_t routes;
        audio::node::observer_t _reset_observer;

        void erase_route_if_either_matched(route const &route) {
            erase_route_if([&route](audio::route const &route_of_set) {
                return route_of_set.source == route.source || route_of_set.destination == route.destination;
            });
        }

        void erase_route_if(std::function<bool(route const &)> pred) {
            erase_if(routes, pred);
        }
    };

    impl() : node::impl(), _core(std::make_unique<core>()) {
    }

    ~impl() = default;

    void prepare(audio::route_node const &node) {
        set_make_kernel([]() { return route_node::kernel{}; });

        _core->_reset_observer =
            subject().make_observer(audio::node::method::will_reset, [weak_node = to_weak(node)](auto const &) {
                if (auto node = weak_node.lock()) {
                    node.impl_ptr<audio::route_node::impl>()->will_reset();
                }
            });
    }

    void will_reset() {
        _core->routes.clear();
    }

    virtual uint32_t input_bus_count() const override {
        return std::numeric_limits<uint32_t>::max();
    }

    virtual uint32_t output_bus_count() const override {
        return std::numeric_limits<uint32_t>::max();
    }

    virtual void prepare_kernel(node::kernel &kernel) override {
        node::impl::prepare_kernel(kernel);

        auto route_kernel = yas::cast<route_node::kernel>(kernel);
        route_kernel.set_routes(_core->routes);
    }

    virtual void render(pcm_buffer &dst_buffer, uint32_t const dst_bus_idx, time const &when) override {
        node::impl::render(dst_buffer, dst_bus_idx, when);

        if (auto kernel = kernel_cast<route_node::kernel>()) {
            auto const &routes = kernel.routes();
            auto output_connection = kernel.output_connection(dst_bus_idx);
            auto input_connections = kernel.input_connections();
            uint32_t const dst_ch_count = dst_buffer.format().channel_count();

            for (auto const &pair : input_connections) {
                if (auto const &input_connection = pair.second) {
                    if (auto node = input_connection.source_node()) {
                        auto const &src_format = input_connection.format();
                        auto const &src_bus_idx = pair.first;
                        uint32_t const src_ch_count = src_format.channel_count();
                        if (auto const result =
                                channel_map_from_routes(routes, src_bus_idx, src_ch_count, dst_bus_idx, dst_ch_count)) {
                            pcm_buffer src_buffer(src_format, dst_buffer, result.value());
                            node.render(src_buffer, src_bus_idx, when);
                        }
                    }
                }
            }
        }
    }

#pragma mark -

    audio::route_set_t const &routes() const {
        return _core->routes;
    }

    void add_route(route &&route) {
        _core->erase_route_if_either_matched(route);
        _core->routes.insert(std::move(route));
        update_kernel();
    }

    void remove_route(route const &route) {
        _core->routes.erase(route);
        update_kernel();
    }

    void remove_route_for_source(route::point const &src_pt) {
        _core->erase_route_if([&src_pt](route const &route_of_set) { return route_of_set.source == src_pt; });
        update_kernel();
    }

    void remove_route_for_destination(route::point const &dst_pt) {
        _core->erase_route_if([&dst_pt](route const &route_of_set) { return route_of_set.destination == dst_pt; });
        update_kernel();
    }

    void set_routes(route_set_t &&routes) {
        _core->routes.clear();
        _core->routes = std::move(routes);
        update_kernel();
    }

    void clear_routes() {
        _core->routes.clear();
        update_kernel();
    }

   private:
    std::unique_ptr<core> _core;
};

#pragma mark - main

audio::route_node::route_node() : node(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::route_node::route_node(std::nullptr_t) : node(nullptr) {
}

audio::route_set_t const &audio::route_node::routes() const {
    return impl_ptr<impl>()->routes();
}

void audio::route_node::add_route(route route) {
    impl_ptr<impl>()->add_route(std::move(route));
}

void audio::route_node::remove_route(route const &route) {
    impl_ptr<impl>()->remove_route(route);
}

void audio::route_node::remove_route_for_source(route::point const &src_pt) {
    impl_ptr<impl>()->remove_route_for_source(src_pt);
}

void audio::route_node::remove_route_for_destination(route::point const &dst_pt) {
    impl_ptr<impl>()->remove_route_for_destination(dst_pt);
}

void audio::route_node::set_routes(route_set_t routes) {
    impl_ptr<impl>()->set_routes(std::move(routes));
}

void audio::route_node::clear_routes() {
    impl_ptr<impl>()->clear_routes();
}
