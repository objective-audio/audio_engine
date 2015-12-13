//
//  yas_audio_math.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <MacTypes.h>
#include <math.h>

namespace yas {
namespace audio {
    class math {
       public:
        static constexpr Float64 two_pi = M_PI * 2.0;

        template <typename T>
        static auto decibel_from_linear(const T linear) -> T;

        template <typename T>
        static auto linear_from_decibel(const T decibel) -> T;

        template <typename T>
        static auto tempo_from_seconds(const T seconds) -> T;

        template <typename T>
        static auto seconds_from_tempo(const T tempo) -> T;

        static Float64 seconds_from_frames(const UInt32 frames, const Float64 sample_rate);
        static UInt32 frames_from_seconds(const Float64 seconds, const Float64 sample_rate);

        template <typename T>
        static auto fill_sine(T *const out_data, const UInt32 length, const Float64 start_phase,
                              const Float64 phase_per_frame) -> T;
    };

    template <typename T>
    class level {
       public:
        level();
        level(const T val);

        bool operator==(const level &) const;
        bool operator!=(const level &) const;

        void set_linear(const T val);
        T linear() const;

        void set_decibel(const T val);
        T decibel() const;

       private:
        T _value;
    };

    class duration {
       public:
        duration();
        duration(const Float64 val);

        bool operator==(const duration &) const;
        bool operator!=(const duration &) const;

        void set_seconds(const Float64 val);
        Float64 seconds() const;

        void set_tempo(const Float64 val);
        Float64 tempo() const;

       private:
        Float64 _value;
    };
}
}