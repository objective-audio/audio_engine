//
//  yas_audio_math.cpp
//

#include <Accelerate/Accelerate.h>
#include <math.h>
#include "yas_audio_math.h"

using namespace yas;

template <>
double audio::math::decibel_from_linear(double const linear) {
    return 20.0 * log10(linear);
}

template <>
float audio::math::decibel_from_linear(float const linear) {
    return 20.0f * log10f(linear);
}

template <>
double audio::math::linear_from_decibel(double const decibel) {
    return pow(10.0, decibel / 20.0);
}

template <>
float audio::math::linear_from_decibel(float const decibel) {
    return powf(10.0f, decibel / 20.0f);
}

template <>
double audio::math::tempo_from_seconds(double const seconds) {
    return pow(2, -log2(seconds)) * 60.0;
}

template <>
double audio::math::seconds_from_tempo(double const tempo) {
    return powf(2, -log2f(tempo / 60.0f));
}

double audio::math::seconds_from_frames(uint32_t const frames, double const sample_rate) {
    return static_cast<double>(frames) / sample_rate;
}

uint32_t audio::math::frames_from_seconds(double const seconds, double const sample_rate) {
    return seconds * sample_rate;
}

template <>
float audio::math::fill_sine(float *const out_data, uint32_t const length, double const start_phase,
                             double const phase_per_frame) {
    if (!out_data || length == 0) {
        return start_phase;
    }

    double phase = start_phase;

    for (uint32_t i = 0; i < length; ++i) {
        out_data[i] = phase;
        phase = fmod(phase + phase_per_frame, two_pi);
    }

    int const len = length;
    vvsinf(out_data, out_data, &len);

    return phase;
}

#pragma mark - level

template <>
audio::level<double>::level() : _value(0.0) {
}

template <>
audio::level<float>::level() : _value(0.0f) {
}

template <>
audio::level<double>::level(double const val) : _value(val) {
}

template <>
audio::level<float>::level(float const val) : _value(val) {
}

template <>
bool audio::level<double>::operator==(level const &rhs) const {
    return _value == rhs._value;
}

template <>
bool audio::level<float>::operator==(level const &rhs) const {
    return _value == rhs._value;
}

template <>
bool audio::level<double>::operator!=(level const &rhs) const {
    return _value != rhs._value;
}

template <>
bool audio::level<float>::operator!=(level const &rhs) const {
    return _value != rhs._value;
}

template <>
void audio::level<double>::set_linear(double const val) {
    _value = val;
}

template <>
void audio::level<float>::set_linear(float const val) {
    _value = val;
}

template <>
double audio::level<double>::linear() const {
    return _value;
}

template <>
float audio::level<float>::linear() const {
    return _value;
}

template <>
void audio::level<double>::set_decibel(double const val) {
    _value = math::linear_from_decibel(val);
}

template <>
void audio::level<float>::set_decibel(float const val) {
    _value = math::linear_from_decibel(val);
}

template <>
double audio::level<double>::decibel() const {
    return math::decibel_from_linear(_value);
}

template <>
float audio::level<float>::decibel() const {
    return math::decibel_from_linear(_value);
}

#pragma mark - duration

audio::duration::duration() : _value(0.0) {
}

audio::duration::duration(double const val) : _value(val) {
}

bool audio::duration::operator==(duration const &rhs) const {
    return _value == rhs._value;
}

bool audio::duration::operator!=(duration const &rhs) const {
    return _value != rhs._value;
}

void audio::duration::set_seconds(double const val) {
    _value = val;
}

double audio::duration::seconds() const {
    return _value;
}

void audio::duration::set_tempo(double const val) {
    _value = math::seconds_from_tempo(val);
}

double audio::duration::tempo() const {
    return math::tempo_from_seconds(_value);
}
