//
//  yas_audio_kernel.cpp
//

#include "yas_audio_graph_node.h"

using namespace yas;

#pragma mark - audio::kernel

audio::graph_kernel::graph_kernel() {
}

audio::graph_kernel::~graph_kernel() = default;

audio::graph_connection_smap audio::graph_kernel::input_connections() const {
    return lock_values(this->_input_connections);
}

audio::graph_connection_smap audio::graph_kernel::output_connections() const {
    return lock_values(this->_output_connections);
}

audio::graph_connection_ptr audio::graph_kernel::input_connection(uint32_t const bus_idx) const {
    if (this->_input_connections.count(bus_idx) > 0) {
        return this->_input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::graph_connection_ptr audio::graph_kernel::output_connection(uint32_t const bus_idx) const {
    if (this->_output_connections.count(bus_idx) > 0) {
        return this->_output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

void audio::graph_kernel::set_input_connections(audio::graph_connection_wmap connections) {
    this->_input_connections = std::move(connections);
}

void audio::graph_kernel::set_output_connections(audio::graph_connection_wmap connections) {
    this->_output_connections = std::move(connections);
}

audio::graph_kernel_ptr audio::graph_kernel::make_shared() {
    auto shared = graph_kernel_ptr(new audio::graph_kernel{});
    shared->_weak_kernel = shared;
    return shared;
}
