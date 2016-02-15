//
//  yas_audio_route.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <MacTypes.h>
#include <memory>
#include <string>
#include <vector>
#include "yas_audio_format.h"
#include "yas_audio_types.h"
#include "yas_result.h"

namespace yas {
namespace audio {
    struct route {
        struct point {
            UInt32 bus;
            UInt32 channel;

            point(UInt32 const bus_idx, UInt32 const ch_idx);

            bool operator==(point const &) const;
            bool operator!=(point const &) const;
        };

        route(UInt32 const src_bus_idx, UInt32 const src_ch_idx, UInt32 const dst_bus_idx, UInt32 const dst_ch_idx);
        route(UInt32 const bus_idx, UInt32 const ch_idx);
        route(point const &src_point, point const &dst_point);

        bool operator==(route const &) const;
        bool operator!=(route const &) const;
        bool operator<(route const &) const;

        point source;
        point destination;
    };

    using route_set_t = std::set<route>;

    using channel_map_result = result<channel_map_t, std::nullptr_t>;
    channel_map_result channel_map_from_routes(route_set_t const &routes, UInt32 const src_bus_idx,
                                               UInt32 const src_ch_count, UInt32 const dst_bus_idx,
                                               UInt32 const dst_ch_count);
}
}
