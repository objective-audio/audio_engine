//
//  yas_audio_kernel.cpp
//

#include "yas_audio_engine_node.h"

using namespace yas;

#pragma mark - audio::engine::kernel

audio::engine::kernel::kernel() {
}

audio::engine::connection_smap audio::engine::kernel::input_connections() const {
    return lock_values(this->_input_connections);
}

audio::engine::connection_smap audio::engine::kernel::output_connections() const {
    return lock_values(this->_output_connections);
}

audio::engine::connection audio::engine::kernel::input_connection(uint32_t const bus_idx) const {
    if (this->_input_connections.count(bus_idx) > 0) {
        return this->_input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::engine::connection audio::engine::kernel::output_connection(uint32_t const bus_idx) const {
    if (this->_output_connections.count(bus_idx) > 0) {
        return this->_output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

void audio::engine::kernel::set_input_connections(audio::engine::connection_wmap connections) {
    throw std::runtime_error("");
}

void audio::engine::kernel::set_output_connections(audio::engine::connection_wmap connections) {
    throw std::runtime_error("");
}

namespace yas::audio::engine {
struct kernel_factory : kernel {
    void set_input_connections(audio::engine::connection_wmap connections) override {
        this->_input_connections = std::move(connections);
    }

    void set_output_connections(audio::engine::connection_wmap connections) override {
        this->_output_connections = std::move(connections);
    }
};
}  // namespace yas::audio::engine

std::shared_ptr<audio::engine::kernel> audio::engine::make_kernel() {
    return std::make_shared<audio::engine::kernel_factory>();
}
