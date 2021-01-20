//
//  yas_audio_offline_device.cpp
//

#include "yas_audio_offline_device.h"

#include "yas_audio_offline_io_core.h"

using namespace yas;

audio::offline_device::offline_device(audio::format const &output_format, offline_render_f &&render_handler)
    : _output_format(output_format), _render_handler(std::move(render_handler)) {
}

std::optional<audio::format> audio::offline_device::input_format() const {
    return std::nullopt;
}

std::optional<audio::format> audio::offline_device::output_format() const {
    return this->_output_format;
}

audio::io_core_ptr audio::offline_device::make_io_core() const {
    return offline_io_core::make_shared(this->_weak_device.lock());
}

std::optional<audio::interruptor_ptr> const &audio::offline_device::interruptor() const {
    static std::optional<audio::interruptor_ptr> const _null_interruptor = std::nullopt;
    return _null_interruptor;
}

chaining::chain_unsync_t<audio::io_device::method> audio::offline_device::io_device_chain() {
    return this->_notifier->chain();
}

audio::offline_render_f audio::offline_device::render_handler() const {
    return this->_render_handler;
}

std::optional<audio::offline_completion_f> audio::offline_device::completion_handler() const {
    return this->_completion_handler;
}

void audio::offline_device::_prepare(offline_device_ptr const &device, offline_completion_f &&completion_handler) {
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

audio::offline_device_ptr audio::offline_device::make_shared(audio::format const &output_format,
                                                             offline_render_f &&render_handler,
                                                             offline_completion_f &&completion_handler) {
    auto shared = offline_device_ptr{new offline_device{output_format, std::move(render_handler)}};
    shared->_prepare(shared, std::move(completion_handler));
    return shared;
}