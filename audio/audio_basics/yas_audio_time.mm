//
//  yas_audio_time.mm
//

#include "yas_audio_time.h"
#include <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <objc_utils/yas_objc_macros.h>
#include <exception>
#include <string>
#include "yas_audio_objc_utils.h"

using namespace yas;

struct audio::time::impl : base::impl {
    objc_ptr<AVAudioTime *> _av_audio_time;

    impl(objc_ptr<AVAudioTime *> &&time) : _av_audio_time(std::move(time)) {
        if (!this->_av_audio_time) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is nil.");
        }
    }

    bool is_equal(std::shared_ptr<base::impl> const &rhs) const override {
        if (auto casted_rhs = std::dynamic_pointer_cast<impl>(rhs)) {
            if (auto rhs_av_audio_time = casted_rhs->_av_audio_time) {
                return [this->_av_audio_time.object() isEqual:rhs_av_audio_time.object()];
            }
        }
        return false;
    }
};

audio::time::time(std::nullptr_t) : base(nullptr) {
}

audio::time::time(AudioTimeStamp const &ts, double const sample_rate)
    : base(std::make_shared<impl>(
          make_objc_ptr([[AVAudioTime alloc] initWithAudioTimeStamp:&ts sampleRate:sample_rate]))) {
}

audio::time::time(uint64_t const host_time)
    : base(std::make_shared<impl>(make_objc_ptr([[AVAudioTime alloc] initWithHostTime:host_time]))) {
}

audio::time::time(int64_t const sample_time, double const sample_rate)
    : base(std::make_shared<impl>(
          make_objc_ptr([[AVAudioTime alloc] initWithSampleTime:sample_time atRate:sample_rate]))) {
}

audio::time::time(uint64_t const host_time, int64_t const sample_time, double const sample_rate)
    : base(std::make_shared<impl>(
          make_objc_ptr([[AVAudioTime alloc] initWithHostTime:host_time sampleTime:sample_time atRate:sample_rate]))) {
}

audio::time::~time() = default;

bool audio::time::is_host_time_valid() const {
    return impl_ptr<impl>()->_av_audio_time.object().isHostTimeValid;
}

uint64_t audio::time::host_time() const {
    return impl_ptr<impl>()->_av_audio_time.object().hostTime;
}

bool audio::time::is_sample_time_valid() const {
    return impl_ptr<impl>()->_av_audio_time.object().isSampleTimeValid;
}

int64_t audio::time::sample_time() const {
    return impl_ptr<impl>()->_av_audio_time.object().sampleTime;
}

double audio::time::sample_rate() const {
    return impl_ptr<impl>()->_av_audio_time.object().sampleRate;
}

AudioTimeStamp audio::time::audio_time_stamp() const {
    return impl_ptr<impl>()->_av_audio_time.object().audioTimeStamp;
}

audio::time audio::time::extrapolate_time_from_anchor(audio::time const &anchor_time) {
    return to_time([impl_ptr<impl>()->_av_audio_time.object()
        extrapolateTimeFromAnchor:anchor_time.impl_ptr<impl>()->_av_audio_time.object()]);
}

std::string audio::time::description() const {
    NSString *description = [impl_ptr<impl>()->_av_audio_time.object() description];
    return to_string((__bridge CFStringRef)description);
}

#pragma mark - global

uint64_t audio::host_time_for_seconds(double seconds) {
    return [AVAudioTime hostTimeForSeconds:seconds];
}

double audio::seconds_for_host_time(uint64_t host_time) {
    return [AVAudioTime secondsForHostTime:host_time];
}

#pragma mark -

std::string yas::to_string(audio::time const &time) {
    return time.description();
}
