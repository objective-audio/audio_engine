//
//  yas_audio_channel_route.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_channel_route.h"
#include "yas_audio_format.h"
#include "yas_cf_utils.h"
#include <exception>

using namespace yas;

class channel_route::impl
{
   public:
    UInt32 source_bus;
    UInt32 source_channel;
    UInt32 destination_bus;
    UInt32 destination_channel;
};

channel_route_sptr channel_route::create(const UInt32 src_bus_idx, const UInt32 src_ch_idx, const UInt32 dst_bus_idx,
                                         const UInt32 dst_ch_idx)
{
    return channel_route_sptr(new channel_route(src_bus_idx, src_ch_idx, dst_bus_idx, dst_ch_idx));
}

channel_route_sptr channel_route::create(const UInt32 bus_idx, const UInt32 ch_idx)
{
    return channel_route_sptr(new channel_route(bus_idx, ch_idx, bus_idx, ch_idx));
}

channel_route::channel_route(const UInt32 src_bus_idx, const UInt32 src_ch_idx, const UInt32 dst_bus_idx,
                             const UInt32 dst_ch_idx)
    : _impl(std::make_unique<impl>())
{
    _impl->source_bus = src_bus_idx;
    _impl->source_channel = src_ch_idx;
    _impl->destination_bus = dst_bus_idx;
    _impl->destination_channel = dst_ch_idx;
}

channel_route::~channel_route() = default;

std::vector<channel_route_sptr> channel_route::default_channel_routes(const UInt32 bus_idx,
                                                                      const audio_format_sptr &format)
{
    if (!format) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format. format is null.");
    }

    if (format->is_interleaved()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format. is_interleaved(" +
                                    std::to_string(format->is_interleaved()) + ")");
    }

    const UInt32 channel_count = format->channel_count();

    std::vector<channel_route_sptr> channel_routes;
    channel_routes.reserve(channel_count);

    for (UInt32 ch_idx = 0; ch_idx < channel_count; ++ch_idx) {
        channel_routes.push_back(channel_route::create(bus_idx, ch_idx));
    }

    return channel_routes;
}

channel_route::channel_route(const channel_route &route) : _impl(std::make_unique<impl>())
{
    _impl->source_bus = route._impl->source_bus;
    _impl->source_channel = route._impl->source_channel;
    _impl->destination_bus = route._impl->destination_bus;
    _impl->destination_channel = route._impl->destination_channel;
}

channel_route::channel_route(channel_route &&route) noexcept : _impl(std::move(route._impl))
{
    route._impl = nullptr;
}

channel_route &channel_route::operator=(const channel_route &route)
{
    if (this == &route) {
        return *this;
    }
    _impl->source_bus = route._impl->source_bus;
    _impl->source_channel = route._impl->source_channel;
    _impl->destination_bus = route._impl->destination_bus;
    _impl->destination_channel = route._impl->destination_channel;
    return *this;
}

channel_route &channel_route::operator=(channel_route &&route) noexcept
{
    if (this == &route) {
        return *this;
    }
    _impl = std::move(route._impl);
    route._impl = nullptr;
    return *this;
}

UInt32 channel_route::source_bus() const
{
    return _impl->source_bus;
}

UInt32 channel_route::source_channel() const
{
    return _impl->source_channel;
}

UInt32 channel_route::destination_bus() const
{
    return _impl->destination_bus;
}

UInt32 channel_route::destination_channel() const
{
    return _impl->destination_channel;
}

CFStringRef channel_route::description() const
{
    return to_cf_object(to_string(*this));
}

std::string yas::to_string(const channel_route &route)
{
    return "src-bus:" + std::to_string(route.source_bus()) + " src-ch:" + std::to_string(route.source_channel()) +
           " dst-bus:" + std::to_string(route.destination_bus()) + " dst-ch:" +
           std::to_string(route.destination_channel());
}
