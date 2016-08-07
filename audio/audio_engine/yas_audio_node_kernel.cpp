//
//  yas_audio_node_kernel.cpp
//

#include "yas_audio_node.h"

using namespace yas;

#pragma mark - audio::kernel::impl

struct audio::node::kernel::impl : base::impl, manageable_kernel::impl {
    audio::connection input_connection(uint32_t const bus_idx) {
        if (_input_connections.count(bus_idx) > 0) {
            return _input_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::connection output_connection(uint32_t const bus_idx) {
        if (_output_connections.count(bus_idx) > 0) {
            return _output_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::connection_smap input_connections() {
        return lock_values(_input_connections);
    }

    audio::connection_smap output_connections() {
        return lock_values(_output_connections);
    }

    void set_input_connections(audio::connection_wmap &&connections) {
        _input_connections = std::move(connections);
    }

    void set_output_connections(audio::connection_wmap &&connections) {
        _output_connections = std::move(connections);
    }

    void set_decorator(base &&decor) {
        _decorator = std::move(decor);
    }

    base &decorator() {
        return _decorator;
    }

   private:
    connection_wmap _input_connections;
    connection_wmap _output_connections;
    base _decorator = nullptr;
};

#pragma mark - audio::kernel

audio::node::kernel::kernel() : base(std::make_unique<impl>()) {
}

audio::node::kernel::kernel(std::nullptr_t) : base(nullptr) {
}

audio::node::kernel::~kernel() = default;

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

void audio::node::kernel::set_decorator(base decor) {
    impl_ptr<impl>()->set_decorator(std::move(decor));
}

base const &audio::node::kernel::decorator() const {
    return impl_ptr<impl>()->decorator();
}

base &audio::node::kernel::decorator() {
    return impl_ptr<impl>()->decorator();
}

audio::node::manageable_kernel &audio::node::kernel::manageable() {
    if (!_manageable) {
        _manageable = audio::node::manageable_kernel{impl_ptr<audio::node::manageable_kernel::impl>()};
    }
    return _manageable;
}
