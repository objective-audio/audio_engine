//
//  yas_audio_math.cpp
//

#include <Accelerate/Accelerate.h>
#include <math.h>
#include "yas_audio_math.h"

using namespace yas;

template <>
Float64 audio::math::decibel_from_linear(Float64 const linear) {
    return 20.0 * log10(linear);
}

template <>
Float32 audio::math::decibel_from_linear(Float32 const linear) {
    return 20.0f * log10f(linear);
}

template <>
Float64 audio::math::linear_from_decibel(Float64 const decibel) {
    return pow(10.0, decibel / 20.0);
}

template <>
Float32 audio::math::linear_from_decibel(Float32 const decibel) {
    return powf(10.0f, decibel / 20.0f);
}

template <>
Float64 audio::math::tempo_from_seconds(Float64 const seconds) {
    return pow(2, -log2(seconds)) * 60.0;
}

template <>
Float64 audio::math::seconds_from_tempo(Float64 const tempo) {
    return powf(2, -log2f(tempo / 60.0f));
}

Float64 audio::math::seconds_from_frames(UInt32 const frames, Float64 const sample_rate) {
    return static_cast<Float64>(frames) / sample_rate;
}

UInt32 audio::math::frames_from_seconds(Float64 const seconds, Float64 const sample_rate) {
    return seconds * sample_rate;
}

template <>
Float32 audio::math::fill_sine(Float32 *const out_data, UInt32 const length, Float64 const start_phase,
                               Float64 const phase_per_frame) {
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
audio::level<Float64>::level(Float64 const val) : _value(val) {
}

template <>
audio::level<Float32>::level(Float32 const val) : _value(val) {
}

template <>
bool audio::level<Float64>::operator==(level const &rhs) const {
    return _value == rhs._value;
}

template <>
bool audio::level<Float32>::operator==(level const &rhs) const {
    return _value == rhs._value;
}

template <>
bool audio::level<Float64>::operator!=(level const &rhs) const {
    return _value != rhs._value;
}

template <>
bool audio::level<Float32>::operator!=(level const &rhs) const {
    return _value != rhs._value;
}

template <>
void audio::level<Float64>::set_linear(Float64 const val) {
    _value = val;
}

template <>
void audio::level<Float32>::set_linear(Float32 const val) {
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
void audio::level<Float64>::set_decibel(Float64 const val) {
    _value = math::linear_from_decibel(val);
}

template <>
void audio::level<Float32>::set_decibel(Float32 const val) {
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

audio::duration::duration(Float64 const val) : _value(val) {
}

bool audio::duration::operator==(duration const &rhs) const {
    return _value == rhs._value;
}

bool audio::duration::operator!=(duration const &rhs) const {
    return _value != rhs._value;
}

void audio::duration::set_seconds(Float64 const val) {
    _value = val;
}

Float64 audio::duration::seconds() const {
    return _value;
}

void audio::duration::set_tempo(Float64 const val) {
    _value = math::seconds_from_tempo(val);
}

Float64 audio::duration::tempo() const {
    return math::tempo_from_seconds(_value);
}
