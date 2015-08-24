//
//  yas_audio_time.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <memory>

@class AVAudioTime;

namespace yas
{
    class audio_time;

    using audio_time_ptr = std::shared_ptr<audio_time>;

    class audio_time
    {
       public:
        static audio_time_ptr create(const AudioTimeStamp &ts, const Float64 sample_rate);
        static audio_time_ptr create(const UInt64 host_time);
        static audio_time_ptr create(const SInt64 sample_time, const Float64 sample_rate);
        static audio_time_ptr create(const UInt64 host_time, const SInt64 sample_time, const Float64 sample_rate);

        audio_time(const AudioTimeStamp &ts, const Float64 sample_rate);
        explicit audio_time(const UInt64 host_time);
        audio_time(const SInt64 sample_time, const Float64 sample_rate);
        audio_time(const UInt64 host_time, const SInt64 sample_time, const Float64 sample_rate);
        explicit audio_time(AVAudioTime *av_audio_time);
        ~audio_time();

        audio_time(const audio_time &);
        audio_time(audio_time &&) noexcept;
        audio_time &operator=(const audio_time &);
        audio_time &operator=(audio_time &&) noexcept;

        bool is_host_time_valid() const;
        UInt64 host_time() const;
        bool is_sample_time_valid() const;
        SInt64 sample_time() const;
        Float64 sample_rate() const;
        AudioTimeStamp audio_time_stamp() const;
        AVAudioTime *av_audio_time() const;

        audio_time extrapolate_time_from_anchor(const audio_time &anchor_time);

       private:
        class impl;
        std::unique_ptr<impl> _impl;
    };

    UInt64 host_time_for_seconds(Float64 seconds);
    Float64 seconds_for_host_time(UInt64 host_time);
}
