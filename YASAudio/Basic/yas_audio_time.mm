//
//  yas_audio_time.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_time.h"
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

audio_time_ptr audio_time::create(const AudioTimeStamp &ts, const Float64 sample_rate)
{
    return std::make_shared<audio_time>(ts, sample_rate);
}

audio_time_ptr audio_time::create(const UInt64 host_time)
{
    return std::make_shared<audio_time>(host_time);
}

audio_time_ptr audio_time::create(const SInt64 sample_time, const Float64 sample_rate)
{
    return std::make_shared<audio_time>(sample_time, sample_rate);
}

audio_time_ptr audio_time::create(const UInt64 host_time, const SInt64 sample_time, const Float64 sample_rate)
{
    return std::make_shared<audio_time>(host_time, sample_time, sample_rate);
}

audio_time::audio_time(const AudioTimeStamp &ts, const Float64 sample_rate)
    : _impl(std::make_unique<impl>([[AVAudioTime alloc] initWithAudioTimeStamp:&ts sampleRate:sample_rate]))
{
    YASRelease(_impl->av_audio_time);
}

audio_time::audio_time(const UInt64 host_time)
    : _impl(std::make_unique<impl>([[AVAudioTime alloc] initWithHostTime:host_time]))
{
    YASRelease(_impl->av_audio_time);
}

audio_time::audio_time(const SInt64 sample_time, const Float64 sample_rate)
    : _impl(std::make_unique<impl>([[AVAudioTime alloc] initWithSampleTime:sample_time atRate:sample_rate]))
{
    YASRelease(_impl->av_audio_time);
}

audio_time::audio_time(const UInt64 host_time, const SInt64 sample_time, const Float64 sample_rate)
    : _impl(std::make_unique<impl>(
          [[AVAudioTime alloc] initWithHostTime:host_time sampleTime:sample_time atRate:sample_rate]))
{
    YASRelease(_impl->av_audio_time);
}

audio_time::audio_time(AVAudioTime *av_audio_time) : _impl(std::make_unique<impl>(av_audio_time))
{
}

audio_time::audio_time(const audio_time &time) : _impl(std::make_unique<impl>(time._impl->av_audio_time))
{
}

audio_time::audio_time(audio_time &&time) noexcept
{
    _impl = std::move(time._impl);
}

audio_time &audio_time::operator=(const audio_time &time)
{
    if (this == &time) {
        return *this;
    }
    _impl = std::make_unique<impl>(time._impl->av_audio_time);
    return *this;
}

audio_time &audio_time::operator=(audio_time &&time) noexcept
{
    if (this == &time) {
        return *this;
    }
    _impl = std::move(time._impl);
    return *this;
}

audio_time::~audio_time()
{
}

bool audio_time::is_host_time_valid() const
{
    return _impl->av_audio_time.isHostTimeValid;
}

UInt64 audio_time::host_time() const
{
    return _impl->av_audio_time.hostTime;
}

bool audio_time::is_sample_time_valid() const
{
    return _impl->av_audio_time.isSampleTimeValid;
}

SInt64 audio_time::sample_time() const
{
    return _impl->av_audio_time.sampleTime;
}

Float64 audio_time::sample_rate() const
{
    return _impl->av_audio_time.sampleRate;
}

AudioTimeStamp audio_time::audio_time_stamp() const
{
    return _impl->av_audio_time.audioTimeStamp;
}

AVAudioTime *audio_time::av_audio_time() const
{
    return YASRetainAndAutorelease(_impl->av_audio_time);
}

audio_time audio_time::extrapolate_time_from_anchor(const audio_time &anchor_time)
{
    return audio_time([_impl->av_audio_time extrapolateTimeFromAnchor:anchor_time._impl->av_audio_time]);
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
