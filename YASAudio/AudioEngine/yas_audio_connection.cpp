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
    audio_format format;
    mutable std::recursive_mutex mutex;

    impl(const audio_node_sptr &source_node, const UInt32 source_bus, const audio_node_sptr &destination_node,
         const UInt32 destination_bus, const audio_format &format)
        : source_bus(source_bus),
          destination_bus(destination_bus),
          format(format),
          source_node(source_node),
          destination_node(destination_node)
    {
    }

    void remove_connection_from_nodes(const audio_connection &connection)
    {
        if (auto node = destination_node.lock()) {
            audio_node::private_access::remove_connection(node, connection);
        }
        if (auto node = source_node.lock()) {
            audio_node::private_access::remove_connection(node, connection);
        }
    }
};

audio_connection::audio_connection(std::nullptr_t) : _impl(nullptr)
{
}

audio_connection::~audio_connection()
{
    if (_impl && _impl.unique()) {
        _impl->remove_connection_from_nodes(*this);
        _impl.reset();
    }
}

audio_connection::audio_connection(const audio_node_sptr &source_node, const UInt32 source_bus,
                                   const audio_node_sptr &destination_node, const UInt32 destination_bus,
                                   const audio_format &format)
    : _impl(std::make_shared<impl>(source_node, source_bus, destination_node, destination_bus, format))
{
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument.");
    }

    audio_node::private_access::add_connection(source_node, *this);
    audio_node::private_access::add_connection(destination_node, *this);
}

audio_connection::audio_connection(const std::shared_ptr<impl> &impl) : _impl(impl)
{
}

bool audio_connection::operator==(const audio_connection &other) const
{
    return _impl && other._impl && _impl == other._impl;
}

bool audio_connection::operator!=(const audio_connection &other) const
{
    return !_impl || !other._impl || _impl != other._impl;
}

bool audio_connection::operator<(const audio_connection &other) const
{
    if (_impl && other._impl) {
        return _impl < other._impl;
    }
    return false;
}

audio_connection::operator bool() const
{
    return _impl != nullptr;
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
    if (_impl) {
        std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
        return _impl->source_node.lock();
    }
    return nullptr;
}

audio_node_sptr audio_connection::destination_node() const
{
    if (_impl) {
        std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
        return _impl->destination_node.lock();
    }
    return nullptr;
}

audio_format &audio_connection::format() const
{
    return _impl->format;
}

uintptr_t audio_connection::key() const
{
    return reinterpret_cast<uintptr_t>(&*_impl);
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
