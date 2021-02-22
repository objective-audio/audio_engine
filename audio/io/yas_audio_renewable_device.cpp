//
//  yas_audio_renewable_device.cpp
//

#include "yas_audio_renewable_device.h"

using namespace yas;
using namespace yas::audio;

renewable_device::renewable_device(device_f const &device_handler, renewal_f const &observing_handler)
    : _device_handler(device_handler), _renewal_handler(observing_handler) {
    this->_renewal_device();
}

std::optional<format> renewable_device::input_format() const {
    return this->_device->input_format();
}

std::optional<format> renewable_device::output_format() const {
    return this->_device->output_format();
}

std::optional<interruptor_ptr> const &renewable_device::interruptor() const {
    return this->_device->interruptor();
}

io_core_ptr renewable_device::make_io_core() const {
    return this->_device->make_io_core();
}

observing::canceller_ptr renewable_device::observe_io_device(
    observing::caller<io_device::method>::handler_f &&handler) {
    return this->_notifier->observe(std::move(handler));
}

void renewable_device::_renewal_device() {
    auto new_device = this->_device_handler();

    if (new_device && this->_device && new_device == this->_device) {
        return;
    }

    this->_device = std::move(new_device);

    auto handler = [this](method const &method) {
        switch (method) {
            case method::notify:
                this->_notifier->notify(io_device::method::updated);
                break;
            case method::renewal:
                this->_renewal_device();
                break;
        }
    };

    this->_observers = this->_renewal_handler(this->_device, handler);

    this->_notifier->notify(io_device::method::updated);
}

renewable_device_ptr renewable_device::make_shared(device_f const &device_handler, renewal_f const &observing_handler) {
    return renewable_device_ptr(new renewable_device{device_handler, observing_handler});
}
