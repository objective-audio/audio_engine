//
//  time.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <audio-engine/common/ptr.h>
#include <audio-engine/common/types.h>

namespace yas::audio {
struct time final {
    time(AudioTimeStamp const &ts, double const sample_rate);
    explicit time(uint64_t const host_time);
    time(int64_t const sample_time, double const sample_rate);
    time(uint64_t const host_time, int64_t const sample_time, double const sample_rate);

    [[nodiscard]] bool is_host_time_valid() const;
    [[nodiscard]] uint64_t host_time() const;
    [[nodiscard]] bool is_sample_time_valid() const;
    [[nodiscard]] int64_t sample_time() const;
    [[nodiscard]] double sample_rate() const;
    [[nodiscard]] AudioTimeStamp audio_time_stamp() const;

    bool operator==(time const &) const;
    bool operator!=(time const &) const;

   private:
    AudioTimeStamp _time_stamp;
    double _sample_rate = 0;
};

static std::optional<time> const null_time_opt{std::nullopt};
static std::optional<time_ptr> const null_time_ptr_opt{std::nullopt};

uint64_t host_time_for_seconds(double seconds);
double seconds_for_host_time(uint64_t host_time);
}  // namespace yas::audio
