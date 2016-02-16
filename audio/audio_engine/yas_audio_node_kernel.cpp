//
//  yas_audio_node_kernel.cpp
//

#include "yas_audio_node.h"

using namespace yas;

class audio::node::kernel::impl {
   public:
    connection_wmap input_connections;
    connection_wmap output_connections;
};

audio::node::kernel::kernel() : _impl(std::make_unique<impl>()) {
}

audio::node::kernel::~kernel() = default;

audio::connection_smap audio::node::kernel::input_connections() const {
    return yas::lock_values(_impl->input_connections);
}

audio::connection_smap audio::node::kernel::output_connections() const {
    return yas::lock_values(_impl->output_connections);
}

audio::connection audio::node::kernel::input_connection(UInt32 const bus_idx) {
    if (_impl->input_connections.count(bus_idx) > 0) {
        return _impl->input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::connection audio::node::kernel::output_connection(UInt32 const bus_idx) {
    if (_impl->output_connections.count(bus_idx) > 0) {
        return _impl->output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

void audio::node::kernel::_set_input_connections(connection_wmap const &connections) {
    _impl->input_connections = connections;
}

void audio::node::kernel::_set_output_connections(connection_wmap const &connections) {
    _impl->output_connections = connections;
}
