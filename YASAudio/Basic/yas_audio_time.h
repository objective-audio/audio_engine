//
//  yas_audio_time.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include <AudioToolbox/AudioToolbox.h>
#include <memory>

namespace yas
{
    class audio_time
    {
       public:
        audio_time();
        audio_time(const std::nullptr_t &);
        audio_time(const AudioTimeStamp &ts, const Float64 sample_rate);
        explicit audio_time(const UInt64 host_time);
        audio_time(const SInt64 sample_time, const Float64 sample_rate);
        audio_time(const UInt64 host_time, const SInt64 sample_time, const Float64 sample_rate);

        ~audio_time() = default;

        audio_time(const audio_time &) = default;
        audio_time(audio_time &&) = default;
        audio_time &operator=(const audio_time &) = default;
        audio_time &operator=(audio_time &&) = default;

        bool operator==(const audio_time &) const;
        bool operator!=(const audio_time &) const;

        explicit operator bool() const;

        bool is_host_time_valid() const;
        UInt64 host_time() const;
        bool is_sample_time_valid() const;
        SInt64 sample_time() const;
        Float64 sample_rate() const;
        AudioTimeStamp audio_time_stamp() const;

        audio_time extrapolate_time_from_anchor(const audio_time &anchor_time);

       private:
        class impl;
        std::shared_ptr<impl> _impl;
    };

    UInt64 host_time_for_seconds(Float64 seconds);
    Float64 seconds_for_host_time(UInt64 host_time);
}
