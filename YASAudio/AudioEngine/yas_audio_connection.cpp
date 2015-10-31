//
//  yas_audio_connection.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_connection.h"
#include "yas_audio_node.h"
#include <mutex>

using namespace yas;

class audio_connection::impl : public base::impl
{
   public:
    UInt32 source_bus;

    UInt32 destination_bus;
    audio_format format;
    mutable std::recursive_mutex mutex;

    impl(const audio_node &source_node, const UInt32 source_bus, const audio_node &destination_node,
         const UInt32 destination_bus, const audio_format &format)
        : source_bus(source_bus),
          destination_bus(destination_bus),
          format(format),
          _source_node(source_node),
          _destination_node(destination_node)
    {
    }

    void remove_connection_from_nodes(const audio_connection &connection)
    {
        if (auto node = _destination_node.lock()) {
            audio_node::private_access::remove_connection(node, connection);
        }
        if (auto node = _source_node.lock()) {
            audio_node::private_access::remove_connection(node, connection);
        }
    }

    audio_node source_node() const
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return _source_node.lock();
    }

    audio_node destination_node() const
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return _destination_node.lock();
    }

    void remove_nodes()
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        _source_node.reset();
        _destination_node.reset();
    }

    void remove_source_node()
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        _source_node.reset();
    }

    void remove_destination_node()
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        _destination_node.reset();
    }

   private:
    weak<audio_node> _source_node;
    weak<audio_node> _destination_node;
};

audio_connection::audio_connection(std::nullptr_t) : super_class(nullptr)
{
}

audio_connection::~audio_connection()
{
    if (impl_ptr() && impl_ptr().unique()) {
        if (auto impl = _impl_ptr()) {
            impl->remove_connection_from_nodes(*this);
        }
        impl_ptr().reset();
    }
}

audio_connection::audio_connection(audio_node &source_node, const UInt32 source_bus, audio_node &destination_node,
                                   const UInt32 destination_bus, const audio_format &format)
    : super_class(std::make_shared<impl>(source_node, source_bus, destination_node, destination_bus, format))
{
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument.");
    }

    audio_node::private_access::add_connection(source_node, *this);
    audio_node::private_access::add_connection(destination_node, *this);
}

UInt32 audio_connection::source_bus() const
{
    return _impl_ptr()->source_bus;
}

UInt32 audio_connection::destination_bus() const
{
    return _impl_ptr()->destination_bus;
}

audio_node audio_connection::source_node() const
{
    if (impl_ptr()) {
        return _impl_ptr()->source_node();
    }
    return audio_node(nullptr);
}

audio_node audio_connection::destination_node() const
{
    if (impl_ptr()) {
        return _impl_ptr()->destination_node();
    }
    return audio_node(nullptr);
}

audio_format &audio_connection::format() const
{
    return _impl_ptr()->format;
}

void audio_connection::_remove_nodes()
{
    _impl_ptr()->remove_nodes();
}

void audio_connection::_remove_source_node()
{
    _impl_ptr()->remove_source_node();
}

void audio_connection::_remove_destination_node()
{
    _impl_ptr()->remove_destination_node();
}

std::shared_ptr<audio_connection::impl> audio_connection::_impl_ptr() const
{
    return impl_ptr<impl>();
}
