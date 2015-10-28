//
//  yas_audio_route_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_route_node.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - kernel

class audio_route_node::kernel : public audio_node::kernel
{
   public:
    ~kernel() = default;

    audio_route_set routes;
};

#pragma mark - impl

class audio_route_node::impl : public audio_node::impl
{
   public:
    class core
    {
       public:
        audio_route_set routes;

        void erase_route_if_either_matched(const audio_route &route)
        {
            erase_route_if([&route](const audio_route &route_of_set) {
                return route_of_set.source == route.source || route_of_set.destination == route.destination;
            });
        }

        void erase_route_if(std::function<bool(const audio_route &)> pred)
        {
            erase_if(routes, pred);
        }
    };

    impl() : audio_node::impl(), _core(std::make_unique<core>())
    {
    }

    ~impl() = default;

    virtual void reset() override
    {
        _core->routes.clear();
        super_class::reset();
    }

    virtual UInt32 input_bus_count() const override
    {
        return std::numeric_limits<UInt32>::max();
    }

    virtual UInt32 output_bus_count() const override
    {
        return std::numeric_limits<UInt32>::max();
    }

    virtual std::shared_ptr<audio_node::kernel> make_kernel() override
    {
        return std::shared_ptr<audio_node::kernel>(new audio_route_node::kernel());
    }

    virtual void prepare_kernel(const std::shared_ptr<audio_node::kernel> &kernel) override
    {
        super_class::prepare_kernel(kernel);

        auto route_kernel = std::static_pointer_cast<audio_route_node::kernel>(kernel);
        route_kernel->routes = _core->routes;
    }

    virtual void render(audio_pcm_buffer &dst_buffer, const UInt32 dst_bus_idx, const audio_time &when) override
    {
        super_class::render(dst_buffer, dst_bus_idx, when);

        if (auto kernel = kernel_cast<audio_route_node::kernel>()) {
            auto &routes = kernel->routes;
            auto output_connection = kernel->output_connection(dst_bus_idx);
            auto input_connections = kernel->input_connections();
            const UInt32 dst_ch_count = dst_buffer.format().channel_count();

            for (const auto &pair : input_connections) {
                if (const auto &input_connection = pair.second) {
                    if (auto node = input_connection.source_node()) {
                        const auto &src_format = input_connection.format();
                        const auto &src_bus_idx = pair.first;
                        const UInt32 src_ch_count = src_format.channel_count();
                        if (const auto result =
                                channel_map_from_routes(routes, src_bus_idx, src_ch_count, dst_bus_idx, dst_ch_count)) {
                            yas::audio_pcm_buffer src_buffer(src_format, dst_buffer, result.value());
                            node.render(src_buffer, src_bus_idx, when);
                        }
                    }
                }
            }
        }
    }

#pragma mark -

    const audio_route_set &routes() const
    {
        return _core->routes;
    }

    void add_route(const audio_route &route)
    {
        _core->erase_route_if_either_matched(route);
        _core->routes.insert(route);
        update_kernel();
    }

    void add_route(audio_route &&route)
    {
        _core->erase_route_if_either_matched(route);
        _core->routes.insert(std::move(route));
        update_kernel();
    }

    void remove_route(const audio_route &route)
    {
        _core->routes.erase(route);
        update_kernel();
    }

    void remove_route_for_source(const audio_route::point &src_pt)
    {
        _core->erase_route_if([&src_pt](const audio_route &route_of_set) { return route_of_set.source == src_pt; });
        update_kernel();
    }

    void remove_route_for_destination(const audio_route::point &dst_pt)
    {
        _core->erase_route_if(
            [&dst_pt](const audio_route &route_of_set) { return route_of_set.destination == dst_pt; });
        update_kernel();
    }

    void set_routes(const audio_route_set &routes)
    {
        _core->routes.clear();
        _core->routes = routes;
        update_kernel();
    }

    void set_routes(audio_route_set &&routes)
    {
        _core->routes.clear();
        _core->routes = std::move(routes);
        update_kernel();
    }

    void clear_routes()
    {
        _core->routes.clear();
        update_kernel();
    }

    std::unique_ptr<core> _core;

   private:
    using super_class = super_class::impl;
};

#pragma mark - main

audio_route_node::audio_route_node() : super_class(std::make_unique<impl>(), create_tag)
{
}

audio_route_node::audio_route_node(std::nullptr_t) : super_class(nullptr)
{
}

const audio_route_set &audio_route_node::routes() const
{
    return _impl_ptr()->routes();
}

void audio_route_node::add_route(const audio_route &route)
{
    _impl_ptr()->add_route(route);
}

void audio_route_node::add_route(audio_route &&route)
{
    _impl_ptr()->add_route(std::move(route));
}

void audio_route_node::remove_route(const audio_route &route)
{
    _impl_ptr()->remove_route(route);
}

void audio_route_node::remove_route_for_source(const audio_route::point &src_pt)
{
    _impl_ptr()->remove_route_for_source(src_pt);
}

void audio_route_node::remove_route_for_destination(const audio_route::point &dst_pt)
{
    _impl_ptr()->remove_route_for_destination(dst_pt);
}

void audio_route_node::set_routes(const audio_route_set &routes)
{
    _impl_ptr()->set_routes(routes);
}

void audio_route_node::set_routes(audio_route_set &&routes)
{
    _impl_ptr()->set_routes(std::move(routes));
}

void audio_route_node::clear_routes()
{
    _impl_ptr()->clear_routes();
}

#pragma mark - private

std::shared_ptr<audio_route_node::impl> audio_route_node::_impl_ptr() const
{
    return std::dynamic_pointer_cast<audio_route_node::impl>(_impl);
}
