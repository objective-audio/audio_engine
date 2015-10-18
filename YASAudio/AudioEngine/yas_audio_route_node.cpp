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
    impl() : audio_node::impl(), _core(std::make_unique<core>())
    {
    }

    ~impl() = default;

    virtual UInt32 input_bus_count() const override
    {
        return std::numeric_limits<UInt32>::max();
    }

    virtual UInt32 output_bus_count() const override
    {
        return std::numeric_limits<UInt32>::max();
    }

    class core;
    std::unique_ptr<core> _core;
};

class audio_route_node::impl::core
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

#pragma mark - main

audio_route_node_sptr audio_route_node::create()
{
    return std::shared_ptr<audio_route_node>(new audio_route_node());
}

audio_route_node::audio_route_node() : audio_node(std::make_unique<impl>())
{
}

const std::set<audio_route> &audio_route_node::routes() const
{
    return _impl_ptr()->_core->routes;
}

void audio_route_node::add_route(const audio_route &route)
{
    _impl_ptr()->_core->erase_route_if_either_matched(route);
    _impl_ptr()->_core->routes.insert(route);
    update_kernel();
}

void audio_route_node::add_route(audio_route &&route)
{
    _impl_ptr()->_core->erase_route_if_either_matched(route);
    _impl_ptr()->_core->routes.insert(std::move(route));
    update_kernel();
}

void audio_route_node::remove_route(const audio_route &route)
{
    _impl_ptr()->_core->routes.erase(route);
    update_kernel();
}

void audio_route_node::remove_route_for_source(const audio_route::point &src_pt)
{
    _impl_ptr()->_core->erase_route_if(
        [&src_pt](const audio_route &route_of_set) { return route_of_set.source == src_pt; });
    update_kernel();
}

void audio_route_node::remove_route_for_destination(const audio_route::point &dst_pt)
{
    _impl_ptr()->_core->erase_route_if(
        [&dst_pt](const audio_route &route_of_set) { return route_of_set.destination == dst_pt; });
    update_kernel();
}

void audio_route_node::set_routes(const std::set<audio_route> &routes)
{
    _impl_ptr()->_core->routes.clear();
    _impl_ptr()->_core->routes = routes;
    update_kernel();
}

void audio_route_node::set_routes(std::set<audio_route> &&routes)
{
    _impl_ptr()->_core->routes.clear();
    _impl_ptr()->_core->routes = std::move(routes);
    update_kernel();
}

void audio_route_node::clear_routes()
{
    _impl_ptr()->_core->routes.clear();
    update_kernel();
}

#pragma mark - protected

std::shared_ptr<audio_node::kernel> audio_route_node::make_kernel()
{
    return std::shared_ptr<audio_node::kernel>(new audio_route_node::kernel());
}

void audio_route_node::prepare_kernel(const std::shared_ptr<audio_node::kernel> &kernel)
{
    super_class::prepare_kernel(kernel);

    if (audio_route_node::kernel *route_kernel = dynamic_cast<audio_route_node::kernel *>(kernel.get())) {
        route_kernel->routes = _impl_ptr()->_core->routes;
    } else {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                 " : failed dynamic cast to audio_route_node::kernel.");
    }
}

#pragma mark - private

audio_route_node::impl *audio_route_node::_impl_ptr() const
{
    return dynamic_cast<audio_route_node::impl *>(_impl.get());
}

#pragma mark - render thread

std::shared_ptr<audio_route_node::kernel> audio_route_node::_kernel() const
{
    return std::static_pointer_cast<audio_route_node::kernel>(super_class::_kernel());
}

void audio_route_node::render(audio_pcm_buffer &dst_buffer, const UInt32 dst_bus_idx, const audio_time &when)
{
    super_class::render(dst_buffer, dst_bus_idx, when);

    if (auto kernel = _kernel()) {
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
                        node->render(src_buffer, src_bus_idx, when);
                    }
                }
            }
        }
    }
}
