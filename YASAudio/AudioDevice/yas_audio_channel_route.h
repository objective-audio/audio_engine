//
//  yas_audio_channel_route.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_format.h"
#include <MacTypes.h>
#include <string>
#include <memory>
#include <vector>

namespace yas
{
    class channel_route
    {
       public:
        static channel_route_sptr create(const UInt32 src_bus_idx, const UInt32 src_ch_idx, const UInt32 dst_bus_idx,
                                         const UInt32 dst_ch_idx);
        static channel_route_sptr create(const UInt32 bus_idx, const UInt32 ch_idx);

        ~channel_route();

        channel_route(const channel_route &);
        channel_route(channel_route &&) noexcept;
        channel_route &operator=(const channel_route &);
        channel_route &operator=(channel_route &&) noexcept;

        static std::vector<channel_route_sptr> default_channel_routes(const UInt32 bus_idx,
                                                                      const audio_format_sptr &format);

        UInt32 source_bus() const;
        UInt32 source_channel() const;
        UInt32 destination_bus() const;
        UInt32 destination_channel() const;

        CFStringRef description() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        channel_route(const UInt32 source_bus, const UInt32 source_channel, const UInt32 destination_bus,
                      const UInt32 destination_channel);
    };

    std::string to_string(const channel_route &);
}
