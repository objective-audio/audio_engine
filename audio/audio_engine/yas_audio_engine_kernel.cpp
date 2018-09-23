//
//  yas_audio_kernel.cpp
//

#include "yas_audio_engine_node.h"

using namespace yas;

#pragma mark - audio::engine::kernel::impl

struct audio::engine::kernel::impl : base::impl, manageable_kernel::impl {
    audio::engine::connection input_connection(uint32_t const bus_idx) {
        if (this->_input_connections.count(bus_idx) > 0) {
            return this->_input_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::engine::connection output_connection(uint32_t const bus_idx) {
        if (this->_output_connections.count(bus_idx) > 0) {
            return this->_output_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::engine::connection_smap input_connections() {
        return lock_values(this->_input_connections);
    }

    audio::engine::connection_smap output_connections() {
        return lock_values(this->_output_connections);
    }

    void set_input_connections(audio::engine::connection_wmap &&connections) {
        this->_input_connections = std::move(connections);
    }

    void set_output_connections(audio::engine::connection_wmap &&connections) {
        this->_output_connections = std::move(connections);
    }

    void set_decorator(base &&decor) {
        this->_decorator = std::move(decor);
    }

    base &decorator() {
        return this->_decorator;
    }

   private:
    engine::connection_wmap _input_connections;
    engine::connection_wmap _output_connections;
    base _decorator = nullptr;
};

#pragma mark - audio::engine::kernel

audio::engine::kernel::kernel() : base(std::make_unique<impl>()) {
}

audio::engine::kernel::kernel(std::nullptr_t) : base(nullptr) {
}

audio::engine::kernel::~kernel() = default;

audio::engine::connection_smap audio::engine::kernel::input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::engine::connection_smap audio::engine::kernel::output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

audio::engine::connection audio::engine::kernel::input_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::engine::connection audio::engine::kernel::output_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

void audio::engine::kernel::set_decorator(base decor) {
    impl_ptr<impl>()->set_decorator(std::move(decor));
}

base const &audio::engine::kernel::decorator() const {
    return impl_ptr<impl>()->decorator();
}

base &audio::engine::kernel::decorator() {
    return impl_ptr<impl>()->decorator();
}

audio::engine::manageable_kernel &audio::engine::kernel::manageable() {
    if (!_manageable) {
        _manageable = audio::engine::manageable_kernel{impl_ptr<audio::engine::manageable_kernel::impl>()};
    }
    return _manageable;
}
