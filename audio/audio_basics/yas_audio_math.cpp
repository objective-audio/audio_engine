//
//  yas_audio_math.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_math.h"
#include <math.h>
#include <Accelerate/Accelerate.h>

using namespace yas;

template <>
Float64 audio::math::decibel_from_linear(const Float64 linear) {
    return 20.0 * log10(linear);
}

template <>
Float32 audio::math::decibel_from_linear(const Float32 linear) {
    return 20.0f * log10f(linear);
}

template <>
Float64 audio::math::linear_from_decibel(const Float64 decibel) {
    return pow(10.0, decibel / 20.0);
}

template <>
Float32 audio::math::linear_from_decibel(const Float32 decibel) {
    return powf(10.0f, decibel / 20.0f);
}

template <>
Float64 audio::math::tempo_from_seconds(const Float64 seconds) {
    return pow(2, -log2(seconds)) * 60.0;
}

template <>
Float64 audio::math::seconds_from_tempo(const Float64 tempo) {
    return powf(2, -log2f(tempo / 60.0f));
}

Float64 audio::math::seconds_from_frames(const UInt32 frames, const Float64 sample_rate) {
    return static_cast<Float64>(frames) / sample_rate;
}

UInt32 audio::math::frames_from_seconds(const Float64 seconds, const Float64 sample_rate) {
    return seconds * sample_rate;
}

template <>
Float32 audio::math::fill_sine(Float32 *const out_data, const UInt32 length, const Float64 start_phase,
                               const Float64 phase_per_frame) {
    if (!out_data || length == 0) {
        return start_phase;
    }

    Float64 phase = start_phase;

    for (UInt32 i = 0; i < length; ++i) {
        out_data[i] = phase;
        phase = fmod(phase + phase_per_frame, two_pi);
    }

    const int len = length;
    vvsinf(out_data, out_data, &len);

    return phase;
}
