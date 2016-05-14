//
//  yas_audio_node_kernel.cpp
//

#include "yas_audio_node.h"

using namespace yas;

struct audio::node::kernel::impl : base::impl, manageable_kernel::impl {
    connection_wmap input_connections;
    connection_wmap output_connections;

    audio::connection input_connection(uint32_t const bus_idx) {
        if (input_connections.count(bus_idx) > 0) {
            return input_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::connection output_connection(uint32_t const bus_idx) {
        if (output_connections.count(bus_idx) > 0) {
            return output_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    void set_input_connections(audio::connection_wmap &&connections) override {
        input_connections = std::move(connections);
    }

    void set_output_connections(audio::connection_wmap &&connections) override {
        output_connections = std::move(connections);
    }
};

audio::node::kernel::kernel() : base(std::make_unique<impl>()) {
}

audio::connection_smap audio::node::kernel::input_connections() const {
    return lock_values(impl_ptr<impl>()->input_connections);
}

audio::connection_smap audio::node::kernel::output_connections() const {
    return lock_values(impl_ptr<impl>()->output_connections);
}

audio::connection audio::node::kernel::input_connection(uint32_t const bus_idx) {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::connection audio::node::kernel::output_connection(uint32_t const bus_idx) {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

audio::node::manageable_kernel audio::node::kernel::manageable() {
    return audio::node::manageable_kernel{impl_ptr<audio::node::manageable_kernel::impl>()};
}
