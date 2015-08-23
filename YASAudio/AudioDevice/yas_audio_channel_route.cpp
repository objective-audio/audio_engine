//
//  yas_audio_channel_route.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_channel_route.h"
#include "yas_audio_format.h"
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

channel_route_ptr channel_route::create(const UInt32 source_bus, const UInt32 source_channel,
                                        const UInt32 destination_bus, const UInt32 destination_channel)
{
    return channel_route_ptr(new channel_route(source_bus, source_channel, destination_bus, destination_channel));
}

channel_route_ptr channel_route::create(const UInt32 bus, const UInt32 channel)
{
    return channel_route_ptr(new channel_route(bus, channel, bus, channel));
}

channel_route::channel_route(const UInt32 source_bus, const UInt32 source_channel, const UInt32 destination_bus,
                             const UInt32 destination_channel)
    : _impl(std::make_unique<impl>())
{
    _impl->source_bus = source_bus;
    _impl->source_channel = source_channel;
    _impl->destination_bus = destination_bus;
    _impl->destination_channel = destination_channel;
}

channel_route::~channel_route()
{
}

std::vector<channel_route_ptr> channel_route::default_channel_routes(const UInt32 bus, const audio_format_ptr &format)
{
    if (!format) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format. format is null.");
    }

    if (format->is_interleaved()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format. is_interleaved(" +
                                    std::to_string(format->is_interleaved()) + ")");
    }

    const UInt32 channel_count = format->channel_count();

    std::vector<channel_route_ptr> channel_routes;
    channel_routes.reserve(channel_count);

    for (UInt32 ch = 0; ch < channel_count; ++ch) {
        channel_routes.push_back(channel_route::create(bus, ch));
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

std::string yas::to_string(const channel_route &route)
{
    return "src-bus:" + std::to_string(route.source_bus()) + " src-ch:" + std::to_string(route.source_channel()) +
           " dst-bus:" + std::to_string(route.destination_bus()) + " dst-ch:" +
           std::to_string(route.destination_channel());
}
