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

struct audio::time::impl {
    objc_ptr<AVAudioTime *> _av_audio_time;

    impl(objc_ptr<AVAudioTime *> &&time) : _av_audio_time(std::move(time)) {
        if (!this->_av_audio_time) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is nil.");
        }
    }

    bool is_equal(std::shared_ptr<impl> const &rhs) const {
        if (auto rhs_av_audio_time = rhs->_av_audio_time) {
            return [this->_av_audio_time.object() isEqual:rhs_av_audio_time.object()];
        }
        return false;
    }
};

audio::time::time(AudioTimeStamp const &ts, double const sample_rate)
    : _impl(std::make_shared<impl>(
          objc_ptr_with_move_object([[AVAudioTime alloc] initWithAudioTimeStamp:&ts sampleRate:sample_rate]))) {
}

audio::time::time(uint64_t const host_time)
    : _impl(std::make_shared<impl>(objc_ptr_with_move_object([[AVAudioTime alloc] initWithHostTime:host_time]))) {
}

audio::time::time(int64_t const sample_time, double const sample_rate)
    : _impl(std::make_shared<impl>(
          objc_ptr_with_move_object([[AVAudioTime alloc] initWithSampleTime:sample_time atRate:sample_rate]))) {
}

audio::time::time(uint64_t const host_time, int64_t const sample_time, double const sample_rate)
    : _impl(std::make_shared<impl>(objc_ptr_with_move_object(
          [[AVAudioTime alloc] initWithHostTime:host_time sampleTime:sample_time atRate:sample_rate]))) {
}

bool audio::time::is_host_time_valid() const {
    return this->_impl->_av_audio_time.object().isHostTimeValid;
}

uint64_t audio::time::host_time() const {
    return this->_impl->_av_audio_time.object().hostTime;
}

bool audio::time::is_sample_time_valid() const {
    return this->_impl->_av_audio_time.object().isSampleTimeValid;
}

int64_t audio::time::sample_time() const {
    return this->_impl->_av_audio_time.object().sampleTime;
}

double audio::time::sample_rate() const {
    return this->_impl->_av_audio_time.object().sampleRate;
}

AudioTimeStamp audio::time::audio_time_stamp() const {
    return this->_impl->_av_audio_time.object().audioTimeStamp;
}

audio::time audio::time::extrapolate_time_from_anchor(audio::time const &anchor_time) {
    return to_time(
        [this->_impl->_av_audio_time.object() extrapolateTimeFromAnchor:anchor_time._impl->_av_audio_time.object()]);
}

std::string audio::time::description() const {
    NSString *description = [this->_impl->_av_audio_time.object() description];
    return to_string((__bridge CFStringRef)description);
}

bool audio::time::operator==(time const &rhs) const {
    return this->_impl && rhs._impl && (this->_impl == rhs._impl || this->_impl->is_equal(rhs._impl));
}

bool audio::time::operator!=(time const &rhs) const {
    return !(*this == rhs);
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
