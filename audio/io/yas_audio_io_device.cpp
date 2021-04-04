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
using namespace yas::audio;

uint32_t io_device::input_channel_count() const {
    if (auto const format = this->input_format()) {
        return format.value().channel_count();
    } else {
        return 0;
    }
}

uint32_t io_device::output_channel_count() const {
    if (auto const format = this->output_format()) {
        return format.value().channel_count();
    } else {
        return 0;
    }
}

bool io_device::is_interrupting() const {
    if (auto const &interruptor = this->interruptor()) {
        return interruptor.value()->is_interrupting();
    } else {
        return false;
    }
}

observing::endable io_device::observe_interruption(observing::caller<interruption_method>::handler_f &&handler) {
    if (auto const interruptor = this->interruptor()) {
        return interruptor.value()->observe_interruption(std::move(handler));
    } else {
        return observing::endable{};
    }
}
