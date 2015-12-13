//
//  yas_audio_math.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include <Accelerate/Accelerate.h>
#include <math.h>
#include "yas_audio_math.h"

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

#pragma mark - level

template <>
audio::level<Float64>::level() : _value(0.0) {
}

template <>
audio::level<Float32>::level() : _value(0.0f) {
}

template <>
audio::level<Float64>::level(const Float64 val) : _value(val) {
}

template <>
audio::level<Float32>::level(const Float32 val) : _value(val) {
}

template <>
bool audio::level<Float64>::operator==(const level &rhs) const {
    return _value == rhs._value;
}

template <>
bool audio::level<Float32>::operator==(const level &rhs) const {
    return _value == rhs._value;
}

template <>
bool audio::level<Float64>::operator!=(const level &rhs) const {
    return _value != rhs._value;
}

template <>
bool audio::level<Float32>::operator!=(const level &rhs) const {
    return _value != rhs._value;
}

template <>
void audio::level<Float64>::set_linear(const Float64 val) {
    _value = val;
}

template <>
void audio::level<Float32>::set_linear(const Float32 val) {
    _value = val;
}

template <>
Float64 audio::level<Float64>::linear() const {
    return _value;
}

template <>
Float32 audio::level<Float32>::linear() const {
    return _value;
}

template <>
void audio::level<Float64>::set_decibel(const Float64 val) {
    _value = math::linear_from_decibel(val);
}

template <>
void audio::level<Float32>::set_decibel(const Float32 val) {
    _value = math::linear_from_decibel(val);
}

template <>
Float64 audio::level<Float64>::decibel() const {
    return math::decibel_from_linear(_value);
}

template <>
Float32 audio::level<Float32>::decibel() const {
    return math::decibel_from_linear(_value);
}

#pragma mark - duration

audio::duration::duration() : _value(0.0) {
}

audio::duration::duration(const Float64 val) : _value(val) {
}

bool audio::duration::operator==(const duration &rhs) const {
    return _value == rhs._value;
}

bool audio::duration::operator!=(const duration &rhs) const {
    return _value != rhs._value;
}

void audio::duration::set_seconds(const Float64 val) {
    _value = val;
}

Float64 audio::duration::seconds() const {
    return _value;
}

void audio::duration::set_tempo(const Float64 val) {
    _value = math::seconds_from_tempo(val);
}

Float64 audio::duration::tempo() const {
    return math::tempo_from_seconds(_value);
}
