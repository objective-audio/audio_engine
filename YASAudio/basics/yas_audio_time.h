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
    namespace audio
    {
        class time
        {
           public:
            time(std::nullptr_t n = nullptr);
            time(const AudioTimeStamp &ts, const Float64 sample_rate);
            explicit time(const UInt64 host_time);
            time(const SInt64 sample_time, const Float64 sample_rate);
            time(const UInt64 host_time, const SInt64 sample_time, const Float64 sample_rate);

            ~time() = default;

            time(const time &) = default;
            time(time &&) = default;
            time &operator=(const time &) = default;
            time &operator=(time &&) = default;

            bool operator==(const time &) const;
            bool operator!=(const time &) const;

            explicit operator bool() const;

            bool is_host_time_valid() const;
            UInt64 host_time() const;
            bool is_sample_time_valid() const;
            SInt64 sample_time() const;
            Float64 sample_rate() const;
            AudioTimeStamp audio_time_stamp() const;

            time extrapolate_time_from_anchor(const time &anchor_time);

           private:
            class impl;
            std::shared_ptr<impl> _impl;
        };

        UInt64 host_time_for_seconds(Float64 seconds);
        Float64 seconds_for_host_time(UInt64 host_time);
    }
}
