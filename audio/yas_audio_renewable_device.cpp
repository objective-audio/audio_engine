//
//  yas_audio_renewable_device.cpp
//

#include "yas_audio_renewable_device.h"

using namespace yas;

audio::renewable_device::renewable_device(device_f const &device_handler, renewal_f const &observing_handler)
    : _device_handler(device_handler),
      _renewal_handler(observing_handler),
      _notifier(chaining::notifier<audio::io_device::method>::make_shared()) {
    this->_renewal_device();
}

std::optional<audio::format> audio::renewable_device::input_format() const {
    return this->_device->input_format();
}

std::optional<audio::format> audio::renewable_device::output_format() const {
    return this->_device->output_format();
}

std::optional<audio::interruptor_ptr> const &audio::renewable_device::interruptor() const {
    return this->_device->interruptor();
}

audio::io_core_ptr audio::renewable_device::make_io_core() const {
    return this->_device->make_io_core();
}

chaining::chain_unsync_t<audio::io_device::method> audio::renewable_device::io_device_chain() {
    return this->_notifier->chain();
}

void audio::renewable_device::_renewal_device() {
    auto new_device = this->_device_handler();

    if (new_device && this->_device && new_device == this->_device) {
        return;
    }

    this->_device = std::move(new_device);

    auto handler = [this](method const &method) {
        switch (method) {
            case method::notify:
                this->_notifier->notify(audio::io_device::method::updated);
                break;
            case method::renewal:
                this->_renewal_device();
                break;
        }
    };

    this->_observer = this->_renewal_handler(this->_device, handler);

    this->_notifier->notify(audio::io_device::method::updated);
}

audio::renewable_device_ptr audio::renewable_device::make_shared(device_f const &device_handler,
                                                                 renewal_f const &observing_handler) {
    return renewable_device_ptr(new renewable_device{device_handler, observing_handler});
}
