//
//  yas_audio_connection.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_connection.h"
#include "yas_audio_node.h"
#include <mutex>
#include <exception>

using namespace yas;

class audio_connection::impl
{
   public:
    std::weak_ptr<audio_node> source_node;
    UInt32 source_bus;
    std::weak_ptr<audio_node> destination_node;
    UInt32 destination_bus;
    audio_format_sptr format;
    mutable std::recursive_mutex mutex;

    impl(const audio_node_sptr &source_node, const UInt32 source_bus, const audio_node_sptr &destination_node,
         const UInt32 destination_bus, const audio_format_sptr &format)
        : source_bus(source_bus),
          destination_bus(destination_bus),
          format(format),
          source_node(source_node),
          destination_node(destination_node)
    {
    }
};

audio_connection_sptr audio_connection::_create(const audio_node_sptr &source_node, const UInt32 source_bus,
                                               const audio_node_sptr &destination_node, const UInt32 destination_bus,
                                               const audio_format_sptr &format)
{
    auto connection =
        audio_connection_sptr(new audio_connection(source_node, source_bus, destination_node, destination_bus, format));
    audio_node::private_access::add_connection(source_node, connection);
    audio_node::private_access::add_connection(destination_node, connection);
    return connection;
}

audio_connection::audio_connection(const audio_node_sptr &source_node, const UInt32 source_bus,
                                   const audio_node_sptr &destination_node, const UInt32 destination_bus,
                                   const audio_format_sptr &format)
    : _impl(std::make_unique<impl>(source_node, source_bus, destination_node, destination_bus, format))
{
    if (!source_node || !destination_node || !format) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument.");
    }
}

audio_connection::~audio_connection()
{
    if (auto destination_node = _impl->destination_node.lock()) {
        audio_node::private_access::remove_connection(destination_node, *this);
    }
    if (auto source_node = _impl->source_node.lock()) {
        audio_node::private_access::remove_connection(source_node, *this);
    }
}

UInt32 audio_connection::source_bus() const
{
    return _impl->source_bus;
}

UInt32 audio_connection::destination_bus() const
{
    return _impl->destination_bus;
}

audio_node_sptr audio_connection::source_node() const
{
    std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
    return _impl->source_node.lock();
}

audio_node_sptr audio_connection::destination_node() const
{
    std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
    return _impl->destination_node.lock();
}

audio_format_sptr &audio_connection::format() const
{
    return _impl->format;
}

void audio_connection::_remove_nodes()
{
    std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
    _impl->source_node.reset();
    _impl->destination_node.reset();
}

void audio_connection::_remove_source_node()
{
    std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
    _impl->source_node.reset();
}

void audio_connection::_remove_destination_node()
{
    std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
    _impl->destination_node.reset();
}
