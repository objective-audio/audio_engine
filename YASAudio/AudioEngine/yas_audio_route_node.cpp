//
//  yas_audio_route_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_route_node.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - node_core

namespace yas
{
    class audio_route_node_core : public audio_node_core
    {
       public:
        audio_route_set routes;
    };
}

#pragma mark - impl

class audio_route_node::impl
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

audio_route_node::audio_route_node() : audio_node(), _impl(std::make_unique<impl>())
{
}

UInt32 audio_route_node::input_bus_count() const
{
    return std::numeric_limits<UInt32>::max();
}

UInt32 audio_route_node::output_bus_count() const
{
    return std::numeric_limits<UInt32>::max();
}

const std::set<audio_route> &audio_route_node::routes() const
{
    return _impl->routes;
}

void audio_route_node::add_route(const audio_route &route)
{
    _impl->erase_route_if_either_matched(route);
    _impl->routes.insert(route);
    update_node_core();
}

void audio_route_node::add_route(audio_route &&route)
{
    _impl->erase_route_if_either_matched(route);
    _impl->routes.insert(std::move(route));
    update_node_core();
}

void audio_route_node::remove_route(const audio_route &route)
{
    _impl->routes.erase(route);
    update_node_core();
}

void audio_route_node::remove_route_for_source(const audio_route::point &src_pt)
{
    _impl->erase_route_if([&src_pt](const audio_route &route_of_set) { return route_of_set.source == src_pt; });
    update_node_core();
}

void audio_route_node::remove_route_for_destination(const audio_route::point &dst_pt)
{
    _impl->erase_route_if([&dst_pt](const audio_route &route_of_set) { return route_of_set.destination == dst_pt; });
    update_node_core();
}

void audio_route_node::set_routes(const std::set<audio_route> &routes)
{
    _impl->routes.clear();
    _impl->routes = routes;
    update_node_core();
}

void audio_route_node::set_routes(std::set<audio_route> &&routes)
{
    _impl->routes.clear();
    _impl->routes = std::move(routes);
    update_node_core();
}

void audio_route_node::clear_routes()
{
    _impl->routes.clear();
    update_node_core();
}

audio_node_core_sptr audio_route_node::make_node_core()
{
    return audio_node_core_sptr(new audio_route_node_core());
}

void audio_route_node::prepare_node_core(const audio_node_core_sptr &node_core)
{
    super_class::prepare_node_core(node_core);

    if (audio_route_node_core *route_node_core = dynamic_cast<audio_route_node_core *>(node_core.get())) {
        route_node_core->routes = _impl->routes;
    } else {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : failed dynamic cast to audio_route_node_core.");
    }
}

void audio_route_node::render(audio_pcm_buffer &dst_buffer, const UInt32 dst_bus_idx, const audio_time &when)
{
    super_class::render(dst_buffer, dst_bus_idx, when);

    if (auto core = node_core()) {
        audio_route_node_core *route_node_core = dynamic_cast<audio_route_node_core *>(core.get());
        auto &routes = route_node_core->routes;
        auto output_connection = core->output_connection(dst_bus_idx);
        auto input_connections = core->input_connections();
        const UInt32 dst_ch_count = dst_buffer.format().channel_count();

        for (const auto &pair : input_connections) {
            if (const auto &input_connection = pair.second) {
                if (auto node = input_connection->source_node()) {
                    const auto &src_format = input_connection->format();
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
