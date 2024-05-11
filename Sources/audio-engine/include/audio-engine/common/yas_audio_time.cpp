//
//  yas_audio_time.mm
//

#include "yas_audio_time.h"

#include <cpp-utils/yas_cf_utils.h>
#include <mach/mach_time.h>

#include <exception>
#include <string>

using namespace yas;
using namespace yas::audio;

namespace yas::audio::time_utils {
static AudioTimeStamp make_time_stamp_from_host_time(uint64_t const host_time) {
    AudioTimeStamp timeStamp{0};
    timeStamp.mHostTime = host_time;
    timeStamp.mFlags = kAudioTimeStampHostTimeValid;
    return timeStamp;
}

static AudioTimeStamp make_time_stamp_from_sample_time(uint64_t const sample_time) {
    AudioTimeStamp timeStamp{0};
    timeStamp.mSampleTime = sample_time;
    timeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    return timeStamp;
}

static AudioTimeStamp make_time_stamp(uint64_t const host_time, uint64_t const sample_time) {
    AudioTimeStamp timeStamp{0};
    timeStamp.mHostTime = host_time;
    timeStamp.mSampleTime = sample_time;
    timeStamp.mFlags = kAudioTimeStampSampleHostTimeValid;
    return timeStamp;
}

static bool is_equal(double const val1, double const val2, double const accuracy) {
    return ((val1 - accuracy) <= val2 && val2 <= (val1 + accuracy));
}

static bool is_equal(SMPTETime const &lhs, SMPTETime const &rhs) {
    return lhs.mSubframes == rhs.mSubframes && lhs.mSubframeDivisor == rhs.mSubframeDivisor &&
           lhs.mCounter == rhs.mCounter && lhs.mType == rhs.mType && lhs.mFlags == rhs.mFlags &&
           lhs.mHours == rhs.mHours && lhs.mMinutes == rhs.mMinutes && lhs.mSeconds == rhs.mSeconds &&
           lhs.mFrames == rhs.mFrames;
}

static bool is_equal(AudioTimeStamp const &lhs, AudioTimeStamp const &rhs) {
    return lhs.mHostTime == rhs.mHostTime && is_equal(lhs.mSampleTime, rhs.mSampleTime, 0.0001) &&
           lhs.mWordClockTime == rhs.mWordClockTime && is_equal(lhs.mRateScalar, rhs.mRateScalar, 0.0001) &&
           lhs.mFlags == rhs.mFlags && is_equal(lhs.mSMPTETime, rhs.mSMPTETime);
}

static mach_timebase_info_data_t const &timebase_info() {
    static mach_timebase_info_data_t _info{.numer = 0, .denom = 0};
    if (_info.denom == 0) {
        mach_timebase_info(&_info);
    }
    return _info;
}

static double const &host_time_to_seconds_rate() {
    static double _rate = 0.0;
    if (_rate == 0.0) {
        auto const &info = timebase_info();
        _rate = static_cast<double>(info.numer) / static_cast<double>(info.denom) / 1000000000.0;
    }
    return _rate;
}
}  // namespace yas::audio::time_utils

time::time(AudioTimeStamp const &time_stamp, double const sample_rate)
    : _time_stamp(time_stamp), _sample_rate(sample_rate) {
}

time::time(uint64_t const host_time) : _time_stamp(time_utils::make_time_stamp_from_host_time(host_time)) {
}

time::time(int64_t const sample_time, double const sample_rate)
    : _time_stamp(time_utils::make_time_stamp_from_sample_time(sample_time)), _sample_rate(sample_rate) {
}

time::time(uint64_t const host_time, int64_t const sample_time, double const sample_rate)
    : _time_stamp(time_utils::make_time_stamp(host_time, sample_time)), _sample_rate(sample_rate) {
}

bool time::is_host_time_valid() const {
    return this->_time_stamp.mFlags | kAudioTimeStampHostTimeValid;
}

uint64_t time::host_time() const {
    return this->_time_stamp.mHostTime;
}

bool time::is_sample_time_valid() const {
    return this->_time_stamp.mFlags | kAudioTimeStampSampleTimeValid;
}

int64_t time::sample_time() const {
    return this->_time_stamp.mSampleTime;
}

double time::sample_rate() const {
    return this->_sample_rate;
}

AudioTimeStamp time::audio_time_stamp() const {
    return this->_time_stamp;
}

bool time::operator==(time const &rhs) const {
    return time_utils::is_equal(this->_time_stamp, rhs._time_stamp) && this->_sample_rate == rhs._sample_rate;
}

bool time::operator!=(time const &rhs) const {
    return !(*this == rhs);
}

#pragma mark - global

uint64_t audio::host_time_for_seconds(double seconds) {
    return static_cast<uint64_t>(std::round(seconds / time_utils::host_time_to_seconds_rate()));
}

double audio::seconds_for_host_time(uint64_t host_time) {
    return static_cast<double>(host_time) * time_utils::host_time_to_seconds_rate();
}
