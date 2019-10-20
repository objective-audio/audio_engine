//
//  yas_audio_avf_device.mm
//

#include "yas_audio_avf_device.h"

#if TARGET_OS_IPHONE

#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>

using namespace yas;

audio::avf_device::avf_device() {
}

double audio::avf_device::sample_rate() const {
    return [AVAudioSession sharedInstance].sampleRate;
}

uint32_t audio::avf_device::input_channel_count() const {
    if ([AVAudioSession sharedInstance].isInputAvailable) {
        return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
    } else {
        return 0;
    }
}

uint32_t audio::avf_device::output_channel_count() const {
    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
}

std::optional<audio::format> audio::avf_device::input_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->input_channel_count();

    if (sample_rate > 0.0 && ch_count > 0) {
        return audio::format({.sample_rate = sample_rate, .channel_count = ch_count});
    } else {
        return std::nullopt;
    }
}

std::optional<audio::format> audio::avf_device::output_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->output_channel_count();

    if (sample_rate > 0.0 && ch_count > 0) {
        return audio::format({.sample_rate = sample_rate, .channel_count = ch_count});
    } else {
        return std::nullopt;
    }
}

audio::avf_io_core_ptr audio::avf_device::make_io_core() const {
    return avf_io_core::make_shared(this->_weak_device.lock());
}

audio::avf_device_ptr audio::avf_device::make_shared() {
    auto shared = std::shared_ptr<avf_device>(new avf_device{});
    shared->_weak_device = shared;
    return shared;
}

#endif
