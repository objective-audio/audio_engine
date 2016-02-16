//
//  yas_audio_route_node.cpp
//

#include "yas_audio_route_node.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - kernel

class audio::route_node::kernel : public node::kernel {
   public:
    ~kernel() = default;

    route_set_t routes;
};

#pragma mark - impl

class audio::route_node::impl : public node::impl {
    using super_class = super_class::impl;

   public:
    class core {
       public:
        route_set_t routes;

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

    virtual void reset() override {
        _core->routes.clear();
        super_class::reset();
    }

    virtual UInt32 input_bus_count() const override {
        return std::numeric_limits<UInt32>::max();
    }

    virtual UInt32 output_bus_count() const override {
        return std::numeric_limits<UInt32>::max();
    }

    virtual std::shared_ptr<node::kernel> make_kernel() override {
        return std::shared_ptr<node::kernel>(new route_node::kernel());
    }

    virtual void prepare_kernel(std::shared_ptr<node::kernel> const &kernel) override {
        super_class::prepare_kernel(kernel);

        auto route_kernel = std::static_pointer_cast<route_node::kernel>(kernel);
        route_kernel->routes = _core->routes;
    }

    virtual void render(pcm_buffer &dst_buffer, UInt32 const dst_bus_idx, time const &when) override {
        super_class::render(dst_buffer, dst_bus_idx, when);

        if (auto kernel = kernel_cast<route_node::kernel>()) {
            auto &routes = kernel->routes;
            auto output_connection = kernel->output_connection(dst_bus_idx);
            auto input_connections = kernel->input_connections();
            UInt32 const dst_ch_count = dst_buffer.format().channel_count();

            for (auto const &pair : input_connections) {
                if (auto const &input_connection = pair.second) {
                    if (auto node = input_connection.source_node()) {
                        auto const &src_format = input_connection.format();
                        auto const &src_bus_idx = pair.first;
                        UInt32 const src_ch_count = src_format.channel_count();
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

audio::route_node::route_node() : super_class(std::make_unique<impl>()) {
}

audio::route_node::route_node(std::nullptr_t) : super_class(nullptr) {
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
