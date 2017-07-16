//
//  yas_audio_time.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class time : public base {
        class impl;

       public:
        time(std::nullptr_t);
        time(AudioTimeStamp const &ts, double const sample_rate);
        explicit time(uint64_t const host_time);
        time(int64_t const sample_time, double const sample_rate);
        time(uint64_t const host_time, int64_t const sample_time, double const sample_rate);

        virtual ~time() final;

        bool is_host_time_valid() const;
        uint64_t host_time() const;
        bool is_sample_time_valid() const;
        int64_t sample_time() const;
        double sample_rate() const;
        AudioTimeStamp audio_time_stamp() const;

        time extrapolate_time_from_anchor(time const &anchor_time);

        std::string description() const;
    };

    uint64_t host_time_for_seconds(double seconds);
    double seconds_for_host_time(uint64_t host_time);
}
std::string to_string(audio::time const &);
}
