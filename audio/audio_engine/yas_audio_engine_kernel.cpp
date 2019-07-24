//
//  yas_audio_kernel.cpp
//

#include "yas_audio_engine_node.h"

using namespace yas;

#pragma mark - audio::engine::kernel

audio::engine::kernel::kernel() {
}

audio::engine::kernel::~kernel() = default;

audio::engine::connection_smap audio::engine::kernel::input_connections() const {
    return lock_values(this->_input_connections);
}

audio::engine::connection_smap audio::engine::kernel::output_connections() const {
    return lock_values(this->_output_connections);
}

std::shared_ptr<audio::engine::connection> audio::engine::kernel::input_connection(uint32_t const bus_idx) const {
    if (this->_input_connections.count(bus_idx) > 0) {
        return this->_input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

std::shared_ptr<audio::engine::connection> audio::engine::kernel::output_connection(uint32_t const bus_idx) const {
    if (this->_output_connections.count(bus_idx) > 0) {
        return this->_output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

void audio::engine::kernel::set_input_connections(audio::engine::connection_wmap connections) {
    this->_input_connections = std::move(connections);
}

void audio::engine::kernel::set_output_connections(audio::engine::connection_wmap connections) {
    this->_output_connections = std::move(connections);
}

std::shared_ptr<audio::engine::manageable_kernel> audio::engine::kernel::manageable() {
    return std::dynamic_pointer_cast<manageable_kernel>(shared_from_this());
}

std::shared_ptr<audio::engine::kernel> audio::engine::make_kernel() {
    return std::shared_ptr<audio::engine::kernel>(new audio::engine::kernel{});
}
