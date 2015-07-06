//
//  yas_audio_channel_route.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include <MacTypes.h>
#include <string>
#include <memory>
#include <vector>

namespace yas
{
    class channel_route
    {
       public:
        static channel_route_ptr create(const UInt32 source_bus, const UInt32 source_channel,
                                        const UInt32 destination_bus, const UInt32 destination_channel);
        static channel_route_ptr create(const UInt32 bus, const UInt32 channel);

        ~channel_route();

        channel_route(const channel_route &);
        channel_route(channel_route &&) noexcept;
        channel_route &operator=(const channel_route &);
        channel_route &operator=(channel_route &&) noexcept;

        static std::vector<channel_route_ptr> default_channel_routes(const UInt32 bus, const audio_format_ptr &format);

        UInt32 source_bus() const;
        UInt32 source_channel() const;
        UInt32 destination_bus() const;
        UInt32 destination_channel() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        channel_route(const UInt32 source_bus, const UInt32 source_channel, const UInt32 destination_bus,
                      const UInt32 destination_channel);
    };
}
