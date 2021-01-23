//
//  yas_audio_mac_empty_device.cpp
//

#include "yas_audio_mac_empty_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

using namespace yas;
using namespace yas::audio;

namespace yas::audio {
struct dummy_io_core : io_core {
    void set_render_handler(std::optional<io_render_f>) override {
    }

    void set_maximum_frames_per_slice(uint32_t const) override {
    }

    bool start() override {
        return false;
    }

    void stop() override {
    }
};
}  // namespace yas::audio

mac_empty_device::mac_empty_device() {
}

std::optional<format> mac_empty_device::input_format() const {
    return std::nullopt;
}

std::optional<format> mac_empty_device::output_format() const {
    return std::nullopt;
}

std::optional<interruptor_ptr> const &mac_empty_device::interruptor() const {
    static std::optional<interruptor_ptr> _null_interruptor = std::nullopt;
    return _null_interruptor;
}

io_core_ptr mac_empty_device::make_io_core() const {
    return std::make_shared<dummy_io_core>();
}

observing::canceller_ptr mac_empty_device::observe_io_device(observing::caller<method>::handler_f &&handler) {
    return this->_notifier->observe(std::move(handler));
}

mac_empty_device_ptr mac_empty_device::make_shared() {
    return mac_empty_device_ptr(new mac_empty_device{});
}

#endif
