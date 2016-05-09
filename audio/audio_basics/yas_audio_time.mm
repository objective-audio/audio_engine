//
//  yas_audio_time.mm
//

#include <AVFoundation/AVFoundation.h>
#include <exception>
#include <string>
#include "yas_audio_objc_utils.h"
#include "yas_audio_time.h"
#include "yas_objc_macros.h"

using namespace yas;

struct audio::time::impl {
    AVAudioTime *av_audio_time;

    impl(AVAudioTime *av_audio_time) : av_audio_time(yas_retain(av_audio_time)) {
        if (!av_audio_time) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is nil.");
        }
    }

    ~impl() {
        yas_release(av_audio_time);
    }

    impl(impl const &) = delete;
    impl(impl &&) = delete;
    impl &operator=(impl const &) = delete;
    impl &operator=(impl &&) = delete;
};

audio::time::time(std::nullptr_t) : _impl(nullptr) {
}

audio::time::time(AudioTimeStamp const &ts, double const sample_rate)
    : _impl(std::make_shared<impl>([[AVAudioTime alloc] initWithAudioTimeStamp:&ts sampleRate:sample_rate])) {
    yas_release(_impl->av_audio_time);
}

audio::time::time(uint64_t const host_time)
    : _impl(std::make_shared<impl>([[AVAudioTime alloc] initWithHostTime:host_time])) {
    yas_release(_impl->av_audio_time);
}

audio::time::time(int64_t const sample_time, double const sample_rate)
    : _impl(std::make_shared<impl>([[AVAudioTime alloc] initWithSampleTime:sample_time atRate:sample_rate])) {
    yas_release(_impl->av_audio_time);
}

audio::time::time(uint64_t const host_time, int64_t const sample_time, double const sample_rate)
    : _impl(std::make_shared<impl>(
          [[AVAudioTime alloc] initWithHostTime:host_time sampleTime:sample_time atRate:sample_rate])) {
    yas_release(_impl->av_audio_time);
}

bool audio::time::operator==(audio::time const &rhs) const {
    if (_impl && rhs._impl) {
        if (_impl == rhs._impl) {
            return true;
        } else {
            return [_impl->av_audio_time isEqual:rhs._impl->av_audio_time];
        }
    } else {
        return false;
    }
}

bool audio::time::operator!=(audio::time const &rhs) const {
    return !(*this == rhs);
}

audio::time::operator bool() const {
    return _impl != nullptr;
}

bool audio::time::is_host_time_valid() const {
    if (_impl) {
        return _impl->av_audio_time.isHostTimeValid;
    } else {
        return false;
    }
}

uint64_t audio::time::host_time() const {
    if (_impl) {
        return _impl->av_audio_time.hostTime;
    } else {
        return 0;
    }
}

bool audio::time::is_sample_time_valid() const {
    if (_impl) {
        return _impl->av_audio_time.isSampleTimeValid;
    } else {
        return false;
    }
}

int64_t audio::time::sample_time() const {
    if (_impl) {
        return _impl->av_audio_time.sampleTime;
    } else {
        return 0;
    }
}

double audio::time::sample_rate() const {
    if (_impl) {
        return _impl->av_audio_time.sampleRate;
    } else {
        return 0.0;
    }
}

AudioTimeStamp audio::time::audio_time_stamp() const {
    if (_impl) {
        return _impl->av_audio_time.audioTimeStamp;
    } else {
        return {0};
    }
}

audio::time audio::time::extrapolate_time_from_anchor(audio::time const &anchor_time) {
    if (_impl) {
        AVAudioTime *time = [_impl->av_audio_time extrapolateTimeFromAnchor:anchor_time._impl->av_audio_time];
        return to_time(time);
    } else {
        return time{nullptr};
    }
}

#pragma mark - global

uint64_t audio::host_time_for_seconds(double seconds) {
    return [AVAudioTime hostTimeForSeconds:seconds];
}

double audio::seconds_for_host_time(uint64_t host_time) {
    return [AVAudioTime secondsForHostTime:host_time];
}
