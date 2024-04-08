//
//  yas_audio_math.cpp
//

#include <Accelerate/Accelerate.h>
#include <audio/utils/yas_audio_math.h>

using namespace yas;
using namespace yas::audio;

template <>
double math::decibel_from_linear(double const linear) {
    return 20.0 * std::log10(linear);
}

template <>
float math::decibel_from_linear(float const linear) {
    return 20.0f * std::log10f(linear);
}

template <>
double math::linear_from_decibel(double const decibel) {
    return std::pow(10.0, decibel / 20.0);
}

template <>
float math::linear_from_decibel(float const decibel) {
    return std::powf(10.0f, decibel / 20.0f);
}

template <>
double math::tempo_from_seconds(double const seconds) {
    return std::pow(2.0, -std::log2(seconds)) * 60.0;
}

template <>
double math::seconds_from_tempo(double const tempo) {
    return std::powf(2.0, -std::log2f(tempo / 60.0f));
}

double math::seconds_from_frames(uint32_t const frames, double const sample_rate) {
    return static_cast<double>(frames) / sample_rate;
}

uint32_t math::frames_from_seconds(double const seconds, double const sample_rate) {
    return seconds * sample_rate;
}

template <>
float math::fill_sine(float *const out_data, uint32_t const length, double const start_phase,
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
level<double>::level() : _value(0.0) {
}

template <>
level<float>::level() : _value(0.0f) {
}

template <>
level<double>::level(double const val) : _value(val) {
}

template <>
level<float>::level(float const val) : _value(val) {
}

template <>
bool level<double>::operator==(level const &rhs) const {
    return _value == rhs._value;
}

template <>
bool level<float>::operator==(level const &rhs) const {
    return _value == rhs._value;
}

template <>
bool level<double>::operator!=(level const &rhs) const {
    return _value != rhs._value;
}

template <>
bool level<float>::operator!=(level const &rhs) const {
    return _value != rhs._value;
}

template <>
void level<double>::set_linear(double const val) {
    _value = val;
}

template <>
void level<float>::set_linear(float const val) {
    _value = val;
}

template <>
double level<double>::linear() const {
    return _value;
}

template <>
float level<float>::linear() const {
    return _value;
}

template <>
void level<double>::set_decibel(double const val) {
    _value = math::linear_from_decibel(val);
}

template <>
void level<float>::set_decibel(float const val) {
    _value = math::linear_from_decibel(val);
}

template <>
double level<double>::decibel() const {
    return math::decibel_from_linear(_value);
}

template <>
float level<float>::decibel() const {
    return math::decibel_from_linear(_value);
}

#pragma mark - duration

duration::duration() : _value(0.0) {
}

duration::duration(double const val) : _value(val) {
}

bool duration::operator==(duration const &rhs) const {
    return _value == rhs._value;
}

bool duration::operator!=(duration const &rhs) const {
    return _value != rhs._value;
}

void duration::set_seconds(double const val) {
    _value = val;
}

double duration::seconds() const {
    return _value;
}

void duration::set_tempo(double const val) {
    _value = math::seconds_from_tempo(val);
}

double duration::tempo() const {
    return math::tempo_from_seconds(_value);
}
