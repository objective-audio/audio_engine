//
//  yas_audio_math.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <MacTypes.h>
#include <math.h>

namespace yas
{
    class audio_math
    {
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
}