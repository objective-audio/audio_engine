//
//  yas_audio_offline_device.cpp
//

#include "yas_audio_offline_device.h"

#include <audio-engine/offline/yas_audio_offline_io_core.h>

using namespace yas;
using namespace yas::audio;

offline_device::offline_device(format const &output_format, offline_render_f &&render_handler)
    : _output_format(output_format), _render_handler(std::move(render_handler)) {
}

std::optional<format> offline_device::input_format() const {
    return std::nullopt;
}

std::optional<format> offline_device::output_format() const {
    return this->_output_format;
}

io_core_ptr offline_device::make_io_core() const {
    return offline_io_core::make_shared(this->_weak_device.lock());
}

std::optional<interruptor_ptr> const &offline_device::interruptor() const {
    static std::optional<interruptor_ptr> const _null_interruptor = std::nullopt;
    return _null_interruptor;
}

observing::endable offline_device::observe_io_device(observing::caller<io_device::method>::handler_f &&handler) {
    return this->_notifier->observe(std::move(handler));
}

offline_render_f offline_device::render_handler() const {
    return this->_render_handler;
}

std::optional<offline_completion_f> offline_device::completion_handler() const {
    return this->_completion_handler;
}

void offline_device::_prepare(offline_device_ptr const &device, offline_completion_f &&completion_handler) {
    this->_weak_device = device;

    this->_completion_handler = [weak_device = this->_weak_device, completion_handler = std::move(completion_handler),
                                 called = std::make_shared<bool>(false)](bool const cancelled) mutable {
        if (!*called) {
            *called = true;
            completion_handler(cancelled);

            if (auto const device = weak_device.lock()) {
                device->_completion_handler = std::nullopt;
                device->_notifier->notify(io_device::method::lost);
            }
        }
    };
}

offline_device_ptr offline_device::make_shared(format const &output_format, offline_render_f &&render_handler,
                                               offline_completion_f &&completion_handler) {
    auto shared = offline_device_ptr{new offline_device{output_format, std::move(render_handler)}};
    shared->_prepare(shared, std::move(completion_handler));
    return shared;
}
