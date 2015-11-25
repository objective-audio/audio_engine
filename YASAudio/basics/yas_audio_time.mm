//
//  yas_audio_time.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_time.h"
#include "yas_objc_utils.h"
#include <AVFoundation/AVFoundation.h>
#include "YASMacros.h"
#include <exception>
#include <string>

using namespace yas;

class audio_time::impl
{
   public:
    AVAudioTime *av_audio_time;

    impl(AVAudioTime *av_audio_time) : av_audio_time(YASRetain(av_audio_time))
    {
        if (!av_audio_time) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is nil.");
        }
    }

    ~impl()
    {
        YASRelease(av_audio_time);
    }

    impl(const impl &) = delete;
    impl(impl &&) = delete;
    impl &operator=(const impl &) = delete;
    impl &operator=(impl &&) = delete;
};

audio_time::audio_time(std::nullptr_t) : _impl(nullptr)
{
}

audio_time::audio_time(const AudioTimeStamp &ts, const Float64 sample_rate)
    : _impl(std::make_shared<impl>([[AVAudioTime alloc] initWithAudioTimeStamp:&ts sampleRate:sample_rate]))
{
    YASRelease(_impl->av_audio_time);
}

audio_time::audio_time(const UInt64 host_time)
    : _impl(std::make_shared<impl>([[AVAudioTime alloc] initWithHostTime:host_time]))
{
    YASRelease(_impl->av_audio_time);
}

audio_time::audio_time(const SInt64 sample_time, const Float64 sample_rate)
    : _impl(std::make_shared<impl>([[AVAudioTime alloc] initWithSampleTime:sample_time atRate:sample_rate]))
{
    YASRelease(_impl->av_audio_time);
}

audio_time::audio_time(const UInt64 host_time, const SInt64 sample_time, const Float64 sample_rate)
    : _impl(std::make_shared<impl>(
          [[AVAudioTime alloc] initWithHostTime:host_time sampleTime:sample_time atRate:sample_rate]))
{
    YASRelease(_impl->av_audio_time);
}

bool audio_time::operator==(const audio_time &rhs) const
{
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

bool audio_time::operator!=(const audio_time &rhs) const
{
    return !(*this == rhs);
}

audio_time::operator bool() const
{
    return _impl != nullptr;
}

bool audio_time::is_host_time_valid() const
{
    if (_impl) {
        return _impl->av_audio_time.isHostTimeValid;
    } else {
        return false;
    }
}

UInt64 audio_time::host_time() const
{
    if (_impl) {
        return _impl->av_audio_time.hostTime;
    } else {
        return 0;
    }
}

bool audio_time::is_sample_time_valid() const
{
    if (_impl) {
        return _impl->av_audio_time.isSampleTimeValid;
    } else {
        return false;
    }
}

SInt64 audio_time::sample_time() const
{
    if (_impl) {
        return _impl->av_audio_time.sampleTime;
    } else {
        return 0;
    }
}

Float64 audio_time::sample_rate() const
{
    if (_impl) {
        return _impl->av_audio_time.sampleRate;
    } else {
        return 0.0;
    }
}

AudioTimeStamp audio_time::audio_time_stamp() const
{
    if (_impl) {
        return _impl->av_audio_time.audioTimeStamp;
    } else {
        return {0};
    }
}

audio_time audio_time::extrapolate_time_from_anchor(const audio_time &anchor_time)
{
    if (_impl) {
        AVAudioTime *time = [_impl->av_audio_time extrapolateTimeFromAnchor:anchor_time._impl->av_audio_time];
        return to_audio_time(time);
    } else {
        return audio_time();
    }
}

#pragma mark - global

UInt64 yas::host_time_for_seconds(Float64 seconds)
{
    return [AVAudioTime hostTimeForSeconds:seconds];
}

Float64 yas::seconds_for_host_time(UInt64 host_time)
{
    return [AVAudioTime secondsForHostTime:host_time];
}
