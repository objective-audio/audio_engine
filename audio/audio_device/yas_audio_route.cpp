//
//  yas_audio_route.cpp
//

#include <exception>
#include "yas_audio_route.h"
#include "yas_cf_utils.h"
#include "yas_result.h"

using namespace yas;

audio::route::point::point(uint32_t const bus_idx, uint32_t const ch_idx) : bus(bus_idx), channel(ch_idx) {
}

bool audio::route::point::operator==(point const &rhs) const {
    return bus == rhs.bus && channel == rhs.channel;
}

bool audio::route::point::operator!=(point const &rhs) const {
    return bus != rhs.bus || channel != rhs.channel;
}

audio::route::route(uint32_t const src_bus_idx, uint32_t const src_ch_idx, uint32_t const dst_bus_idx,
                    uint32_t const dst_ch_idx)
    : source(src_bus_idx, src_ch_idx), destination(dst_bus_idx, dst_ch_idx) {
}

audio::route::route(uint32_t const bus_idx, uint32_t const ch_idx)
    : source(bus_idx, ch_idx), destination(bus_idx, ch_idx) {
}

audio::route::route(point const &src_point, point const &dst_point) : source(src_point), destination(dst_point) {
}

bool audio::route::operator==(route const &rhs) const {
    return source == rhs.source && destination == rhs.destination;
}

bool audio::route::operator!=(route const &rhs) const {
    return source != rhs.source || destination != rhs.destination;
}

bool audio::route::operator<(route const &rhs) const {
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

audio::channel_map_result audio::channel_map_from_routes(route_set_t const &routes, uint32_t const src_bus_idx,
                                                         uint32_t const src_ch_count, uint32_t const dst_bus_idx,
                                                         uint32_t const dst_ch_count) {
    channel_map_t channel_map(src_ch_count, -1);
    bool exists = false;

    for (auto const &route : routes) {
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
