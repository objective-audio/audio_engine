//
//  yas_audio_route.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_format.h"
#include "yas_result.h"
#include <MacTypes.h>
#include <string>
#include <memory>
#include <vector>

namespace yas
{
    struct audio_route {
        struct point {
            UInt32 bus;
            UInt32 channel;

            point(const UInt32 bus_idx, const UInt32 ch_idx);

            bool operator==(const point &) const;
            bool operator!=(const point &) const;
        };

        audio_route(const UInt32 src_bus_idx, const UInt32 src_ch_idx, const UInt32 dst_bus_idx,
                    const UInt32 dst_ch_idx);
        audio_route(const UInt32 bus_idx, const UInt32 ch_idx);
        audio_route(const point &src_point, const point &dst_point);

        bool operator==(const audio_route &) const;
        bool operator!=(const audio_route &) const;
        bool operator<(const audio_route &) const;

        point source;
        point destination;
    };

    using channel_map_result = result<channel_map_t, std::nullptr_t>;
    channel_map_result channel_map_from_routes(const audio_route_set &routes, const UInt32 src_bus_idx,
                                               const UInt32 src_ch_count, const UInt32 dst_bus_idx,
                                               const UInt32 dst_ch_count);
}
