//
//  yas_audio_node_kernel.cpp
//

#include "yas_audio_node.h"

using namespace yas;

#pragma mark - kernel::impl

audio::connection audio::node::kernel::impl::input_connection(uint32_t const bus_idx) {
    if (_input_connections.count(bus_idx) > 0) {
        return _input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::connection audio::node::kernel::impl::output_connection(uint32_t const bus_idx) {
    if (_output_connections.count(bus_idx) > 0) {
        return _output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::connection_smap audio::node::kernel::impl::input_connections() {
    return lock_values(_input_connections);
}

audio::connection_smap audio::node::kernel::impl::output_connections() {
    return lock_values(_output_connections);
}

void audio::node::kernel::impl::set_input_connections(audio::connection_wmap &&connections) {
    _input_connections = std::move(connections);
}

void audio::node::kernel::impl::set_output_connections(audio::connection_wmap &&connections) {
    _output_connections = std::move(connections);
}

#pragma mark - kernel

audio::node::kernel::kernel() : base(std::make_unique<impl>()) {
}

audio::node::kernel::kernel(std::shared_ptr<impl> &&impl) : base(std::move(impl)) {
}

audio::node::kernel::kernel(std::nullptr_t) : base(nullptr) {
}

audio::connection_smap audio::node::kernel::input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::connection_smap audio::node::kernel::output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

audio::connection audio::node::kernel::input_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::connection audio::node::kernel::output_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

audio::node::manageable_kernel audio::node::kernel::manageable() {
    return audio::node::manageable_kernel{impl_ptr<audio::node::manageable_kernel::impl>()};
}
