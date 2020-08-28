//
//  yas_audio_mac_empty_device.cpp
//

#include "yas_audio_mac_empty_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

using namespace yas;

namespace yas::audio {
struct dummy_io_core : io_core {
    void initialize() override {
    }

    void uninitialize() override {
    }

    void set_render_handler(std::optional<io_render_f>) override {
    }

    void set_maximum_frames_per_slice(uint32_t const) override {
    }

    bool start() override {
        return false;
    }

    void stop() override {
    }

    pcm_buffer const *input_buffer_on_render() const override {
        return nullptr;
    }
};
}  // namespace yas::audio

audio::mac_empty_device::mac_empty_device() : _notifier(chaining::notifier<audio::io_device::method>::make_shared()) {
}

std::optional<audio::format> audio::mac_empty_device::input_format() const {
    return std::nullopt;
}

std::optional<audio::format> audio::mac_empty_device::output_format() const {
    return std::nullopt;
}

std::optional<audio::interruptor_ptr> const &audio::mac_empty_device::interruptor() const {
    static std::optional<audio::interruptor_ptr> _null_interruptor = std::nullopt;
    return _null_interruptor;
}

audio::io_core_ptr audio::mac_empty_device::make_io_core() const {
    return std::make_shared<dummy_io_core>();
}

chaining::chain_unsync_t<audio::io_device::method> audio::mac_empty_device::io_device_chain() {
    return this->_notifier->chain();
}

audio::mac_empty_device_ptr audio::mac_empty_device::make_shared() {
    return mac_empty_device_ptr(new mac_empty_device{});
}

#endif
