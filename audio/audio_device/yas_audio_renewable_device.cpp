//
//  yas_audio_renewable_device.cpp
//

#include "yas_audio_renewable_device.h"

using namespace yas;

audio::renewable_device::renewable_device(device_f const &device_handler, observing_f const &observing_handler)
    : _device_handler(device_handler),
      _observing_handler(observing_handler),
      _notifier(chaining::notifier<audio::io_device::method>::make_shared()) {
    this->_update_device();
}

std::optional<audio::format> audio::renewable_device::input_format() const {
    return this->_device->input_format();
}

std::optional<audio::format> audio::renewable_device::output_format() const {
    return this->_device->output_format();
}

audio::io_core_ptr audio::renewable_device::make_io_core() const {
    return this->_device->make_io_core();
}

chaining::chain_unsync_t<audio::io_device::method> audio::renewable_device::io_device_chain() {
    return this->_notifier->chain();
}

void audio::renewable_device::_update_device() {
    auto new_device = this->_device_handler();

    if (new_device && this->_device && new_device == this->_device) {
        return;
    }

    this->_device = std::move(new_device);

    auto notify = [this]() { this->_notifier->notify(audio::io_device::method::updated); };
    auto update = [this]() { this->_update_device(); };

    this->_observer = this->_observing_handler(this->_device, update, notify);

    this->_notifier->notify(audio::io_device::method::updated);
}

audio::renewable_device_ptr audio::renewable_device::make_shared(device_f const &device_handler,
                                                                 observing_f const &observing_handler) {
    return renewable_device_ptr(new renewable_device{device_handler, observing_handler});
}
