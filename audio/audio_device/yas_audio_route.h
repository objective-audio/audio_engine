//
//  yas_audio_engine_route.h
//

#pragma once

#include <set>
#include "yas_audio_types.h"

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
struct route {
    struct point {
        uint32_t bus;
        uint32_t channel;

        bool operator==(point const &) const;
        bool operator!=(point const &) const;
    };

    route(uint32_t const src_bus_idx, uint32_t const src_ch_idx, uint32_t const dst_bus_idx, uint32_t const dst_ch_idx);
    route(uint32_t const bus_idx, uint32_t const ch_idx);
    route(point const &src_point, point const &dst_point);

    bool operator==(route const &) const;
    bool operator!=(route const &) const;
    bool operator<(route const &) const;

    point source;
    point destination;
};

using route_set_t = std::set<route>;

using channel_map_result = result<channel_map_t, std::nullptr_t>;
channel_map_result channel_map_from_routes(route_set_t const &routes, uint32_t const src_bus_idx,
                                           uint32_t const src_ch_count, uint32_t const dst_bus_idx,
                                           uint32_t const dst_ch_count);
}  // namespace yas::audio
