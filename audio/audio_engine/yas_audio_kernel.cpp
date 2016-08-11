//
//  yas_audio_kernel.cpp
//

#include "yas_audio_node.h"

using namespace yas;

#pragma mark - audio::kernel::impl

struct audio::kernel::impl : base::impl, manageable_kernel::impl {
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

    void set_extension(base &&ext) {
        _extension = std::move(ext);
    }

    base &extension() {
        return _extension;
    }

   private:
    connection_wmap _input_connections;
    connection_wmap _output_connections;
    base _extension = nullptr;
};

#pragma mark - audio::kernel

audio::kernel::kernel() : base(std::make_unique<impl>()) {
}

audio::kernel::kernel(std::nullptr_t) : base(nullptr) {
}

audio::kernel::~kernel() = default;

audio::connection_smap audio::kernel::input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::connection_smap audio::kernel::output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

audio::connection audio::kernel::input_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::connection audio::kernel::output_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

void audio::kernel::set_extension(base ext) {
    impl_ptr<impl>()->set_extension(std::move(ext));
}

base const &audio::kernel::extension() const {
    return impl_ptr<impl>()->extension();
}

base &audio::kernel::extension() {
    return impl_ptr<impl>()->extension();
}

audio::manageable_kernel &audio::kernel::manageable() {
    if (!_manageable) {
        _manageable = audio::manageable_kernel{impl_ptr<audio::manageable_kernel::impl>()};
    }
    return _manageable;
}
