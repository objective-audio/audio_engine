//
//  yas_audio_node_kernel.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_node.h"

using namespace yas;

class audio_node::kernel::impl
{
   public:
    audio_connection_wmap input_connections;
    audio_connection_wmap output_connections;
};

audio_node::kernel::kernel() : _impl(std::make_unique<impl>())
{
}

audio_node::kernel::~kernel() = default;

audio_connection_smap audio_node::kernel::input_connections() const
{
    return yas::lock_values(_impl->input_connections);
}

audio_connection_smap audio_node::kernel::output_connections() const
{
    return yas::lock_values(_impl->output_connections);
}

audio_connection audio_node::kernel::input_connection(const UInt32 bus_idx)
{
    if (_impl->input_connections.count(bus_idx) > 0) {
        return _impl->input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio_connection audio_node::kernel::output_connection(const UInt32 bus_idx)
{
    if (_impl->output_connections.count(bus_idx) > 0) {
        return _impl->output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

void audio_node::kernel::_set_input_connections(const audio_connection_wmap &connections)
{
    _impl->input_connections = connections;
}

void audio_node::kernel::_set_output_connections(const audio_connection_wmap &connections)
{
    _impl->output_connections = connections;
}