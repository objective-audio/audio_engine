//
//  yas_audio_io_device.cpp
//

#include "yas_audio_io_device.h"

#if TARGET_OS_IPHONE
#include "yas_audio_ios_device.h"
#elif TARGET_OS_MAC
#include "yas_audio_mac_device.h"
#endif

using namespace yas;

uint32_t audio::io_device::input_channel_count() const {
    if (auto const format = this->input_format()) {
        return format.value().channel_count();
    } else {
        return 0;
    }
}

uint32_t audio::io_device::output_channel_count() const {
    if (auto const format = this->output_format()) {
        return format.value().channel_count();
    } else {
        return 0;
    }
}

std::optional<audio::io_device_ptr> audio::io_device::default_device() {
#if TARGET_OS_IPHONE
    return ios_device::make_shared();
#elif TARGET_OS_MAC
    if (auto const output_device = mac_device::default_output_device()) {
        return output_device;
    } else if (auto const input_device = mac_device::default_input_device()) {
        return input_device;
    } else {
        return std::nullopt;
    }
#endif
}
