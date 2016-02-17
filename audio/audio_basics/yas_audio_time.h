//
//  yas_audio_time.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include "yas_audio_types.h"

namespace yas {
namespace audio {
    class time {
       public:
        time(std::nullptr_t);
        time(AudioTimeStamp const &ts, Float64 const sample_rate);
        explicit time(UInt64 const host_time);
        time(SInt64 const sample_time, Float64 const sample_rate);
        time(UInt64 const host_time, SInt64 const sample_time, Float64 const sample_rate);

        ~time() = default;

        time(time const &) = default;
        time(time &&) = default;
        time &operator=(time const &) = default;
        time &operator=(time &&) = default;

        bool operator==(time const &) const;
        bool operator!=(time const &) const;

        explicit operator bool() const;

        bool is_host_time_valid() const;
        UInt64 host_time() const;
        bool is_sample_time_valid() const;
        SInt64 sample_time() const;
        Float64 sample_rate() const;
        AudioTimeStamp audio_time_stamp() const;

        time extrapolate_time_from_anchor(time const &anchor_time);

       private:
        class impl;
        std::shared_ptr<impl> _impl;
    };

    UInt64 host_time_for_seconds(Float64 seconds);
    Float64 seconds_for_host_time(UInt64 host_time);
}
}
