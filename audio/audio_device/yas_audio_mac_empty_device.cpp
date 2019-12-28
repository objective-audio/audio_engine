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

    std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const override {
        static std::optional<pcm_buffer_ptr> const _null_buffer = std::nullopt;
        return _null_buffer;
    }

    std::optional<time_ptr> const &input_time_on_render() const override {
        static std::optional<time_ptr> const _null_time = std::nullopt;
        return _null_time;
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
