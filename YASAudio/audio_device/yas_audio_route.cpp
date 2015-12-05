//
//  yas_audio_route.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_route.h"
#include "yas_audio_format.h"
#include "yas_cf_utils.h"
#include <exception>

using namespace yas;

audio::route::point::point(const UInt32 bus_idx, const UInt32 ch_idx) : bus(bus_idx), channel(ch_idx)
{
}

bool audio::route::point::operator==(const point &rhs) const
{
    return bus == rhs.bus && channel == rhs.channel;
}

bool audio::route::point::operator!=(const point &rhs) const
{
    return bus != rhs.bus || channel != rhs.channel;
}

audio::route::route(const UInt32 src_bus_idx, const UInt32 src_ch_idx, const UInt32 dst_bus_idx,
                    const UInt32 dst_ch_idx)
    : source(src_bus_idx, src_ch_idx), destination(dst_bus_idx, dst_ch_idx)
{
}

audio::route::route(const UInt32 bus_idx, const UInt32 ch_idx) : source(bus_idx, ch_idx), destination(bus_idx, ch_idx)
{
}

audio::route::route(const point &src_point, const point &dst_point) : source(src_point), destination(dst_point)
{
}

bool audio::route::operator==(const audio::route &rhs) const
{
    return source == rhs.source && destination == rhs.destination;
}

bool audio::route::operator!=(const audio::route &rhs) const
{
    return source != rhs.source || destination != rhs.destination;
}

bool audio::route::operator<(const audio::route &rhs) const
{
    if (source.bus != rhs.source.bus) {
        return source.bus < rhs.source.bus;
    }

    if (destination.bus != rhs.destination.bus) {
        return destination.bus < rhs.destination.bus;
    }

    if (source.channel != rhs.source.channel) {
        return source.channel < rhs.source.channel;
    }

    return destination.channel < rhs.destination.channel;
}

#pragma mark -

audio::channel_map_result yas::audio::channel_map_from_routes(const route_set_t &routes, const UInt32 src_bus_idx,
                                                              const UInt32 src_ch_count, const UInt32 dst_bus_idx,
                                                              const UInt32 dst_ch_count)
{
    channel_map_t channel_map(src_ch_count, -1);
    bool exists = false;

    for (const auto &route : routes) {
        if (route.source.bus == src_bus_idx && route.destination.bus == dst_bus_idx &&
            route.source.channel < src_ch_count && route.destination.channel < dst_ch_count) {
            channel_map.at(route.source.channel) = route.destination.channel;
            exists = true;
        }
    }

    if (exists) {
        return channel_map_result(std::move(channel_map));
    }

    return channel_map_result(nullptr);
}
